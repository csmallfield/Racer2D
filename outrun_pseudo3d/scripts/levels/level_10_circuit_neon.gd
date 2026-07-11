extends TrackLevel
## CIRCUIT 2 — Neon Loop. City theme, right-biased: a tight counter-clockwise
## street circuit — hard rights between skyline walls, flat and fast.


func _init() -> void:
	level_name = "CIRCUIT 2 — NEON LOOP"
	time_limit = 85.0          # per lap
	laps = 3
	checkpoint_count = 2
	traffic_count = 27
	music = "music_city"
	theme = {
		"sky_top": Color(0.1, 0.02, 0.18),
		"sky_bottom": Color(0.85, 0.25, 0.45),
		"sun": Color(1.0, 0.75, 0.35),
		"hills": Color(0.12, 0.06, 0.2),
		"grass_light": Color(0.16, 0.16, 0.2),
		"grass_dark": Color(0.13, 0.13, 0.17),
		"road_light": Color(0.21, 0.21, 0.26),
		"road_dark": Color(0.18, 0.18, 0.23),
		"rumble_light": Color(0.85, 0.85, 0.9),
		"rumble_dark": Color(0.9, 0.35, 0.2),
		"lane": Color(0.85, 0.8, 0.5),
		"fog": Color(0.16, 0.06, 0.2),
		"start": Color(0.9, 0.9, 0.95),
		"finish": Color(0.06, 0.06, 0.1),
	}


func build(b: TrackBuilder) -> void:
	var R := TrackBuilder.ROAD
	# Right-biased street circuit: hard rights between the walls.

	b.add_straight(R.LENGTH.SHORT)
	b.add_straight(R.LENGTH.MEDIUM)
	b.add_curve(R.LENGTH.SHORT, R.CURVE.HARD)
	b.add_curve(R.LENGTH.SHORT, -R.CURVE.MEDIUM)
	b.add_curve(R.LENGTH.MEDIUM, R.CURVE.MEDIUM)
	b.add_straight(R.LENGTH.MEDIUM)
	b.add_curve(R.LENGTH.MEDIUM, R.CURVE.MEDIUM)
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.SHORT, R.CURVE.HARD)
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.SHORT, R.CURVE.HARD)
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.SHORT, R.CURVE.HARD)
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.SHORT, R.CURVE.HARD)
	b.add_curve(R.LENGTH.SHORT, -R.CURVE.MEDIUM)
	b.add_curve(R.LENGTH.MEDIUM, R.CURVE.MEDIUM)
	b.add_straight(R.LENGTH.MEDIUM)
	b.add_curve(R.LENGTH.MEDIUM, R.CURVE.MEDIUM)
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.SHORT, R.CURVE.HARD)
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.SHORT, R.CURVE.HARD)
	b.add_straight(R.LENGTH.MEDIUM)
	b.add_curve(R.LENGTH.SHORT, R.CURVE.HARD)
	b.add_straight(R.LENGTH.MEDIUM)
	b.add_curve(R.LENGTH.SHORT, R.CURVE.HARD)
	b.add_straight(R.LENGTH.MEDIUM)
	b.add_curve(R.LENGTH.MEDIUM, R.CURVE.MEDIUM)
	b.add_curve(R.LENGTH.SHORT, -R.CURVE.MEDIUM)
	b.add_curve(R.LENGTH.MEDIUM, R.CURVE.MEDIUM)
	b.add_downhill_to_end(25)

	var end := b.segments.size()
	b.add_scenery("building", 6, end, 13, 1.0, 2.2, 3.6)
	b.add_scenery("building_2", 11, end, 15, -1.0, 2.0, 3.4)
	b.add_scenery("streetlight", 8, end, 9, -1.0, 1.35, 1.45)
	b.add_scenery("streetlight", 13, end, 9, 1.0, 1.35, 1.45)
