extends Node2D
## Game orchestrator: discovers levels, builds tracks, runs the game loop
## for 1-4 local players across split-screen viewports. Each player is
## mirrored as a world car entity in the segment lists, which gives
## player-vs-player collisions, mutual slipstream, and AI avoidance of
## every player through the same code paths as traffic and rivals.

const LEVELS_DIR := "res://scripts/levels"
const AI_LOOKAHEAD := 20        # segments traffic scans ahead for avoidance
const MP_FINISH_GRACE := 20.0   # after the first finish, others get this long
const PLAYER_LABELS: Array[String] = ["P1", "P2", "P3", "P4"]

## MENU now covers the whole front end (the MenuFlow wizard renders every
## pre-race screen); LEADERBOARD and SETTINGS remain distinct leaf screens.
## All menu-family states stay below COUNTDOWN so the `state >= COUNTDOWN`
## in-race guards elsewhere keep working.
enum State { MENU, LEADERBOARD, SETTINGS, RACER_SELECT, COUNTDOWN, RUNNING, STAGE_CLEAR, GAME_OVER, PAUSED }
## In-sim race kind. The higher-level menu branch (tournament vs quick race)
## lives in `play_mode`; the sim only needs to know circuit / tour / time trial.
enum Mode { TOUR, CIRCUIT, TIME_TRIAL }

## Settings rows: {label, property (on the Settings autoload), type, step, min, max}
const SETTINGS_ROWS: Array = [
	{"label": "FULLSCREEN", "prop": "fullscreen", "type": "bool"},
	{"label": "MUSIC VOLUME", "prop": "music_volume", "type": "pct", "step": 0.1},
	{"label": "SFX VOLUME", "prop": "sfx_volume", "type": "pct", "step": 0.1},
	{"label": "RETRO FILTER", "prop": "crt_enabled", "type": "bool"},
	{"label": "  SCANLINES", "prop": "crt_scanlines", "type": "float", "step": 0.05, "min": 0.0, "max": 0.8},
	{"label": "  COLOR FRINGE", "prop": "crt_fringe", "type": "float", "step": 0.2, "min": 0.0, "max": 5.0},
	{"label": "  DISTORTION", "prop": "crt_curvature", "type": "float", "step": 0.01, "min": 0.0, "max": 0.2},
	{"label": "  VIGNETTE", "prop": "crt_vignette", "type": "float", "step": 0.05, "min": 0.0, "max": 0.8},
	{"label": "  NOISE", "prop": "crt_noise", "type": "float", "step": 0.01, "min": 0.0, "max": 0.25},
]
var level_paths: Array = []
var level_names: Array = []
var level_musics: Array = []
var level_laps: Array = []      # per level: 0 = tour, >0 = circuit lap count
var laps: Array[int] = []       # per player: completed laps this race
var level_index := 0
var level: TrackLevel
var track: TrackBuilder
var palette_timeline: PaletteTimeline   # resolved theme over track position
var cars: Array = []
var rivals: RivalManager

# --- Players and views ---
var player_count := 1
var players: Array[PlayerCar] = []
var views: Array = []           # [{container, viewport, renderer, hud}]
var mirrors: Array = []         # per-player world car entities in seg.cars
var next_cp: Array[int] = []
var finished: Array[bool] = []
var finish_time: Array[float] = []
var finish_order: Array[int] = []   # order index at the line, -1 = racing
var _prev_air: Array[float] = []
var _prev_boosting: Array[bool] = []
var _finishers := 0
var _finish_deadline := -1.0

var state: State = State.MENU
var mode: Mode = Mode.TOUR
var menu: MenuLayer
var menu_flow: MenuFlow
var racer_select: RacerSelectLayer
## Selections gathered by the menu flow. Phase 1 plumbing: play_mode/difficulty/
## selected_racers/current_cup are stored and made sticky but not yet read by
## the sim — they wire into gameplay, records, and tournaments in later phases.
## lap_override IS live (feeds total_laps) so Quick Race lap counts work now.
var play_mode := "QUICK_RACE"   # TOURNAMENT / QUICK_RACE / TIME_TRIAL
var difficulty := 1             # 0 Easy, 1 Normal, 2 Hard
var selected_racers: Array = [] # racer id per player slot
var lap_override := 0           # >0 overrides level.laps (Quick Race circuits)
var current_cup := ""           # tournament cup id (series logic is a later phase)
var menu_sel := 0
var select_sel := 0
var paused_from: State = State.RUNNING
var time_left := 0.0
var countdown_t := 0.0
var _last_count := -1
var race_time := 0.0
var section_time := 0.0
var cp_zs: Array[float] = []
var _board_title := ""
var _view_titles: Array[String] = []
var _last_beep_second := -1
var pickups: Array = []
var _bump_cd: Array[float] = []  # per-player contact-sound cooldown


func _ready() -> void:
	randomize()
	_discover_levels()
	menu = MenuLayer.new()
	_build_views(1)
	add_child(menu)   # menu draws over every viewport
	racer_select = RacerSelectLayer.new()
	racer_select.main = self
	racer_select.visible = false
	add_child(racer_select)
	menu_flow = MenuFlow.new(self, menu)
	_load_level(0)    # idle stage 1 as the menu backdrop
	_enter_menu()


func solo() -> bool:
	return player_count == 1


## The furthest race progress among players (finished players count as
## past the line). Rivals reference this for rubber-banding and attacks.
func lead_progress() -> float:
	var best := 0.0
	for i in range(players.size()):
		best = maxf(best, _effective_progress(i))
	return best


func _effective_progress(i: int) -> float:
	if finished[i]:
		return race_length() + float(100 - finish_order[i]) * 10.0
	return float(laps[i]) * track.track_length() + players[i].position_z


func total_laps() -> int:
	return lap_override if lap_override > 0 else maxi(level.laps, 1)


