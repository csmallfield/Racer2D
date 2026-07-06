extends TrackLevel
## STAGE 4 — Neon City.
## Flat, fast, and tight: hard 90-ish corners between straights, heavy
## traffic, skyline both sides, synthwave dusk palette.


func _init() -> void:
	level_name = "STAGE 4 — NEON CITY"
	time_limit = 340.0
	traffic_count = 80
	music = "music_city"
	theme = {
		"sky_top": Color(0.1, 0.02, 0.18),
		"sky_bottom": Color(0.85, 0.25, 0.45),
		"sun": Color(1.0, 0.75, 0.35),
		"hills": Color(0.12, 0.06, 0.2),          # reads as a far skyline
		"grass_light": Color(0.16, 0.16, 0.2),    # concrete verges
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
	# Street grid: straights are braking zones, corners are walls.

	b.add_straight(R.LENGTH.SHORT)
	b.add_straight(R.LENGTH.MEDIUM)
	b.add_curve(R.LENGTH.SHORT, R.CURVE.HARD)
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.SHORT, -R.CURVE.HARD)
	b.add_straight(R.LENGTH.LONG)
	b.add_curve(R.LENGTH.SHORT, -R.CURVE.HARD)
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.SHORT, R.CURVE.HARD)
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.SHORT, R.CURVE.HARD)
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.SHORT, -R.CURVE.HARD)
	b.add_straight(R.LENGTH.MEDIUM)
	b.add_curve(R.LENGTH.MEDIUM, R.CURVE.MEDIUM)
	b.add_straight(R.LENGTH.MEDIUM)
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.MEDIUM)
	b.add_straight(R.LENGTH.MEDIUM)
	b.add_curve(R.LENGTH.MEDIUM, R.CURVE.MEDIUM)
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.SHORT, -R.CURVE.HARD)
	b.add_straight(R.LENGTH.LONG)
	b.add_curve(R.LENGTH.SHORT, -R.CURVE.HARD)
	b.add_straight(R.LENGTH.MEDIUM)
	b.add_curve(R.LENGTH.SHORT, R.CURVE.HARD)
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.SHORT, R.CURVE.HARD)
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.SHORT, -R.CURVE.HARD)
	b.add_straight(R.LENGTH.SHORT)
	b.add_curve(R.LENGTH.SHORT, R.CURVE.HARD)
	b.add_straight(R.LENGTH.MEDIUM)
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.MEDIUM)
	b.add_straight(R.LENGTH.MEDIUM)
	b.add_curve(R.LENGTH.MEDIUM, -R.CURVE.MEDIUM)
	b.add_straight(R.LENGTH.LONG)
	b.add_curve(R.LENGTH.SHORT, -R.CURVE.HARD)
	b.add_straight(R.LENGTH.LONG)

	var end := b.segments.size()
	b.add_scenery("building", 10, end, 14, 1.0, 2.2, 3.6)
	b.add_scenery("building_2", 16, end, 17, -1.0, 2.0, 3.4)
	b.add_scenery("building_2", 24, end, 23, 1.0, 2.6, 4.0)
	b.add_scenery("streetlight", 8, end, 10, -1.0, 1.35, 1.45)
	b.add_scenery("streetlight", 13, end, 10, 1.0, 1.35, 1.45)
	b.add_sprite(28, "sign", -1.3)
	b.add_sprite(28, "sign", 1.3)
