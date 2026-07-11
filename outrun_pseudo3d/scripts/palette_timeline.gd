class_name PaletteTimeline
extends RefCounted
## Resolves a keyframed theme against a track position.
##
## A level authors a base theme (TrackLevel.theme) plus a list of palette
## transitions (TrackLevel.palette_keyframes). Each transition names a PARTIAL
## target palette, the segment where the blend begins, and how many segments it
## lasts. resolve(seg) walks the transitions in order and lerps, so the renderer
## always gets a single flat theme dict that changes smoothly along the track.
##
## Transitions are applied cumulatively and must be sorted by start segment and
## be non-overlapping: a blend runs to completion before the next one begins.
## (Two simultaneous blends over the same range are not supported by design.)
##
## Keying is by TRACK SEGMENT INDEX. On tours the track is traversed once, so a
## keyframe fires once. On circuits position_z wraps every lap, so a keyframe
## fires once PER LAP (day -> sunset -> day). For race-long progression on a
## circuit, feed resolve() a total-progress segment count instead of the wrapped
## index (see the note in RoadRenderer).

## A transition keyframe is a Dictionary:
##   "to"    : Dictionary  - PARTIAL theme; only the keys that change
##   "start" : int         - segment index where the blend begins
##   "over"  : int         - blend length in segments (>= 1)
##   "ease"  : String      - "in_out" (default), "in", "out", or "linear"

var _base: Dictionary = {}
var _keys: Array = []      # transitions, sorted by start


## Build a timeline from a base theme and a (possibly empty) keyframe list.
## Always returns a valid timeline; with no keyframes, resolve() just returns
## the base theme, so callers never need to null-check.
static func build(base: Dictionary, keyframes: Array = []) -> PaletteTimeline:
	var t := PaletteTimeline.new()
	t._base = base.duplicate()
	var ks: Array = keyframes.duplicate()
	# Defensive: normalise and sort so resolve() can assume order and bounds.
	for k in ks:
		if not k.has("over"):
			k["over"] = 1
		k["over"] = maxi(1, int(k["over"]))
		if not k.has("ease"):
			k["ease"] = "in_out"
		if not k.has("to"):
			k["to"] = {}
	ks.sort_custom(func(a, b): return int(a.start) < int(b.start))
	t._keys = ks
	return t


func has_keyframes() -> bool:
	return not _keys.is_empty()


## The active theme at a track segment index.
func resolve(seg: int) -> Dictionary:
	if _keys.is_empty():
		return _base
	var cur: Dictionary = _base.duplicate()
	for kf in _keys:
		var start := int(kf.start)
		var over := int(kf.over)
		# The fully-applied version of this transition (partial merged onto cur).
		var target := _merge(cur, kf.to)
		if seg >= start + over:
			cur = target                       # transition complete, carry forward
		elif seg <= start:
			break                              # not started; later ones neither
		else:
			var raw := float(seg - start) / float(over)
			cur = _lerp_theme(cur, target, _ease(String(kf.ease), raw))
			break                              # mid-blend; later ones not started
	return cur


# === HELPERS ===

## Copy `base`, overwriting only the keys present in `partial`.
static func _merge(base: Dictionary, partial: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate()
	for k in partial:
		out[k] = partial[k]
	return out


## Per-key colour lerp. Both dicts share the base keyset, so iterate `b`.
static func _lerp_theme(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out: Dictionary = {}
	for k in b:
		var ca: Color = a.get(k, b[k])
		out[k] = ca.lerp(b[k], t)
	return out


static func _ease(mode: String, t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	match mode:
		"linear":
			return t
		"in":
			return TrackBuilder.ease_in_curve(0.0, 1.0, t)
		"out":
			return TrackBuilder.ease_out_curve(0.0, 1.0, t)
		_:
			return TrackBuilder.ease_in_out_curve(0.0, 1.0, t)
