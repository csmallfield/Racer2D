class_name HudLayer
extends CanvasLayer
## Simple arcade HUD: speed (bottom-left), timer (top-center),
## stage name (top-left), big center message, control hints (bottom).
## Positions assume the 1280x720 logical resolution set in project.godot
## (canvas_items stretch keeps this stable at any window size).

var speed_label: Label
var time_label: Label
var stage_label: Label
var message_label: Label
var hint_label: Label
var position_label: Label
var flash_label: Label
var _flash_t := 0.0


func _ready() -> void:
	stage_label = _make_label(Vector2(24, 16), Vector2(600, 40), 26,
			HORIZONTAL_ALIGNMENT_LEFT, Color(1, 1, 1))
	time_label = _make_label(Vector2(0, 14), Vector2(1280, 60), 44,
			HORIZONTAL_ALIGNMENT_CENTER, Color(1, 0.9, 0.3))
	speed_label = _make_label(Vector2(24, 650), Vector2(400, 50), 36,
			HORIZONTAL_ALIGNMENT_LEFT, Color(1, 1, 1))
	message_label = _make_label(Vector2(0, 280), Vector2(1280, 100), 56,
			HORIZONTAL_ALIGNMENT_CENTER, Color(1, 1, 1))
	position_label = _make_label(Vector2(856, 644), Vector2(400, 56), 40,
			HORIZONTAL_ALIGNMENT_RIGHT, Color(1, 0.9, 0.3))
	flash_label = _make_label(Vector2(0, 380), Vector2(1280, 40), 26,
			HORIZONTAL_ALIGNMENT_CENTER, Color(1, 0.9, 0.3))
	hint_label = _make_label(Vector2(0, 686), Vector2(1272, 30), 16,
			HORIZONTAL_ALIGNMENT_RIGHT, Color(1, 1, 1, 0.7))
	hint_label.text = "Arrows/WASD or gamepad  •  R restart stage  •  N next stage"


func _make_label(pos: Vector2, size: Vector2, font_size: int,
		align: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 8)
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


func set_position_rank(rank: int, total: int) -> void:
	position_label.text = "%s / %d" % [ordinal(rank), total]


## Short race message ("PASSED VIPER!") that fades after a moment.
func set_flash(text: String) -> void:
	flash_label.text = text
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
