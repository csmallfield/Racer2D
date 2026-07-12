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

@export_group("Shake")
@export var shake_strength := 9.0       # boost-ignition shake amplitude (px)
@export var shake_time := 0.5          # shake duration (s), decaying
