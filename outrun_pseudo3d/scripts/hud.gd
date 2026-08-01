class_name HudLayer
extends CanvasLayer
## Simple arcade HUD: speed (bottom-left), timer (top-center),
## stage name (top-left), big center message, control hints (bottom).
##
## Elements are authored in 1920x1080 design units but placed as insets from
## the edges of the ACTUAL viewport, at one uniform scale. That matters twice
## over: split-screen views are halves and quadrants, and with the adaptive
## logical viewport a 1P frame on an ultrawide is wider than 16:9. Scaling the
## two axes independently (as this used to) stretched the type; positioning
## from the top-left alone left the corner readouts stranded mid-screen.

var speed_label: Label
var time_label: Label
var stage_label: Label
var message_label: Label
var hint_label: Label
var position_label: Label
var lap_label: Label
var flash_label: Label
var race_time_label: Label
var board_bg: ColorRect
var board_label: RichTextLabel
var _flash_t := 0.0
var track_bar: TrackBar
var boost_bar: BoostBar

const DESIGN := Vector2(1920.0, 1080.0)
const H_LEFT := 0
const H_CENTER := 1
const H_RIGHT := 2
const V_TOP := 0
const V_BOTTOM := 1

## One uniform scale (never separate x/y), vs the 1920x1080 design.
var _k := 1.0
## Layout table: [{node, h, v, inset, size, font, keys}] — replayed by
## _place_all() on build and on every viewport resize.
var _items: Array = []


func _ready() -> void:
	stage_label = _make_label(H_LEFT, V_TOP, Vector2(36, 24), Vector2(900, 60),
			39, HORIZONTAL_ALIGNMENT_LEFT, Color(1, 1, 1))
	time_label = _make_label(H_CENTER, V_TOP, Vector2(0, 21), Vector2(1920, 90),
			66, HORIZONTAL_ALIGNMENT_CENTER, Color(1, 0.9, 0.3))
	speed_label = _make_label(H_LEFT, V_BOTTOM, Vector2(36, 30), Vector2(600, 75),
			54, HORIZONTAL_ALIGNMENT_LEFT, Color(1, 1, 1))
	message_label = _make_label(H_CENTER, V_TOP, Vector2(0, 420), Vector2(1920, 150),
			84, HORIZONTAL_ALIGNMENT_CENTER, Color(1, 1, 1))
	lap_label = _make_label(H_RIGHT, V_BOTTOM, Vector2(36, 114), Vector2(600, 60),
			40, HORIZONTAL_ALIGNMENT_RIGHT, Color(0.9, 0.9, 0.95))
	position_label = _make_label(H_RIGHT, V_BOTTOM, Vector2(36, 30), Vector2(600, 84),
			60, HORIZONTAL_ALIGNMENT_RIGHT, Color(1, 0.9, 0.3))
	flash_label = _make_label(H_CENTER, V_TOP, Vector2(0, 570), Vector2(1920, 60),
			39, HORIZONTAL_ALIGNMENT_CENTER, Color(1, 0.9, 0.3))
	race_time_label = _make_label(H_CENTER, V_TOP, Vector2(0, 108), Vector2(1920, 45),
			30, HORIZONTAL_ALIGNMENT_CENTER, Color(1, 1, 1, 0.85))
	boost_bar = BoostBar.new()
	boost_bar.visible = false
	add_child(boost_bar)
	_track(boost_bar, H_LEFT, V_BOTTOM, Vector2(36, 119), Vector2(300, 21))
	track_bar = TrackBar.new()
	track_bar.visible = false
	add_child(track_bar)
	_track(track_bar, H_CENTER, V_BOTTOM, Vector2(0, 69), Vector2(1200, 18))
	_make_leaderboard()
	hint_label = _make_label(H_RIGHT, V_BOTTOM, Vector2(12, 6), Vector2(1908, 45),
			24, HORIZONTAL_ALIGNMENT_RIGHT, Color(1, 1, 1, 0.7))
	hint_label.text = "P1 WASD+Shift / pad1  \u2022  P2 Arrows+Ctrl / pad2  \u2022  R restart  \u2022  P pause  \u2022  Esc menu"
	_place_all()


## Re-run the layout against the current viewport. main.gd calls this when the
## window or logical frame changes, instead of rebuilding the views — a rebuild
## would blank the stage name, lap counter and progress bar mid-race.
func relayout() -> void:
	_place_all()


func _track(node: Control, h: int, v: int, inset: Vector2, size: Vector2,
		font: int = 0, keys: Array = []) -> void:
	_items.append({"node": node, "h": h, "v": v, "inset": inset,
			"size": size, "font": font, "keys": keys})


func _place_all() -> void:
	if not is_inside_tree():
		return
	var vp := get_viewport().get_visible_rect().size
	_k = minf(vp.x / DESIGN.x, vp.y / DESIGN.y)
	for it in _items:
		var node: Control = it.node
		var w: float = float(it.size.x) * _k
		var h: float = float(it.size.y) * _k
		var inset: Vector2 = it.inset
		var x := inset.x * _k
		match int(it.h):
			H_CENTER:
				x = (vp.x - w) * 0.5 + inset.x * _k
			H_RIGHT:
				x = vp.x - w - inset.x * _k
		var y := inset.y * _k
		if int(it.v) == V_BOTTOM:
			y = vp.y - h - inset.y * _k
		node.position = Vector2(x, y)
		node.size = Vector2(w, h)
		var font: int = int(it.font)
		if font > 0:
			for key in it.keys:
				node.add_theme_font_size_override(String(key),
						maxi(10, int(float(font) * _k)))
			if node is Label:
				node.add_theme_constant_override("outline_size",
						maxi(4, int(12.0 * _k)))
	track_bar.k = _k
	track_bar.queue_redraw()
	boost_bar.queue_redraw()


## Positions are insets from the named edges, in 1920x1080 design units.
func _make_label(h: int, v: int, inset: Vector2, size: Vector2, font_size: int,
		align: HorizontalAlignment, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	add_child(l)
	_track(l, h, v, inset, size, font_size, ["font_size"])
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
	lap_label.text = ""
	flash_label.text = ""
	_flash_t = 0.0
	hide_progress()
	boost_bar.visible = false


func set_lap(current: int, total: int) -> void:
	lap_label.text = "LAP %d / %d" % [current, total]


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


## The results board is a centred card, so both parts anchor to the frame
## centre rather than to design-space x offsets.
func _make_leaderboard() -> void:
	board_bg = ColorRect.new()
	board_bg.color = Color(0.02, 0.02, 0.06, 0.82)
	board_bg.visible = false
	add_child(board_bg)
	_track(board_bg, H_CENTER, V_TOP, Vector2(0, 180), Vector2(750, 720))
	board_label = RichTextLabel.new()
	board_label.bbcode_enabled = true
	board_label.scroll_active = false
	board_label.visible = false
	add_child(board_label)
	_track(board_label, H_CENTER, V_TOP, Vector2(0, 204), Vector2(690, 678),
			36, ["normal_font_size", "bold_font_size"])


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
