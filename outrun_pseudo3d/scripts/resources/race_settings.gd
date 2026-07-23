class_name RaceSettings
extends Resource
## Pack-level AI tuning and the rival roster. Edit resources/race_settings.tres.

## Grid order: last entry starts on pole (nearest the start line... farthest
## ahead). Levels' rival_count takes the first N of this list.
@export var roster: Array[Resource] = []

## Tournament cups, in menu order. Each is a CupDefinition; adding one is a
## new .tres here, no code change. Registered explicitly rather than scanned
## from disk, which is unreliable in exported builds.
@export var cups: Array[Resource] = []

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
## Short by design. The whole field passes a given point in well under a
## second, so a long respawn means the leader takes every canister and
## anyone back in the pack never sees one — scarcity that rewards whoever
## is already winning. Short enough that two or three cars can share one.
@export var pickup_respawn := 1.5      # seconds until a taken canister returns
## Boost granted for crossing a checkpoint, to every racer, in every mode.
## Small: canisters stay the real prize. Because it is capped at the tank
## size, a leader running full gains nothing while a straggler running empty
## gains all of it — catch-up flavour with no rubber-banding and no position
## lookup.
@export var checkpoint_boost_amount := 0.5
## Random canisters scattered when a level defines none of its own.
@export var auto_pickup_count := 4

@export_group("Pack Momentum")
## The fake extension of drafting: rivals running in a group carry each
## other — a speed bonus per nearby rival (within pack_radius), capped at
## pack_max_stack cars. One big train or several splinter groups can
## bridge gaps to a lone leader that no single car ever could.
@export var pack_radius := 3000.0
@export var pack_bonus_per_car := 0.015
@export var pack_max_stack := 5
## Per-race cruise variance: each rival rolls form at the grid, so the
## same cars don't finish in the same order every race.
@export var form_variance := 0.025

@export_group("Traffic Placement")
@export var traffic_cluster_min := 2
@export var traffic_cluster_max := 5
@export var roadblock_chance := 0.2    # 3-abreast staggered rolling blocks
@export var single_car_chance := 0.3   # loners; the rest spawns as packs
