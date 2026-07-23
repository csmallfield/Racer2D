class_name CupDefinition
extends Resource
## One tournament cup: an ordered manifest of tracks plus its scoring rules.
## Edit resources/cups/*.tres, and register them on race_settings.tres so the
## menu can list them.
##
## Adding a cup is dropping a .tres in and adding it to that array — no code
## change. Nothing here requires a cup to be all circuits or all tours; the
## manifest is just a track list, and circuit-vs-tour behaviour is derived
## per level at load time.

@export var display_name := "CUP"

## Level filenames in race order, e.g. "level_09_circuit_coastal.gd".
## Filenames rather than indices, for the same reason the records keys use
## them: reordering the level list must never scramble a cup.
@export var tracks: Array[String] = []

## Laps for circuit rounds in this cup. 0 = use each level's own value.
## The tuning knob for cup length — three 3-lap circuits is a much shorter
## sitting than a five-tour cup.
@export var lap_override := 0

## Optional points override, highest placing first. Leave empty to use the
## default table for the field size (see series_state.gd).
@export var points_table: Array[int] = []
