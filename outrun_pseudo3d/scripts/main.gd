extends Node2D
## Game orchestrator: discovers levels, builds tracks, runs the game loop
## (player update, traffic, collisions, timer, stage progression).

const LEVELS_DIR := "res://scripts/levels"
const STAGE_CLEAR_DELAY := 3.0

enum State { RUNNING, STAGE_CLEAR, GAME_OVER }

var level_paths: Array = []
var level_index := 0
var level: TrackLevel
var track: TrackBuilder
var player: PlayerCar
var cars: Array = []

var renderer: RoadRenderer
var hud: HudLayer

var state: State = State.RUNNING
var time_left := 0.0
var state_timer := 0.0


func _ready() -> void:
	randomize()
	_discover_levels()
	renderer = RoadRenderer.new()
	renderer.main = self
	add_child(renderer)
	hud = HudLayer.new()
	add_child(hud)
	_load_level(0)


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

	player = PlayerCar.new()
	_spawn_traffic()

	time_left = level.time_limit
	state = State.RUNNING
	hud.set_stage(level.level_name)
	hud.set_message("")


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

	if Input.is_action_just_pressed("restart"):
		_load_level(level_index)
		return
	if Input.is_action_just_pressed("next_level"):
		_load_level(level_index + 1)
		return

	match state:
		State.RUNNING:
			_run_frame(dt)
		State.STAGE_CLEAR:
			_coast_frame(dt, PlayerCar.MAX_SPEED * 0.35)
			state_timer -= dt
			if state_timer <= 0.0:
				_load_level(level_index + 1)
		State.GAME_OVER:
			_coast_frame(dt, 0.0)

	hud.set_speed(player.speed_kmh())
	hud.set_time(time_left)


func _run_frame(dt: float) -> void:
	var crossed := player.update(dt, self)
	_update_traffic(dt)
	_check_collisions()
	_scroll_background(dt)

	time_left -= dt
	if crossed:
		state = State.STAGE_CLEAR
		state_timer = STAGE_CLEAR_DELAY
		hud.set_message("STAGE CLEAR!")
	elif time_left <= 0.0:
		time_left = 0.0
		state = State.GAME_OVER
		hud.set_message("TIME UP — press R to retry")


## Keeps the world moving (with input disabled) during clear/game-over states.
func _coast_frame(dt: float, target_speed: float) -> void:
	player.speed = move_toward(player.speed, target_speed, PlayerCar.MAX_SPEED * 0.5 * dt)
	player.position_z = fposmod(player.position_z + player.speed * dt, track.track_length())
	player.steer_dir = 0
	player.bounce = 0.0
	_update_traffic(dt)
	_scroll_background(dt)


func _scroll_background(dt: float) -> void:
	var seg := find_segment(player.position_z)
	renderer.hill_offset -= seg.curve * (player.speed / PlayerCar.MAX_SPEED) * dt * 120.0


func _update_traffic(dt: float) -> void:
	var track_len := track.track_length()
	for car in cars:
		var old_seg := find_segment(car.z)
		car.z = fposmod(car.z + car.speed * dt, track_len)
		var new_seg := find_segment(car.z)
		if old_seg.index != new_seg.index:
			old_seg.cars.erase(car)
			new_seg.cars.append(car)


func _check_collisions() -> void:
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
			break


static func _overlap(x1: float, w1: float, x2: float, w2: float, percent: float = 1.0) -> bool:
	var half := percent * 0.5
	var min1 := x1 - w1 * half
	var max1 := x1 + w1 * half
	var min2 := x2 - w2 * half
	var max2 := x2 + w2 * half
	return not (max1 < min2 or min1 > max2)
