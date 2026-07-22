class_name RacerSelectLayer
extends CanvasLayer
## Racer Select (Phase 2). Sequential, one player at a time: a portrait grid on
## the right, a beauty illustration + name + stat bars on the left. Each player
## navigates the grid and locks in; the screen advances to the next player, and
## completes once everyone has chosen. Back steps a player back, then cancels
## out to the previous menu step.
##
## Purely presentation + local input. main.gd owns state; it calls open()/frame()
## /close() and receives the result via _racer_select_done / _racer_select_cancel.
## Placeholder art: when a profile leaves portrait/illustration null, the tile /
## panel falls back to a flat block in the profile's livery color, so real art
## can be dropped into the .tres later with no code change.

const COLS := 3
const TILE_W := 300.0
const TILE_H := 208.0
const TILE_GAP := 24.0
const GRID_ORIGIN := Vector2(858, 250)

var main                              # orchestrator, for backdrop + callbacks

var _roster: Array = []              # Array[RivalProfile]
var _count := 1                      # players choosing
var _current := 0                    # player currently choosing (0-based)
var _cursor := 0                     # highlighted roster index
var _picks: Array = []               # chosen roster index per player
var _sticky: Array = []              # each player's last-used racer, to home on

# Built once per open(), cleared on close().
var _dynamic: Array[Node] = []       # everything we spawn, for teardown
var _tiles: Array[ColorRect] = []
var _portraits: Array[TextureRect] = []
var _locks: Array[Label] = []
var _cursor_frame: ColorRect
var _title: Label
var _name: Label
var _illus_bg: ColorRect
var _illus: TextureRect
var _illus_tag: Label
var _stat_pips: Dictionary = {}      # stat key -> Array[ColorRect] (5 pips)

const PLAYER_TINT: Array[Color] = [
	Color(0.95, 0.3, 0.3), Color(0.4, 0.6, 1.0),
	Color(0.35, 0.9, 0.5), Color(1.0, 0.85, 0.3),
]


# === LIFECYCLE ===

## Show the screen for `count` players, each pre-homed on their sticky pick.
func open(roster: Array, count: int, sticky: Array) -> void:
	_teardown()
	_roster = roster
	_count = maxi(count, 1)
	_current = 0
	_picks = []
	_sticky = sticky.duplicate()
	_cursor = _homed(0)

	_build_static()
	_build_grid()
	_refresh()
	visible = true


func close() -> void:
	visible = false
	_teardown()


## Polled by main while state == RACER_SELECT. Keeps the backdrop alive and
## drives grid navigation for the current player.
func frame(_dt: float) -> void:
	if main != null:
		main._update_traffic(_dt)

	var moved := false
	if Input.is_action_just_pressed("ui_right"):
		_cursor = (_cursor + 1) % _roster.size(); moved = true
	elif Input.is_action_just_pressed("ui_left"):
		_cursor = (_cursor - 1 + _roster.size()) % _roster.size(); moved = true
	elif Input.is_action_just_pressed("ui_down"):
		_cursor = mini(_cursor + COLS, _roster.size() - 1); moved = true
	elif Input.is_action_just_pressed("ui_up"):
		_cursor = maxi(_cursor - COLS, 0); moved = true
	if moved:
		Audio.play("menu_move")
		_refresh()

	if Input.is_action_just_pressed("ui_accept"):
		Audio.play("menu_select")
		_lock_current()
	elif Input.is_action_just_pressed("ui_cancel"):
		_back()


# === SELECTION ===

func _lock_current() -> void:
	if _current < _picks.size():
		_picks[_current] = _cursor
	else:
		_picks.append(_cursor)

	if _current == _count - 1:
		if main != null:
			main._racer_select_done(_picks.duplicate())
		return
	_current += 1
	# Home the next player on their prior pick (redo) or their sticky racer.
	if _current < _picks.size():
		_cursor = _valid_index(_picks[_current])
	else:
		_cursor = _homed(_current)
	_refresh()


func _back() -> void:
	if _current == 0:
		Audio.play("menu_move")
		if main != null:
			main._racer_select_cancel()
		return
	Audio.play("menu_move")
	_current -= 1
	# Return this player to their previous pick, then drop it so they can redo.
	var prev: int = _valid_index(_picks[_current]) if _current < _picks.size() else _homed(_current)
	if _current < _picks.size():
		_picks.resize(_current)
	_cursor = prev
	_refresh()


# === RENDER ===

func _refresh() -> void:
	_title.text = ("CHOOSE YOUR RACER" if _count == 1
			else "PLAYER %d — CHOOSE YOUR RACER" % (_current + 1))
	_title.add_theme_color_override("font_color", _player_color())

	# Grid: move the cursor frame, refresh lock badges.
	var tile := _tiles[_cursor]
	_cursor_frame.position = tile.position - Vector2(5, 5)
	_cursor_frame.size = tile.size + Vector2(10, 10)
	_cursor_frame.color = _player_color()
	for i in range(_locks.size()):
		var who := -1
		for p in range(_picks.size()):
			if p != _current and int(_picks[p]) == i:
				who = p
		_locks[i].visible = who >= 0
		if who >= 0:
			_locks[i].text = "P%d" % (who + 1)
			_locks[i].add_theme_color_override("font_color", PLAYER_TINT[who % 4])

	# Detail panel for the highlighted racer.
	var prof: RivalProfile = _roster[_cursor]
	_name.text = String(prof.display_name)
	_illus_bg.color = _placeholder_color(prof)
	if prof.illustration != null:
		_illus.texture = prof.illustration
		_illus.visible = true
		_illus_tag.visible = false
	else:
		_illus.visible = false
		_illus_tag.visible = true
	_set_pips("speed", int(prof.stat_speed))
	_set_pips("accel", int(prof.stat_accel))
	_set_pips("handling", int(prof.stat_handling))


