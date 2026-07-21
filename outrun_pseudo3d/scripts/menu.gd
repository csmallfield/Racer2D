class_name MenuLayer
extends CanvasLayer
## Menu overlay rendered above the (idle) game world: title screen with mode
## selection, a stage picker, and the persistent best-times board.
## Purely visual — main.gd owns all input and state; this layer just draws
## whichever view it's told to.

const TITLE := "SKYLINE RUSH"   # working title — rename at will

var _dim: ColorRect
var _title_label: Label
var _content: RichTextLabel

const LIST_HEIGHT := 660.0   # content box height; rows adapt to fit


## Fit n rows into the content box: font shrinks and spacing tightens as
## lists grow, so nothing ever renders off the bottom of the screen.
func _fit_list(n: int, spaced: bool) -> String:
	var per_row := LIST_HEIGHT / maxf(float(n) + 2.0, 1.0)
	if spaced:
		per_row *= 0.55
	var size := clampi(int(per_row * 0.62), 24, 45)
	_content.add_theme_font_size_override("normal_font_size", size)
	_content.add_theme_font_size_override("bold_font_size", size)
	return "\n\n" if spaced and n <= 5 else "\n"


func _ready() -> void:
	_dim = ColorRect.new()
	_dim.size = Vector2(1920, 1080)
	_dim.color = Color(0.02, 0.02, 0.06, 0.66)
	add_child(_dim)

	_title_label = Label.new()
	_title_label.position = Vector2(0, 135)
	_title_label.size = Vector2(1920, 135)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 108)
	_title_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	_title_label.text = TITLE
	add_child(_title_label)

	_content = RichTextLabel.new()
	_content.position = Vector2(360, 345)
	_content.size = Vector2(1200, 660)
	_content.bbcode_enabled = true
	_content.scroll_active = false
	_content.add_theme_font_size_override("normal_font_size", 45)
	_content.add_theme_font_size_override("bold_font_size", 45)
	add_child(_content)


func hide_menu() -> void:
	visible = false


## items: displayed strings; sel: highlighted index.
func show_main(items: Array[String], sel: int) -> void:
	show_list(TITLE, items, sel)


## Generic selectable list under an arbitrary title.
func show_list(title: String, items: Array[String], sel: int) -> void:
	visible = true
	_title_label.text = title
	var gap := _fit_list(items.size(), true)
	var rows := "\n[center]"
	for i in range(items.size()):
		rows += _row(items[i], i == sel) + gap
	rows += "[color=#888888]select with Enter / gamepad A[/color][/center]"
	_content.text = rows


## Wizard screen: an optional gray subtitle block above a selectable list.
## Used for the Confirm summary, Credits, and the Racer Select placeholder.
func show_config(title: String, subtitle: Array, items: Array[String], sel: int) -> void:
	visible = true
	_title_label.text = title
	var gap := _fit_list(items.size() + subtitle.size() + 1, false)
	var rows := "\n[center]"
	for line in subtitle:
		rows += "[color=#aaaaaa]%s[/color]%s" % [String(line), gap]
	if not subtitle.is_empty():
		rows += gap
	for i in range(items.size()):
		rows += _row(items[i], i == sel) + gap
	rows += "[color=#888888]Enter / A select  •  Esc / B back[/color][/center]"
	_content.text = rows


## Stage picker: left/right cycles, shown with the chosen mode as context.
func show_levels(stage_names: Array, sel: int, mode_name: String) -> void:
	visible = true
	_title_label.text = mode_name
	var gap := _fit_list(stage_names.size() + 2, false)
	var rows := "\n[center][color=#aaaaaa]SELECT STAGE[/color]" + gap
	for i in range(stage_names.size()):
		rows += _row(String(stage_names[i]), i == sel) + gap
	rows += "[color=#888888]Enter / gamepad A to start  •  Esc / B for menu[/color][/center]"
	_content.text = rows


## Best-times board for one stage. columns: [{title, times}] — tour stages
## show TOUR + TIME TRIAL side by side, circuits a single CIRCUIT column.
func show_board(stage_name: String, columns: Array) -> void:
	visible = true
	_title_label.text = "BEST TIMES"
	var rows := "[center][b]%s[/b]\n" % stage_name
	rows += "[color=#888888]steer to change stage  •  brake for menu[/color]\n\n[/center]"
	rows += "[table=%d]" % (columns.size() * 2)
	for col in columns:
		rows += "[cell][color=#ffd24d]  %s[/color][/cell][cell][/cell]" % String(col.title)
	for i in range(Records.MAX_ENTRIES):
		for col in columns:
			rows += _time_cell(i, col.times)
	rows += "[/table]"
	_content.text = rows


static func _time_cell(i: int, times: Array) -> String:
	var rank := "[cell][color=#e8e8e8]  %2d.  [/color][/cell]" % (i + 1)
	if i < times.size():
		return rank + "[cell][color=#e8e8e8]%s   [/color][/cell]" \
				% HudLayer.format_time(float(times[i]))
	return rank + "[cell][color=#555555]—:——   [/color][/cell]"


static func _row(text: String, selected: bool) -> String:
	if selected:
		return "[color=#ffd24d]▶ %s[/color]" % text
	return "[color=#e8e8e8]  %s[/color]" % text
