class_name RivalManager
extends RefCounted
## Road Rash-style AI opponents (minus the combat): a named roster of rivals
## racing the same start-to-finish run as the player at comparable speeds.
##
## Behavior model:
##  - Each rival has a personality cruise speed (the roster is a ladder from
##    beatable to genuinely fast) and a preferred lane.
##  - They brake for curves proportionally to severity — out-cornering them
##    is the player's main edge, exactly like out-riding the Road Rash pack.
##  - Mild rubber-banding keeps the pack racing instead of stringing out.
##  - They swerve around traffic, each other, and the player (reusing the
##    traffic avoidance AI), hug apexes, and bonk into traffic when a dodge
##    fails, which costs them dearly.
##  - Progress is tracked monotonically for live ranking ("3rd/10").
##
## Owned by main.gd; rivals live in the same per-segment car lists as
## traffic, so rendering, mutual avoidance, and player collision all work
## on them with no special cases.

# === CONFIG ===

## Pack tuning and roster come from resources/race_settings.tres via the
## GameConfig autoload; per-rival personality from resources/rivals/*.tres.
var cfg: RaceSettings = GameConfig.race

var rivals: Array = []
var events: Array[String] = []    # overtake messages, consumed by main each frame
var leader_cp_times: Array[float] = []   # best rival time at each checkpoint


# === LIFECYCLE ===

## Grid the roster just ahead of the start line: the player begins last
## and races through the pack, Road Rash style.
func spawn(main: Node2D, count: int) -> void:
	rivals.clear()
	leader_cp_times.clear()
	for k in range(int(main.total_cps())):
		leader_cp_times.append(-1.0)
	var n := clampi(count, 0, cfg.roster.size())
	for i in range(n):
		var profile: RivalProfile = cfg.roster[i]
		SpriteCatalog.register_rival(i, profile)
		var rival := {
			"name": profile.display_name,
			"sprite": "rival_%d" % i,
			"z": cfg.grid_gap * float(i + 1),
			"offset": -0.45 if i % 2 == 0 else 0.45,
			"lane": profile.preferred_lane,
			"speed": 0.0,          # standing start behind the countdown
			# Form: a per-race roll on cruise, so grid order doesn't
			# script the finish and different races have different heroes.
			"base_speed": (profile.cruise_fraction + randf_range(
					-cfg.form_variance, cfg.form_variance))
					* GameConfig.player.max_speed,
			"bonk_t": 0.0,
			"dodge_dir": 0.0,      # committed dodge direction (hysteresis)
			"dodge_t": 0.0,        # time remaining on the commitment
			"next_cp": 0,          # index of the next checkpoint to cross
			"finish_time": -1.0,   # race clock at the finish line, -1 = racing
			"y": main.ground_y(cfg.grid_gap * float(i + 1)), "vy": 0.0, "air": 0.0,
			"boost": profile.boost_capacity,
			"slip": 0.0,
			"prev_curve": 0.0,
			"boost_cap": profile.boost_capacity,
			"boosting": false,
			"aggression": profile.boost_aggression,
			"was_ahead": true,
			"finished": false,
		}
		rivals.append(rival)
		var seg: Dictionary = main.find_segment(float(rival.z))
		seg.cars.append(rival)


# === PER-FRAME UPDATE ===