func race_length() -> float:
	return float(total_laps()) * track.track_length()


func total_cps() -> int:
	return cp_zs.size() * total_laps()


## Absolute race progress of checkpoint index k (indices run through laps).
func cp_progress_z(k: int) -> float:
	var per_lap := cp_zs.size()
	return float(k / per_lap) * track.track_length() + cp_zs[k % per_lap]


func player_z() -> float:
	return views[0].renderer.player_z()


# === VIEWS ===

## Build the split-screen layout: SubViewport per player, each with its own
## renderer and HUD. 1P: full frame. 2P: stacked halves. 4P: quadrants.
## Draw distance shrinks with player count to keep four immediate-mode
## renderers inside the frame budget.
func _build_views(count: int) -> void:
	player_count = count
	for v in views:
		v.container.queue_free()
	views.clear()

	var base := Vector2(1920, 1080)
	var rects: Array = []
	match count:
		1: rects = [Rect2(Vector2.ZERO, base)]
		2: rects = [Rect2(0, 0, base.x, base.y / 2),
				Rect2(0, base.y / 2, base.x, base.y / 2)]
		3: rects = [Rect2(0, 0, base.x / 2, base.y / 2),
				Rect2(base.x / 2, 0, base.x / 2, base.y / 2),
				Rect2(0, base.y / 2, base.x, base.y / 2)]
		_: rects = [Rect2(0, 0, base.x / 2, base.y / 2),
				Rect2(base.x / 2, 0, base.x / 2, base.y / 2),
				Rect2(0, base.y / 2, base.x / 2, base.y / 2),
				Rect2(base.x / 2, base.y / 2, base.x / 2, base.y / 2)]

	var dd_base: int = GameConfig.camera.draw_distance
	for i in range(count):
		# Per-view draw distance by view size: full frame 100%, wide halves
		# 66%, quadrants 45% (3P mixes both).
		var dd := dd_base
		if count > 1:
			dd = int(dd_base * (0.66 if rects[i].size.x >= base.x else 0.45))
		var container := SubViewportContainer.new()
		container.stretch = true
		container.position = rects[i].position
		container.size = rects[i].size
		add_child(container)
		move_child(container, 0)   # keep the menu layer on top
		var vp := SubViewport.new()
		vp.size = Vector2i(rects[i].size)
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		container.add_child(vp)
		var renderer := RoadRenderer.new()
		renderer.main = self
		renderer.player_index = i
		renderer.draw_distance = dd
		vp.add_child(renderer)
		var hud := HudLayer.new()
		vp.add_child(hud)
		views.append({"container": container, "viewport": vp,
				"renderer": renderer, "hud": hud})


# === LEVEL FLOW ===

## Levels are auto-discovered: drop a new .gd file into res://scripts/levels/
## and it becomes a stage (played in filename order).
func _discover_levels() -> void:
	level_paths.clear()
	var dir := DirAccess.open(LEVELS_DIR)
	if dir != null:
		for f in dir.get_files():
			var fname: String = f
			# In exported builds scripts show up as .gd.remap; strip that.
			if fname.ends_with(".remap"):
				fname = fname.trim_suffix(".remap")
			if fname.ends_with(".gd"):
				var path := LEVELS_DIR + "/" + fname
				if not level_paths.has(path):
					level_paths.append(path)
	level_paths.sort()
	level_names.clear()
	level_musics.clear()
	level_laps.clear()
	for path in level_paths:
		var script: GDScript = load(path)
		var inst: TrackLevel = script.new()
		level_names.append(inst.level_name)
		level_laps.append(inst.laps)
		if not inst.music.is_empty() and not level_musics.has(inst.music):
			level_musics.append(inst.music)
	if level_paths.is_empty():
		push_error("No levels found in %s" % LEVELS_DIR)


func _load_level(idx: int) -> void:
	if level_paths.is_empty():
		return
	level_index = ((idx % level_paths.size()) + level_paths.size()) % level_paths.size()
	var script: GDScript = load(level_paths[level_index])
	level = script.new()

	track = TrackBuilder.new()
	level.build(track)
	track.finalize()
	# Built after finalize() so build() can author keyframes by segment count.
	palette_timeline = PaletteTimeline.build(level.theme, level.palette_keyframes)

	cp_zs = track.mark_checkpoints(level.checkpoint_count)
	_init_pickups()
	section_time = level.time_limit / float(level.checkpoint_count + 1)
	race_time = 0.0
	_finishers = 0
	_finish_deadline = -1.0

	players.clear()
	mirrors.clear()
	next_cp.clear()
	finished.clear()
	finish_time.clear()
	finish_order.clear()
	_prev_air.clear()
	_prev_boosting.clear()
	_bump_cd.clear()
	laps.clear()
	for i in range(player_count):
		laps.append(0)
		var profile := _player_profile(i)
		if profile != null:
			SpriteCatalog.register_player_from_profile(i, profile)
		else:
			SpriteCatalog.register_player(i)
		var p := PlayerCar.new()
		p.input_prefix = "p%d_" % i
		# Side-by-side grid for multiple players, staggered slightly.
		p.x = 0.0 if player_count == 1 else lerpf(-0.5, 0.5,
				float(i) / float(player_count - 1))
		# Forward stagger (never negative: fposmod would wrap a negative
		# start to the end of the track — an instant finish).
		p.position_z = float(i) * 120.0
		players.append(p)
		next_cp.append(0)
		finished.append(false)
		finish_time.append(0.0)
		finish_order.append(-1)
		_prev_air.append(0.0)
		_prev_boosting.append(false)
		_bump_cd.append(0.0)
		mirrors.append({"z": 0.0, "offset": p.x, "speed": 0.0,
				"sprite": "player_%d" % i, "y": 0.0, "vy": 0.0, "air": 0.0,
				"pidx": i})
	_spawn_traffic()
	for i in range(player_count):
		_sync_mirror(i, true)
	rivals = RivalManager.new()
	rivals.spawn(self, level.rival_count if mode != Mode.TIME_TRIAL else 0,
			_excluded_racers())

	time_left = section_time
	_last_beep_second = -1
	for v in views:
		v.renderer.reset_camera()
		v.renderer.player = players[v.renderer.player_index]
		v.hud.set_stage(level.level_name)
		v.hud.set_message("")
		v.hud.hide_leaderboard()
		v.hud.clear_race_ui()
		v.hud.set_race_time(0.0)
	Audio.stop_engine()


