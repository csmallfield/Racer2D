class_name HudLayer
extends CanvasLayer
## Simple arcade HUD: speed (bottom-left), timer (top-center),
## stage name (top-left), big center message, control hints (bottom).
## Positions assume the 1920x1080 logical resolution set in project.godot
## (canvas_items stretch keeps this stable at any window size).

var speed_label: Label
var time_label: Label
var stage_label: Label
var message_label: Label
var hint_label: Label
var position_label: Label
var flash_label: Label
var race_time_label: Label
var board_bg: ColorRect
var board_label: RichTextLabel
var _flash_t := 0.0
# Layout scale vs the 1920x1080 design (split-screen viewports are smaller).
var _kx := 1.0
var _ky := 1.0
var track_bar: TrackBar
var boost_bar: BoostBar


func _ready() -> void:
	var vp := get_viewport().get_visible_rect().size
	_kx = vp.x / 1920.0
	_ky = vp.y / 1080.0
	stage_label = _make_label(Vector2(36, 24), Vector2(900, 60), 39,
			HORIZONTAL_ALIGNMENT_LEFT, Color(1, 1, 1))
	time_label = _make_label(Vector2(0, 21), Vector2(1920, 90), 66,
			HORIZONTAL_ALIGNMENT_CENTER, Color(1, 0.9, 0.3))
	speed_label = _make_label(Vector2(36, 975), Vector2(600, 75), 54,
			HORIZONTAL_ALIGNMENT_LEFT, Color(1, 1, 1))
	message_label = _make_label(Vector2(0, 420), Vector2(1920, 150), 84,
			HORIZONTAL_ALIGNMENT_CENTER, Color(1, 1, 1))
	position_label = _make_label(Vector2(1284, 966), Vector2(600, 84), 60,
			HORIZONTAL_ALIGNMENT_RIGHT, Color(1, 0.9, 0.3))
	flash_label = _make_label(Vector2(0, 570), Vector2(1920, 60), 39,
			HORIZONTAL_ALIGNMENT_CENTER, Color(1, 0.9, 0.3))
	race_time_label = _make_label(Vector2(0, 108), Vector2(1920, 45), 30,
			HORIZONTAL_ALIGNMENT_CENTER, Color(1, 1, 1, 0.85))
	boost_bar = BoostBar.new()
	boost_bar.position = Vector2(36 * _kx, 940 * _ky)
	boost_bar.size = Vector2(300 * _kx, 21 * _ky)
	boost_bar.visible = false
	add_child(boost_bar)
	track_bar = TrackBar.new()
	track_bar.position = Vector2(360 * _kx, 993 * _ky)
	track_bar.size = Vector2(1200 * _kx, 18 * _ky)
	track_bar.k = _ky
	track_bar.visible = false
	add_child(track_bar)
	_make_leaderboard()
	hint_label = _make_label(Vector2(0, 1029), Vector2(1908, 45), 24,
			HORIZONTAL_ALIGNMENT_RIGHT, Color(1, 1, 1, 0.7))
	hint_label.text = "P1 WASD+Shift / pad1  •  P2 Arrows+Ctrl / pad2  •  R restart  •  P pause  •  Esc menu"


## Positions/sizes are authored in 1920x1080 design coordinates and scaled
## to the actual viewport (split-screen views are halves or quadrants).
func _make_label(pos: Vector2, size: Vector2, font_size: int,
		align: HorizontalAlignment, color: Color) -> Label:
	var l := Label.new()
	l.position = Vector2(pos.x * _kx, pos.y * _ky)
	l.size = Vector2(size.x * _kx, size.y * _ky)
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", maxi(10, int(font_size * _ky)))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", maxi(4, int(12 * _ky)))
	add_child(l)
	return l


func set_speed(kmh: int) -> void:
	speed_label.text = "%d km/h" % kmh


func set_time(seconds: float) -> void:
	time_label.text = "%d" % int(ceil(maxf(0.0, seconds)))


func set_stage(stage_name: String) -> void:
	stage_label.text = stage_name


func set_message(text: String) -> void:
	message_label.text = text


## Reset per-race HUD elements (position, flash) between modes/menu.
func clear_race_ui() -> void:
	position_label.text = ""
	flash_label.text = ""
	_flash_t = 0.0
	hide_progress()
	boost_bar.visible = false


func set_position_rank(rank: int, total: int) -> void:
	position_label.text = "%s / %d" % [ordinal(rank), total]


## Short race message ("PASSED VIPER!") that fades after a moment.
## Color per call: checkpoint deltas use red (behind) / green (ahead).
func set_flash(text: String, color: Color = Color(1, 0.9, 0.3)) -> void:
	flash_label.text = text
	flash_label.add_theme_color_override("font_color", color)
	_flash_t = 2.0


