class_name RivalProfile
extends Resource
## One AI opponent. Roster order in RaceSettings = grid order (last entry
## starts on pole). Livery color drives both the generated placeholder car
## and the progress-bar dot; assign car_texture to use real art instead.

@export var display_name := "RIVAL"
@export var color := Color.WHITE
## Cruise speed as a fraction of the player's max speed (1.0 = matches you
## flat-out; such a rival is only beatable through corners and traffic).
@export_range(0.5, 1.1) var cruise_fraction := 0.9
## Signed preferred lane in road-halves (-1..1); the racing line they hold
## when nothing needs dodging.
@export_range(-0.85, 0.85) var preferred_lane := 0.4
## Optional sprite art. Leave empty to generate a placeholder in `color`
## with a racing stripe. World size stays 510x295 units.
@export var car_texture: Texture2D