## Keep a player's world mirror entity in sync (position, segment lists).
## The mirror sits where the car SPRITE sits: player_z() ahead of the camera.
func _sync_mirror(i: int, force_seg: bool = false) -> void:
	var m: Dictionary = mirrors[i]
	var p := players[i]
	var new_z := fposmod(p.position_z + player_z(), track.track_length())
	var old_seg := find_segment(float(m.z))
	m.z = new_z
	m.offset = p.x
	m.speed = p.speed
	m.air = p.air
	m.y = p.y_pos
	var new_seg := find_segment(new_z)
	if force_seg:
		new_seg.cars.append(m)
	elif old_seg.index != new_seg.index:
		old_seg.cars.erase(m)
		new_seg.cars.append(m)


func _start_race(idx: int) -> void:
	_load_level(idx)
	menu.hide_menu()
	var fractions: Array = []
	for z in cp_zs:
		fractions.append(z / track.track_length())
	for v in views:
		v.hud.setup_progress(fractions)
	state = State.COUNTDOWN
	countdown_t = 3.0
	_last_count = -1
	var music_name := level.music
	if music_name.is_empty() or not Audio.has_sound(music_name):
		var available: Array = level_musics.filter(
				func(m): return Audio.has_sound(String(m)))
		if not available.is_empty():
			music_name = available.pick_random()
	Audio.play_music(music_name)


func _enter_menu() -> void:
	state = State.MENU
	menu_sel = 0
	for v in views:
		v.hud.set_message("")
		v.hud.hide_leaderboard()
		v.hud.clear_race_ui()
	Audio.stop_engine()
	Audio.play_music("music_menu")
	menu_flow.reset()


# === SHARED HELPERS (unchanged logic) ===

## Ballistic vertical step for an NPC car dict. Grounded motion sets
## vertical velocity from terrain slope x speed, so hill crests launch cars
## naturally — the faster, the bigger the air. (Player has the same model
## inside PlayerCar.update.)
func _step_air(car: Dictionary, g_prev: float, dt: float) -> void:
	var g_new := ground_y(float(car.z))
	car.vy = float(car.vy) - GameConfig.player.gravity * dt
	car.y = float(car.y) + float(car.vy) * dt
	if float(car.y) <= g_new:
		car.y = g_new
		car.vy = minf(maxf(float(car.vy), (g_new - g_prev) / maxf(dt, 0.0001)),
				GameConfig.player.max_launch_vy)
	car.air = float(car.y) - g_new


## Interpolated road altitude (world units) at any track position.
func ground_y(z: float) -> float:
	var seg := find_segment(z)
	var t := fposmod(z, TrackBuilder.SEGMENT_LENGTH) / TrackBuilder.SEGMENT_LENGTH
	return lerpf(seg.p1.world.y, seg.p2.world.y, t)


## Gather level-authored boost canisters; if the level placed none,
## scatter a random set (avoiding the grid and the final run-in).
func _init_pickups() -> void:
	pickups.clear()
	for seg in track.segments:
		for pu in seg.pickups:
			pickups.append(pu)
	if not pickups.is_empty():
		return
	# Sparse by design: one canister per ~450 segments (roughly one per
	# checkpoint section). Plentiful boost hands the leader an insurmountable
	# edge — scarcity is what makes taking one a decision.
	var count: int = maxi(GameConfig.race.auto_pickup_count,
			track.segments.size() / 450)
	var lanes: Array = [-0.66, 0.0, 0.66]
	var seg_count := track.segments.size()
	for i in range(count):
		var frac := (float(i) + randf_range(0.25, 0.75)) / float(count)
		var idx := clampi(int(frac * float(seg_count)), 30, seg_count - 40)
		track.add_boost_pickup(idx, lanes.pick_random())
		pickups.append(track.segments[idx].pickups[-1])


## Traffic spawns with RHYTHM, not uniformity: loose packs (mixed lanes and
## pace), occasional 3-abreast rolling roadblocks that demand a real
## decision, some loners, and breathing room in between.
func _spawn_traffic() -> void:
	cars.clear()
	for seg in track.segments:
		seg.cars.clear()
	var lanes := [-0.66, 0.0, 0.66]
	var sprites := ["car_blue", "car_yellow", "car_green"]
	var rc: RaceSettings = GameConfig.race
	var budget: int = level.traffic_count
	var lo := 3000.0
	var hi := track.track_length() - 3000.0
	while budget > 0:
		var roll := randf()
		if roll < rc.single_car_chance or budget < 3:
			_place_traffic_car(randf_range(lo, hi), float(lanes.pick_random()),
					randf_range(0.12, 0.5), sprites)
			budget -= 1
		elif roll < rc.single_car_chance + rc.roadblock_chance:
			# Rolling roadblock: all three lanes, staggered, matched pace —
			# thread it, boost around it, or brake and draft.
			var z := randf_range(lo, hi)
			var pace := randf_range(0.16, 0.3)
			for k in range(3):
				_place_traffic_car(z + float(k) * randf_range(120.0, 260.0),
						float(lanes[k]), pace + randf_range(-0.02, 0.02), sprites)
			budget -= 3
		else:
			var size: int = mini(randi_range(rc.traffic_cluster_min,
					rc.traffic_cluster_max), budget)
			var z2 := randf_range(lo, hi)
			for k in range(size):
				_place_traffic_car(z2 + randf_range(0.0, 1500.0),
						float(lanes.pick_random()), randf_range(0.12, 0.5), sprites)
			budget -= size


