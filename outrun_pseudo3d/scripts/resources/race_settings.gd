class_name RaceSettings
extends Resource
## Pack-level AI tuning and the rival roster. Edit resources/race_settings.tres.

## Grid order: last entry starts on pole (nearest the start line... farthest
## ahead). Levels' rival_count takes the first N of this list.
@export var roster: Array[Resource] = []

@export_group("Grid")
@export var grid_gap := 500.0           # world units between grid slots

@export_group("Cornering")
@export var curve_slowdown := 0.034     # cruise loss per unit of curve severity
@export var curve_slowdown_cap := 0.25
@export var apex_bias := 0.08           # how far rivals cut toward a curve's inside

@export_group("Steering")
@export var lateral_speed := 1.0        # lane-keeping drift, road-halves/s at full speed
@export var lookahead := 35             # segments scanned ahead for avoidance
@export var dodge_commit := 0.5         # seconds a dodge direction is latched
@export var dodge_rate := 1.3           # committed dodge drift, road-halves/s at speed

@export_group("Speed")
@export var accel := 3000.0             # world units / s^2
@export var rubber_range := 12000.0     # gap beyond which rubber-banding kicks in
@export var rubber_ahead := 0.99        # leaders barely wait
@export var rubber_behind := 1.05       # stragglers push (capped below player max)

@export_group("Collisions")
@export var bonk_speed_cut := 0.75      # hitting traffic keeps this much speed
@export var bonk_cooldown := 1.5
@export var ram_distance := 700.0       # tuck-behind range for matching player speed

@export_group("Presentation")
@export var flash_range := 2500.0       # overtakes flash only when nearby

@export_group("Boost AI")
## Rivals only boost when |curve| is at or below this severity.
@export var boost_curve_threshold := 1.0
## Behind the player and within this range counts as an attack opportunity.
@export var boost_attack_range := 6000.0
## Past this fraction of the track everyone sprints for the line.
@export var final_sprint_fraction := 0.85

@export_group("Pickups")
@export var pickup_boost_amount := 1.5  # seconds of boost per canister
@export var pickup_respawn := 25.0      # seconds until a taken canister returns
## Random canisters scattered when a level defines none of its own.
@export var auto_pickup_count := 4
