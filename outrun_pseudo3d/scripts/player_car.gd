class_name PlayerCar
extends RefCounted
## Player state and arcade physics (speed, steering, centrifugal drift,
## off-road slowdown). Position along the track is in world units; lateral
## position x is normalized so that -1..1 spans the road surface.

## All tunables live in resources/player_settings.tres (via GameConfig).
var s: PlayerSettings = GameConfig.player

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
	var speed_percent := speed / s.max_speed
	# At full speed you can cross the whole road in ~1 second.
	var dx := dt * 2.0 * speed_percent

	# Wheels off the ground: barely any steering, no centrifugal grip.
	var control := 1.0 if air <= s.air_threshold else s.air_control

	# Analog on gamepads, -1/0/+1 on keyboard.
	var steer := Input.get_axis("steer_left", "steer_right")
	x += dx * steer * control
	steer_dir = steer

	# Centrifugal force: curves push the car toward the outside.
	x -= dx * speed_percent * seg.curve * s.centrifugal * control

	# Slipstream detection: another car ahead within the tow range and
	# roughly in our lane. Strength eases in/out over s.slip_build_time.
	var in_stream := false
	if speed_percent > s.slip_min_speed and air <= s.air_threshold:
		var seg_count: int = main.track.segments.size()
		for i in range(1, s.slip_segments + 1):
			var ahead: Dictionary = main.track.segments[(int(seg.index) + i) % seg_count]
			for car in ahead.cars:
				if absf(float(car.offset) - x) < s.slip_lateral:
					in_stream = true
					break
			if in_stream:
				break
	slip = move_toward(slip, 1.0 if in_stream else 0.0, dt / s.slip_build_time)
	var slip_max := s.max_speed * (1.0 + s.slip_top_bonus * slip)

	# Analog triggers scale acceleration/braking; keys give full strength.
	# Airborne: wheels can't push or brake — light air drag only.
	var throttle := Input.get_action_strength("accelerate")
	var brake_in := Input.get_action_strength("brake")
	if air > s.air_threshold:
		speed += s.decel * 0.15 * dt
	elif throttle > 0.0:
		speed += s.accel * (1.0 + s.slip_accel_bonus * slip) * dt * throttle
	elif brake_in > 0.0:
		speed += s.braking * dt * brake_in
	else:
		speed += s.decel * dt

	# Off-road: rough ground slows you down hard and shakes the car.
	# (Not while airborne — you can jump the grass.)
	if (x < -1.0 or x > 1.0) and air <= s.air_threshold:
		if speed > s.off_road_limit:
			speed += s.off_road_decel * dt
		bounce = sin(Time.get_ticks_msec() * 0.06) * 5.0 * speed_percent
	else:
		bounce = 0.0

	x = clampf(x, -2.5, 2.5)
	speed = maxf(speed, 0.0)
	if speed > slip_max:
		# Overspeed from a fading slipstream bleeds off instead of snapping.
		speed = move_toward(speed, slip_max, s.max_speed * 0.6 * dt)

	var track_len: float = main.track.track_length()
	var g_prev := _sprite_ground(main)
	var new_z := position_z + speed * dt
	var crossed_finish := new_z >= track_len
	position_z = fposmod(new_z, track_len)
	step_vertical(dt, main, g_prev)
	return crossed_finish


## Ground under the DRAWN car — it sits player_z() ahead of position_z (the
## camera). Sampling at position_z made the car land on ground ~840 units
## behind what the eye sees.
func _sprite_ground(main: Node) -> float:
	return main.ground_y(position_z + main.renderer.player_z())


## Vertical: ballistic with terrain contact. Grounded motion sets vy from
## slope x speed, so a crest taken at pace launches the car naturally.
## Call with the sprite ground captured BEFORE advancing position_z.
## Runs every frame the car moves — including post-race coasting, or the
## frozen altitude drags the aiming camera into the terrain.
func step_vertical(dt: float, main: Node, g_prev: float) -> void:
	var g_new := _sprite_ground(main)
	vy -= s.gravity * dt
	y_pos += vy * dt
	if y_pos <= g_new:
		y_pos = g_new
		vy = minf(maxf(vy, (g_new - g_prev) / maxf(dt, 0.0001)), s.max_launch_vy)
	air = y_pos - g_new


func speed_kmh() -> int:
	return int(speed / 40.0)   # cosmetic conversion: s.max_speed reads as 300 km/h
