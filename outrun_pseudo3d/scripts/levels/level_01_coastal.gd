extends TrackLevel
## STAGE 1 — Coastal Run.
## A gentle opener: rolling hills, S-curves, one big climb, palm-lined road.
## This file doubles as the reference example for the level authoring API.


func _init() -> void:
	level_name = "STAGE 1 — COASTAL RUN"
	time_limit = 80.0
	traffic_count = 12
	music = "music_coastal"
	theme = {
		"sky_top": Color(0.12, 0.35, 0.82),
		"sky_bottom": Color(0.55, 0.78, 0.95),
		"sun": Color(1.0, 0.96, 0.8),
		"hills": Color(0.2, 0.45, 0.4),
		"grass_light": Color(0.34, 0.66, 0.2),
		"grass_dark": Color(0.29, 0.58, 0.17),
		"road_light": Color(0.43, 0.43, 0.45),
		"road_dark": Color(0.39, 0.39, 0.41),
		"rumble_light": Color(0.93, 0.93, 0.93),
		"rumble_dark": Color(0.78, 0.13, 0.13),
		"lane": Color(0.92, 0.92, 0.92),
		"fog": Color(0.55, 0.78, 0.95),
		"start": Color(0.95, 0.95, 0.95),
		"finish": Color(0.08, 0.08, 0.08),
	}


func build(b: TrackBuilder) -> void:
	var R := TrackBuilder.ROAD

	# --- Road layout ---
	b.add_straight(R.LENGTH.SHORT)
	b.add_low_rolling_hills()
	b.add_curve(R.LENGTH.MEDIUM, R.CURVE.MEDIUM, R.HILL.LOW)
	b.add_straight(R.LENGTH.MEDIUM)
	b.add_s_curves()
	b.add_hill(R.LENGTH.MEDIUM, R.HILL.HIGH)
	b.add_curve(R.LENGTH.LONG, -R.CURVE.MEDIUM)
	b.add_hill(R.LENGTH.SHORT, -R.HILL.MEDIUM)
	b.add_curve(R.LENGTH.MEDIUM, R.CURVE.EASY, R.HILL.LOW)
	b.add_straight(R.LENGTH.SHORT)
	b.add_downhill_to_end()

	# --- Scenery ---
	var end := b.segments.size()
	b.add_scenery("palm", 20, end, 6, 1.0)
	b.add_scenery("palm", 25, end, 7, -1.0)
	b.add_scenery("tree", 40, end, 13, -1.0, 1.8, 3.6)
	b.add_scenery("tree", 55, end, 17, 1.0, 1.8, 3.6)
	b.add_scenery("rock", 100, end, 41, -1.0, 1.4, 2.2)

	# Billboards flanking the start.
	b.add_sprite(30, "sign", -1.3)
	b.add_sprite(30, "sign", 1.3)
	b.add_sprite(120, "sign", -1.3)
