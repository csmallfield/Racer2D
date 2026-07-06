extends Node
## Autoloaded as "GameConfig": the single access point for tunable game
## resources. Missing/broken .tres files fall back to script defaults, so
## the game always boots.

var player: PlayerSettings
var camera: CameraSettings
var race: RaceSettings
var retro: RetroFilterSettings


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


func _load_res(path: String) -> Resource:
	if not ResourceLoader.exists(path):
		push_warning("GameConfig: %s missing, using script defaults." % path)
		return null
	return load(path)
