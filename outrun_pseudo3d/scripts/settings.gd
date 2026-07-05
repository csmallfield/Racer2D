extends Node
## Autoloaded as "Settings": user options with persistence (user://settings.json)
## and live application. Owns the retro screen filter — a full-window
## ColorRect on a top CanvasLayer running assets/shaders/retro_screen.gdshader
## over everything (game, HUD, and menus alike, as a real CRT would).

const SAVE_PATH := "user://settings.json"
const SHADER := "res://assets/shaders/retro_screen.gdshader"

var fullscreen := false
var music_volume := 1.0        # 0..1 linear
var sfx_volume := 1.0
var crt_enabled := false
var crt_curvature := 0.04
var crt_scanlines := 0.3
var crt_fringe := 1.4          # chromatic aberration, px
var crt_vignette := 0.25
var crt_noise := 0.05

var _layer: CanvasLayer
var _rect: ColorRect
var _mat: ShaderMaterial


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER)
	_rect.material = _mat
	_layer.add_child(_rect)
	_load()
	apply()


func apply() -> void:
	_layer.visible = crt_enabled
	_mat.set_shader_parameter("curvature", crt_curvature)
	_mat.set_shader_parameter("scanline_strength", crt_scanlines)
	_mat.set_shader_parameter("aberration", crt_fringe)
	_mat.set_shader_parameter("vignette", crt_vignette)
	_mat.set_shader_parameter("noise_strength", crt_noise)
	_mat.set_shader_parameter("flicker", crt_noise * 0.4)
	DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
			else DisplayServer.WINDOW_MODE_WINDOWED)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(sfx_volume, 0.0001)))
	Audio.set_music_volume(music_volume)


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"fullscreen": fullscreen, "music": music_volume, "sfx": sfx_volume,
		"crt": crt_enabled, "curvature": crt_curvature,
		"scanlines": crt_scanlines, "fringe": crt_fringe,
		"vignette": crt_vignette, "noise": crt_noise,
	}))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if not d is Dictionary:
		return
	fullscreen = bool(d.get("fullscreen", fullscreen))
	music_volume = float(d.get("music", music_volume))
	sfx_volume = float(d.get("sfx", sfx_volume))
	crt_enabled = bool(d.get("crt", crt_enabled))
	crt_curvature = float(d.get("curvature", crt_curvature))
	crt_scanlines = float(d.get("scanlines", crt_scanlines))
	crt_fringe = float(d.get("fringe", crt_fringe))
	crt_vignette = float(d.get("vignette", crt_vignette))
	crt_noise = float(d.get("noise", crt_noise))
