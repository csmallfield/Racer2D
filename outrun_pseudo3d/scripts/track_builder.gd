class_name TrackBuilder
extends RefCounted
## Builds a track as an array of road segments.
##
## Levels (see track_level.gd) receive a TrackBuilder in build() and call the
## add_* methods to author the road. The road is described as a sequence of
## pieces, each with an entry ramp, a hold section, and an exit ramp, so
## curves and hills ease in and out smoothly.
##
## Curve values are "x acceleration per segment" (higher = sharper).
## Hill values are in segment-length units of altitude change.

const SEGMENT_LENGTH := 200.0   # world units per segment
const RUMBLE_LENGTH := 3        # segments per light/dark stripe

## Handy preset values, mirroring classic pseudo-3D tuning.
# v25 piece sizes: corners and hills stay short, punchy events — tracks get
# their length from MORE pieces, never from stretching individual ones
# (long grinding corners are where racing goes to die).
const ROAD := {
	"LENGTH": {"NONE": 0, "SHORT": 25, "MEDIUM": 50, "LONG": 100},
	"CURVE": {"NONE": 0.0, "EASY": 2.0, "MEDIUM": 4.0, "HARD": 6.0},
	"HILL": {"NONE": 0.0, "LOW": 20.0, "MEDIUM": 40.0, "HIGH": 60.0},
}

var segments: Array = []


func track_length() -> float:
	return segments.size() * SEGMENT_LENGTH


func last_y() -> float:
	if segments.is_empty():
		return 0.0
	return segments[segments.size() - 1].p2.world.y


# === EASING ===

static func ease_in_curve(a: float, b: float, percent: float) -> float:
	return a + (b - a) * pow(percent, 2.0)


static func ease_out_curve(a: float, b: float, percent: float) -> float:
	return a + (b - a) * (1.0 - pow(1.0 - percent, 2.0))


static func ease_in_out_curve(a: float, b: float, percent: float) -> float:
	return a + (b - a) * ((-cos(percent * PI) / 2.0) + 0.5)


# === CORE SEGMENT CONSTRUCTION ===

func _make_point(y: float, z: float) -> Dictionary:
	return {
		"world": {"x": 0.0, "y": y, "z": z},
		"camera": {"x": 0.0, "y": 0.0, "z": 0.0},
		"screen": {"x": 0.0, "y": 0.0, "w": 0.0, "scale": 0.0},
	}


func _add_segment(curve: float, y: float) -> void:
	var i := segments.size()
	segments.append({
		"index": i,
		"curve": curve,
		"p1": _make_point(last_y(), i * SEGMENT_LENGTH),
		"p2": _make_point(y, (i + 1) * SEGMENT_LENGTH),
		"sprites": [],
		"cars": [],
		"clip": 0.0,
		"looped": false,
		"color": int(i / float(RUMBLE_LENGTH)) % 2,   # alternate light/dark stripes
		"special": "",
		"pickups": [],
	})


## The fundamental road piece: eases into a curve/hill, holds it, eases out.
## y is the total altitude change, in units of SEGMENT_LENGTH.
func add_road(enter: int, hold: int, leave: int, curve: float, y: float = 0.0) -> void:
	var start_y := last_y()
	var end_y := start_y + y * SEGMENT_LENGTH
	var total := float(max(1, enter + hold + leave))
	for n in range(enter):
		_add_segment(
			ease_in_curve(0.0, curve, float(n) / max(1.0, float(enter))),
			ease_in_out_curve(start_y, end_y, float(n) / total))
	for n in range(hold):
		_add_segment(
			curve,
			ease_in_out_curve(start_y, end_y, float(enter + n) / total))
	for n in range(leave):
		_add_segment(
			ease_in_out_curve(curve, 0.0, float(n) / max(1.0, float(leave))),
			ease_in_out_curve(start_y, end_y, float(enter + hold + n) / total))


# === CONVENIENCE PIECES ===

