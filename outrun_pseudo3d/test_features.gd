extends SceneTree
## Checks for the five fixes. Run with:
##   godot --headless --script res://test_features.gd
##
## The "Identifier not found: GameConfig" line Godot prints at load is a
## --script quirk (autoloads are not compile-time visible to a bare SceneTree)
## and does not affect the run.

const STATE_COUNTDOWN := 6
const STATE_RUNNING := 7
const DT := 1.0 / 60.0

var fails := 0


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  PASS  ", what)
	else:
		fails += 1
		print("  FAIL  ", what)


func _initialize() -> void:
	var main: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var gc: Node = root.get_node("/root/GameConfig")
	var roster: Array = gc.race.roster
	# Load by path rather than by class_name: naming these classes here pulls
	# them into this script's compile graph, where autoloads are not visible
	# to a bare --script SceneTree, and the whole global class table falls over.
	var PlayerCarS: GDScript = load("res://scripts/player_car.gd")
	var RecordsS: GDScript = load("res://scripts/records.gd")

	print("=== racer stats now drive the car ===")
	var budgets: Array = []
	for prof in roster:
		budgets.append(int(prof.stat_speed) + int(prof.stat_accel)
				+ int(prof.stat_handling))
	var equal := true
	for b in budgets:
		if b != budgets[0]:
			equal = false
	_ok(equal, "every racer spends the same stat budget (%d)" % int(budgets[0]))

	var neutral = PlayerCarS.new()
	_ok(is_equal_approx(neutral.top_mul, 1.0) and is_equal_approx(neutral.accel_mul, 1.0)
			and is_equal_approx(neutral.grip_mul, 1.0),
			"an unpicked car is exactly baseline")

	var tops: Array = []
	var accels: Array = []
	var grips: Array = []
	for prof in roster:
		var car = PlayerCarS.new()
		car.apply_profile(prof)
		tops.append(car.top_mul)
		accels.append(car.accel_mul)
		grips.append(car.grip_mul)
		_ok(car.top_mul > 0.9 and car.accel_mul > 0.8 and car.grip_mul > 0.85,
				"%s: no stat combination produces a broken car" % prof.display_name)
	var top_spread: float = float(tops.max()) - float(tops.min())
	# The rival roster's cruise_fraction spans 0.94..1.03. A player top-speed
	# spread wider than that would decide races before the first corner.
	var cruise: Array = []
	for prof in roster:
		cruise.append(float(prof.cruise_fraction))
	var cruise_spread: float = float(cruise.max()) - float(cruise.min())
	_ok(top_spread < cruise_spread,
			"player top-speed spread (%.3f) stays inside the rival pace spread (%.3f)"
			% [top_spread, cruise_spread])
	_ok(float(accels.max()) - float(accels.min()) > top_spread,
			"acceleration is the more differentiated axis, as intended")
	# Nobody should be strictly better than anybody else.
	var dominated := 0
	for i in range(roster.size()):
		for j in range(roster.size()):
			if i == j:
				continue
			if (float(tops[i]) >= float(tops[j]) and float(accels[i]) >= float(accels[j])
					and float(grips[i]) >= float(grips[j])
					and (float(tops[i]) > float(tops[j])
						or float(accels[i]) > float(accels[j])
						or float(grips[i]) > float(grips[j]))):
				dominated += 1
	_ok(dominated == 0, "no racer strictly dominates another on all three axes")

	print("=== record rank is no longer #0 ===")
	# These write real entries, so stash the player's board and put it back
	# afterwards. Running a test must not cost someone their high scores —
	# and without this the assertions also fail on the second run, because
	# the first run left its fixtures behind.
	const RECORDS_PATH := "user://best_times.json"
	var saved := ""
	var had_records := FileAccess.file_exists(RECORDS_PATH)
	if had_records:
		saved = FileAccess.get_file_as_string(RECORDS_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RECORDS_PATH))
	var lv := "test_level.gd"
	var bk := "normal"
	_ok(RecordsS.projected_rank(lv, bk, 60.0) == 1, "first time on an empty board is #1")
	RecordsS.add_entry(lv, bk, {"t": 60.0, "racer": "viper", "initials": "AAA"})
	RecordsS.add_entry(lv, bk, {"t": 50.0, "racer": "grog", "initials": "BBB"})
	_ok(RecordsS.projected_rank(lv, bk, 55.0) == 2, "a time between two entries is #2")
	_ok(RecordsS.projected_rank(lv, bk, 45.0) == 1, "beating the board is #1")
	_ok(RecordsS.projected_rank(lv, bk, 70.0) == 3, "a slower time still ranks")
	_ok(RecordsS.projected_rank(lv, bk, 55.0, 1) == 3,
			"a better time in the same batch pushes this one down")
	# projected_rank must agree with what add_entry will actually return.
	var predicted: int = RecordsS.projected_rank(lv, bk, 52.0)
	var actual: int = RecordsS.add_entry(lv, bk, {"t": 52.0, "racer": "axel", "initials": "CCC"})
	_ok(predicted == actual,
			"projection matches the rank add_entry assigns (%d)" % actual)
	# Full board rejects.
	for k in range(20):
		RecordsS.add_entry(lv, bk, {"t": float(k) + 1.0, "racer": "biff", "initials": "DDD"})
	_ok(RecordsS.projected_rank(lv, bk, 9999.0) == 0, "a non-qualifying time returns 0")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RECORDS_PATH))
	if had_records:
		var f := FileAccess.open(RECORDS_PATH, FileAccess.WRITE)
		f.store_string(saved)
		f.close()
	_ok(FileAccess.file_exists(RECORDS_PATH) == had_records,
			"the real records file is left exactly as it was found")

	print("=== the player is named, not 'YOU' ===")
	var names_found: Array = []
	for prof in roster:
		names_found.append(String(prof.display_name))
	main.selected_racers = [0]
	main.player_count = 1
	var solo_name: String = main._player_display_name(0)
	_ok(names_found.has(solo_name), "solo results use the chosen racer's name (%s)" % solo_name)
	_ok(solo_name != "YOU", "the literal 'YOU' is gone")
	main.selected_racers = []
	_ok(main._player_display_name(0) == "P1",
			"no racer picked falls back to the seat label")
	# Split-screen keeps the seat prefix.
	# player_count drives solo(); the players array is only rebuilt by
	# _load_level, so this checks the labelling branch rather than a real
	# two-player race.
	main.selected_racers = [0, 1]
	main.player_count = 2
	var board: Array = main._merged_board()
	var labelled := 0
	for row in board:
		if bool(row.get("is_player", false)):
			var n: String = String(row.name)
			if n.begins_with("P1 \u00b7 ") and n.length() > 5:
				labelled += 1
	_ok(labelled >= 1, "split-screen rows carry both the seat and the racer")
	main.selected_racers = []
	main.player_count = 1

	print("=== tournament congratulations ===")
	var st = main.standings_layer
	var rows: Array = []
	for k in range(8):
		rows.append({"key": "r%d" % k, "name": "RIVAL %d" % k, "points": 20 - k,
				"awarded": 0, "is_player": false, "delta": 0})
	for place in [1, 2, 3, 5]:
		var test_rows: Array = rows.duplicate(true)
		test_rows[place - 1] = {"key": "p0", "name": "VIPER",
				"points": test_rows[place - 1].points, "awarded": 0,
				"is_player": true, "delta": 0}
		st.open("TEST CUP", 3, 3, test_rows, true)
		await process_frame
		var text := ""
		for c in st.get_children():
			for n in c.get_children():
				if n is Label and String(n.text).contains("YOU"):
					text += String(n.text) + "|"
		match place:
			1:
				_ok(text.contains("WON THE CUP"), "1st place gets a win message")
			2:
				_ok(text.contains("2ND"), "2nd place is called out by name")
			3:
				_ok(text.contains("3RD"), "3rd place is called out by name")
			_:
				_ok(text.contains("KEEP PRACTICING") and text.contains("5TH"),
						"off the podium gets encouragement and the real placing")
	# Two humans, two lines.
	var multi: Array = rows.duplicate(true)
	multi[1] = {"key": "p0", "name": "P1 \u00b7 VIPER", "points": 19, "awarded": 0,
			"is_player": true, "delta": 0}
	multi[4] = {"key": "p1", "name": "P2 \u00b7 GROG", "points": 16, "awarded": 0,
			"is_player": true, "delta": 0}
	st.open("TEST CUP", 3, 3, multi, true)
	await process_frame
	var lines := 0
	for c in st.get_children():
		for n in c.get_children():
			if n is Label and (String(n.text).contains("YOU TOOK")
					or String(n.text).contains("YOU CAME")
					or String(n.text).contains("YOU WON")):
				lines += 1
	_ok(lines == 2, "split-screen gets one congratulations line per human")
	# And nothing on a mid-cup table.
	st.open("TEST CUP", 1, 3, multi, false)
	await process_frame
	var mid := 0
	for c in st.get_children():
		for n in c.get_children():
			if n is Label and String(n.text).contains("KEEP PRACTICING"):
				mid += 1
	_ok(mid == 0, "no congratulations before the cup is over")
	st.close() if st.has_method("close") else st.set("visible", false)

	print("=== camera pitch on descents ===")
	seed(20260802)
	main._start_race(0)
	var guard := 0
	while main.state == STATE_COUNTDOWN and guard < 1200:
		main._countdown_frame(DT)
		guard += 1
	var rend = main.views[0].renderer
	var cd: float = rend.camera_depth
	var track_len: float = main.track.track_length()

	# Find the steepest sustained descent on Coastal Run.
	var worst_z := 0.0
	var worst_grad := 0.0
	var step := 400.0
	var z := 0.0
	while z < track_len - 8000.0:
		var g: float = (main.ground_y(z + 6000.0) - main.ground_y(z)) / 6000.0
		if g < worst_grad:
			worst_grad = g
			worst_z = z
		z += step
	_ok(worst_grad < -0.3, "level_01 really does have a steep descent (%.2f)" % worst_grad)

	# Vanishing point as a fraction of frame height, with and without pitch.
	# screen.y = h*0.5 - (scale*camera.y + pitch)*h*0.5, and scale*camera.y
	# converges to gradient*camera_depth, so the road converges to
	# h*0.5*(1 - gradient*camera_depth - pitch). Larger = lower on screen.
	var before: float = 0.5 * (1.0 - worst_grad * cd)
	main.players[0].position_z = worst_z
	for k in range(240):        # let the smoothing settle
		rend._update_pitch()
	var after: float = 0.5 * (1.0 - worst_grad * cd - rend._pitch)
	print("        vanishing point: %.1f%% of frame height -> %.1f%%"
			% [before * 100.0, after * 100.0])
	_ok(before > 0.9, "before: the road converged off the bottom of the frame")
	_ok(after < 0.72, "after: the road is back into the frame")
	_ok(after > 0.55, "after: a descent still reads as a descent, not as flat road")

	# Level ground must be untouched — this is the regression that matters,
	# since most of every track is not a steep hill.
	var flat_z := 0.0
	var flattest := 999.0
	z = 0.0
	while z < track_len - 8000.0:
		var g: float = absf((main.ground_y(z + 6000.0) - main.ground_y(z)) / 6000.0)
		if g < flattest:
			flattest = g
			flat_z = z
		z += step
	main.players[0].position_z = flat_z
	for k in range(240):
		rend._update_pitch()
	_ok(absf(rend._pitch) < 0.02, "flat road pitches essentially not at all (%.4f)" % rend._pitch)

	# Climbs pitch the other way, and nothing exceeds the clamp.
	var max_seen := 0.0
	z = 0.0
	while z < track_len - 8000.0:
		main.players[0].position_z = z
		for k in range(120):
			rend._update_pitch()
		max_seen = maxf(max_seen, absf(rend._pitch))
		z += 4000.0
	_ok(max_seen <= gc.camera.pitch_max + 0.001,
			"pitch never exceeds pitch_max anywhere on the track (%.3f)" % max_seen)

	print("")
	if fails == 0:
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % fails)
	quit(1 if fails > 0 else 0)
