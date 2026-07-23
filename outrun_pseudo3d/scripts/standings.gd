class_name StandingsLayer
extends CanvasLayer
## Championship table between tournament rounds, and the final table when the
## cup ends. Built procedurally like RacerSelectLayer / InitialsEntryLayer.
##
## Human entrants are drawn bold and tinted; AI sit in normal weight, so the
## rivalry that matters reads at a glance in splitscreen.

var main                          # orchestrator, for backdrop + callback

var _rows: Array = []
var _final := false
var _dynamic: Array[Node] = []

const PLAYER_TINT: Array[Color] = [
	Color(0.95, 0.3, 0.3), Color(0.4, 0.6, 1.0),
	Color(0.35, 0.9, 0.5), Color(1.0, 0.85, 0.3),
]


# === LIFECYCLE ===

## `rows` comes from SeriesState.standings(). `final` switches the screen to
## the end-of-cup presentation.
func open(cup_name: String, round_no: int, total: int, rows: Array,
		final: bool) -> void:
	_teardown()
	_rows = rows
	_final = final
	_build(cup_name, round_no, total)
	visible = true


func close() -> void:
	visible = false
	_teardown()


func frame(_dt: float) -> void:
	if main != null:
		main._update_traffic(_dt)
	if (Input.is_action_just_pressed("ui_accept")
			or Input.is_action_just_pressed("ui_cancel")):
		Audio.play("menu_select")
		if main != null:
			main._standings_done()


# === RENDER ===

func _build(cup_name: String, round_no: int, total: int) -> void:
	var dim := ColorRect.new()
	dim.size = Vector2(1920, 1080)
	dim.color = Color(0.02, 0.02, 0.06, 0.85)
	_add(dim)

	var title := _label(cup_name, 62, HORIZONTAL_ALIGNMENT_CENTER)
	title.position = Vector2(0, 60)
	title.size = Vector2(1920, 90)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.35))
	_add(title)

	var sub_text := "FINAL STANDINGS" if _final else "ROUND %d / %d" % [round_no, total]
	var sub := _label(sub_text, 38, HORIZONTAL_ALIGNMENT_CENTER)
	sub.position = Vector2(0, 150)
	sub.size = Vector2(1920, 60)
	sub.add_theme_color_override("font_color", Color(0.7, 0.7, 0.78))
	_add(sub)

	if _final and not _rows.is_empty():
		var champ := _label("%s WINS THE CUP" % String(_rows[0].name), 52,
				HORIZONTAL_ALIGNMENT_CENTER)
		champ.position = Vector2(0, 210)
		champ.size = Vector2(1920, 70)
		champ.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
		_add(champ)

	# Rows sized to fit whatever the field is (6-10 entrants).
	var top := 300.0
	var row_h := minf(56.0, 620.0 / maxf(float(_rows.size()), 1.0))
	var font := int(clampf(row_h * 0.62, 22.0, 36.0))
	for i in range(_rows.size()):
		_build_row(i, _rows[i], top + i * row_h, row_h, font)

	var hint := _label("Enter / A to continue", 30, HORIZONTAL_ALIGNMENT_CENTER)
	hint.position = Vector2(0, 990)
	hint.size = Vector2(1920, 50)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
	_add(hint)


func _build_row(i: int, row: Dictionary, y: float, row_h: float, font: int) -> void:
	var is_player := bool(row.get("is_player", false))
	var tint := Color(0.88, 0.88, 0.92)
	if is_player:
		var slot := 0
		var key := String(row.get("key", "p0"))
		if key.length() > 1 and key.substr(1).is_valid_int():
			slot = int(key.substr(1))
		tint = PLAYER_TINT[slot % PLAYER_TINT.size()]
		# Banner behind human entrants, so they pop out of the AI field.
		var band := ColorRect.new()
		band.position = Vector2(430, y - 2)
		band.size = Vector2(1060, row_h - 6)
		band.color = Color(tint.r, tint.g, tint.b, 0.14)
		_add(band)

	var pos := _label("%d." % (i + 1), font, HORIZONTAL_ALIGNMENT_RIGHT)
	pos.position = Vector2(440, y)
	pos.size = Vector2(70, row_h)
	pos.add_theme_color_override("font_color", tint)
	_add(pos)

	var name_lbl := _label(String(row.get("name", "")), font, HORIZONTAL_ALIGNMENT_LEFT)
	name_lbl.position = Vector2(540, y)
	name_lbl.size = Vector2(430, row_h)
	name_lbl.add_theme_color_override("font_color", tint)
	if is_player:
		name_lbl.add_theme_font_size_override("font_size", font + 4)
	_add(name_lbl)

	# Movement against the previous round's table.
	var delta := int(row.get("delta", 0))
	if not _final and delta != 0:
		var arrow := "\u25B2 %d" % delta if delta > 0 else "\u25BC %d" % -delta
		var d := _label(arrow, font - 6, HORIZONTAL_ALIGNMENT_LEFT)
		d.position = Vector2(980, y)
		d.size = Vector2(140, row_h)
		d.add_theme_color_override("font_color",
				Color(0.4, 0.9, 0.5) if delta > 0 else Color(0.9, 0.45, 0.4))
		_add(d)

	if not _final:
		var got := int(row.get("awarded", 0))
		var gained := _label("+%d" % got if got > 0 else "\u2014", font - 4,
				HORIZONTAL_ALIGNMENT_RIGHT)
		gained.position = Vector2(1130, y)
		gained.size = Vector2(140, row_h)
		gained.add_theme_color_override("font_color",
				Color(0.65, 0.72, 0.8) if got > 0 else Color(0.5, 0.35, 0.35))
		_add(gained)

	var pts := _label("%d" % int(row.get("points", 0)), font, HORIZONTAL_ALIGNMENT_RIGHT)
	pts.position = Vector2(1320, y)
	pts.size = Vector2(160, row_h)
	pts.add_theme_color_override("font_color", tint)
	_add(pts)


# === HELPERS ===

func _label(text: String, size: int, align: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	return l


func _add(n: Node) -> void:
	add_child(n)
	_dynamic.append(n)


func _teardown() -> void:
	for n in _dynamic:
		if is_instance_valid(n):
			n.queue_free()
	_dynamic.clear()
