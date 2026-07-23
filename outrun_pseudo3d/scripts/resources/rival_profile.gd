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

@export_group("Boost")
## Matches the player's tank. Kept level deliberately: an asymmetric
## capacity means a richer boost economy quietly favours whoever has the
## deeper tank rather than whoever drives better.
@export var boost_capacity := 3.0
## Willingness to burn boost (0 = hoards it, 1 = fires at every opening).
## Governs how quickly they take valid opportunities: straights while
## attacking the player or sprinting for the line.
@export_range(0.0, 1.0) var boost_aggression := 0.5

@export_group("Selection Screen")
## Grid profile picture. Leave empty for a flat placeholder in `color`.
@export var portrait: Texture2D
## Beauty illustration (character + car) for the select detail panel.
## Leave empty for a placeholder block; drop in real art here later.
@export var illustration: Texture2D
## Player-facing stat bars (1..5). Deliberately separate from the AI-tuning
## fields above so what a player sees can be tuned apart from how the car
## actually drives — the two only converge in a later phase.
@export_range(1, 5) var stat_speed := 3
@export_range(1, 5) var stat_accel := 3
@export_range(1, 5) var stat_handling := 3
