class_name PlayerCar
extends RefCounted
## Player state and arcade physics (speed, steering, centrifugal drift,
## off-road slowdown). Position along the track is in world units; lateral
## position x is normalized so that -1..1 spans the road surface.

const MAX_SPEED := 12000.0                 # world units per second
const ACCEL := MAX_SPEED / 5.0
const BRAKING := -MAX_SPEED
const DECEL := -MAX_SPEED / 5.0
const OFF_ROAD_DECEL := -MAX_SPEED / 2.0
const OFF_ROAD_LIMIT := MAX_SPEED / 4.0
const CENTRIFUGAL := 0.3                   # how hard curves push you outward

var position_z := 0.0     # distance along the track (world units)
var x := 0.0              # lateral position, -1..1 = on road
var speed := 0.0
var steer_dir := 0.0      # -1..1 analog steer amount, used for car tilt
var bounce := 0.0         # vertical shake in screen px when off-road


## Advances the player one frame. Returns true if the finish line was crossed.
func update(dt: float, main: Node) -> bool:
	var seg: Dictionary = main.find_segment(position_z)
	var speed_percent := speed / MAX_SPEED
	# At full speed you can cross the whole road in ~1 second.
	var dx := dt * 2.0 * speed_percent

	# Analog on gamepads, -1/0/+1 on keyboard.
	var steer := Input.get_axis("steer_left", "steer_right")
	x += dx * steer
	steer_dir = steer

	# Centrifugal force: curves push the car toward the outside.
	x -= dx * speed_percent * seg.curve * CENTRIFUGAL

	# Analog triggers scale acceleration/braking; keys give full strength.
	var throttle := Input.get_action_strength("accelerate")
	var brake_in := Input.get_action_strength("brake")
	if throttle > 0.0:
		speed += ACCEL * dt * throttle
	elif brake_in > 0.0:
		speed += BRAKING * dt * brake_in
	else:
		speed += DECEL * dt

	# Off-road: rough ground slows you down hard and shakes the car.
	if x < -1.0 or x > 1.0:
		if speed > OFF_ROAD_LIMIT:
			speed += OFF_ROAD_DECEL * dt
		bounce = sin(Time.get_ticks_msec() * 0.06) * 5.0 * speed_percent
	else:
		bounce = 0.0

	x = clampf(x, -2.5, 2.5)
	speed = clampf(speed, 0.0, MAX_SPEED)

	var track_len: float = main.track.track_length()
	var new_z := position_z + speed * dt
	var crossed_finish := new_z >= track_len
	position_z = fposmod(new_z, track_len)
	return crossed_finish


func speed_kmh() -> int:
	return int(speed / 40.0)   # cosmetic conversion: MAX_SPEED reads as 300 km/h
