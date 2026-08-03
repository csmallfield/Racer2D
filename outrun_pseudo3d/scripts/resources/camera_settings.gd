class_name CameraSettings
extends Resource
## Camera and view tunables. Edit resources/camera_settings.tres.

@export var height := 1200.0            # camera height above the road (world units)
@export var fov_deg := 100.0
@export var draw_distance := 300        # segments drawn ahead of the camera
@export var fog_density := 5.0
@export var aesthetic_lift := 0.08      # keeps the car framed above the bottom edge

@export_group("Aim")
## 0 = camera rides its own ground (car moves freely in frame);
## 1 = rigidly locked to the car. The delay is the chase lag (seconds,
## exponential smoothing time constant).
@export_range(0.0, 1.0) var aim_strength := 0.75
@export var aim_delay := 0.1

@export_group("Pitch")
## Aim down into descents (and up over climbs) instead of looking dead level.
## 0 disables it entirely and restores the old framing; 1.0 fully cancels the
## slope, which flattens the sense of a hill. Tune by eye on level_01's
## closing descent — that is the worst case in the shipped set.
@export_range(0.0, 1.0) var pitch_strength := 0.7
## Segments of road averaged when measuring the gradient ahead.
@export var pitch_lookahead := 30.0
## Hard ceiling on the pitch, in the same units as the projection term; it
## moves the horizon by half its value. Sized so the steepest gradient in the
## shipped levels (-1.18 on level_01, needing 0.69) clears it comfortably —
## a clamp that binds on a normal hill just reintroduces the original bug at
## a slightly better angle.
@export var pitch_max := 1.0
## Smoothing time constant. Too fast and crests snap; too slow and the pitch
## arrives after the hill has been and gone.
@export var pitch_delay := 0.25

@export_group("Shake")
@export var shake_strength := 9.0       # boost-ignition shake amplitude (px)
@export var shake_time := 0.5          # shake duration (s), decaying
