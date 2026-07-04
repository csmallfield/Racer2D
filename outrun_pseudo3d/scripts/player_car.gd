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
const GRAVITY := 22000.0                   # vertical fall, world units/s^2
const AIR_THRESHOLD := 10.0                # above this height you're airborne
const MAX_LAUNCH_VY := 5000.0              # caps crest launches (keeps air readable)
const FALL_MULT := 1.7                     # falling gravity multiplier — catches
                                           # plunging roads fast, kills float
const AIR_CONTROL := 0.2                   # steering authority in the air

# Slipstream: tuck in close behind another car at speed and drag drops —
# extra acceleration and a top-speed overshoot. This is the player's
# deliberate passing technique (rivals don't get it).
const SLIP_SEGMENTS := 7          # how far ahead the tow reaches (x200 units)
const SLIP_LATERAL := 0.35        # max lateral offset to count as "tucked in"
const SLIP_MIN_SPEED := 0.5       # no tow below half speed
const SLIP_BUILD_TIME := 0.6      # seconds to reach full effect
const SLIP_TOP_BONUS := 0.05      # +5% top speed at full slipstream
const SLIP_ACCEL_BONUS := 0.8     # +80% acceleration at full slipstream

var position_z := 0.0     # distance along the track (world units)
var x := 0.0              # lateral position, -1..1 = on road
var speed := 0.0
var steer_dir := 0.0      # -1..1 analog steer amount, used for car tilt
var bounce := 0.0         # vertical shake in screen px when off-road
var slip := 0.0           # slipstream strength 0..1 (read by main for audio)
var y_pos := 0.0          # absolute altitude (world units)
var vy := 0.0             # vertical velocity
var air := 0.0            # height above the road; > 0 while airborne


## Advances the player one frame. Returns true if the finish line was crossed.
func update(dt: float, main: Node) -> bool:
	var seg: Dictionary = main.find_segment(position_z)
	var speed_percent := speed / MAX_SPEED
	# At full speed you can cross the whole road in ~1 second.
	var dx := dt * 2.0 * speed_percent

	# Wheels off the ground: barely any steering, no centrifugal grip.
	var control := 1.0 if air <= AIR_THRESHOLD else AIR_CONTROL

	# Analog on gamepads, -1/0/+1 on keyboard.
	var steer := Input.get_axis("steer_left", "steer_right")
	x += dx * steer * control
	steer_dir = steer

	# Centrifugal force: curves push the car toward the outside.
	x -= dx * speed_percent * seg.curve * CENTRIFUGAL * control

	# Slipstream detection: another car ahead within the tow range and
	# roughly in our lane. Strength eases in/out over SLIP_BUILD_TIME.
	var in_stream := false
	if speed_percent > SLIP_MIN_SPEED and air <= AIR_THRESHOLD:
		var seg_count: int = main.track.segments.size()
		for i in range(1, SLIP_SEGMENTS + 1):
			var ahead: Dictionary = main.track.segments[(int(seg.index) + i) % seg_count]
			for car in ahead.cars:
				if absf(float(car.offset) - x) < SLIP_LATERAL:
					in_stream = true
					break
			if in_stream:
				break
	slip = move_toward(slip, 1.0 if in_stream else 0.0, dt / SLIP_BUILD_TIME)
	var slip_max := MAX_SPEED * (1.0 + SLIP_TOP_BONUS * slip)

	# Analog triggers scale acceleration/braking; keys give full strength.
	# Airborne: wheels can't push or brake — light air drag only.
	var throttle := Input.get_action_strength("accelerate")
	var brake_in := Input.get_action_strength("brake")
	if air > AIR_THRESHOLD:
		speed += DECEL * 0.15 * dt
	elif throttle > 0.0:
		speed += ACCEL * (1.0 + SLIP_ACCEL_BONUS * slip) * dt * throttle
	elif brake_in > 0.0:
		speed += BRAKING * dt * brake_in
	else:
		speed += DECEL * dt

	# Off-road: rough ground slows you down hard and shakes the car.
	# (Not while airborne — you can jump the grass.)
	if (x < -1.0 or x > 1.0) and air <= AIR_THRESHOLD:
		if speed > OFF_ROAD_LIMIT:
			speed += OFF_ROAD_DECEL * dt
		bounce = sin(Time.get_ticks_msec() * 0.06) * 5.0 * speed_percent
	else:
		bounce = 0.0

	x = clampf(x, -2.5, 2.5)
	speed = maxf(speed, 0.0)
	if speed > slip_max:
		# Overspeed from a fading slipstream bleeds off instead of snapping.
		speed = move_toward(speed, slip_max, MAX_SPEED * 0.6 * dt)

	var track_len: float = main.track.track_length()
	var g_prev: float = main.ground_y(position_z)
	var new_z := position_z + speed * dt
	var crossed_finish := new_z >= track_len
	position_z = fposmod(new_z, track_len)

	# Vertical: ballistic with terrain contact. Grounded motion sets vy from
	# slope x speed, so a crest taken at pace launches the car naturally.
	var g_new: float = main.ground_y(position_z)
	vy -= GRAVITY * (FALL_MULT if vy < 0.0 else 1.0) * dt
	y_pos += vy * dt
	if y_pos <= g_new:
		y_pos = g_new
		vy = minf(maxf(vy, (g_new - g_prev) / maxf(dt, 0.0001)), MAX_LAUNCH_VY)
	air = y_pos - g_new

	return crossed_finish


func speed_kmh() -> int:
	return int(speed / 40.0)   # cosmetic conversion: MAX_SPEED reads as 300 km/h