func update(dt: float, main: Node2D) -> void:
	events.clear()
	var track_len: float = main.track.track_length()
	# All player-relative behavior (rubber band, boost attacks, flashes)
	# references the LEAD player; avoidance of every player happens through
	# their mirror entities in the segment car lists.
	var lead_progress: float = main.lead_progress()

	for ri in range(rivals.size()):
		var r: Dictionary = rivals[ri]
		var old_seg: Dictionary = main.find_segment(float(r.z))
		var seg_count: int = main.track.segments.size()
		var rival_w: float = SpriteCatalog.get_def(r.sprite).world_w \
				/ RoadRenderer.ROAD_WIDTH

		# --- Target speed: personality, corners, rubber band. ---
		var target: float = r.base_speed
		target *= 1.0 - minf(cfg.curve_slowdown_cap,
				absf(float(old_seg.curve)) * cfg.curve_slowdown)
		var gap: float = float(r.z) - lead_progress
		if gap > cfg.rubber_range:
			target *= cfg.rubber_ahead
		elif gap < -cfg.rubber_range:
			target = minf(target * cfg.rubber_behind, GameConfig.player.max_speed * 1.0)
		var aggr: float = float(r.aggression)

		# --- Pack momentum: the fake extension of drafting. Rivals running
		# in a group carry each other — a bonus per nearby rival, capped —
		# so one big train or several splinter groups bridge gaps a lone
		# car never could. Applied after the rubber clamp: packs genuinely
		# exceed the normal ceilings. ---
		var pack_n := 0
		for oj in range(rivals.size()):
			if oj != ri and not bool(rivals[oj].finished) \
					and absf(float(rivals[oj].z) - float(r.z)) < cfg.pack_radius:
				pack_n += 1
		target *= 1.0 + cfg.pack_bonus_per_car * float(mini(pack_n, cfg.pack_max_stack))

		# --- Drafting: the same slipstream physics the player has, off
		# traffic, other rivals, and player mirrors. A chase train runs
		# faster than a lone leader; applied after the rubber clamp, this
		# is the honest gap-closer. ---
		var ps: PlayerSettings = GameConfig.player
		var in_stream := false
		if float(r.speed) / ps.max_speed > ps.slip_min_speed \
				and float(r.air) < 10.0:
			for k in range(1, ps.slip_segments + 1):
				var sseg: Dictionary = main.track.segments[
						(int(old_seg.index) + k) % seg_count]
				for other in sseg.cars:
					if other == r:
						continue
					if absf(float(other.offset) - float(r.offset)) < ps.slip_lateral:
						in_stream = true
						break
				if in_stream:
					break
		r.slip = move_toward(float(r.slip), 1.0 if in_stream else 0.0,
				dt / ps.slip_build_time)
		target *= 1.0 + ps.slip_top_bonus * float(r.slip)

		# --- Boost policy: burn fuel on straights while attacking the
		# player from behind or sprinting for the line. Aggression sets
		# how quickly a rival takes a valid opening (applied AFTER the
		# rubber clamp — boost genuinely exceeds normal ceilings).
		var straight := absf(float(old_seg.curve)) <= cfg.boost_curve_threshold
		# Corner exits are prime boost real estate: just left a corner,
		# road now open. Chasing = far behind the lead — burn to close.
		var exiting: bool = straight \
				and absf(float(r.prev_curve)) > cfg.boost_curve_threshold
		r.prev_curve = old_seg.curve
		if bool(r.boosting):
			if not straight or float(r.boost) <= 0.0:
				r.boosting = false
		elif straight and float(r.boost) > 0.4 and float(r.air) < 10.0:
			var sprinting: bool = float(r.z) \
					> float(main.race_length()) * cfg.final_sprint_fraction
			var attacking := gap < 0.0 and gap > -cfg.boost_attack_range
			var chasing := gap < -cfg.rubber_range
			if (sprinting or attacking or chasing or exiting) \
					and randf() < aggr * dt * (4.0 if exiting else 2.0):
				r.boosting = true
		if bool(r.boosting):
			r.boost = maxf(0.0, float(r.boost) - dt)
			target *= 1.0 + GameConfig.player.boost_top_bonus

		r.speed = move_toward(float(r.speed), target,
				cfg.accel * (1.0 + ps.slip_accel_bonus * float(r.slip)) * dt)

		# --- Steering: dodge obstacles, otherwise run the racing line.
		# Dodges are COMMITTED: the first dodge signal latches a direction
		# for cfg.dodge_commit seconds, refreshed by same-direction signals and
		# deaf to opposite ones. Without this, per-frame dodge impulses
		# alternate with lane-keeping pulling back toward the obstacle and
		# the rival vibrates instead of swerving. ---
		var dodge: float = main._car_steer(r, old_seg, cfg.lookahead)
		if absf(dodge) > 0.0001 \
				and (float(r.dodge_t) <= 0.0 or signf(dodge) == float(r.dodge_dir)):
			r.dodge_dir = signf(dodge)
			r.dodge_t = cfg.dodge_commit
		if float(r.dodge_t) > 0.0:
			r.dodge_t = float(r.dodge_t) - dt
			r.offset = float(r.offset) + float(r.dodge_dir) * cfg.dodge_rate * dt \
					* (float(r.speed) / GameConfig.player.max_speed)
		else:
			# Hungry rivals steer for canisters ahead; otherwise run the
			# racing line. Dodges (above) always take priority.
			var goal: float = clampf(
					float(r.lane) - float(old_seg.curve) * cfg.apex_bias, -0.85, 0.85)
			if float(r.boost) < float(r.boost_cap) - cfg.pickup_boost_amount * 0.5:
				for k in range(1, cfg.lookahead):
					var pseg: Dictionary = main.track.segments[
							(int(old_seg.index) + k) % seg_count]
					var found := false
					for pu in pseg.pickups:
						if not bool(pu.taken):
							goal = clampf(float(pu.offset), -0.85, 0.85)
							found = true
							break
					if found:
						break
			r.offset = move_toward(float(r.offset), goal,
					dt * cfg.lateral_speed * (float(r.speed) / GameConfig.player.max_speed))
		r.offset = clampf(float(r.offset), -1.0, 1.0)

		# --- Advance (z is monotonic race progress; fposmod wraps for
		# segment lookup and rendering). ---
		var g_prev: float = main.ground_y(float(r.z))
		r.z = float(r.z) + float(r.speed) * dt
		main._step_air(r, g_prev, dt)
		var new_seg: Dictionary = main.find_segment(float(r.z))
		if old_seg.index != new_seg.index:
			old_seg.cars.erase(r)
			new_seg.cars.append(r)

		# --- Boost pickups: first racer through takes it. ---
		for pu in new_seg.pickups:
			if not bool(pu.taken) \
					and absf(float(pu.offset) - float(r.offset)) < 0.45:
				pu.taken = true
				pu.respawn_t = cfg.pickup_respawn
				r.boost = minf(float(r.boost) + cfg.pickup_boost_amount,
						float(r.boost_cap))

		# --- Bonk: a dodge that failed. Hitting slow traffic hurts. ---
		# Only near the player: beyond the dodge AI's active range rivals
		# are simulated abstractly, and punishing them for collisions they
		# were never allowed to avoid would be unfair (and invisible).
		r.bonk_t = maxf(0.0, float(r.bonk_t) - dt)
		var simulated_range: float = GameConfig.camera.draw_distance * TrackBuilder.SEGMENT_LENGTH
		if float(r.bonk_t) <= 0.0 and absf(gap) < simulated_range \
				and float(r.air) < 250.0:
			for other in new_seg.cars:
				if other == r:
					continue
				if float(other.speed) < float(r.speed) * 0.7 \
						and _overlap(float(r.offset), rival_w, float(other.offset),
								SpriteCatalog.get_def(other.sprite).world_w
								/ RoadRenderer.ROAD_WIDTH, 0.9):
					r.speed = float(r.speed) * cfg.bonk_speed_cut
					r.bonk_t = cfg.bonk_cooldown
					break

		# --- Checkpoint and finish times, lap-aware: checkpoint indices run
		# through every lap (index -> lap * per-lap-count + local). ---
		while int(r.next_cp) < leader_cp_times.size() \
				and float(r.z) >= main.cp_progress_z(int(r.next_cp)):
			var k: int = int(r.next_cp)
			if leader_cp_times[k] < 0.0 or float(main.race_time) < leader_cp_times[k]:
				leader_cp_times[k] = float(main.race_time)
			r.next_cp = k + 1
		if not bool(r.finished) and float(r.z) >= main.race_length():
			r.finished = true
			r.finish_time = float(main.race_time)

		# --- Overtake events (solo only; measured against the lead player). ---
		var ahead := float(r.z) > lead_progress
		if ahead != bool(r.was_ahead) and absf(gap) < cfg.flash_range:
			if ahead:
				events.append("%s PASSED YOU" % r.name)
			else:
				events.append("PASSED %s!" % r.name)
		r.was_ahead = ahead