func _place_traffic_car(z: float, offset: float, pace: float, sprites: Array) -> void:
	z = clampf(z, 2500.0, track.track_length() - 500.0)
	var car := {
		"z": z,
		"offset": offset,
		"speed": GameConfig.player.max_speed * pace,
		"sprite": sprites.pick_random(),
		"y": ground_y(z), "vy": 0.0, "air": 0.0,
	}
	cars.append(car)
	find_segment(z).cars.append(car)


func find_segment(z: float) -> Dictionary:
	var seg_count := track.segments.size()
	var i := int(floor(fposmod(z, track.track_length()) / TrackBuilder.SEGMENT_LENGTH))
	return track.segments[i % seg_count]



func _process(dt: float) -> void:
	if track == null:
		return

	if state >= State.COUNTDOWN:
		if Input.is_action_just_pressed("restart"):
			_start_race(level_index)
			return
		if Input.is_action_just_pressed("next_level"):
			_start_race(_next_in_category(level_index, 1))
			return

	# Leaving a race is Escape ONLY — ui_cancel also carries gamepad B,
	# which is boost in-race. B still backs out of menus via ui_cancel.
	if state >= State.COUNTDOWN and Input.is_action_just_pressed("quit_to_menu"):
		_enter_menu()
		return

	if Input.is_action_just_pressed("pause"):
		if state == State.RUNNING or state == State.COUNTDOWN:
			paused_from = state
			state = State.PAUSED
			for v in views:
				v.hud.set_message("PAUSED")
			Audio.stop_engine()
		elif state == State.PAUSED:
			state = paused_from
			for v in views:
				v.hud.set_message("")
			_last_count = -1
		return

	match state:
		State.MENU:
			menu_flow.frame(dt)
		State.LEADERBOARD:
			_leaderboard_frame(dt)
		State.SETTINGS:
			_settings_frame(dt)
		State.RACER_SELECT:
			racer_select.frame(dt)
		State.COUNTDOWN:
			_countdown_frame(dt)
		State.RUNNING:
			_run_frame(dt)
		State.STAGE_CLEAR:
			race_time += dt
			for i in range(players.size()):
				_coast_player(i, dt, GameConfig.player.max_speed * 0.35)
			_update_traffic(dt)
			rivals.update(dt, self)
			_scroll_backgrounds(dt)
			if not (solo() and mode == Mode.TIME_TRIAL):
				var live := _merged_board()
				for i in range(views.size()):
					views[i].hud.show_leaderboard(live, _view_titles[i])
			if Input.is_action_just_pressed("ui_accept") or _any_accel():
				_start_race(_next_in_category(level_index, 1))
		State.GAME_OVER:
			for i in range(players.size()):
				_coast_player(i, dt, 0.0)
			_update_traffic(dt)
			rivals.update(dt, self)
		State.PAUSED:
			pass

	for i in range(views.size()):
		views[i].hud.set_speed(players[views[i].renderer.player_index].speed_kmh())
		if solo():
			views[i].hud.set_time(time_left)


func _any_accel() -> bool:
	for i in range(player_count):
		if Input.is_action_just_pressed("p%d_accelerate" % i):
			return true
	return false


## Terminal actions the MenuFlow calls once selections are made. The flow
## owns navigation and rendering; main owns state transitions and the race.

func open_board() -> void:
	state = State.LEADERBOARD
	select_sel = 0
	_refresh_board()


func open_settings() -> void:
	state = State.SETTINGS
	menu_sel = 0
	_show_settings()


func quit_game() -> void:
	get_tree().quit()


## Last-used racer for a player slot. Phase 1 defaults to the slot livery;
## the Racer Select grid (Phase 2) will write real picks into Settings.
func sticky_racer(slot: int) -> int:
	if slot < Settings.sticky_racers.size():
		return int(Settings.sticky_racers[slot])
	return slot


## Launch a fully-configured race. race_kind is the in-sim Mode
## ("TOUR" / "CIRCUIT" / "TIME_TRIAL"); p_mode is the menu branch kept for
## later phases (tournament series, difficulty-filtered records, etc.).
func start_configured(p_mode: String, race_kind: String, count: int,
		diff: int, racers: Array, laps: int, idx: int, cup: String) -> void:
	play_mode = p_mode
	match race_kind:
		"CIRCUIT":
			mode = Mode.CIRCUIT
		"TIME_TRIAL":
			mode = Mode.TIME_TRIAL
		_:
			mode = Mode.TOUR
	difficulty = diff
	selected_racers = racers.duplicate()
	lap_override = laps
	current_cup = cup
	# Persist sticky prefs (Time Trial has no difficulty, so leave it be).
	if p_mode != "TIME_TRIAL":
		Settings.difficulty = diff
	Settings.sticky_racers = racers.duplicate()
	Settings.save()
	if count != player_count:
		_build_views(count)
	_start_race(idx)


# === RACER SELECT ===

## Open the Racer Select screen for `count` players (called by the menu flow).
## The flow resumes via _racer_select_done / _racer_select_cancel below.
func open_racer_select(count: int, sticky: Array) -> void:
	state = State.RACER_SELECT
	menu.hide_menu()
	racer_select.open(GameConfig.race.roster, count, sticky)


func _racer_select_done(picks: Array) -> void:
	racer_select.close()
	state = State.MENU
	menu_flow.racer_done(picks)


func _racer_select_cancel() -> void:
	racer_select.close()
	state = State.MENU
	menu_flow.racer_cancelled()


## The roster profile a player slot chose, or null to fall back to the fixed
## slot livery. selected_racers holds roster indices set at race start.
func _player_profile(slot: int) -> RivalProfile:
	if slot < selected_racers.size():
		var idx: int = int(selected_racers[slot])
		var roster: Array = GameConfig.race.roster
		if idx >= 0 and idx < roster.size():
			return roster[idx]
	return null


