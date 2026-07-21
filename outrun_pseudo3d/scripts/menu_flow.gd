class_name MenuFlow
extends RefCounted
## Pre-race navigation wizard (Phase 1 of the menu restructure).
##
## Models the whole front end as a STACK of screens. Moving forward pushes a
## screen; Back simply pops one. Each top-level mode is just a different
## sequence of pushes, so Tournament / Quick Race / Time Trial can share steps
## without duplicating trees, and no screen needs to know who pushed it.
##
## main.gd owns the render surface (MenuLayer) and every terminal action
## (start a race, open the board, open settings, quit). This controller only
## gathers selections into `ctx` and, when the sequence completes, hands them
## to main.start_configured().
##
## Phase 1 scope: the tree, Credits, Confirm, back-nav, and the difficulty /
## racer / lap PLUMBING. Difficulty and racer are stored + made sticky but do
## not yet change the sim (later phases). Racer Select is a labelled
## placeholder; the grid lands in Phase 2. Tournament gathers a cup and starts
## its first track as a single race — the series/points logic is a later phase.

const DIFF_NAMES: Array[String] = ["EASY", "NORMAL", "HARD"]
const LAP_VALUES: Array[int] = [2, 3, 5]

var main                         # the Node2D orchestrator (untyped: no class_name)
var menu: MenuLayer

var stack: Array = []            # [{id: String, sel: int}] — top is the live screen
var ctx: Dictionary = {}         # accumulated selections for the current run


func _init(orchestrator, menu_layer: MenuLayer) -> void:
	main = orchestrator
	menu = menu_layer


## Reset to the top of the tree (called on entering the menu from anywhere).
func reset() -> void:
	ctx = {}
	stack = [{"id": "main", "sel": 0}]
	_render()


# === PER-FRAME INPUT ===

## Polled from main._process while state == MENU. Keeps the idle backdrop
## alive and drives list navigation for whichever screen is on top.
func frame(_dt: float) -> void:
	main._update_traffic(_dt)   # traffic keeps ambling behind the menu
	if stack.is_empty():
		reset()
		return
	var scr: Dictionary = stack.back()
	var id: String = String(scr.id)
	var count := _items_for(id).size()

	var moved := 0
	if Input.is_action_just_pressed("ui_down"):
		moved = 1
	elif Input.is_action_just_pressed("ui_up"):
		moved = -1
	if moved != 0 and count > 0:
		scr.sel = wrapi(int(scr.sel) + moved, 0, count)
		Audio.play("menu_move")
		_render()

	# Confirm screen: left/right nudges difficulty from any row, for speed.
	if id == "confirm":
		var adj := 0
		if Input.is_action_just_pressed("ui_right"):
			adj = 1
		elif Input.is_action_just_pressed("ui_left"):
			adj = -1
		if adj != 0:
			ctx["difficulty"] = wrapi(int(ctx.get("difficulty", 1)) + adj, 0, 3)
			Audio.play("menu_move")
			_render()

	if Input.is_action_just_pressed("ui_accept"):
		Audio.play("menu_select")
		_on_confirm(id, int(scr.sel))
	elif Input.is_action_just_pressed("ui_cancel"):
		_back()


# === STACK OPS ===

func _push(id: String) -> void:
	stack.append({"id": id, "sel": _default_sel(id)})
	_render()


func _back() -> void:
	var id: String = String(stack.back().id)
	if id == "main":
		_push("quit_confirm")   # Back at the root asks to quit, per the spec
		return
	Audio.play("menu_move")
	stack.pop_back()
	if stack.is_empty():
		stack.append({"id": "main", "sel": 0})
	_render()


## Sensible landing selection when a screen is first shown.
func _default_sel(id: String) -> int:
	match id:
		"difficulty":
			return clampi(int(Settings.difficulty), 0, 2)
		"laps":
			return LAP_VALUES.find(3)   # default 3 laps
		"confirm":
			return _items_for("confirm").size() - 1   # highlight START
		_:
			return 0


# === CONFIRM / TRANSITIONS ===

func _on_confirm(id: String, sel: int) -> void:
	match id:
		"main":
			match sel:
				0: _push("play")
				1: main.open_board()
				2: main.open_settings()
				3: _push("credits")
				4: _push("quit_confirm")
		"play":
			match sel:
				0:
					ctx["play_mode"] = "TOURNAMENT"
					_push("players")
				1:
					ctx["play_mode"] = "QUICK_RACE"
					_push("players")
				2:
					ctx["play_mode"] = "TIME_TRIAL"
					ctx["players"] = 1   # Time Trial is single-player only
					_push("tt_type")
		"players":
			ctx["players"] = sel + 1
			_push("difficulty")
		"difficulty":
			ctx["difficulty"] = sel
			if String(ctx.get("play_mode", "")) == "TOURNAMENT":
				_push("cup")
			else:
				_push("type")
		"cup":
			ctx["is_circuit"] = sel == 0
			ctx["cup"] = "CIRCUIT CUP" if sel == 0 else "TOUR CUP"
			_push("racer")
		"type", "tt_type":
			ctx["is_circuit"] = sel == 0
			_push("track")
		"track":
			var lvls := _levels_of_type(bool(ctx.get("is_circuit", false)))
			if not lvls.is_empty():
				ctx["track_idx"] = int(lvls[clampi(sel, 0, lvls.size() - 1)])
			else:
				ctx["track_idx"] = 0
			if String(ctx.get("play_mode", "")) == "QUICK_RACE" \
					and bool(ctx.get("is_circuit", false)):
				_push("laps")
			else:
				_push("racer")
		"laps":
			ctx["laps_sel"] = sel
			_push("racer")
		"racer":
			# Phase 1 stub: adopt the sticky racer(s) and move on. Time Trial
			# skips Confirm (spec: Racer Select -> Start).
			if String(ctx.get("play_mode", "")) == "TIME_TRIAL":
				_start()
			else:
				_push("confirm")
		"confirm":
			if sel == 0:
				ctx["difficulty"] = wrapi(int(ctx.get("difficulty", 1)) + 1, 0, 3)
				_render()
			else:
				_start()
		"credits":
			_back()
		"quit_confirm":
			if sel == 1:
				main.quit_game()
			else:
				_back()


