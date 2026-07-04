extends Node2D
## Game orchestrator: discovers levels, builds tracks, runs the game loop
## (player update, traffic, collisions, timer, stage progression).

const LEVELS_DIR := "res://scripts/levels"
const AI_LOOKAHEAD := 20        # segments traffic scans ahead for avoidance

enum State { MENU, LEVEL_SELECT, LEADERBOARD, COUNTDOWN, RUNNING, STAGE_CLEAR, GAME_OVER, PAUSED }
enum Mode { RACE, TIME_TRIAL }

const MENU_ITEMS: Array[String] = ["RACE", "TIME TRIAL", "BEST TIMES", "QUIT"]

var level_paths: Array = []
var level_names: Array = []     # display names, parallel to level_paths
var level_musics: Array = []    # every music name levels declare (fallback pool)
var level_index := 0
var level: TrackLevel
var track: TrackBuilder
var player: PlayerCar
var cars: Array = []
var rivals: RivalManager

var renderer: RoadRenderer
var hud: HudLayer

var state: State = State.MENU
var mode: Mode = Mode.RACE
var menu: MenuLayer
var menu_sel := 0               # highlighted row in the current menu view
var select_sel := 0             # highlighted stage in level select / board
var paused_from: State = State.RUNNING   # state to resume into after pause
var time_left := 0.0
var countdown_t := 0.0          # 3..0 pre-race countdown
var _last_count := -1           # last whole second announced in the countdown
var race_time := 0.0            # overall race clock, counts up while RUNNING
var section_time := 0.0         # timer grant per checkpoint section
var cp_zs: Array[float] = []    # checkpoint z positions on the track
var player_next_cp := 0         # index of the player's next checkpoint
var player_finish_time := 0.0   # race clock when the player crossed the line
var _board_title := ""          # frozen at the player's finish
var _last_beep_second := -1     # last whole second a time_warning beep fired
var _prev_air := 0.0            # player air last frame (landing detection)


func _ready() -> void:
	randomize()
	_discover_levels()
	renderer = RoadRenderer.new()
	renderer.main = self
	add_child(renderer)
	hud = HudLayer.new()
	add_child(hud)
	menu = MenuLayer.new()
	add_child(menu)
	_load_level(0)   # idle stage 1 as the menu backdrop
	_enter_menu()


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
	for path in level_paths:
		var script: GDScript = load(path)
		var inst: TrackLevel = script.new()
		level_names.append(inst.level_name)
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

	cp_zs = track.mark_checkpoints(level.checkpoint_count)
	section_time = level.time_limit / float(level.checkpoint_count + 1)
	player_next_cp = 0
	race_time = 0.0

	player = PlayerCar.new()
	_spawn_traffic()
	rivals = RivalManager.new()
	rivals.spawn(self, level.rival_count if mode == Mode.RACE else 0)

	time_left = section_time
	_last_beep_second = -1
	hud.set_stage(level.level_name)
	hud.set_message("")
	hud.hide_leaderboard()
	hud.clear_race_ui()
	hud.set_race_time(0.0)
	Audio.stop_engine()


## Load a stage and begin its countdown (level music starts here so the
## idle menu backdrop stays on menu music).
func _start_race(idx: int) -> void:
	_load_level(idx)
	menu.hide_menu()
	var fractions: Array = []
	for z in cp_zs:
		fractions.append(z / track.track_length())
	hud.setup_progress(fractions)
	state = State.COUNTDOWN
	countdown_t = 3.0
	_last_count = -1
	# Levels without a dedicated (and present) track get a random existing one.
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
	hud.set_message("")
	hud.hide_leaderboard()
	hud.clear_race_ui()
	Audio.stop_engine()
	Audio.play_music("music_menu")
	menu.show_main(MENU_ITEMS, menu_sel)


