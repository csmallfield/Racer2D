extends TrackLevel
## STAGE 2 — Desert Pass.
## Harder: sharper curves, bigger elevation swings, more traffic, dusk palette.


func _init() -> void:
	level_name = "STAGE 2 — DESERT PASS"
	time_limit = 85.0
	traffic_count = 16
	music = "music_desert"
	theme = {
		"sky_top": Color(0.35, 0.15, 0.4),
		"sky_bottom": Color(0.95, 0.6, 0.35),
		"sun": Color(1.0, 0.75, 0.4),
		"hills": Color(0.5, 0.3, 0.25),
		"grass_light": Color(0.8, 0.65, 0.4),
		"grass_dark": Color(0.72, 0.57, 0.34),
		"road_light": Color(0.45, 0.4, 0.38),
		"road_dark": Color(0.41, 0.36, 0.34),
		"rumble_light": Color(0.92, 0.88, 0.8),
		"rumble_dark": Color(0.65, 0.2, 0.1),
		"lane": Color(0.9, 0.85, 0.7),
		"fog": Color(0.95, 0.65, 0.4),
		"start": Color(0.95, 0.92, 0.85),
		"finish": Color(0.1, 0.08, 0.06),
	}


func build(b: TrackBuilder) -> void:
	var R := TrackBuilder.ROAD

	# --- Road layout ---
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.MEDIUM, R.CURVE.HARD, R.HILL.LOW)
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.HARD, -R.HILL.LOW)
	b.add_hill(R.LENGTH.LONG, R.HILL.HIGH)
	b.add_s_curves()
	b.add_curve(R.LENGTH.LONG, R.CURVE.MEDIUM, -R.HILL.MEDIUM)
	b.add_low_rolling_hills(R.LENGTH.SHORT, R.HILL.MEDIUM)
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.HARD, R.HILL.LOW)
	b.add_straight(R.LENGTH.SHORT)
	b.add_s_curves()
	b.add_downhill_to_end()

	# --- Scenery ---
	var end := b.segments.size()
	b.add_scenery("cactus", 15, end, 5, 1.0)
	b.add_scenery("cactus", 18, end, 6, -1.0)
	b.add_scenery("rock", 30, end, 11, 1.0, 1.4, 2.8)
	b.add_scenery("rock", 45, end, 13, -1.0, 1.4, 2.8)

	b.add_sprite(40, "sign", 1.3)
	b.add_sprite(200, "sign", -1.3)
	b.add_sprite(201, "sign", 1.3)
