class_name RetroFilterSettings
extends Resource
## Designer defaults for the retro screen filter (resources/retro_filter.tres).
## These seed the Settings autoload at boot; the in-game settings menu can
## then adjust the user-facing subset (persisted separately in user://).
## Flicker and scanline density are resource-only — tune them here.

@export var enabled_by_default := false
@export_range(0.0, 0.25) var curvature := 0.01       # barrel distortion
@export_range(0.0, 1.0) var scanlines := 0.3
@export_range(100.0, 1080.0) var scanline_density := 540.0
@export_range(0.0, 6.0) var fringe := 1.4            # chromatic offset, px
@export_range(0.0, 1.0) var vignette := 0.25
@export_range(0.0, 0.3) var noise := 0.05
@export_range(0.0, 0.2) var flicker := 0.005          # independent of noise now