## Unique roster indices the players picked — excluded from the AI field so
## nobody races their own clone.
func _excluded_racers() -> Array:
	var out: Array = []
	for r in selected_racers:
		var idx: int = int(r)
		if not out.has(idx):
			out.append(idx)
	return out


## Settings screen: up/down select, left/right adjust (applied live),
## Esc saves and returns.
func _settings_frame(dt: float) -> void:
	_update_traffic(dt)
	var moved := 0
	if Input.is_action_just_pressed("ui_down"):
		moved = 1
	elif Input.is_action_just_pressed("ui_up"):
		moved = -1
	if moved != 0:
		menu_sel = wrapi(menu_sel + moved, 0, SETTINGS_ROWS.size())
		Audio.play("menu_move")
		_show_settings()
	var adj := 0
	if (Input.is_action_just_pressed("ui_right")
			or Input.is_action_just_pressed("p0_steer_right")):
		adj = 1
	elif (Input.is_action_just_pressed("ui_left")
			or Input.is_action_just_pressed("p0_steer_left")):
		adj = -1
	if adj != 0 or Input.is_action_just_pressed("ui_accept"):
		if adj == 0:
			adj = 1   # accept toggles/steps forward
		_adjust_setting(SETTINGS_ROWS[menu_sel], adj)
		Audio.play("menu_move")
		Settings.apply()
		_show_settings()
	if Input.is_action_just_pressed("ui_cancel"):
		Audio.play("menu_select")
		Settings.save()
		_enter_menu()


func _adjust_setting(row: Dictionary, dir: int) -> void:
	var prop: String = row.prop
	match String(row.type):
		"bool":
			Settings.set(prop, not bool(Settings.get(prop)))
		"pct", "float":
			var v: float = float(Settings.get(prop)) + float(row.step) * float(dir)
			var lo: float = float(row.get("min", 0.0))
			var hi: float = float(row.get("max", 1.0))
			Settings.set(prop, clampf(v, lo, hi))


func _show_settings() -> void:
	var rows: Array[String] = []
	for row in SETTINGS_ROWS:
		var val: String
		match String(row.type):
			"bool":
				val = "ON" if bool(Settings.get(row.prop)) else "OFF"
			"pct":
				val = "%d%%" % int(round(float(Settings.get(row.prop)) * 100.0))
			_:
				val = "%.2f" % float(Settings.get(row.prop))
		rows.append("%s   %s" % [row.label, val])
	menu.show_list("SETTINGS", rows, menu_sel)


## Levels belonging to the current in-race mode: circuits for CIRCUIT, tours
## otherwise. Used by post-race "next level" advancement (R / N in-race).
func _category_indices() -> Array[int]:
	var out: Array[int] = []
	for i in range(level_paths.size()):
		var is_circuit: bool = int(level_laps[i]) > 0
		if (mode == Mode.CIRCUIT) == is_circuit:
			out.append(i)
	return out


## The next level within the current mode's category (wraps).
func _next_in_category(global_idx: int, step: int) -> int:
	var cat := _category_indices()
	if cat.is_empty():
		return global_idx
	var pos := maxi(cat.find(global_idx), 0)
	return cat[wrapi(pos + step, 0, cat.size())]


func _leaderboard_frame(dt: float) -> void:
	_update_traffic(dt)
	var moved := 0
	if (Input.is_action_just_pressed("ui_right")
			or Input.is_action_just_pressed("p0_steer_right")):
		moved = 1
	elif (Input.is_action_just_pressed("ui_left")
			or Input.is_action_just_pressed("p0_steer_left")):
		moved = -1
	if moved != 0:
		select_sel = wrapi(select_sel + moved, 0, level_names.size())
		Audio.play("menu_move")
		_refresh_board()
	if (Input.is_action_just_pressed("ui_cancel")
			or Input.is_action_just_pressed("ui_accept")):
		Audio.play("menu_move")
		_enter_menu()


func _refresh_board() -> void:
	var fname := String(level_paths[select_sel]).get_file()
	var columns: Array = []
	if int(level_laps[select_sel]) > 0:
		columns = [{"title": "CIRCUIT", "times": Records.get_times(fname, "circuit")}]
	else:
		columns = [{"title": "TOUR", "times": Records.get_times(fname, "race")},
				{"title": "TIME TRIAL", "times": Records.get_times(fname, "time_trial")}]
	menu.show_board(String(level_names[select_sel]), columns)


## Pre-race: racers held on the grid, traffic ambling, big 3-2-1 center
## stage. RUNNING (and the race clock) begins on GO.
func _countdown_frame(dt: float) -> void:
	countdown_t -= dt
	_update_traffic(dt)
	_scroll_backgrounds(dt)
	Audio.update_engine(0.0, false)
	var whole := int(ceilf(countdown_t))
	if countdown_t <= 0.0:
		state = State.RUNNING
		for v in views:
			v.hud.set_message("")
			v.hud.set_flash("GO!")
		Audio.play("countdown_go")
	elif whole != _last_count:
		_last_count = whole
		for v in views:
			v.hud.set_message(str(whole))
		Audio.play("countdown_beep")


# === THE RACE FRAME ===

