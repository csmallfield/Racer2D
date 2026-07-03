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

# === TUNING ===

const NAMES: Array[String] = [
	"VIPER", "NATASHA", "BIFF", "SLATER", "ROXY",
	"DIABLO", "JUNKO", "AXEL", "GROG",
]
const GRID_GAP := 500.0           # world units between grid slots at the start
const CRUISE_MIN := 0.80          # slowest rival cruise, fraction of MAX_SPEED
const CRUISE_MAX := 0.96          # fastest rival cruise
const CURVE_SLOWDOWN := 0.045     # cruise loss per unit of curve severity
const CURVE_SLOWDOWN_CAP := 0.32
const APEX_BIAS := 0.08           # how far rivals cut toward a curve's inside
const LATERAL_SPEED := 1.0        # lane-keeping drift, road-halves per second
const DODGE_COMMIT := 0.5         # seconds a rival commits to a dodge direction
const DODGE_RATE := 1.3           # committed dodge drift, road-halves/s at full speed
const ACCEL := PlayerCar.MAX_SPEED / 4.0
const RUBBER_RANGE := 15000.0     # gap beyond which rubber-banding kicks in
const RUBBER_AHEAD := 0.93        # leaders ease off
const RUBBER_BEHIND := 1.07       # stragglers push (capped below player max)
const BONK_SPEED_CUT := 0.5       # hitting traffic halves a rival's speed
const BONK_COOLDOWN := 2.0
const RAM_DISTANCE := 700.0       # tuck-behind range for matching player speed
const FLASH_RANGE := 2500.0       # overtakes flash only when they happen nearby

var rivals: Array = []
var events: Array[String] = []    # overtake messages, consumed by main each frame
var leader_cp_times: Array[float] = []   # best rival time at each checkpoint


# === LIFECYCLE ===

