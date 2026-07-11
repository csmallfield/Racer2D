extends TrackLevel
## CIRCUIT 3 — Sugar Ring. Candy theme, left-biased with bouncy hills: a
## rolling frosted speedway ringed by lollipops.


func _init() -> void:
	level_name = "CIRCUIT 3 — SUGAR RING"
	time_limit = 80.0          # per lap
	laps = 3
	checkpoint_count = 2
	traffic_count = 18
	music = "music_candy"
	theme = {
		"sky_top": Color(0.55, 0.8, 1.0),
		"sky_bottom": Color(1.0, 0.75, 0.9),
		"sun": Color(1.0, 0.95, 0.6),
		"hills": Color(0.85, 0.6, 0.9),
		"grass_light": Color(0.55, 0.9, 0.75),
		"grass_dark": Color(0.45, 0.82, 0.66),
		"road_light": Color(0.75, 0.65, 0.9),
		"road_dark": Color(0.68, 0.58, 0.84),
		"rumble_light": Color(1.0, 1.0, 1.0),
		"rumble_dark": Color(0.95, 0.25, 0.4),
		"lane": Color(1.0, 0.95, 0.8),
		"fog": Color(0.95, 0.8, 0.95),
		"start": Color(1.0, 1.0, 1.0),
		"finish": Color(0.6, 0.2, 0.45),
	}


func build(b: TrackBuilder) -> void:
	var R := TrackBuilder.ROAD
	# Left-biased, bouncy frosted speedway.

	b.add_straight(R.LENGTH.SHORT)
	b.add_low_rolling_hills()
	b.add_curve(R.LENGTH.SHORT, -R.CURVE.HARD)
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.EASY, R.HILL.LOW)
	b.add_low_rolling_hills()
	b.add_curve(R.LENGTH.SHORT, -R.CURVE.HARD)
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.MEDIUM)
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.SHORT, R.CURVE.EASY, R.HILL.LOW)
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.MEDIUM, -R.HILL.LOW)
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.EASY, R.HILL.LOW)
	b.add_low_rolling_hills()
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.MEDIUM)
	b.add_straight(R.LENGTH.SHORT)
	b.add_low_rolling_hills()
	b.add_curve(R.LENGTH.SHORT, -R.CURVE.HARD)
	b.add_downhill_to_end(25)

	var end := b.segments.size()
	b.add_scenery("lollipop", 8, end, 9, 1.0, 1.3, 2.2)
	b.add_scenery("lollipop", 13, end, 11, -1.0, 1.3, 2.2)
	b.add_sprite(40, "sign", -1.3)
	b.add_sprite(40, "sign", 1.3)