func _run_frame(dt: float) -> void:
	race_time += dt
	for v in views:
		v.hud.set_race_time(race_time)

	for i in range(players.size()):
		if finished[i]:
			_coast_player(i, dt, GameConfig.player.max_speed * 0.35)
			continue
		var p := players[i]
		var prev_z := p.position_z
		var crossed := p.update(dt, self)
		_sync_mirror(i)
		_check_player_checkpoint(i, prev_z)
		_per_player_effects(i, dt)
		_check_collisions(i)
		_player_shunts(i, dt)
		if crossed:
			laps[i] += 1
			if laps[i] >= total_laps():
				_on_player_finish(i)
			else:
				# Lap line: refill the section timer and mark the lap.
				if solo():
					time_left += section_time
					_last_beep_second = -1
				Audio.play("checkpoint")
				views[i].hud.set_flash("LAP %d / %d" % [laps[i] + 1, total_laps()])

	_update_traffic(dt)
	rivals.update(dt, self)
	if solo() and mode != Mode.TIME_TRIAL:
		for e in rivals.events:
			views[0].hud.set_flash(e)
	_update_ranks_and_bars()
	_update_pickup_respawns(dt)
	_scroll_backgrounds(dt)
	Audio.update_engine(players[0].speed / GameConfig.player.max_speed,
			absf(players[0].x) > 1.0, players[0].steer_dir)

	# Countdown timer, time-up, and the last-10 beeps are solo-only:
	# multiplayer is a pure race to the line.
	if solo():
		time_left -= dt
		var whole_seconds := int(ceilf(time_left))
		if whole_seconds <= 10 and whole_seconds >= 1 \
				and whole_seconds != _last_beep_second:
			_last_beep_second = whole_seconds
			Audio.play("time_warning")
		if not finished[0] and time_left <= 0.0:
			time_left = 0.0
			state = State.GAME_OVER
			views[0].hud.set_message("TIME UP — press R to retry")
			Audio.play("game_over")
			return

	# Multiplayer stragglers: grace period after the first finish.
	if _finish_deadline > 0.0 and race_time >= _finish_deadline:
		for i in range(players.size()):
			if not finished[i]:
				_mark_finished(i, INF)
	if _finishers == players.size():
		_end_race()


func _per_player_effects(i: int, dt: float) -> void:
	var p := players[i]
	var v: Dictionary = views[i]
	if p.slip > 0.9:
		Audio.play("slipstream", -4.0, 1.0, 1.5)
	if p.boosting and not _prev_boosting[i]:
		v.renderer.shake()
		Audio.play("boost", -3.0, 1.0, 0.3)
	_prev_boosting[i] = p.boosting
	v.hud.set_boost(p.boost / GameConfig.player.boost_capacity)
	if _prev_air[i] > 200.0 and p.air <= 0.5:
		Audio.play("land", -6.0)
	_prev_air[i] = p.air
	# Boost canisters at this player's car.
	var pseg := find_segment(p.position_z + player_z())
	for pu in pseg.pickups:
		if not bool(pu.taken) and p.air < 120.0 \
				and absf(float(pu.offset) - p.x) < 0.4:
			pu.taken = true
			pu.respawn_t = GameConfig.race.pickup_respawn
			p.boost = minf(p.boost + GameConfig.race.pickup_boost_amount,
					GameConfig.player.boost_capacity)
			Audio.play("pickup", -2.0)


func _update_pickup_respawns(dt: float) -> void:
	for pu in pickups:
		if bool(pu.taken):
			pu.respawn_t = float(pu.respawn_t) - dt
			if float(pu.respawn_t) <= 0.0:
				pu.taken = false


func _update_ranks_and_bars() -> void:
	var track_len := track.track_length()
	var circuit := level.laps > 0
	var rival_dots: Array = []
	for r in rivals.rivals:
		var def: Dictionary = SpriteCatalog.get_def(r.sprite)
		var rp: float = fposmod(float(r.z), track_len) / track_len if circuit \
				else minf(float(r.z) / track_len, 1.0)
		if bool(r.finished):
			rp = 1.0
		rival_dots.append({"p": rp, "color": def.get("map_color", Color.WHITE)})
	for i in range(views.size()):
		var pi: int = views[i].renderer.player_index
		var dots: Array = rival_dots.duplicate()
		for j in range(players.size()):
			if j == pi:
				continue
			var pdef: Dictionary = SpriteCatalog.get_def("player_%d" % j)
			var pp: float = minf(_effective_progress(j) / race_length(), 1.0)
			if circuit and not finished[j]:
				pp = players[j].position_z / track_len
			dots.append({"p": pp, "color": pdef.get("map_color", Color.WHITE)})
		views[i].hud.update_progress(players[pi].position_z / track_len, dots)
		if mode != Mode.TIME_TRIAL or not solo():
			views[i].hud.set_position_rank(_rank_of(pi), _total_racers())
		if level.laps > 0:
			views[i].hud.set_lap(mini(laps[pi] + 1, total_laps()), total_laps())


func _total_racers() -> int:
	return rivals.rivals.size() + players.size()


func _rank_of(i: int) -> int:
	var prog := _effective_progress(i)
	var rank := 1
	for r in rivals.rivals:
		if float(r.z) > prog:
			rank += 1
	for j in range(players.size()):
		if j != i and _effective_progress(j) > prog:
			rank += 1
	return rank


# === FINISHING ===

func _on_player_finish(i: int) -> void:
	_mark_finished(i, race_time)
	Audio.play("stage_clear")
	views[i].hud.set_flash("FINISHED %s!" % HudLayer.ordinal(_rank_of(i)))
	if _finish_deadline < 0.0 and players.size() > 1:
		_finish_deadline = race_time + MP_FINISH_GRACE
	if _finishers == players.size():
		_end_race()


func _mark_finished(i: int, t: float) -> void:
	if finished[i]:
		return
	finished[i] = true
	finish_time[i] = t
	finish_order[i] = _finishers
	_finishers += 1


