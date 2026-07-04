extends TrackLevel
## STAGE 6 — Rocky Mountains.
## Twice the altitude of anything else: monster climbs into sharp crests
## that launch a fast car clean off the road, plunging descents, sweeping
## high passes. Light traffic — the mountain is the opponent.


func _init() -> void:
	level_name = "STAGE 6 — ROCKY MOUNTAINS"
	time_limit = 95.0
	traffic_count = 8
	music = "music_mountain"
	theme = {
		"sky_top": Color(0.45, 0.6, 0.8),
		"sky_bottom": Color(0.85, 0.9, 0.95),
		"sun": Color(1.0, 1.0, 0.9),
		"hills": Color(0.4, 0.45, 0.55),
		"grass_light": Color(0.4, 0.44, 0.4),     # scree and alpine scrub
		"grass_dark": Color(0.34, 0.38, 0.35),
		"road_light": Color(0.36, 0.36, 0.4),
		"road_dark": Color(0.32, 0.32, 0.36),
		"rumble_light": Color(0.95, 0.95, 0.97),  # snow-white edges
		"rumble_dark": Color(0.6, 0.15, 0.12),
		"lane": Color(0.9, 0.9, 0.92),
		"fog": Color(0.75, 0.8, 0.88),
		"start": Color(0.95, 0.95, 0.98),
		"finish": Color(0.12, 0.12, 0.18),
	}


func build(b: TrackBuilder) -> void:
	var R := TrackBuilder.ROAD
	# Hill values are 2x the standard presets (LOW/MEDIUM/HIGH = 20/40/60):
	# 40/80/120 makes crests genuinely ballistic at speed.

	b.add_straight(R.LENGTH.SHORT)
	b.add_hill(R.LENGTH.MEDIUM, 80)                          # first big climb
	b.add_curve(R.LENGTH.LONG, R.CURVE.EASY, 40)             # sweeping high pass
	b.add_hill(R.LENGTH.SHORT, 60)                           # sharp crest — jump
	b.add_hill(R.LENGTH.MEDIUM, -120)                        # plunging descent
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.MEDIUM, 40)
	b.add_hill(R.LENGTH.LONG, 120)                           # the monster climb
	b.add_hill(R.LENGTH.SHORT, -60)                          # crest over the top
	b.add_curve(R.LENGTH.MEDIUM, R.CURVE.HARD, -40)          # downhill hard corner
	b.add_low_rolling_hills()
	b.add_downhill_to_end()

	# --- Scenery: rock everywhere, hardy trees in the valleys ---
	var end := b.segments.size()
	b.add_scenery("rock", 8, end, 9, 1.0, 1.3, 2.4)
	b.add_scenery("rock", 13, end, 11, -1.0, 1.3, 2.4)
	b.add_scenery("tree", 30, end, 21, 1.0, 1.6, 2.6)
	b.add_scenery("tree", 44, end, 23, -1.0, 1.6, 2.6)
	b.add_sprite(24, "sign", -1.3)
	b.add_sprite(24, "sign", 1.3)
