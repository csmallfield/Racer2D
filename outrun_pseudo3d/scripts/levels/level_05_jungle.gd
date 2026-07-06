extends TrackLevel
## STAGE 5 — Jungle Run.
## Winding and claustrophobic: relentless medium curves over rolling
## ground, dense canopy walls, thick green haze. Few straights — rhythm
## is everything.


func _init() -> void:
	level_name = "STAGE 5 — JUNGLE RUN"
	time_limit = 380.0
	traffic_count = 60
	music = "music_jungle"
	theme = {
		"sky_top": Color(0.35, 0.6, 0.55),
		"sky_bottom": Color(0.75, 0.85, 0.6),
		"sun": Color(1.0, 0.95, 0.75),
		"hills": Color(0.1, 0.3, 0.2),
		"grass_light": Color(0.16, 0.42, 0.18),
		"grass_dark": Color(0.12, 0.36, 0.14),
		"road_light": Color(0.4, 0.34, 0.26),     # packed dirt
		"road_dark": Color(0.35, 0.3, 0.22),
		"rumble_light": Color(0.75, 0.7, 0.55),
		"rumble_dark": Color(0.5, 0.3, 0.15),
		"lane": Color(0.7, 0.65, 0.5),
		"fog": Color(0.3, 0.5, 0.35),
		"start": Color(0.9, 0.9, 0.8),
		"finish": Color(0.1, 0.15, 0.08),
	}


func build(b: TrackBuilder) -> void:
	var R := TrackBuilder.ROAD
	# Winding and hilly, almost no rest.

	b.add_straight(R.LENGTH.SHORT)
	b.add_s_curves()
	b.add_curve(R.LENGTH.MEDIUM, R.CURVE.MEDIUM, R.HILL.LOW)
	b.add_hill(R.LENGTH.SHORT, -R.HILL.HIGH)
	b.add_s_curves()
	b.add_low_rolling_hills()
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.MEDIUM, -R.HILL.LOW)
	b.add_hill(R.LENGTH.SHORT, R.HILL.HIGH)
	b.add_curve(R.LENGTH.SHORT, -R.CURVE.HARD)
	b.add_low_rolling_hills()
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.MEDIUM)
	b.add_curve(R.LENGTH.SHORT, R.CURVE.HARD, -R.HILL.LOW)
	b.add_low_rolling_hills()
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.MEDIUM, R.CURVE.EASY, R.HILL.MEDIUM)
	b.add_s_curves()
	b.add_curve(R.LENGTH.SHORT, R.CURVE.HARD, R.HILL.LOW)
	b.add_low_rolling_hills()
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.MEDIUM)
	b.add_curve(R.LENGTH.SHORT, R.CURVE.HARD, -R.HILL.LOW)
	b.add_low_rolling_hills()
	b.add_hill(R.LENGTH.SHORT, R.HILL.HIGH)
	b.add_curve(R.LENGTH.SHORT, -R.CURVE.HARD)
	b.add_s_curves()
	b.add_curve(R.LENGTH.MEDIUM, R.CURVE.MEDIUM, R.HILL.LOW)
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.MEDIUM, R.CURVE.EASY, R.HILL.MEDIUM)
	b.add_s_curves()
	b.add_curve(R.LENGTH.SHORT, R.CURVE.HARD, R.HILL.LOW)
	b.add_low_rolling_hills()
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.MEDIUM, -R.HILL.LOW)
	b.add_hill(R.LENGTH.SHORT, -R.HILL.HIGH)
	b.add_s_curves()
	b.add_s_curves()
	b.add_curve(R.LENGTH.MEDIUM, R.CURVE.MEDIUM, R.HILL.LOW)
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.MEDIUM, R.CURVE.EASY, R.HILL.MEDIUM)
	b.add_s_curves()
	b.add_curve(R.LENGTH.SHORT, R.CURVE.HARD, R.HILL.LOW)
	b.add_low_rolling_hills()
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.MEDIUM, -R.HILL.LOW)
	b.add_hill(R.LENGTH.SHORT, R.HILL.HIGH)
	b.add_curve(R.LENGTH.SHORT, -R.CURVE.HARD)
	b.add_hill(R.LENGTH.SHORT, -R.HILL.HIGH)
	b.add_s_curves()
	b.add_low_rolling_hills()
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.MEDIUM)
	b.add_curve(R.LENGTH.SHORT, R.CURVE.HARD, -R.HILL.LOW)
	b.add_low_rolling_hills()
	b.add_downhill_to_end()

	var end := b.segments.size()
	b.add_scenery("tree", 8, end, 5, 1.0, 1.25, 2.2)
	b.add_scenery("tree", 11, end, 5, -1.0, 1.25, 2.2)
	b.add_scenery("palm", 14, end, 9, 1.0, 1.5, 2.8)
	b.add_scenery("palm", 19, end, 9, -1.0, 1.5, 2.8)
	b.add_scenery("rock", 40, end, 37, -1.0, 1.3, 1.8)
	b.add_sprite(26, "sign", -1.3)
	b.add_sprite(26, "sign", 1.3)