## Player checkpoint crossing: extend the section timer (leftover time
## carries over, OutRun style) and flash the delta to the fastest rival
## through the same checkpoint.
func _check_player_checkpoint(prev_z: float) -> void:
	if player_next_cp >= cp_zs.size():
		return
	var cp_z := cp_zs[player_next_cp]
	if prev_z < cp_z and player.position_z >= cp_z:
		time_left += section_time
		_last_beep_second = -1
		Audio.play("checkpoint")
		if mode == Mode.TIME_TRIAL:
			hud.set_flash("CHECKPOINT")
			player_next_cp += 1
			return
		# Racing-standard delta: "+" behind the leader (red), "-" ahead (green).
		var leader_t: float = rivals.leader_cp_times[player_next_cp]
		var green := Color(0.35, 0.95, 0.4)
		var red := Color(0.95, 0.3, 0.25)
		if leader_t < 0.0:
			# Nobody has crossed yet: your cushion over the best chaser.
			var eta: float = rivals.next_rival_eta(cp_z)
			hud.set_flash("CHECKPOINT  -%s  (LEADER)"
					% HudLayer.format_time(eta), green)
		else:
			var delta := race_time - leader_t
			var sign_str := "+" if delta >= 0.0 else "-"
			hud.set_flash("CHECKPOINT  %s%s"
					% [sign_str, HudLayer.format_time(absf(delta))],
					red if delta >= 0.0 else green)
		player_next_cp += 1


func _update_progress_bar() -> void:
	var track_len := track.track_length()
	var dots: Array = []
	for r in rivals.rivals:
		var def: Dictionary = SpriteCatalog.get_def(r.sprite)
		dots.append({
			"p": minf(float(r.z) / track_len, 1.0),
			"color": def.get("map_color", Color.WHITE),
		})
	hud.update_progress(player.position_z / track_len, dots)


## Ballistic vertical step for an NPC car dict. Grounded motion sets
## vertical velocity from terrain slope x speed, so hill crests launch cars
## naturally — the faster, the bigger the air. (Player has the same model
## inside PlayerCar.update.)
func _step_air(car: Dictionary, g_prev: float, dt: float) -> void:
	var g_new := ground_y(float(car.z))
	car.vy = float(car.vy) - PlayerCar.GRAVITY \
			* (PlayerCar.FALL_MULT if float(car.vy) < 0.0 else 1.0) * dt
	car.y = float(car.y) + float(car.vy) * dt
	if float(car.y) <= g_new:
		car.y = g_new
		car.vy = minf(maxf(float(car.vy), (g_new - g_prev) / maxf(dt, 0.0001)),
				PlayerCar.MAX_LAUNCH_VY)
	car.air = float(car.y) - g_new


## Interpolated road altitude (world units) at any track position.
func ground_y(z: float) -> float:
	var seg := find_segment(z)
	var t := fposmod(z, TrackBuilder.SEGMENT_LENGTH) / TrackBuilder.SEGMENT_LENGTH
	return lerpf(seg.p1.world.y, seg.p2.world.y, t)