func _end_race() -> void:
	state = State.STAGE_CLEAR
	var fname := String(level_paths[level_index]).get_file()
	var mode_key := "race"
	if mode == Mode.CIRCUIT:
		mode_key = "circuit"
	elif mode == Mode.TIME_TRIAL:
		mode_key = "time_trial"
	var best_rank := -1
	if solo() and finish_time[0] != INF:
		best_rank = Records.add_time(fname, mode_key, finish_time[0])

	if solo() and mode == Mode.TIME_TRIAL:
		var times: Array = Records.get_times(fname, mode_key)
		var entries: Array = []
		var marked := false
		for k in range(times.size()):
			var is_you := (not marked
					and absf(float(times[k]) - finish_time[0]) < 0.0005)
			if is_you:
				marked = true
			entries.append({"name": "YOU" if is_you else "-",
					"time": float(times[k]), "is_player": is_you})
		_board_title = "TIME TRIAL — %s" % HudLayer.format_time(finish_time[0])
		if best_rank > 0:
			_board_title += "  (BEST #%d)" % best_rank
		views[0].hud.show_leaderboard(entries, _board_title)
		return

	var entries := _merged_board()
	_view_titles.clear()
	for i in range(views.size()):
		var pi: int = views[i].renderer.player_index
		var rank := 1
		for k in range(entries.size()):
			if int(entries[k].get("pidx", -1)) == pi:
				rank = k + 1
				break
		var title := "FINISHED %s of %d" % [HudLayer.ordinal(rank), _total_racers()]
		if solo() and best_rank > 0:
			title += "  —  BEST #%d" % best_rank
		if i == 0:
			_board_title = title
		_view_titles.append(title)
		views[i].hud.show_leaderboard(entries, title)


## Merged results: players (by finish time; DNF ranked by progress at the
## deadline) + rivals (finished by time, still-racing in running order).
func _merged_board() -> Array:
	var done: Array = []
	var racing: Array = []
	for i in range(players.size()):
		var label: String = "YOU" if solo() else PLAYER_LABELS[i]
		if finished[i] and finish_time[i] != INF:
			done.append({"name": label, "time": finish_time[i],
					"is_player": true, "pidx": i})
		else:
			racing.append({"name": label, "time": -1.0, "is_player": true,
					"pidx": i, "z": _effective_progress(i)})
	for r in rivals.rivals:
		if float(r.finish_time) >= 0.0:
			done.append({"name": r.name, "time": float(r.finish_time),
					"is_player": false})
		else:
			racing.append({"name": r.name, "time": -1.0, "is_player": false,
					"z": float(r.z)})
	done.sort_custom(func(a, b): return float(a.time) < float(b.time))
	racing.sort_custom(func(a, b): return float(a.z) > float(b.z))
	return done + racing


# === CHECKPOINTS ===

func _check_player_checkpoint(i: int, prev_z: float) -> void:
	if next_cp[i] >= total_cps():
		return
	# Only this lap's checkpoints are eligible (indices run through laps).
	if next_cp[i] / cp_zs.size() != laps[i]:
		return
	var cp_z := cp_zs[next_cp[i] % cp_zs.size()]
	var p := players[i]
	if prev_z < cp_z and p.position_z >= cp_z:
		var hud: HudLayer = views[i].hud
		if solo():
			time_left += section_time
			_last_beep_second = -1
		Audio.play("checkpoint")
		if mode == Mode.TIME_TRIAL and solo():
			hud.set_flash("CHECKPOINT")
			next_cp[i] += 1
			return
		var leader_t := -1.0
		if next_cp[i] < rivals.leader_cp_times.size():
			leader_t = rivals.leader_cp_times[next_cp[i]]
		var green := Color(0.35, 0.95, 0.4)
		var red := Color(0.95, 0.3, 0.25)
		if leader_t < 0.0 and mode != Mode.TIME_TRIAL:
			var eta: float = rivals.next_rival_eta(cp_progress_z(next_cp[i]))
			hud.set_flash("CHECKPOINT  -%s  (LEADER)"
					% HudLayer.format_time(eta), green)
		elif leader_t >= 0.0:
			var delta := race_time - leader_t
			var sign_str := "+" if delta >= 0.0 else "-"
			hud.set_flash("CHECKPOINT  %s%s"
					% [sign_str, HudLayer.format_time(absf(delta))],
					red if delta >= 0.0 else green)
		else:
			hud.set_flash("CHECKPOINT")
		next_cp[i] += 1


# === COASTING / BACKGROUND ===

func _coast_player(i: int, dt: float, target_speed: float) -> void:
	var p := players[i]
	p.speed = move_toward(p.speed, target_speed, GameConfig.player.max_speed * 0.5 * dt)
	var g_prev := p._sprite_ground(self)
	p.position_z = fposmod(p.position_z + p.speed * dt, track.track_length())
	p.step_vertical(dt, self, g_prev)
	p.steer_dir = 0.0
	p.bounce = 0.0
	p.x = move_toward(p.x, 0.0 if solo() else p.x, dt * 1.5)
	_sync_mirror(i)


func _scroll_backgrounds(dt: float) -> void:
	for v in views:
		var p: PlayerCar = players[v.renderer.player_index]
		var seg := find_segment(p.position_z)
		v.renderer.hill_offset += seg.curve \
				* (p.speed / GameConfig.player.max_speed) * dt * 120.0


# === TRAFFIC / AI STEERING / COLLISIONS ===

func _update_traffic(dt: float) -> void:
	var track_len := track.track_length()
	for car in cars:
		var old_seg := find_segment(car.z)
		car.offset = clampf(
				float(car.offset) + _car_steer(car, old_seg) * dt * 60.0,
				-1.2, 1.2)
		var g_prev := ground_y(float(car.z))
		car.z = fposmod(car.z + car.speed * dt, track_len)
		_step_air(car, g_prev, dt)
		var new_seg := find_segment(car.z)
		if old_seg.index != new_seg.index:
			old_seg.cars.erase(car)
			new_seg.cars.append(car)


