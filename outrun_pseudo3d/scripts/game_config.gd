extends Node
## Autoloaded as "GameConfig": the single access point for tunable game
## resources. Missing/broken .tres files fall back to script defaults, so
## the game always boots.

var player: PlayerSettings
var camera: CameraSettings
var race: RaceSettings
var retro: RetroFilterSettings

## Active difficulty. Never null — falls back to script defaults, which ARE
## Normal, so a missing .tres degrades to baseline tuning.
var difficulty: DifficultyProfile

## Pristine, never-mutated originals. `player` and `race` above are per-race
## working copies derived from these. Godot Resources are shared references:
## scaling GameConfig.race.curve_slowdown in place would corrupt the loaded
## .tres for the whole session and compound every race.
var _player_base: PlayerSettings
var _race_base: RaceSettings
var _difficulties: Array[DifficultyProfile] = []


func _init() -> void:
	player = _load_res("res://resources/player_settings.tres") as PlayerSettings
	if player == null:
		player = PlayerSettings.new()
	camera = _load_res("res://resources/camera_settings.tres") as CameraSettings
	if camera == null:
		camera = CameraSettings.new()
	race = _load_res("res://resources/race_settings.tres") as RaceSettings
	if race == null:
		race = RaceSettings.new()
	retro = _load_res("res://resources/retro_filter.tres") as RetroFilterSettings
	if retro == null:
		retro = RetroFilterSettings.new()

	_player_base = player
	_race_base = race
	for name in ["easy", "normal", "hard"]:
		var d := _load_res("res://resources/difficulties/%s.tres" % name) as DifficultyProfile
		if d == null:
			d = DifficultyProfile.new()
		_difficulties.append(d)
	apply_difficulty(1)


## Rebuild `player` and `race` as difficulty-scaled copies of the pristine
## bases. Call once per race, before anything caches those references —
## PlayerCar and RivalManager both grab them at construction.
func apply_difficulty(index: int) -> void:
	difficulty = _difficulties[clampi(index, 0, _difficulties.size() - 1)]

	# Shallow duplicates: the roster Array is shared with the base by design,
	# so roster indices stay valid everywhere (racer select, exclusions). We
	# never mutate the roster itself.
	var p := _player_base.duplicate() as PlayerSettings
	var r := _race_base.duplicate() as RaceSettings

	# --- Opposition: pace ---
	r.curve_slowdown = _race_base.curve_slowdown * difficulty.curve_slowdown_scale
	# The cap scales too, or the knob does nothing on sharp bends — where the
	# uncapped loss already exceeds it at every difficulty.
	r.curve_slowdown_cap = _race_base.curve_slowdown_cap * difficulty.curve_slowdown_scale
	r.form_variance = _race_base.form_variance * difficulty.form_variance_scale
	r.pack_bonus_per_car = _race_base.pack_bonus_per_car * difficulty.pack_bonus_scale
	r.rubber_behind = _race_base.rubber_behind * difficulty.rubber_behind_scale

	# --- Opposition: skill ---
	r.lookahead = maxi(4, int(round(float(_race_base.lookahead)
			* difficulty.lookahead_scale)))
	r.apex_bias = _race_base.apex_bias * difficulty.apex_bias_scale

	# --- Player assists (neutral outside Easy) ---
	p.centrifugal = _player_base.centrifugal * difficulty.centrifugal_scale
	p.off_road_limit = _player_base.off_road_limit * difficulty.off_road_limit_scale
	p.off_road_decel = _player_base.off_road_decel * difficulty.off_road_decel_scale

	player = p
	race = r


func _load_res(path: String) -> Resource:
	if not ResourceLoader.exists(path):
		push_warning("GameConfig: %s missing, using script defaults." % path)
		return null
	return load(path)
