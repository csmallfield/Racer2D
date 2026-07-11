extends TrackLevel
## STAGE 12 — SUNSET VALLEY.
## Reference example for the two aesthetic systems:
##   1. Palette keyframes — the stage opens dry and midday-bright, greens into a
##      lush valley a quarter of the way in, then blends to a warm sunset in the
##      final third. Two sequential, non-overlapping, PARTIAL transitions.
##   2. Sprite parallax background — a four-layer stack (clouds, far mountains,
##      mid hills, near treeline). The mountains/hills/treeline are tinted from
##      the palette, so the dry->lush->sunset keyframes recolour the whole
##      skyline automatically. All art is BackgroundCatalog standins.


func _init() -> void:
	level_name = "STAGE 12 — SUNSET VALLEY"
	time_limit = 110.0
	traffic_count = 80
	music = "music_jungle"

	# Base palette: dry, dusty, high midday sun.
	theme = {
		"sky_top": Color(0.30, 0.55, 0.86),
		"sky_bottom": Color(0.76, 0.85, 0.92),
		"sun": Color(1.0, 0.98, 0.90),
		"hills": Color(0.55, 0.50, 0.34),
		"grass_light": Color(0.70, 0.62, 0.32),
		"grass_dark": Color(0.62, 0.55, 0.28),
		"road_light": Color(0.43, 0.43, 0.45),
		"road_dark": Color(0.39, 0.39, 0.41),
		"rumble_light": Color(0.93, 0.93, 0.93),
		"rumble_dark": Color(0.80, 0.20, 0.15),
		"lane": Color(0.92, 0.92, 0.92),
		"fog": Color(0.80, 0.85, 0.90),
		"start": Color(0.95, 0.95, 0.95),
		"finish": Color(0.08, 0.08, 0.08),
	}

	# Parallax background: far-to-near. Mountains and hills tint from "hills",
	# the treeline from "grass_dark" — all palette-driven, so they follow the
	# keyframes below. Clouds are an untinted white wash.
	background = [
		{"sprite": "clouds_far", "parallax": 0.04, "y": 0.34, "scale": 1.0,
				"fog": 0.15},
		{"sprite": "mountains_far", "parallax": 0.12, "y": 0.50, "scale": 1.15,
				"tint_key": "hills", "fog": 0.45},
		{"sprite": "hills_mid", "parallax": 0.22, "y": 0.52, "scale": 1.0,
				"tint_key": "hills", "fog": 0.25},
		{"sprite": "treeline_near", "parallax": 0.42, "y": 0.545, "scale": 0.95,
				"tint_key": "grass_dark", "fog": 0.08},
	]


func build(b: TrackBuilder) -> void:
	var R := TrackBuilder.ROAD

	# A flowing valley run — punchy v25 rhythm, nothing that grinds.
	b.add_straight(R.LENGTH.SHORT)
	b.add_low_rolling_hills()
	b.add_curve(R.LENGTH.MEDIUM, R.CURVE.EASY, R.HILL.LOW)
	b.add_hill(R.LENGTH.SHORT, R.HILL.HIGH)
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.MEDIUM, -R.HILL.LOW)
	b.add_s_curves()
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.MEDIUM, R.CURVE.MEDIUM, R.HILL.LOW)
	b.add_low_rolling_hills()
	b.add_hill(R.LENGTH.MEDIUM, R.HILL.HIGH)
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.EASY)
	b.add_s_curves()
	b.add_curve(R.LENGTH.LONG, R.CURVE.EASY, R.HILL.LOW)
	b.add_hill(R.LENGTH.SHORT, -R.HILL.MEDIUM)
	b.add_low_rolling_hills()
	b.add_curve(R.LENGTH.MEDIUM, R.CURVE.MEDIUM)
	b.add_downhill_to_end()

	# --- Palette keyframes, authored by fraction of the finished track ---
	# (build() runs before the timeline is assembled, so segment counts exist.)
	var n := b.segments.size()

	# 1) DRY -> LUSH. Only the ground/hill colours change; sky stays midday.
	var lush := {
		"hills": Color(0.20, 0.45, 0.25),
		"grass_light": Color(0.32, 0.64, 0.22),
		"grass_dark": Color(0.24, 0.54, 0.18),
	}
	# 2) DAY -> SUNSET. Applied AFTER lush (cumulative), so hills ease from the
	# lush green toward a dusk-shaded tone. Sky, sun, fog and rumble warm up.
	var sunset := {
		"sky_top": Color(0.24, 0.14, 0.44),
		"sky_bottom": Color(0.96, 0.55, 0.30),
		"sun": Color(1.0, 0.70, 0.34),
		"fog": Color(0.92, 0.56, 0.34),
		"hills": Color(0.34, 0.26, 0.34),
		"grass_light": Color(0.26, 0.40, 0.22),
		"grass_dark": Color(0.20, 0.32, 0.18),
		"rumble_dark": Color(0.62, 0.22, 0.24),
	}

	palette_keyframes = [
		{"to": lush, "start": int(n * 0.22), "over": int(n * 0.14),
				"ease": "in_out"},
		{"to": sunset, "start": int(n * 0.55), "over": int(n * 0.24),
				"ease": "in_out"},
	]

	# --- Scenery ---
	var end := b.segments.size()
	b.add_scenery("tree", 30, end, 9, 1.0, 1.5, 3.4)
	b.add_scenery("tree", 36, end, 11, -1.0, 1.5, 3.4)
	b.add_scenery("rock", 120, end, 37, 1.0, 1.4, 2.4)
	b.add_sprite(28, "sign", -1.3)
	b.add_sprite(28, "sign", 1.3)
