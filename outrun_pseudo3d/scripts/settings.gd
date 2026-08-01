extends Node
## Autoloaded as "Settings": user options with persistence (user://settings.json)
## and live application. Owns the retro screen filter — a full-window
## ColorRect on a top CanvasLayer running assets/shaders/retro_screen.gdshader
## over everything (game, HUD, and menus alike, as a real CRT would).

const SAVE_PATH := "user://settings.json"
const SHADER := "res://assets/shaders/retro_screen.gdshader"
## Bumped when the save layout changes. v1 had a plain `fullscreen` bool;
## v2 replaces it with the display block below and migrates on load.
const SAVE_VERSION := 2

# --- Display. See DisplayConfig for the policy these drive. ---
var window_mode := DisplayConfig.MODE_FULLSCREEN
var monitor := -1              # -1 = follow whichever screen the window is on
var window_size_idx := -1      # index into DisplayConfig.presets(); -1 = auto
var aspect_mode := DisplayConfig.ASPECT_AUTO
var render_scale := 1.0        # content_scale_factor: 0.5 / 0.75 / 1.0
var vsync := true

var music_volume := 1.0        # 0..1 linear
var sfx_volume := 1.0
# Menu selections made sticky across sessions (set from the menu flow, not the
# settings screen). difficulty: 0 Easy / 1 Normal / 2 Hard. sticky_racers holds
# the last-used racer id per player slot.
var difficulty := 1
var sticky_racers: Array = []
## Arcade initials per player slot, pre-filled on the record-entry screen.
var sticky_initials: Array = ["AAA", "AAA", "AAA", "AAA"]
# Seeded from resources/retro_filter.tres (designer defaults); the menu
# subset is then overridden by the user save. Flicker and scanline density
# are resource-only.
var crt_enabled := false
var crt_curvature := 0.04
var crt_scanlines := 0.3
var crt_fringe := 1.4          # chromatic aberration, px
var crt_vignette := 0.25
var crt_noise := 0.05
var crt_flicker := 0.02
var crt_density := 540.0

var _layer: CanvasLayer
var _rect: ColorRect
var _mat: ShaderMaterial
var _applying_display := false


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
	var d: RetroFilterSettings = GameConfig.retro
	crt_enabled = d.enabled_by_default
	crt_curvature = d.curvature
	crt_scanlines = d.scanlines
	crt_fringe = d.fringe
	crt_vignette = d.vignette
	crt_noise = d.noise
	crt_flicker = d.flicker
	crt_density = d.scanline_density
	_load()
	apply()
	# Window resizes (and monitor changes) re-derive the logical frame. This is
	# the root Viewport's signal, so it also fires when we set content_scale_size
	# ourselves — _apply_content_scale only writes on a real change, so the
	# second pass is a no-op and it terminates.
	get_window().size_changed.connect(_on_window_resized)


func _on_window_resized() -> void:
	if _applying_display:
		return
	_apply_content_scale()


func apply() -> void:
	_layer.visible = crt_enabled
	_mat.set_shader_parameter("curvature", crt_curvature)
	_mat.set_shader_parameter("scanline_strength", crt_scanlines)
	_mat.set_shader_parameter("aberration", crt_fringe)
	_mat.set_shader_parameter("vignette", crt_vignette)
	_mat.set_shader_parameter("noise_strength", crt_noise)
	_mat.set_shader_parameter("flicker", crt_flicker)
	_mat.set_shader_parameter("scanline_density", crt_density)
	apply_display()
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(sfx_volume, 0.0001)))
	Audio.set_music_volume(music_volume)


## Push the display block to the window. Every write is guarded against the
## current value: apply() runs on every settings keystroke (including volume
## nudges), and unconditional window_set_mode calls make the window flicker.
func apply_display() -> void:
	if _applying_display or not DisplayConfig.available():
		return
	_applying_display = true
	var w := get_window()
	var screen := DisplayConfig.screen_index(monitor)
	if w.current_screen != screen:
		w.current_screen = screen
	var target := Window.MODE_FULLSCREEN
	match window_mode:
		DisplayConfig.MODE_EXCLUSIVE:
			target = Window.MODE_EXCLUSIVE_FULLSCREEN
		DisplayConfig.MODE_WINDOWED:
			target = Window.MODE_WINDOWED
	if w.mode != target:
		w.mode = target
	if window_mode == DisplayConfig.MODE_WINDOWED:
		var want := current_preset()
		if w.size != want:
			w.size = want
			var usable := DisplayServer.screen_get_usable_rect(screen)
			w.position = usable.position + (usable.size - want) / 2
	DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	_apply_content_scale()
	_applying_display = false