## Hand the gathered configuration to main and launch.
func _start() -> void:
	var p_mode := String(ctx.get("play_mode", "QUICK_RACE"))
	var is_tt := p_mode == "TIME_TRIAL"
	var is_circuit := bool(ctx.get("is_circuit", false))

	var idx: int
	if p_mode == "TOURNAMENT":
		var lvls := _levels_of_type(is_circuit)   # cup starts on its first track (stub)
		idx = int(lvls[0]) if not lvls.is_empty() else 0
	else:
		idx = int(ctx.get("track_idx", 0))

	var count := 1 if is_tt else int(ctx.get("players", 1))
	var diff := 1 if is_tt else int(ctx.get("difficulty", 1))
	var laps := 0
	if p_mode == "QUICK_RACE" and is_circuit:
		laps = LAP_VALUES[clampi(int(ctx.get("laps_sel", 1)), 0, LAP_VALUES.size() - 1)]

	var racers: Array = []
	for i in range(count):
		racers.append(main.sticky_racer(i))

	var kind := "TIME_TRIAL" if is_tt else ("CIRCUIT" if is_circuit else "TOUR")
	main.start_configured(p_mode, kind, count, diff, racers, laps, idx,
			String(ctx.get("cup", "")))


# === RENDER ===

func _render() -> void:
	var scr: Dictionary = stack.back()
	var id: String = String(scr.id)
	var items := _items_for(id)
	var sub := _subtitle_for(id)
	if sub.is_empty():
		menu.show_list(_title_for(id), items, int(scr.sel))
	else:
		menu.show_config(_title_for(id), sub, items, int(scr.sel))


func _title_for(id: String) -> String:
	match id:
		"main": return MenuLayer.TITLE
		"play": return "SELECT MODE"
		"players": return "PLAYERS"
		"difficulty": return "DIFFICULTY"
		"cup": return "SELECT CUP"
		"type", "tt_type": return "RACE TYPE"
		"track": return "SELECT TRACK"
		"laps": return "LAP COUNT"
		"racer": return "RACER SELECT"
		"confirm": return "CONFIRM"
		"credits": return "CREDITS"
		"quit_confirm": return "QUIT?"
		_: return ""


func _items_for(id: String) -> Array[String]:
	match id:
		"main":
			return ["PLAY", "HIGHSCORES", "SETTINGS", "CREDITS", "QUIT"]
		"play":
			return ["TOURNAMENT", "QUICK RACE", "TIME TRIAL"]
		"players":
			return ["SINGLE", "2 PLAYERS", "3 PLAYERS", "4 PLAYERS"]
		"difficulty":
			return DIFF_NAMES.duplicate()
		"cup":
			return ["CIRCUIT CUP", "TOUR CUP"]
		"type", "tt_type":
			return ["CIRCUIT", "TOUR"]
		"track":
			var names: Array[String] = []
			for i in _levels_of_type(bool(ctx.get("is_circuit", false))):
				names.append(String(main.level_names[i]))
			return names
		"laps":
			var ls: Array[String] = []
			for v in LAP_VALUES:
				ls.append("%d LAPS" % v)
			return ls
		"racer":
			return ["CONTINUE"]
		"confirm":
			return ["DIFFICULTY:  %s" % DIFF_NAMES[int(ctx.get("difficulty", 1))], "START"]
		"credits":
			return ["BACK"]
		"quit_confirm":
			return ["NO", "YES"]
	return []


func _subtitle_for(id: String) -> Array[String]:
	match id:
		"racer":
			return ["The full racer grid arrives in the next update.",
					"Using your last-used racer for now."]
		"confirm":
			var lines: Array[String] = []
			var p_mode := String(ctx.get("play_mode", ""))
			lines.append("MODE:  %s" % ("TOURNAMENT" if p_mode == "TOURNAMENT" else "QUICK RACE"))
			lines.append("PLAYERS:  %d" % int(ctx.get("players", 1)))
			if p_mode == "TOURNAMENT":
				lines.append("CUP:  %s" % String(ctx.get("cup", "")))
			else:
				lines.append("TRACK:  %s" % String(main.level_names[int(ctx.get("track_idx", 0))]))
				if bool(ctx.get("is_circuit", false)):
					lines.append("LAPS:  %d" % LAP_VALUES[clampi(
							int(ctx.get("laps_sel", 1)), 0, LAP_VALUES.size() - 1)])
			return lines
		"credits":
			return ["OUTRUN PSEUDO-3D", "A script-authored arcade racer.",
					"Built with Godot.", "", "(placeholder credits)"]
	return []


## Global level indices whose type matches (circuit = laps > 0).
func _levels_of_type(is_circuit: bool) -> Array:
	var out: Array = []
	for i in range(main.level_laps.size()):
		if (int(main.level_laps[i]) > 0) == is_circuit:
			out.append(i)
	return out
