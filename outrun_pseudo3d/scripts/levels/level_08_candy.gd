extends TrackLevel
## STAGE 8 — Sugar Rush.
## Over the top: cotton-candy sky, mint frosting fields, a lavender taffy
## road with candy-stripe edges, giant lollipops lining every curve, and
## bouncy rolling hills the whole way. Sincerely ridiculous.


func _init() -> void:
	level_name = "STAGE 8 — SUGAR RUSH"
	time_limit = 340.0
	traffic_count = 48
	music = "music_candy"
	theme = {
		"sky_top": Color(0.55, 0.8, 1.0),
		"sky_bottom": Color(1.0, 0.75, 0.9),
		"sun": Color(1.0, 0.95, 0.6),
		"hills": Color(0.85, 0.6, 0.9),
		"grass_light": Color(0.55, 0.9, 0.75),    # mint frosting
		"grass_dark": Color(0.45, 0.82, 0.66),
		"road_light": Color(0.75, 0.65, 0.9),     # lavender taffy
		"road_dark": Color(0.68, 0.58, 0.84),
		"rumble_light": Color(1.0, 1.0, 1.0),     # candy-cane stripes
		"rumble_dark": Color(0.95, 0.25, 0.4),
		"lane": Color(1.0, 0.95, 0.8),
		"fog": Color(0.95, 0.8, 0.95),            # cotton candy haze
		"start": Color(1.0, 1.0, 1.0),
		"finish": Color(0.6, 0.2, 0.45),
	}


func build(b: TrackBuilder) -> void:
	var R := TrackBuilder.ROAD
	# Bouncy everywhere, sweeping and relentlessly cheerful.

	b.add_straight(R.LENGTH.SHORT)
	b.add_low_rolling_hills()
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.MEDIUM, R.HILL.MEDIUM)
	b.add_low_rolling_hills()
	b.add_curve(R.LENGTH.LONG, R.CURVE.EASY, R.HILL.LOW)
	b.add_low_rolling_hills()
	b.add_hill(R.LENGTH.SHORT, R.HILL.HIGH)
	b.add_hill(R.LENGTH.SHORT, -R.HILL.HIGH)
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.SHORT, R.CURVE.HARD)
	b.add_low_rolling_hills()
	b.add_s_curves()
	b.add_curve(R.LENGTH.LONG, R.CURVE.MEDIUM, -R.HILL.LOW)
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.EASY, R.HILL.LOW)
	b.add_low_rolling_hills()
	b.add_hill(R.LENGTH.SHORT, -R.HILL.MEDIUM)
	b.add_low_rolling_hills()
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.SHORT, R.CURVE.HARD)
	b.add_low_rolling_hills()
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.EASY, R.HILL.LOW)
	b.add_low_rolling_hills()
	b.add_s_curves()
	b.add_curve(R.LENGTH.LONG, R.CURVE.MEDIUM, -R.HILL.LOW)
	b.add_hill(R.LENGTH.SHORT, -R.HILL.MEDIUM)
	b.add_low_rolling_hills()
	b.add_low_rolling_hills()
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.MEDIUM, R.HILL.MEDIUM)
	b.add_low_rolling_hills()
	b.add_hill(R.LENGTH.SHORT, R.HILL.HIGH)
	b.add_hill(R.LENGTH.SHORT, -R.HILL.HIGH)
	b.add_low_rolling_hills()
	b.add_curve(R.LENGTH.LONG, R.CURVE.EASY, R.HILL.LOW)
	b.add_low_rolling_hills()
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.MEDIUM, R.HILL.MEDIUM)
	b.add_hill(R.LENGTH.SHORT, -R.HILL.MEDIUM)
	b.add_low_rolling_hills()
	b.add_low_rolling_hills()
	b.add_curve(R.LENGTH.LONG, R.CURVE.EASY, R.HILL.LOW)
	b.add_downhill_to_end()

	var end := b.segments.size()
	b.add_scenery("lollipop", 10, end, 11, 1.0, 1.3, 2.2)
	b.add_scenery("lollipop", 16, end, 13, -1.0, 1.3, 2.2)
	b.add_scenery("sign", 120, end, 157, 1.0, 1.3, 1.35)
	b.add_sprite(70, "sign", -1.3)
	b.add_sprite(70, "sign", 1.3)
