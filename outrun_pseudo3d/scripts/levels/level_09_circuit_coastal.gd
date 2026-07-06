extends TrackLevel
## CIRCUIT 1 — Seaside Ring. Coastal theme, left-biased: a fast clockwise
## bowl of long left sweepers with one right kink and a rolling back stretch.


func _init() -> void:
	level_name = "CIRCUIT 1 — SEASIDE RING"
	time_limit = 80.0          # per lap
	laps = 3
	checkpoint_count = 2
	traffic_count = 21
	music = "music_coastal"
	theme = {
		"sky_top": Color(0.15, 0.35, 0.8),
		"sky_bottom": Color(0.55, 0.8, 0.95),
		"sun": Color(1.0, 0.95, 0.7),
		"hills": Color(0.2, 0.45, 0.35),
		"grass_light": Color(0.25, 0.65, 0.25),
		"grass_dark": Color(0.2, 0.58, 0.2),
		"road_light": Color(0.42, 0.42, 0.45),
		"road_dark": Color(0.38, 0.38, 0.41),
		"rumble_light": Color(0.95, 0.95, 0.95),
		"rumble_dark": Color(0.85, 0.2, 0.2),
		"lane": Color(0.9, 0.9, 0.85),
		"fog": Color(0.6, 0.78, 0.9),
		"start": Color(0.95, 0.95, 0.95),
		"finish": Color(0.1, 0.1, 0.1),
	}


func build(b: TrackBuilder) -> void:
	var R := TrackBuilder.ROAD
	# Left-biased ring: fast bowl of left sweepers, one right kink.

	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.SHORT, -R.CURVE.HARD)
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.MEDIUM)
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.MEDIUM)
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.EASY, R.HILL.LOW)
	b.add_curve(R.LENGTH.SHORT, R.CURVE.MEDIUM, -R.HILL.LOW)
	b.add_curve(R.LENGTH.LONG, -R.CURVE.EASY)
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.MEDIUM)
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.EASY, R.HILL.LOW)
	b.add_curve(R.LENGTH.SHORT, R.CURVE.MEDIUM, -R.HILL.LOW)
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.MEDIUM)
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.LONG, -R.CURVE.EASY)
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.SHORT, -R.CURVE.HARD)
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.SHORT, -R.CURVE.HARD)
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.MEDIUM)
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.EASY, R.HILL.LOW)
	b.add_curve(R.LENGTH.SHORT, R.CURVE.MEDIUM, -R.HILL.LOW)
	b.add_downhill_to_end(25)

	var end := b.segments.size()
	b.add_scenery("palm", 8, end, 9, 1.0, 1.3, 2.4)
	b.add_scenery("tree", 14, end, 11, -1.0, 1.4, 2.6)
	b.add_sprite(30, "sign", -1.3)
	b.add_sprite(30, "sign", 1.3)
