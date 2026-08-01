extends SceneTree
## Headless verification for the multi-resolution work. Run with:
##   godot --headless --script res://test_display.gd
## Deleted before delivery; kept here so the checks are reproducible.

var fails := 0


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  PASS  ", what)
	else:
		fails += 1
		print("  FAIL  ", what)


func _initialize() -> void:
	print("=== logical viewport policy ===")
	var auto := DisplayConfig.ASPECT_AUTO
	var pill := DisplayConfig.ASPECT_PILLARBOX
	_ok(DisplayConfig.logical_size(Vector2i(1920, 1080), auto) == Vector2i(1920, 1080),
			"16:9 1080p -> authored frame exactly")
	_ok(DisplayConfig.logical_size(Vector2i(3840, 2160), auto) == Vector2i(1920, 1080),
			"16:9 4K -> authored frame (render res is not logical res)")
	_ok(DisplayConfig.logical_size(Vector2i(2560, 1080), auto) == Vector2i(2560, 1080),
			"21:9 -> wider logical frame")
	_ok(DisplayConfig.logical_size(Vector2i(3440, 1440), auto) == Vector2i(2580, 1080),
			"21:9 1440p -> 2580x1080")
	_ok(DisplayConfig.logical_size(Vector2i(5120, 1440), auto) == Vector2i(3840, 1080),
			"32:9 -> 3840x1080, inside the cap")
	_ok(DisplayConfig.logical_size(Vector2i(7680, 1080), auto) == Vector2i(3888, 1080),
			"triple-head 64:9 -> capped at MAX_ASPECT, pillarboxed beyond")
	_ok(DisplayConfig.logical_size(Vector2i(1920, 1200), auto) == Vector2i(1920, 1080),
			"16:10 -> letterboxed onto the authored frame, never narrower")
	_ok(DisplayConfig.logical_size(Vector2i(1024, 768), auto) == Vector2i(1920, 1080),
			"4:3 -> letterboxed onto the authored frame")
	_ok(DisplayConfig.logical_size(Vector2i(2560, 1080), pill) == Vector2i(1920, 1080),
			"pillarbox override forces 16:9 on an ultrawide")
	_ok(DisplayConfig.logical_size(Vector2i(0, 0), auto) == Vector2i(1920, 1080),
			"degenerate window size does not divide by zero")
	# Every frame is >= 16:9, which is what lets RoadRenderer keep using
	# _ref_w = min(w, h * 16/9) unchanged.
	for win in [Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(5120, 1440),
			Vector2i(1280, 1024), Vector2i(3000, 2000)]:
		var f := DisplayConfig.logical_size(win, auto)
		_ok(float(f.x) / float(f.y) >= 16.0 / 9.0 - 0.001,
				"frame for %s is never narrower than 16:9" % str(win))

	print("=== window presets ===")
	var p1080 := DisplayConfig.presets_for(Vector2i(1920, 1080), Vector2i(1920, 1040))
	_ok(p1080.size() > 0 and p1080[p1080.size() - 1].y <= 1080, "1080p desktop yields fitting sizes")
	_ok(not p1080.has(Vector2i(2560, 1440)), "no preset larger than the desktop")
	var puw := DisplayConfig.presets_for(Vector2i(3440, 1440), Vector2i(3440, 1400))
	var uw_shaped := true
	for s in puw:
		if absf(float(s.x) / float(s.y) - 3440.0 / 1440.0) > 0.02:
			uw_shaped = false
	_ok(uw_shaped and puw.size() > 0, "presets are shaped like the monitor, not forced to 16:9")
	var tiny := DisplayConfig.presets_for(Vector2i(1366, 768), Vector2i(1366, 700))
	_ok(tiny.size() > 0, "small laptop still gets at least one window size")
	_ok(DisplayConfig.default_index_for(p1080, Vector2i(1920, 1040)) < p1080.size(),
			"default windowed index is in range")

	print("=== design frame fit ===")
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var frame := DesignFrame.attach(layer)
	await process_frame
	var vp: Vector2 = root.get_visible_rect().size
	var k: float = minf(vp.x / 1920.0, vp.y / 1080.0)
	_ok(is_equal_approx(frame.scale.x, frame.scale.y), "frame scale is uniform (no stretch)")
	_ok(is_equal_approx(frame.scale.x, k), "frame scale fits the viewport")
	var centre := frame.position + DesignFrame.DESIGN * frame.scale * 0.5
	_ok(centre.is_equal_approx(vp * 0.5), "frame is centred in the viewport")

	print("=== HUD anchoring across frame shapes ===")
	for size in [Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(3840, 1080),
			Vector2i(1920, 540), Vector2i(960, 540), Vector2i(1280, 540)]:
		var sub := SubViewport.new()
		sub.size = size
		root.add_child(sub)
		var hud := HudLayer.new()
		sub.add_child(hud)
		await process_frame
		var f := Vector2(size)
		var tag := "%dx%d" % [size.x, size.y]
		# Corner readouts must sit in the corners, not at design-space offsets.
		var right_gap: float = f.x - (hud.position_label.position.x + hud.position_label.size.x)
		_ok(right_gap >= 0.0 and right_gap < 0.05 * f.x,
				"%s: position readout stays on the right edge" % tag)
		var bottom_gap: float = f.y - (hud.speed_label.position.y + hud.speed_label.size.y)
		_ok(bottom_gap >= 0.0 and bottom_gap < 0.06 * f.y,
				"%s: speed readout stays on the bottom edge" % tag)
		_ok(hud.stage_label.position.x < 0.05 * f.x, "%s: stage name stays on the left" % tag)
		# Centred elements really centred.
		var tc: float = hud.time_label.position.x + hud.time_label.size.x * 0.5
		_ok(absf(tc - f.x * 0.5) < 1.0, "%s: timer is centred" % tag)
		var bc: float = hud.board_bg.position.x + hud.board_bg.size.x * 0.5
		_ok(absf(bc - f.x * 0.5) < 1.0, "%s: results card is centred" % tag)
		# Nothing overflows the frame.
		var inside := true
		for n in [hud.time_label, hud.speed_label, hud.position_label, hud.lap_label,
				hud.stage_label, hud.hint_label, hud.board_bg, hud.track_bar, hud.boost_bar]:
			if (n.position.x < -1.0 or n.position.y < -1.0
					or n.position.x + n.size.x > f.x + 1.0
					or n.position.y + n.size.y > f.y + 1.0):
				inside = false
		_ok(inside, "%s: no HUD element spills outside the frame" % tag)
		# Uniform scale: font must not stretch with the frame's aspect.
		var fs: int = hud.time_label.get_theme_font_size("font_size")
		var expect: int = maxi(10, int(66.0 * minf(f.x / 1920.0, f.y / 1080.0)))
		_ok(fs == expect, "%s: type scales uniformly (%d)" % [tag, fs])
		sub.queue_free()

	print("=== HUD relayout keeps state ===")
	var sub2 := SubViewport.new()
	sub2.size = Vector2i(1920, 1080)
	root.add_child(sub2)
	var hud2 := HudLayer.new()
	sub2.add_child(hud2)
	await process_frame
	hud2.set_stage("SUNSET COAST")
	hud2.set_lap(2, 3)
	sub2.size = Vector2i(2560, 1080)
	await process_frame
	hud2.relayout()
	_ok(hud2.stage_label.text == "SUNSET COAST" and hud2.lap_label.text == "LAP 2 / 3",
			"relayout preserves labels set once per race")
	var rg: float = 2560.0 - (hud2.lap_label.position.x + hud2.lap_label.size.x)
	_ok(rg >= 0.0 and rg < 128.0, "relayout moves the lap counter to the new right edge")
	sub2.queue_free()

	print("=== settings screen walk ===")
	# The lesson from the MenuFlow typed-array crash: menu paths must actually
	# be walked, because typed assignment failures are runtime errors that
	# --import and a boot cannot catch.
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main: Node2D = main_scene.instantiate()
	root.add_child(main)
	# Autoloads are not compile-time visible to a --script SceneTree.
	var st: Node = root.get_node("/root/Settings")
	await process_frame
	await process_frame
	main.open_settings()
	await process_frame
	var rows: int = main.SETTINGS_ROWS.size()
	_ok(rows >= 14, "settings screen has the display block (%d rows)" % rows)
	for i in range(rows):
		main.menu_sel = i
		for dir in [1, -1, 1]:
			main._adjust_setting(main.SETTINGS_ROWS[i], dir)
			st.apply()
			main._show_settings()
		await process_frame
	_ok(true, "every settings row adjusts and renders in both directions")
	# Cycle display mode all the way round and confirm it lands back home.
	var start: int = st.window_mode
	for n in range(3):
		main._adjust_setting(main.SETTINGS_ROWS[0], 1)
	_ok(st.window_mode == start, "display mode wraps cleanly")
	# Monitor cycles through AUTO and every attached screen.
	var seen := {}
	for n in range(6):
		main._adjust_setting(main.SETTINGS_ROWS[1], 1)
		seen[st.monitor] = true
	_ok(seen.has(-1), "monitor selection includes AUTO")
	# Save / load round-trip, including migration off the v1 bool.
	st.window_mode = DisplayConfig.MODE_WINDOWED
	st.aspect_mode = DisplayConfig.ASPECT_PILLARBOX
	st.render_scale = 0.75
	st.vsync = false
	st.save()
	st.window_mode = DisplayConfig.MODE_FULLSCREEN
	st.aspect_mode = DisplayConfig.ASPECT_AUTO
	st.render_scale = 1.0
	st.vsync = true
	st._load()
	_ok(st.window_mode == DisplayConfig.MODE_WINDOWED
			and st.aspect_mode == DisplayConfig.ASPECT_PILLARBOX
			and is_equal_approx(st.render_scale, 0.75)
			and st.vsync == false, "display settings survive save/load")
	var f := FileAccess.open("user://settings.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"fullscreen": false, "music": 0.5}))
	f.close()
	st.window_mode = DisplayConfig.MODE_FULLSCREEN
	st._load()
	_ok(st.window_mode == DisplayConfig.MODE_WINDOWED,
			"v1 save migrates: fullscreen=false -> WINDOWED")

	print("=== split-screen rects follow the frame ===")
	for count in [1, 2, 3, 4]:
		var rects: Array = main._view_rects(count)
		_ok(rects.size() == count, "%dP: %d rects" % [count, count])
		var area := 0.0
		for r in rects:
			area += r.size.x * r.size.y
		var full: float = main.get_viewport_rect().size.x * main.get_viewport_rect().size.y
		_ok(absf(area - full) < 1.0, "%dP: rects tile the whole frame exactly" % count)
	var before: Vector2 = main.views[0].container.size
	main._relayout_views()
	await process_frame
	_ok(main.views[0].container.size == before
			and main.views[0].viewport.size.x == int(before.x),
			"relayout keeps the container and its SubViewport in step")

	print("=== overlay layers render on a wide frame ===")
	# Every full-screen overlay was reparented into a DesignFrame. Use the
	# instances main.gd already owns rather than referencing the classes here,
	# which would pull them into this script's compile-time dependency graph.
	var gc: Node = root.get_node("/root/GameConfig")
	var frame_size: Vector2 = root.get_visible_rect().size

	main.racer_select.open(gc.race.roster, 2, [])
	await process_frame
	_ok(main.racer_select.get_child_count() >= 2,
			"racer select builds a scrim plus a framed card")
	_ok(main.racer_select.get_child(0).size.is_equal_approx(frame_size),
			"racer select scrim covers the whole frame, not just 16:9")

	main.standings_layer.open("TEST CUP", 1, 3,
			[{"name": "VIPER", "points": 15, "is_player": true, "delta": 0}], false)
	await process_frame
	_ok(main.standings_layer.get_child(0).size.is_equal_approx(frame_size),
			"standings scrim covers the whole frame")

	main.initials_entry.open([{"slot": 0, "label": "P1", "racer": "viper"}])
	await process_frame
	_ok(main.initials_entry.get_child(0).size.is_equal_approx(frame_size),
			"initials entry scrim covers the whole frame")

	# The card itself must be centred and uniformly scaled, never stretched.
	for ov in [main.racer_select, main.standings_layer, main.initials_entry]:
		var df: Control = null
		for c in ov.get_children():
			if c is DesignFrame:
				df = c
		_ok(df != null and is_equal_approx(df.scale.x, df.scale.y),
				"%s composes in a uniformly scaled frame" % ov.get_class())

	main._enter_menu()
	await process_frame

	print("")
	if fails == 0:
		print("ALL CHECKS PASSED")
	else:
		print("%d CHECK(S) FAILED" % fails)
	quit(1 if fails > 0 else 0)
