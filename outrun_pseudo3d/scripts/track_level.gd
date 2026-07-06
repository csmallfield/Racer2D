class_name TrackLevel
extends RefCounted
## Base class for authorable levels.
##
## To create a new level:
##   1. Create a new .gd file in res://scripts/levels/
##   2. `extends TrackLevel`
##   3. Set metadata (level_name, time_limit, traffic_count, theme) in _init()
##   4. Override build(b) and describe the road with the TrackBuilder API
##
## Levels are auto-discovered from res://scripts/levels/ at startup and played
## in filename order, so prefix files with numbers (level_01_..., level_02_...).

var level_name := "UNNAMED STAGE"
var time_limit := 70.0       # total seconds, split evenly per checkpoint section
var traffic_count := 10      # number of NPC cars on the track
var rival_count := 9         # AI opponents racing you (max 9); rank shows N+1 total
var checkpoint_count := 11   # evenly spaced; time_limit is split across sections
## 0 = point-to-point tour stage. >0 = circuit: the track loops this many
## laps, the finish line refills the section timer each lap, and time_limit
## is the PER-LAP allotment. Circuits appear only in Circuit mode.
var laps := 0
var music := ""              # sound name in assets/audio/, e.g. "music_coastal"

## Colors used by the renderer. Override any/all of these per level.
var theme := {
	"sky_top": Color(0.15, 0.35, 0.8),
	"sky_bottom": Color(0.55, 0.75, 0.95),
	"sun": Color(1.0, 0.95, 0.75),
	"hills": Color(0.25, 0.45, 0.35),
	"grass_light": Color(0.35, 0.65, 0.2),
	"grass_dark": Color(0.3, 0.58, 0.17),
	"road_light": Color(0.42, 0.42, 0.44),
	"road_dark": Color(0.38, 0.38, 0.4),
	"rumble_light": Color(0.92, 0.92, 0.92),
	"rumble_dark": Color(0.75, 0.12, 0.12),
	"lane": Color(0.9, 0.9, 0.9),
	"fog": Color(0.55, 0.75, 0.95),
	"start": Color(0.95, 0.95, 0.95),
	"finish": Color(0.1, 0.1, 0.1),
}


## Override this. Describe the road using the TrackBuilder API.
func build(b: TrackBuilder) -> void:
	b.add_straight()