func _process(dt: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= dt
		flash_label.modulate.a = clampf(_flash_t / 0.6, 0.0, 1.0)
		if _flash_t <= 0.0:
			flash_label.text = ""


static func ordinal(n: int) -> String:
	var suffix := "th"
	if n % 100 < 11 or n % 100 > 13:
		match n % 10:
			1: suffix = "st"
			2: suffix = "nd"
			3: suffix = "rd"
	return "%d%s" % [n, suffix]


func _make_leaderboard() -> void:
	board_bg = ColorRect.new()
	board_bg.position = Vector2(585 * _kx, 180 * _ky)
	board_bg.size = Vector2(750 * _kx, 720 * _ky)
	board_bg.color = Color(0.02, 0.02, 0.06, 0.82)
	board_bg.visible = false
	add_child(board_bg)
	board_label = RichTextLabel.new()
	board_label.position = Vector2(615 * _kx, 204 * _ky)
	board_label.size = Vector2(690 * _kx, 678 * _ky)
	board_label.bbcode_enabled = true
	board_label.scroll_active = false
	board_label.add_theme_font_size_override("normal_font_size", maxi(12, int(36 * _ky)))
	board_label.add_theme_font_size_override("bold_font_size", maxi(12, int(36 * _ky)))
	board_label.visible = false
	add_child(board_label)


## entries: sorted array of {name, time, is_player}; the player row is
## highlighted. Shown until hide_leaderboard().
func show_leaderboard(entries: Array, title: String = "RACE RESULTS") -> void:
	var rows := "[center][b]%s[/b]\n\n[/center]" % title
	rows += "[table=3]"
	for i in range(entries.size()):
		var e: Dictionary = entries[i]
		var racing: bool = float(e.time) < 0.0
		var open_tag := "[color=#ffd24d]"
		if not bool(e.is_player):
			open_tag = "[color=#777777]" if racing else "[color=#e8e8e8]"
		var time_str := "—:——" if racing else format_time(float(e.time))
		rows += "[cell]%s %s  [/color][/cell]" % [open_tag, ordinal(i + 1)]
		rows += "[cell]%s %s  [/color][/cell]" % [open_tag, String(e.name)]
		rows += "[cell]%s%s[/color][/cell]" % [open_tag, time_str]
	rows += "[/table]"
	rows += "\n[center][color=#aaaaaa]accelerate to continue[/color][/center]"
	board_label.text = rows
	board_bg.visible = true
	board_label.visible = true


func hide_leaderboard() -> void:
	board_bg.visible = false
	board_label.visible = false


func set_race_time(t: float) -> void:
	race_time_label.text = format_time(t)


static func format_time(t: float) -> String:
	var m := int(t / 60.0)
	var sec := fmod(t, 60.0)
	return "%d:%04.1f" % [m, sec]


## Show the progress bar for a new race. cp_fractions: checkpoint positions
## as 0..1 along the track.
func set_boost(frac: float) -> void:
	boost_bar.visible = true
	boost_bar.frac = clampf(frac, 0.0, 1.0)
	boost_bar.queue_redraw()


func setup_progress(cp_fractions: Array) -> void:
	track_bar.cp_fractions = cp_fractions
	track_bar.player_p = 0.0
	track_bar.dots = []
	track_bar.visible = true
	track_bar.queue_redraw()


## dots: [{p: 0..1, color: Color}] — one per rival. Empty in time trial.
func update_progress(player_p: float, dots: Array) -> void:
	track_bar.player_p = player_p
	track_bar.dots = dots
	track_bar.queue_redraw()


func hide_progress() -> void:
	track_bar.visible = false


## Thin strip mapping the whole track: checkpoint ticks, a finish tick,
## rival dots in their livery colors, and a larger gold player marker.
class TrackBar:
	extends Control

	var cp_fractions: Array = []
	var dots: Array = []
	var player_p := 0.0
	var k := 1.0   # viewport scale factor

	func _draw() -> void:
		var w := size.x
		draw_rect(Rect2(0, 7.5 * k, w, 3 * k), Color(1, 1, 1, 0.35))
		for f in cp_fractions:
			draw_rect(Rect2(float(f) * w - 1.5 * k, 1.5 * k, 3 * k, 15 * k),
					Color(1, 1, 1, 0.6))
		draw_rect(Rect2(w - 3.0 * k, 0, 4.5 * k, 18 * k), Color(1, 0.9, 0.3, 0.9))
		for d in dots:
			draw_circle(Vector2(clampf(float(d.p), 0.0, 1.0) * w, 9.0 * k),
					4.5 * k, d.color)
		draw_circle(Vector2(clampf(player_p, 0.0, 1.0) * w, 9.0 * k),
				7.5 * k, Color(0.1, 0.1, 0.1))
		draw_circle(Vector2(clampf(player_p, 0.0, 1.0) * w, 9.0 * k),
				6.0 * k, Color(1, 0.85, 0.2))


## Boost fuel gauge: dim track with a hot fill.
class BoostBar:
	extends Control

	var frac := 0.0

	func _draw() -> void:
		draw_rect(Rect2(0, 0, size.x, size.y), Color(0, 0, 0, 0.45))
		if frac > 0.0:
			draw_rect(Rect2(2, 2, (size.x - 4.0) * frac, size.y - 4.0),
					Color(1.0, 0.55, 0.05))
		draw_rect(Rect2(0, 0, size.x, size.y), Color(1, 1, 1, 0.5), false, 2.0)