func _set_pips(key: String, value: int) -> void:
	var pips: Array = _stat_pips[key]
	for i in range(pips.size()):
		pips[i].color = (Color(1, 0.85, 0.3) if i < value
				else Color(0.25, 0.25, 0.3))


# === CONSTRUCTION ===

func _build_static() -> void:
	var dim := ColorRect.new()
	dim.size = Vector2(1920, 1080)
	dim.color = Color(0.02, 0.02, 0.06, 0.74)
	_add(dim)

	_title = _label("", 62, HORIZONTAL_ALIGNMENT_CENTER)
	_title.position = Vector2(0, 70)
	_title.size = Vector2(1920, 90)
	_add(_title)

	# --- Detail panel (left) ---
	_name = _label("", 58, HORIZONTAL_ALIGNMENT_CENTER)
	_name.position = Vector2(150, 190)
	_name.size = Vector2(600, 70)
	_name.add_theme_color_override("font_color", Color(1, 0.9, 0.35))
	_add(_name)

	_illus_bg = ColorRect.new()
	_illus_bg.position = Vector2(150, 275)
	_illus_bg.size = Vector2(600, 520)
	_add(_illus_bg)

	_illus = TextureRect.new()
	_illus.position = _illus_bg.position
	_illus.size = _illus_bg.size
	_illus.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_illus.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_add(_illus)

	_illus_tag = _label("CHARACTER + CAR\nILLUSTRATION", 32, HORIZONTAL_ALIGNMENT_CENTER)
	_illus_tag.position = _illus_bg.position
	_illus_tag.size = _illus_bg.size
	_illus_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_illus_tag.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	_add(_illus_tag)

	# --- Stat bars ---
	var stats := [["SPEED", "speed"], ["ACCEL", "accel"], ["HANDLING", "handling"]]
	var y := 815.0
	for row in stats:
		var lbl := _label(String(row[0]), 30, HORIZONTAL_ALIGNMENT_LEFT)
		lbl.position = Vector2(150, y)
		lbl.size = Vector2(260, 40)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_add(lbl)
		var pips: Array[ColorRect] = []
		for p in range(5):
			var pip := ColorRect.new()
			pip.position = Vector2(410 + p * 52, y + 4)
			pip.size = Vector2(44, 30)
			_add(pip)
			pips.append(pip)
		_stat_pips[String(row[1])] = pips
		y += 58.0

	var hint := _label(
			"\u25C4 \u25BA \u25B2 \u25BC move    \u2022    Enter / A select    \u2022    Esc / B back",
			30, HORIZONTAL_ALIGNMENT_CENTER)
	hint.position = Vector2(0, 1000)
	hint.size = Vector2(1920, 50)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
	_add(hint)


func _build_grid() -> void:
	# Cursor frame sits behind the tiles; its margin shows as a colored border.
	_cursor_frame = ColorRect.new()
	_add(_cursor_frame)

	_tiles.clear()
	_portraits.clear()
	_locks.clear()
	for i in range(_roster.size()):
		var prof: RivalProfile = _roster[i]
		var col := i % COLS
		var rowi := i / COLS
		var pos := GRID_ORIGIN + Vector2(col * (TILE_W + TILE_GAP), rowi * (TILE_H + TILE_GAP))

		var tile := ColorRect.new()
		tile.position = pos
		tile.size = Vector2(TILE_W, TILE_H)
		tile.color = _placeholder_color(prof)
		_add(tile)
		_tiles.append(tile)

		var portrait := TextureRect.new()
		portrait.position = pos
		portrait.size = Vector2(TILE_W, TILE_H)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.visible = prof.portrait != null
		portrait.texture = prof.portrait
		_add(portrait)
		_portraits.append(portrait)

		var name_lbl := _label(String(prof.display_name), 34, HORIZONTAL_ALIGNMENT_CENTER)
		name_lbl.position = pos + Vector2(0, TILE_H - 52)
		name_lbl.size = Vector2(TILE_W, 46)
		_add(name_lbl)

		var lock := _label("", 30, HORIZONTAL_ALIGNMENT_RIGHT)
		lock.position = pos + Vector2(-14, 8)
		lock.size = Vector2(TILE_W, 36)
		lock.visible = false
		_add(lock)
		_locks.append(lock)


# === HELPERS ===

func _player_color() -> Color:
	return PLAYER_TINT[_current % PLAYER_TINT.size()]


## Livery-derived block color for placeholder tiles/panels (kept dark enough
## that white text stays legible).
func _placeholder_color(prof: RivalProfile) -> Color:
	return Color(prof.color).darkened(0.35)


## Where player `p` should start: their sticky racer if we have one, else pole.
func _homed(p: int) -> int:
	if p < _sticky.size():
		return _valid_index(_sticky[p])
	return 0


func _valid_index(v) -> int:
	var i := int(v)
	if i < 0 or i >= _roster.size():
		return 0
	return i


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
	_tiles.clear()
	_portraits.clear()
	_locks.clear()
	_stat_pips.clear()