## Grid the roster just ahead of the start line: the player begins last
## and races through the pack, Road Rash style.
func spawn(main: Node2D, count: int) -> void:
	rivals.clear()
	leader_cp_times.clear()
	var cp_count: int = main.cp_zs.size()
	for k in range(cp_count):
		leader_cp_times.append(-1.0)
	var n := clampi(count, 1, NAMES.size())
	for i in range(n):
		var t := float(i) / float(maxi(1, n - 1))
		var base: float = lerpf(CRUISE_MIN, CRUISE_MAX, t) * PlayerCar.MAX_SPEED
		var rival := {
			"name": NAMES[i],
			"sprite": "rival_%d" % i,
			"z": GRID_GAP * float(i + 1),
			"offset": -0.45 if i % 2 == 0 else 0.45,
			"lane": randf_range(0.25, 0.55) * (-1.0 if i % 2 == 0 else 1.0),
			"speed": 0.0,          # standing start behind the countdown
			"base_speed": base,
			"bonk_t": 0.0,
			"dodge_dir": 0.0,      # committed dodge direction (hysteresis)
			"dodge_t": 0.0,        # time remaining on the commitment
			"next_cp": 0,          # index of the next checkpoint to cross
			"finish_time": -1.0,   # race clock at the finish line, -1 = racing
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
	var player: PlayerCar = main.player
	var player_seg: Dictionary = main.find_segment(player.position_z)
	var player_w: float = SpriteCatalog.get_def("player").world_w \
			/ RoadRenderer.ROAD_WIDTH

	for r in rivals:
		var old_seg: Dictionary = main.find_segment(float(r.z))
		var rival_w: float = SpriteCatalog.get_def(r.sprite).world_w \
				/ RoadRenderer.ROAD_WIDTH

		# --- Target speed: personality, corners, rubber band. ---
		var target: float = r.base_speed
		target *= 1.0 - minf(CURVE_SLOWDOWN_CAP,
				absf(float(old_seg.curve)) * CURVE_SLOWDOWN)
		var gap: float = float(r.z) - player.position_z
		if gap > RUBBER_RANGE:
			target *= RUBBER_AHEAD
		elif gap < -RUBBER_RANGE:
			target = minf(target * RUBBER_BEHIND, PlayerCar.MAX_SPEED * 0.99)

		# Don't ghost through the player: right behind and overlapping,
		# a faster rival tucks in until the dodge AI finds a way around.
		if gap < 0.0 and gap > -RAM_DISTANCE and float(r.speed) > player.speed \
				and _overlap(player.x, player_w, float(r.offset), rival_w, 0.9):
			target = minf(target, player.speed * 0.95)

		r.speed = move_toward(float(r.speed), target, ACCEL * dt)

		# --- Steering: dodge obstacles, otherwise run the racing line.
		# Dodges are COMMITTED: the first dodge signal latches a direction
		# for DODGE_COMMIT seconds, refreshed by same-direction signals and
		# deaf to opposite ones. Without this, per-frame dodge impulses
		# alternate with lane-keeping pulling back toward the obstacle and
		# the rival vibrates instead of swerving. ---
		var dodge: float = main._car_steer(r, old_seg, player_seg, player_w)
		if absf(dodge) > 0.0001 \
				and (float(r.dodge_t) <= 0.0 or signf(dodge) == float(r.dodge_dir)):
			r.dodge_dir = signf(dodge)
			r.dodge_t = DODGE_COMMIT
		if float(r.dodge_t) > 0.0:
			r.dodge_t = float(r.dodge_t) - dt
			r.offset = float(r.offset) + float(r.dodge_dir) * DODGE_RATE * dt \
					* (float(r.speed) / PlayerCar.MAX_SPEED)
		else:
			var apex: float = clampf(
					float(r.lane) - float(old_seg.curve) * APEX_BIAS, -0.85, 0.85)
			r.offset = move_toward(float(r.offset), apex,
					dt * LATERAL_SPEED * (float(r.speed) / PlayerCar.MAX_SPEED))
		r.offset = clampf(float(r.offset), -1.0, 1.0)

		# --- Advance (z is monotonic race progress; fposmod wraps for
		# segment lookup and rendering). ---
		r.z = float(r.z) + float(r.speed) * dt
		var new_seg: Dictionary = main.find_segment(float(r.z))
		if old_seg.index != new_seg.index:
			old_seg.cars.erase(r)
			new_seg.cars.append(r)

		# --- Bonk: a dodge that failed. Hitting slow traffic hurts. ---
		# Only near the player: beyond the dodge AI's active range rivals
		# are simulated abstractly, and punishing them for collisions they
		# were never allowed to avoid would be unfair (and invisible).
		r.bonk_t = maxf(0.0, float(r.bonk_t) - dt)
		var simulated_range: float = RoadRenderer.DRAW_DISTANCE * TrackBuilder.SEGMENT_LENGTH
		if float(r.bonk_t) <= 0.0 and absf(gap) < simulated_range:
			for other in new_seg.cars:
				if other == r:
					continue
				if float(other.speed) < float(r.speed) * 0.7 \
						and _overlap(float(r.offset), rival_w, float(other.offset),
								SpriteCatalog.get_def(other.sprite).world_w
								/ RoadRenderer.ROAD_WIDTH, 0.9):
					r.speed = float(r.speed) * BONK_SPEED_CUT
					r.bonk_t = BONK_COOLDOWN
					break

		# --- Checkpoint and finish times (race clock read from main). ---
		var cp_zs: Array[float] = main.cp_zs
		while int(r.next_cp) < cp_zs.size() and float(r.z) >= cp_zs[int(r.next_cp)]:
			var k: int = int(r.next_cp)
			if leader_cp_times[k] < 0.0 or float(main.race_time) < leader_cp_times[k]:
				leader_cp_times[k] = float(main.race_time)
			r.next_cp = k + 1
		if not bool(r.finished) and float(r.z) >= track_len:
			r.finished = true
			r.finish_time = float(main.race_time)

		# --- Overtake events (only when it happens in your mirrors). ---
		var ahead := float(r.z) > player.position_z
		if ahead != bool(r.was_ahead) and absf(gap) < FLASH_RANGE:
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


## Final results at the moment the player crosses the line: finished rivals
## use their recorded times; still-racing rivals get a projected finish
## (remaining distance at a stabilized speed — arcade-honest, and it keeps
## the board consistent with track positions). Sorted by time; the caller
## finds the player row for rank and highlighting.
func board_entries(player_time: float, track_len: float) -> Array:
	var entries: Array = [
		{"name": "YOU", "time": player_time, "is_player": true},
	]
	for r in rivals:
		var t: float = float(r.finish_time)
		if t < 0.0:
			var proj_speed: float = maxf(float(r.speed), float(r.base_speed) * 0.8)
			t = player_time + (track_len - float(r.z)) / proj_speed
		entries.append({"name": r.name, "time": t, "is_player": false})
	entries.sort_custom(func(a, b): return float(a.time) < float(b.time))
	return entries