func _spawn_traffic() -> void:
	cars.clear()
	for seg in track.segments:
		seg.cars.clear()
	var lane_offsets := [-0.66, 0.0, 0.66]
	var sprite_names := ["car_blue", "car_yellow", "car_green"]
	for i in range(level.traffic_count):
		var z := randf_range(3000.0, track.track_length() - 3000.0)
		var car := {
			"z": z,
			"offset": lane_offsets.pick_random(),
			"speed": PlayerCar.MAX_SPEED * randf_range(0.12, 0.5),
			"sprite": sprite_names.pick_random(),
			"y": ground_y(z), "vy": 0.0, "air": 0.0,   # vertical state
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
			_start_race(level_index + 1)
			return

	# Esc (ui_cancel) backs out of any race state to the menu.
	if state >= State.COUNTDOWN and Input.is_action_just_pressed("ui_cancel"):
		_enter_menu()
		return

	# Pause toggle (P / gamepad Start) during the countdown or the race.
	if Input.is_action_just_pressed("pause"):
		if state == State.RUNNING or state == State.COUNTDOWN:
			paused_from = state
			state = State.PAUSED
			hud.set_message("PAUSED")
			Audio.stop_engine()
		elif state == State.PAUSED:
			state = paused_from
			hud.set_message("")
			_last_count = -1   # countdown repaints its number on resume
		return

	match state:
		State.MENU:
			_menu_frame(dt)
		State.LEVEL_SELECT:
			_level_select_frame(dt)
		State.LEADERBOARD:
			_leaderboard_frame(dt)
		State.COUNTDOWN:
			_countdown_frame(dt)
		State.RUNNING:
			_run_frame(dt)
		State.STAGE_CLEAR:
			race_time += dt   # late finishers still get real times
			_coast_frame(dt, PlayerCar.MAX_SPEED * 0.35)
			if mode == Mode.RACE:
				hud.show_leaderboard(rivals.board_entries(player_finish_time),
						_board_title)
			if Input.is_action_just_pressed("accelerate"):
				_start_race(level_index + 1)
		State.GAME_OVER:
			_coast_frame(dt, 0.0)
		State.PAUSED:
			pass   # world frozen; only the pause toggle and Esc are live

	hud.set_speed(player.speed_kmh())
	hud.set_time(time_left)


## Title menu: traffic ambles through the idle backdrop while the player
## picks a mode. Navigation: steer/ui up-down, accelerate/ui_accept selects.
func _menu_frame(dt: float) -> void:
	_update_traffic(dt)
	# ui_* actions only: "accelerate" contains the Up arrow and "brake" the
	# Down arrow, so they would fire alongside ui_up/ui_down navigation.
	# Enter / Space / gamepad A confirm via ui_accept.
	var moved := 0
	if Input.is_action_just_pressed("ui_down"):
		moved = 1
	elif Input.is_action_just_pressed("ui_up"):
		moved = -1
	if moved != 0:
		menu_sel = wrapi(menu_sel + moved, 0, MENU_ITEMS.size())
		Audio.play("menu_move")
		menu.show_main(MENU_ITEMS, menu_sel)
	if Input.is_action_just_pressed("ui_accept"):
		Audio.play("menu_select")
		match menu_sel:
			0:
				mode = Mode.RACE
				_open_level_select()
			1:
				mode = Mode.TIME_TRIAL
				_open_level_select()
			2:
				state = State.LEADERBOARD
				select_sel = 0
				_refresh_board()
			3:
				get_tree().quit()


func _open_level_select() -> void:
	state = State.LEVEL_SELECT
	select_sel = level_index
	menu.show_levels(level_names, select_sel,
			"RACE" if mode == Mode.RACE else "TIME TRIAL")


func _level_select_frame(dt: float) -> void:
	_update_traffic(dt)
	var moved := 0
	if (Input.is_action_just_pressed("ui_down")
			or Input.is_action_just_pressed("steer_right")):
		moved = 1
	elif (Input.is_action_just_pressed("ui_up")
			or Input.is_action_just_pressed("steer_left")):
		moved = -1
	if moved != 0:
		select_sel = wrapi(select_sel + moved, 0, level_names.size())
		Audio.play("menu_move")
		menu.show_levels(level_names, select_sel,
				"RACE" if mode == Mode.RACE else "TIME TRIAL")
	if Input.is_action_just_pressed("ui_accept"):
		Audio.play("menu_select")
		_start_race(select_sel)
	elif Input.is_action_just_pressed("ui_cancel"):
		Audio.play("menu_move")
		_enter_menu()


func _leaderboard_frame(dt: float) -> void:
	_update_traffic(dt)
	var moved := 0
	if (Input.is_action_just_pressed("ui_right")
			or Input.is_action_just_pressed("steer_right")):
		moved = 1
	elif (Input.is_action_just_pressed("ui_left")
			or Input.is_action_just_pressed("steer_left")):
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
	menu.show_board(String(level_names[select_sel]),
			Records.get_times(fname, "race"),
			Records.get_times(fname, "time_trial"))


## Pre-race: racers held on the grid, traffic ambling, big 3-2-1 center
## stage. RUNNING (and the race clock) begins on GO.
func _countdown_frame(dt: float) -> void:
	countdown_t -= dt
	_update_traffic(dt)
	_scroll_background(dt)
	Audio.update_engine(0.0, false)
	var whole := int(ceilf(countdown_t))
	if countdown_t <= 0.0:
		state = State.RUNNING
		hud.set_message("")
		hud.set_flash("GO!")
		Audio.play("countdown_go")
	elif whole != _last_count:
		_last_count = whole
		hud.set_message(str(whole))
		Audio.play("countdown_beep")


func _run_frame(dt: float) -> void:
	race_time += dt
	hud.set_race_time(race_time)
	var prev_z := player.position_z
	var crossed := player.update(dt, self)
	_check_player_checkpoint(prev_z)
	_update_traffic(dt)
	rivals.update(dt, self)
	if mode == Mode.RACE:
		for e in rivals.events:
			hud.set_flash(e)
		hud.set_position_rank(rivals.player_rank(player.position_z),
				rivals.total_racers())
	_update_progress_bar()

	# Slipstream whoosh as the tow reaches full strength.
	if player.slip > 0.9:
		Audio.play("slipstream", -4.0, 1.0, 1.5)

	# Landing thud after real air.
	if _prev_air > 200.0 and player.air <= 0.5:
		Audio.play("land", -6.0)
	_prev_air = player.air
	_check_collisions()
	_scroll_background(dt)
	Audio.update_engine(player.speed / PlayerCar.MAX_SPEED,
			absf(player.x) > 1.0, player.steer_dir)

	time_left -= dt
	var whole_seconds := int(ceilf(time_left))
	if whole_seconds <= 10 and whole_seconds >= 1 and whole_seconds != _last_beep_second:
		_last_beep_second = whole_seconds
		Audio.play("time_warning")

	if crossed:
		state = State.STAGE_CLEAR
		player_finish_time = race_time
		var fname := String(level_paths[level_index]).get_file()
		var mode_key := "race" if mode == Mode.RACE else "time_trial"
		var best_rank := Records.add_time(fname, mode_key, player_finish_time)
		hud.set_message("")
		if mode == Mode.RACE:
			var entries: Array = rivals.board_entries(player_finish_time)
			var final_rank := 1
			for i in range(entries.size()):
				if bool(entries[i].is_player):
					final_rank = i + 1
					break
			_board_title = "FINISHED %s of %d" % [HudLayer.ordinal(final_rank),
					rivals.total_racers()]
			if best_rank > 0:
				_board_title += "  —  BEST #%d" % best_rank
			hud.show_leaderboard(entries, _board_title)
		else:
			# Time trial: your run against the stage's all-time top 10.
			var times: Array = Records.get_times(fname, mode_key)
			var entries: Array = []
			var marked := false
			for i in range(times.size()):
				var is_you := (not marked
						and absf(float(times[i]) - player_finish_time) < 0.0005)
				if is_you:
					marked = true
				entries.append({"name": "YOU" if is_you else "-",
						"time": float(times[i]), "is_player": is_you})
			_board_title = "TIME TRIAL — %s" % HudLayer.format_time(player_finish_time)
			if best_rank > 0:
				_board_title += "  (BEST #%d)" % best_rank
			hud.show_leaderboard(entries, _board_title)
		Audio.play("stage_clear")
	elif time_left <= 0.0:
		time_left = 0.0
		state = State.GAME_OVER
		hud.set_message("TIME UP — press R to retry")
		Audio.play("game_over")


## Keeps the world moving (with input disabled) during clear/game-over states.
func _coast_frame(dt: float, target_speed: float) -> void:
	player.speed = move_toward(player.speed, target_speed, PlayerCar.MAX_SPEED * 0.5 * dt)
	player.position_z = fposmod(player.position_z + player.speed * dt, track.track_length())
	player.steer_dir = 0.0
	player.bounce = 0.0
	player.x = move_toward(player.x, 0.0, dt * 1.5)
	_update_traffic(dt)
	rivals.update(dt, self)
	_scroll_background(dt)
	Audio.update_engine(player.speed / PlayerCar.MAX_SPEED, false)


func _scroll_background(dt: float) -> void:
	var seg := find_segment(player.position_z)
	# In a right-hand curve the world rotates left past you, so the far
	# hills sweep left: offset increases (sampled as x + offset).
	renderer.hill_offset += seg.curve * (player.speed / PlayerCar.MAX_SPEED) * dt * 120.0


func _update_traffic(dt: float) -> void:
	var track_len := track.track_length()
	var player_seg := find_segment(player.position_z)
	var player_w: float = SpriteCatalog.get_def("player").world_w / RoadRenderer.ROAD_WIDTH
	for car in cars:
		var old_seg := find_segment(car.z)
		car.offset = clampf(
				float(car.offset) + _car_steer(car, old_seg, player_seg, player_w) * dt * 60.0,
				-1.2, 1.2)
		var g_prev := ground_y(float(car.z))
		car.z = fposmod(car.z + car.speed * dt, track_len)
		_step_air(car, g_prev, dt)
		var new_seg := find_segment(car.z)
		if old_seg.index != new_seg.index:
			old_seg.cars.erase(car)
			new_seg.cars.append(car)


## Per-frame lateral steering for one NPC car (codeincomplete's updateCarOffset).
## Scans up to AI_LOOKAHEAD segments ahead; dodges the player and slower cars,
## steering harder the closer the obstacle. Returns offset delta per 1/60 s.
## lookahead: how many segments ahead the car scans (rivals scan farther —
## at racing speeds the default gives too little reaction time).
func _car_steer(car: Dictionary, car_seg: Dictionary, player_seg: Dictionary,
		player_w: float, lookahead: int = AI_LOOKAHEAD) -> float:
	var seg_count := track.segments.size()
	# Cars far outside the drawn window don't need AI (invisible anyway).
	var rel: int = (int(car_seg.index) - int(player_seg.index) + seg_count) % seg_count
	if rel > RoadRenderer.DRAW_DISTANCE:
		return 0.0

	var car_w: float = SpriteCatalog.get_def(car.sprite).world_w / RoadRenderer.ROAD_WIDTH
	var car_x: float = float(car.offset)
	for i in range(1, lookahead):
		var seg: Dictionary = track.segments[(int(car_seg.index) + i) % seg_count]

		# Player ahead of us, we're faster, and paths overlap: swerve.
		if seg.index == player_seg.index and car.speed > player.speed \
				and _overlap(player.x, player_w, car_x, car_w, 1.2):
			var dir := 0.0
			if player.x > 0.5:
				dir = -1.0
			elif player.x < -0.5:
				dir = 1.0
			else:
				dir = 1.0 if car_x > player.x else -1.0
			return dir / float(i) * float(car.speed - player.speed) / PlayerCar.MAX_SPEED

		# Slower car ahead: swerve around it.
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
				return dir / float(i) * float(car.speed - other.speed) / PlayerCar.MAX_SPEED

	# Nothing ahead: drift back toward the road if we've wandered wide.
	if float(car.offset) < -0.9:
		return 0.1
	if float(car.offset) > 0.9:
		return -0.1
	return 0.0

func _check_collisions() -> void:
	# Airborne cars sail clean over traffic and scenery.
	if player.air > 250.0:
		return
	var seg := find_segment(player.position_z + renderer.player_z())
	var player_w: float = SpriteCatalog.get_def("player").world_w / RoadRenderer.ROAD_WIDTH

	# Roadside scenery (only ever placed off-road, so only check when off-road).
	if absf(player.x) > 0.8:
		for spr in seg.sprites:
			var def: Dictionary = SpriteCatalog.get_def(spr.name)
			if not def.collidable:
				continue
			var sw: float = def.world_w / RoadRenderer.ROAD_WIDTH
			if _overlap(player.x, player_w, spr.offset, sw):
				player.speed = PlayerCar.MAX_SPEED * 0.06
				Audio.play("crash", 0.0, 1.0, 0.5)
				break

	# Traffic: rear-ending a slower car slams your speed down and pushes
	# you back behind it.
	for car in seg.cars:
		if player.speed <= car.speed:
			continue
		var cw: float = SpriteCatalog.get_def(car.sprite).world_w / RoadRenderer.ROAD_WIDTH
		if _overlap(player.x, player_w, car.offset, cw, 0.8):
			player.speed = car.speed * (car.speed / maxf(player.speed, 1.0))
			player.position_z = fposmod(car.z - renderer.player_z(), track.track_length())
			Audio.play("bump", 0.0, 1.0, 0.3)
			break


static func _overlap(x1: float, w1: float, x2: float, w2: float, percent: float = 1.0) -> bool:
	var half := percent * 0.5
	var min1 := x1 - w1 * half
	var max1 := x1 + w1 * half
	var min2 := x2 - w2 * half
	var max2 := x2 + w2 * half
	return not (max1 < min2 or min1 > max2)