# === RANKING ===

func player_rank(player_progress: float) -> int:
	var rank := 1
	for r in rivals:
		if float(r.z) > player_progress:
			rank += 1
	return rank


func total_racers() -> int:
	return rivals.size() + 1


static func _overlap(x1: float, w1: float, x2: float, w2: float,
		percent: float = 1.0) -> bool:
	var half := percent * 0.5
	return not (x1 + w1 * half < x2 - w2 * half or x1 - w1 * half > x2 + w2 * half)


## Live results: finished racers sorted by time, then still-racing rivals in
## their current running order with no time (they fill in as they cross —
## refresh each frame while the board is up). The player row's index is the
## final rank.
func board_entries(player_time: float) -> Array:
	var finished: Array = [
		{"name": "YOU", "time": player_time, "is_player": true},
	]
	var racing: Array = []
	for r in rivals:
		if float(r.finish_time) >= 0.0:
			finished.append({"name": r.name, "time": float(r.finish_time),
					"is_player": false})
		else:
			racing.append({"name": r.name, "time": -1.0, "is_player": false,
					"z": float(r.z)})
	finished.sort_custom(func(a, b): return float(a.time) < float(b.time))
	racing.sort_custom(func(a, b): return float(a.z) > float(b.z))
	return finished + racing


## Projected seconds until the best-placed rival still short of a checkpoint
## reaches it — the "how far ahead am I?" number when the player leads.
func next_rival_eta(cp_z: float) -> float:
	var best := INF
	for r in rivals:
		if float(r.z) < cp_z:
			var eta: float = (cp_z - float(r.z)) \
					/ maxf(float(r.speed), GameConfig.player.max_speed * 0.2)
			best = minf(best, eta)
	return best if best < INF else 0.0
