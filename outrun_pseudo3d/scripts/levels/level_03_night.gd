extends TrackLevel
## STAGE 3 — Night Ridge.
## Dark palette, long sweepers, big climbs, and a hard corner near the end.
## Long sweepers, big climbs, and a hard corner near the end.


func _init() -> void:
	level_name = "STAGE 3 — NIGHT RIDGE"
	time_limit = 90.0
	traffic_count = 14
	music = "music_night"
	theme = {
		"sky_top": Color(0.02, 0.03, 0.12),
		"sky_bottom": Color(0.1, 0.12, 0.3),
		"sun": Color(0.92, 0.92, 0.85),      # reads as a moon
		"hills": Color(0.07, 0.08, 0.18),
		"grass_light": Color(0.1, 0.2, 0.12),
		"grass_dark": Color(0.08, 0.17, 0.1),
		"road_light": Color(0.2, 0.2, 0.25),
		"road_dark": Color(0.17, 0.17, 0.22),
		"rumble_light": Color(0.7, 0.7, 0.75),
		"rumble_dark": Color(0.55, 0.1, 0.1),
		"lane": Color(0.75, 0.75, 0.8),
		"fog": Color(0.05, 0.06, 0.15),
		"start": Color(0.8, 0.8, 0.85),
		"finish": Color(0.05, 0.05, 0.08),
	}


func build(b: TrackBuilder) -> void:
	var R := TrackBuilder.ROAD

	# --- Road layout ---
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.LONG, R.CURVE.EASY, R.HILL.MEDIUM)
	b.add_s_curves()
	b.add_hill(R.LENGTH.MEDIUM, R.HILL.HIGH)
	b.add_curve(R.LENGTH.LONG, -R.CURVE.MEDIUM, -R.HILL.LOW)
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.MEDIUM, R.CURVE.HARD)
	b.add_low_rolling_hills()
	b.add_downhill_to_end()

	# --- Scenery ---
	var end := b.segments.size()
	b.add_scenery("tree", 20, end, 9, 1.0)
	b.add_scenery("tree", 26, end, 11, -1.0)
	b.add_scenery("rock", 60, end, 33, 1.0, 1.4, 2.4)
	b.add_sprite(30, "sign", -1.3)
	b.add_sprite(30, "sign", 1.3)