## Per-frame lateral steering for one NPC car. Scans ahead and dodges any
## slower car in the segment lists — traffic, rivals, and every player's
## mirror entity alike. AI is skipped for cars far from every player.
func _car_steer(car: Dictionary, car_seg: Dictionary,
		lookahead: int = AI_LOOKAHEAD) -> float:
	var seg_count := track.segments.size()
	var near_any := false
	for p in players:
		var pseg := find_segment(p.position_z)
		var rel: int = (int(car_seg.index) - int(pseg.index) + seg_count) % seg_count
		if rel <= GameConfig.camera.draw_distance:
			near_any = true
			break
	if not near_any:
		return 0.0

	var car_w: float = SpriteCatalog.get_def(car.sprite).world_w / RoadRenderer.ROAD_WIDTH
	var car_x: float = float(car.offset)
	for i in range(1, lookahead):
		var seg: Dictionary = track.segments[(int(car_seg.index) + i) % seg_count]
		for other in seg.cars:
			if other == car:
				continue
			var other_w: float = SpriteCatalog.get_def(other.sprite).world_w \
					/ RoadRenderer.ROAD_WIDTH
			var other_x: float = float(other.offset)
			if car.speed > other.speed \
					and _overlap(car_x, car_w, other_x, other_w, 1.2):
				var dir := 0.0
				if other_x > 0.5:
					dir = -1.0
				elif other_x < -0.5:
					dir = 1.0
				else:
					dir = 1.0 if car_x > other_x else -1.0
				return dir / float(i) * float(car.speed - other.speed) \
						/ GameConfig.player.max_speed

	if float(car.offset) < -0.9:
		return 0.1
	if float(car.offset) > 0.9:
		return -0.1
	return 0.0


## Contact FROM others — the missing half of collisions. Rear shunts: a
## faster car slamming into your tail throws you forward (and costs them).
## Side-swipes: near-pace lateral contact shoves both cars apart with a
## little speed scrub. Works against traffic, rivals, and other players
## (pushes on a mirror entity route to the real player).
func _player_shunts(i: int, dt: float) -> void:
	_bump_cd[i] = maxf(0.0, _bump_cd[i] - dt)
	var p := players[i]
	if p.air > 250.0:
		return
	var track_len := track.track_length()
	var pw: float = SpriteCatalog.get_def("player").world_w / RoadRenderer.ROAD_WIDTH
	var pz := fposmod(p.position_z + player_z(), track_len)
	for off in [-1, 0, 1]:
		var seg := find_segment(pz + float(off) * TrackBuilder.SEGMENT_LENGTH)
		for car in seg.cars:
			if int(car.get("pidx", -1)) == i:
				continue
			var dz := fposmod(float(car.z) - pz + track_len * 0.5, track_len) \
					- track_len * 0.5
			var cw: float = SpriteCatalog.get_def(car.sprite).world_w \
					/ RoadRenderer.ROAD_WIDTH
			if not _overlap(p.x, pw, float(car.offset), cw, 0.9):
				continue
			if dz < -60.0 and dz > -600.0 and float(car.speed) > p.speed * 1.02:
				# Rear shunt: they hit you.
				p.speed += (float(car.speed) - p.speed) * 0.6
				car.speed = float(car.speed) * 0.8
				p.bounce = 6.0
				if _bump_cd[i] <= 0.0:
					Audio.play("bump", -2.0)
					_bump_cd[i] = 0.4
			elif absf(dz) <= 260.0 and absf(float(car.speed) - p.speed) \
					< GameConfig.player.max_speed * 0.15:
				# Side-swipe: push apart, both scrub.
				var dir := signf(p.x - float(car.offset))
				if dir == 0.0:
					dir = 1.0
				p.x += dir * 1.2 * dt
				p.speed *= 1.0 - 0.25 * dt
				var pj := int(car.get("pidx", -1))
				if pj >= 0:
					players[pj].x -= dir * 1.2 * dt
					players[pj].speed *= 1.0 - 0.25 * dt
				else:
					car.offset = clampf(float(car.offset) - dir * 1.2 * dt, -1.2, 1.2)
					car.speed = float(car.speed) * (1.0 - 0.25 * dt)
				if _bump_cd[i] <= 0.0:
					Audio.play("bump", -6.0, 1.0, 0.25)
					_bump_cd[i] = 0.35


func _check_collisions(i: int) -> void:
	var p := players[i]
	if p.air > 250.0:
		return
	var seg := find_segment(p.position_z + player_z())
	var player_w: float = SpriteCatalog.get_def("player").world_w / RoadRenderer.ROAD_WIDTH

	if absf(p.x) > 0.8:
		for spr in seg.sprites:
			var def: Dictionary = SpriteCatalog.get_def(spr.name)
			if not def.collidable:
				continue
			var sw: float = def.world_w / RoadRenderer.ROAD_WIDTH
			if _overlap(p.x, player_w, spr.offset, sw):
				p.speed = GameConfig.player.max_speed * 0.06
				Audio.play("crash", 0.0, 1.0, 0.5)
				break

	# Rear-ending anything slower — traffic, rivals, or another player's
	# mirror — slams your speed and pushes you back behind it.
	for car in seg.cars:
		if int(car.get("pidx", -1)) == i:
			continue   # your own mirror
		if p.speed <= car.speed:
			continue
		var cw: float = SpriteCatalog.get_def(car.sprite).world_w / RoadRenderer.ROAD_WIDTH
		if _overlap(p.x, player_w, car.offset, cw, 0.8):
			p.speed = car.speed * (car.speed / maxf(p.speed, 1.0))
			p.position_z = fposmod(car.z - player_z(), track.track_length())
			Audio.play("bump", 0.0, 1.0, 0.3)
			break


static func _overlap(x1: float, w1: float, x2: float, w2: float, percent: float = 1.0) -> bool:
	var half := percent * 0.5
	var min1 := x1 - w1 * half
	var max1 := x1 + w1 * half
	var min2 := x2 - w2 * half
	var max2 := x2 + w2 * half
	return not (max1 < min2 or min1 > max2)