func add_straight(n: int = ROAD.LENGTH.MEDIUM) -> void:
	add_road(n, n, n, 0.0, 0.0)


func add_hill(n: int = ROAD.LENGTH.MEDIUM, height: float = ROAD.HILL.MEDIUM) -> void:
	add_road(n, n, n, 0.0, height)


func add_curve(n: int = ROAD.LENGTH.MEDIUM, curve: float = ROAD.CURVE.MEDIUM, height: float = 0.0) -> void:
	add_road(n, n, n, curve, height)


func add_low_rolling_hills(n: int = ROAD.LENGTH.SHORT, height: float = ROAD.HILL.LOW) -> void:
	add_road(n, n, n, 0.0, height / 2.0)
	add_road(n, n, n, 0.0, -height)
	add_road(n, n, n, ROAD.CURVE.EASY, height)
	add_road(n, n, n, 0.0, 0.0)
	add_road(n, n, n, -ROAD.CURVE.EASY, height / 2.0)
	add_road(n, n, n, 0.0, 0.0)


func add_s_curves() -> void:
	add_road(ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, -ROAD.CURVE.EASY)
	add_road(ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.CURVE.MEDIUM, ROAD.HILL.LOW)
	add_road(ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.CURVE.EASY, -ROAD.HILL.LOW)
	add_road(ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, -ROAD.CURVE.EASY, ROAD.HILL.MEDIUM)
	add_road(ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, -ROAD.CURVE.MEDIUM, -ROAD.HILL.MEDIUM)


## Curves gently back down to altitude zero so the loop point doesn't pop.
func add_downhill_to_end(n: int = 200) -> void:
	add_road(n, n, n, -ROAD.CURVE.EASY, -last_y() / SEGMENT_LENGTH)


# === SCENERY & SPRITES ===

## A boost canister on the road, collectible by any racer (first come).
## Levels can place them deliberately; stages that place none get a random
## scatter (RaceSettings.auto_pickup_count).
func add_boost_pickup(seg_index: int, offset: float) -> void:
	if seg_index < 0 or seg_index >= segments.size():
		return
	segments[seg_index].pickups.append(
			{"offset": offset, "taken": false, "respawn_t": 0.0})


func add_sprite(seg_index: int, sprite_name: String, offset: float) -> void:
	if seg_index < 0 or seg_index >= segments.size():
		return
	segments[seg_index].sprites.append({"name": sprite_name, "offset": offset})


## Scatter one sprite type along a range of segments.
## side: +1 = right of road, -1 = left of road.
## Offsets are in half-road-widths; 1.0 is exactly the road edge.
func add_scenery(sprite_name: String, start_index: int, end_index: int, step: int,
		side: float, offset_min: float = 1.3, offset_max: float = 3.2) -> void:
	var last: int = mini(end_index, segments.size())
	var i := start_index
	while i < last:
		add_sprite(i, sprite_name, side * randf_range(offset_min, offset_max))
		i += step


## Paint checkpoint stripes across the road at `count` evenly spaced points
## and return their z positions (used for timer extensions and time deltas).
## Call after finalize().
func mark_checkpoints(count: int) -> Array[float]:
	var zs: Array[float] = []
	for k in range(1, count + 1):
		var idx := int(float(segments.size()) * float(k) / float(count + 1))
		zs.append(float(idx) * SEGMENT_LENGTH)
		for i in range(idx, mini(idx + RUMBLE_LENGTH * 2, segments.size())):
			if segments[i].special == "":
				segments[i].special = "checkpoint"
	return zs


## Call after build() to mark start/finish stripes.
func finalize() -> void:
	if segments.size() < 20:
		# Safety net: a track needs some minimum length to render/loop sanely.
		add_straight(ROAD.LENGTH.MEDIUM)
	for i in range(0, RUMBLE_LENGTH * 2):
		segments[i].special = "start"
	for i in range(segments.size() - RUMBLE_LENGTH * 2, segments.size()):
		segments[i].special = "finish"