## Derive the logical viewport from the live window size. Everything that lays
## out against the frame (RoadRenderer, HudLayer, DesignFrame, the split-screen
## rects in main.gd) reacts to the viewport size_changed this raises.
func _apply_content_scale() -> void:
	var w := get_window()
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	w.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var want := DisplayConfig.logical_size(w.size, aspect_mode)
	if w.content_scale_size != want:
		w.content_scale_size = want
	var f := clampf(render_scale, 0.25, 1.0)
	if not is_equal_approx(w.content_scale_factor, f):
		w.content_scale_factor = f


## Window presets for the currently selected monitor.
func presets() -> Array[Vector2i]:
	return DisplayConfig.presets(DisplayConfig.screen_index(monitor))


func preset_count() -> int:
	return presets().size()


## The chosen windowed size, clamping (and repairing) a stale saved index —
## the preset list is monitor-dependent, so a save made on another machine or
## another monitor can point past the end of it.
func current_preset() -> Vector2i:
	var list := presets()
	if list.is_empty():
		return DisplayConfig.DESIGN
	if window_size_idx < 0 or window_size_idx >= list.size():
		window_size_idx = DisplayConfig.default_preset_index(
				DisplayConfig.screen_index(monitor))
		window_size_idx = clampi(window_size_idx, 0, list.size() - 1)
	return list[window_size_idx]


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"version": SAVE_VERSION,
		"window_mode": window_mode, "monitor": monitor,
		"window_size": window_size_idx, "aspect_mode": aspect_mode,
		"render_scale": render_scale, "vsync": vsync,
		"music": music_volume, "sfx": sfx_volume,
		"crt": crt_enabled, "curvature": crt_curvature,
		"scanlines": crt_scanlines, "fringe": crt_fringe,
		"vignette": crt_vignette, "noise": crt_noise,
		"difficulty": difficulty, "racers": sticky_racers,
		"initials": sticky_initials,
	}))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		# First run: auto-detect. Borderless fullscreen on the current screen is
		# already native resolution, so the only thing to pick is the windowed
		# size the player gets if they switch.
		if DisplayConfig.available():
			var s := DisplayConfig.screen_index(-1)
			window_size_idx = DisplayConfig.default_preset_index(s)
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if not d is Dictionary:
		return
	if d.has("window_mode"):
		window_mode = int(d.get("window_mode", window_mode))
		monitor = int(d.get("monitor", monitor))
		window_size_idx = int(d.get("window_size", window_size_idx))
		aspect_mode = int(d.get("aspect_mode", aspect_mode))
		render_scale = clampf(float(d.get("render_scale", render_scale)), 0.25, 1.0)
		vsync = bool(d.get("vsync", vsync))
	elif d.has("fullscreen"):
		# v1 save: the old bool only distinguished fullscreen from windowed.
		window_mode = (DisplayConfig.MODE_FULLSCREEN if bool(d.get("fullscreen", false))
				else DisplayConfig.MODE_WINDOWED)
	music_volume = float(d.get("music", music_volume))
	sfx_volume = float(d.get("sfx", sfx_volume))
	crt_enabled = bool(d.get("crt", crt_enabled))
	crt_curvature = float(d.get("curvature", crt_curvature))
	crt_scanlines = float(d.get("scanlines", crt_scanlines))
	crt_fringe = float(d.get("fringe", crt_fringe))
	crt_vignette = float(d.get("vignette", crt_vignette))
	crt_noise = float(d.get("noise", crt_noise))
	difficulty = int(d.get("difficulty", difficulty))
	var r: Variant = d.get("racers", sticky_racers)
	sticky_racers = r if r is Array else sticky_racers
	var ini: Variant = d.get("initials", sticky_initials)
	sticky_initials = ini if ini is Array else sticky_initials
