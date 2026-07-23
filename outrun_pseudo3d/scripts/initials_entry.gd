class_name InitialsEntryLayer
extends CanvasLayer
## Arcade "NEW RECORD — ENTER YOUR INITIALS" screen. Shown after a race in
## which at least one human set a qualifying time, and before the results
## board, so the results screen stays the last thing on screen and its
## existing accept-to-continue behaviour is untouched.
##
## Prompts are handled one at a time: in splitscreen, each qualifying player
## gets the screen in turn. Purely presentation + local input; main.gd owns
## the state and receives the finished list via _initials_done.

const CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 "
const SLOTS := 3

var main                          # orchestrator, for backdrop + callback

var _prompts: Array = []          # queued {slot, rank, time, initials, metric}
var _index := 0                   # prompt being entered
var _chars: Array[int] = []       # CHARS index per slot
var _cursor := 0                  # slot being edited
var _results: Array = []          # confirmed initials, one per prompt

var _dynamic: Array[Node] = []
var _title: Label
var _subtitle: Label
var _slot_labels: Array[Label] = []
var _underlines: Array[ColorRect] = []

const PLAYER_TINT: Array[Color] = [
	Color(0.95, 0.3, 0.3), Color(0.4, 0.6, 1.0),
	Color(0.35, 0.9, 0.5), Color(1.0, 0.85, 0.3),
]


# === LIFECYCLE ===

## `prompts` is an array of dictionaries, one per qualifying time:
## {slot: int, rank: int, time: float, initials: String, metric: String}
func open(prompts: Array) -> void:
	_teardown()
	_prompts = prompts
	_index = 0
	_results = []
	_build()
	_load_prompt()
	visible = true


func close() -> void:
	visible = false
	_teardown()


func frame(_dt: float) -> void:
	if main != null:
		main._update_traffic(_dt)

	if Input.is_action_just_pressed("ui_up"):
		_cycle(1)
	elif Input.is_action_just_pressed("ui_down"):
		_cycle(-1)
	elif Input.is_action_just_pressed("ui_right"):
		_cursor = mini(_cursor + 1, SLOTS - 1)
		Audio.play("menu_move")
		_refresh()
	elif Input.is_action_just_pressed("ui_cancel"):
		# Backs up a character. There's no backing out of a record, so at the
		# first slot this does nothing rather than cancelling the entry.
		if _cursor > 0:
			_cursor -= 1
			Audio.play("menu_move")
			_refresh()
	elif Input.is_action_just_pressed("ui_left"):
		_cursor = maxi(_cursor - 1, 0)
		Audio.play("menu_move")
		_refresh()
	elif Input.is_action_just_pressed("ui_accept"):
		Audio.play("menu_select")
		_confirm()


# === ENTRY ===

func _cycle(dir: int) -> void:
	_chars[_cursor] = wrapi(_chars[_cursor] + dir, 0, CHARS.length())
	Audio.play("menu_move")
	_refresh()


func _confirm() -> void:
	_results.append(_text())
	_index += 1
	if _index >= _prompts.size():
		if main != null:
			main._initials_done(_results.duplicate())
		return
	_load_prompt()


## Seed the entry from this player's sticky initials, so a repeat visit is
## usually just "accept".
func _load_prompt() -> void:
	var p: Dictionary = _prompts[_index]
	var seed_text := String(p.get("initials", "AAA")).to_upper()
	_chars.clear()
	for i in range(SLOTS):
		var ch := seed_text.substr(i, 1) if i < seed_text.length() else "A"
		var idx := CHARS.find(ch)
		_chars.append(idx if idx >= 0 else 0)
	_cursor = 0
	_refresh()


func _text() -> String:
	var out := ""
	for i in range(SLOTS):
		out += CHARS.substr(_chars[i], 1)
	return out


# === RENDER ===

func _refresh() -> void:
	var p: Dictionary = _prompts[_index]
	var slot := int(p.get("slot", 0))
	var tint := PLAYER_TINT[slot % PLAYER_TINT.size()]

	_title.text = "NEW RECORD"
	_title.add_theme_color_override("font_color", tint)

	var who := "" if _prompts.size() <= 1 and slot == 0 else "PLAYER %d   " % (slot + 1)
	_subtitle.text = "%s#%d   %s   %s" % [who, int(p.get("rank", 0)),
			String(p.get("metric", "TIME")), HudLayer.format_time(float(p.get("time", 0.0)))]

	for i in range(SLOTS):
		_slot_labels[i].text = CHARS.substr(_chars[i], 1)
		var active := i == _cursor
		_slot_labels[i].add_theme_color_override("font_color",
				tint if active else Color(0.92, 0.92, 0.95))
		_underlines[i].color = tint if active else Color(0.3, 0.3, 0.35)


func _build() -> void:
	var dim := ColorRect.new()
	dim.size = Vector2(1920, 1080)
	dim.color = Color(0.02, 0.02, 0.06, 0.82)
	_add(dim)

	_title = _label("", 76, HORIZONTAL_ALIGNMENT_CENTER)
	_title.position = Vector2(0, 250)
	_title.size = Vector2(1920, 100)
	_add(_title)

	_subtitle = _label("", 40, HORIZONTAL_ALIGNMENT_CENTER)
	_subtitle.position = Vector2(0, 360)
	_subtitle.size = Vector2(1920, 60)
	_subtitle.add_theme_color_override("font_color", Color(1, 0.9, 0.35))
	_add(_subtitle)

	_slot_labels.clear()
	_underlines.clear()
	var total_w := float(SLOTS) * 140.0
	var start_x := (1920.0 - total_w) * 0.5
	for i in range(SLOTS):
		var lbl := _label("A", 120, HORIZONTAL_ALIGNMENT_CENTER)
		lbl.position = Vector2(start_x + i * 140.0, 480)
		lbl.size = Vector2(140, 160)
		_add(lbl)
		_slot_labels.append(lbl)

		var line := ColorRect.new()
		line.position = Vector2(start_x + i * 140.0 + 20.0, 650)
		line.size = Vector2(100, 8)
		_add(line)
		_underlines.append(line)

	var hint := _label(
			"\u25B2 \u25BC change    \u2022    \u25C4 \u25BA move    \u2022    Enter / A confirm",
			30, HORIZONTAL_ALIGNMENT_CENTER)
	hint.position = Vector2(0, 760)
	hint.size = Vector2(1920, 50)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
	_add(hint)


# === HELPERS ===

func _label(text: String, size: int, align: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
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
	_slot_labels.clear()
	_underlines.clear()
