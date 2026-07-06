extends TrackLevel
## STAGE 7 — Hollow Ridge.
## Creepy: a blood moon over near-black hills, dense murky fog, dead trees
## clawing at the road, jack-o'-lanterns glowing on the verges. Twisty and
## mean — the fog hides the corners until they're on you.


func _init() -> void:
	level_name = "STAGE 7 — HOLLOW RIDGE"
	time_limit = 380.0
	traffic_count = 24
	music = "music_halloween"
	theme = {
		"sky_top": Color(0.03, 0.01, 0.06),
		"sky_bottom": Color(0.14, 0.04, 0.16),
		"sun": Color(0.9, 0.25, 0.1),             # blood moon
		"hills": Color(0.05, 0.02, 0.08),
		"grass_light": Color(0.1, 0.08, 0.12),
		"grass_dark": Color(0.07, 0.05, 0.09),
		"road_light": Color(0.16, 0.13, 0.18),
		"road_dark": Color(0.13, 0.1, 0.15),
		"rumble_light": Color(0.85, 0.45, 0.1),   # pumpkin-orange edges
		"rumble_dark": Color(0.25, 0.1, 0.3),
		"lane": Color(0.6, 0.5, 0.35),
		"fog": Color(0.08, 0.04, 0.1),
		"start": Color(0.8, 0.75, 0.7),
		"finish": Color(0.04, 0.02, 0.05),
	}


func build(b: TrackBuilder) -> void:
	var R := TrackBuilder.ROAD
	# Writhing, never straight for long; corners materialize from the murk.

	b.add_straight(R.LENGTH.SHORT)
	b.add_hill(R.LENGTH.SHORT, -R.HILL.MEDIUM)
	b.add_s_curves()
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.SHORT, R.CURVE.HARD)
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.EASY, R.HILL.LOW)
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.MEDIUM, -R.HILL.LOW)
	b.add_low_rolling_hills()
	b.add_curve(R.LENGTH.SHORT, -R.CURVE.HARD)
	b.add_low_rolling_hills()
	b.add_s_curves()
	b.add_curve(R.LENGTH.MEDIUM, R.CURVE.MEDIUM, -R.HILL.MEDIUM)
	b.add_s_curves()
	b.add_curve(R.LENGTH.MEDIUM, R.CURVE.HARD, R.HILL.LOW)
	b.add_curve(R.LENGTH.SHORT, -R.CURVE.HARD, R.HILL.LOW)
	b.add_low_rolling_hills()
	b.add_curve(R.LENGTH.MEDIUM, R.CURVE.EASY, R.HILL.MEDIUM)
	b.add_curve(R.LENGTH.SHORT, -R.CURVE.HARD)
	b.add_curve(R.LENGTH.SHORT, -R.CURVE.HARD, R.HILL.LOW)
	b.add_low_rolling_hills()
	b.add_s_curves()
	b.add_curve(R.LENGTH.MEDIUM, R.CURVE.HARD, R.HILL.LOW)
	b.add_hill(R.LENGTH.SHORT, -R.HILL.MEDIUM)
	b.add_s_curves()
	b.add_curve(R.LENGTH.SHORT, -R.CURVE.HARD)
	b.add_low_rolling_hills()
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.SHORT, R.CURVE.HARD)
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.EASY, R.HILL.LOW)
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.MEDIUM, -R.HILL.LOW)
	b.add_low_rolling_hills()
	b.add_s_curves()
	b.add_curve(R.LENGTH.MEDIUM, R.CURVE.MEDIUM, -R.HILL.MEDIUM)
	b.add_curve(R.LENGTH.MEDIUM, R.CURVE.EASY, R.HILL.MEDIUM)
	b.add_curve(R.LENGTH.SHORT, -R.CURVE.HARD)
	b.add_curve(R.LENGTH.SHORT, -R.CURVE.HARD)
	b.add_low_rolling_hills()
	b.add_hill(R.LENGTH.SHORT, -R.HILL.MEDIUM)
	b.add_s_curves()
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.SHORT, R.CURVE.HARD)
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.EASY, R.HILL.LOW)
	b.add_downhill_to_end()

	var end := b.segments.size()
	b.add_scenery("dead_tree", 8, end, 7, 1.0, 1.25, 2.4)
	b.add_scenery("dead_tree", 12, end, 7, -1.0, 1.25, 2.4)
	b.add_scenery("pumpkin", 30, end, 41, 1.0, 1.15, 1.4)
	b.add_scenery("pumpkin", 51, end, 43, -1.0, 1.15, 1.4)
	b.add_scenery("rock", 90, end, 83, -1.0, 1.6, 2.2)
	b.add_sprite(60, "sign", -1.3)
	b.add_sprite(60, "sign", 1.3)
