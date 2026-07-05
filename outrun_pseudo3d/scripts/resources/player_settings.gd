class_name PlayerSettings
extends Resource
## All player-car physics tunables. Defaults mirror the shipped feel;
## edit resources/player_settings.tres in the inspector to tune.

@export_group("Speed")
@export var max_speed := 12000.0        # world units per second
@export var accel := 2400.0             # max_speed / 5
@export var braking := -12000.0
@export var decel := -2400.0            # engine braking when coasting
@export var off_road_decel := -6000.0
@export var off_road_limit := 3000.0    # off-road only slows you above this

@export_group("Handling")
@export var centrifugal := 0.3          # how hard curves push you outward

@export_group("Air")
@export var gravity := 22000.0          # world units / s^2
@export var air_threshold := 10.0       # above this height you're airborne
@export var max_launch_vy := 5000.0     # caps crest launches (keeps air readable)
@export var air_control := 0.2          # steering authority in the air

@export_group("Slipstream")
@export var slip_segments := 7          # tow reach, in track segments
@export var slip_lateral := 0.35        # max lateral offset to count as tucked in
@export var slip_min_speed := 0.5       # no tow below this fraction of max speed
@export var slip_build_time := 0.6      # seconds to reach full effect
@export var slip_top_bonus := 0.05      # +top speed at full slipstream
@export var slip_accel_bonus := 0.8     # +acceleration at full slipstream

@export_group("Boost")
@export var boost_capacity := 3.0       # seconds of boost carried (full at the grid)
@export var boost_top_bonus := 0.18     # +top speed while boosting
@export var boost_accel_bonus := 1.0    # +acceleration while boosting
