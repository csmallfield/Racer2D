# Delivery Manifest — outrun_pseudo3d v1

Full drop-in Godot 4.7 project. Open the folder in Godot and press Play.
All files verified against source; all .gd files parse-checked with gdtoolkit.

| File | Lines | Purpose |
|---|---|---|
| project.godot | 61 | Project config: 1280×720 canvas_items stretch, gl_compatibility, input map (WASD/arrows, R, N) |
| scenes/main.tscn | 6 | Boot scene — single Node2D running main.gd; everything else is built in code |
| scripts/main.gd | 202 | Orchestrator: auto-discovers levels, builds tracks, traffic, collisions, timer, RUNNING/STAGE_CLEAR/GAME_OVER states |
| scripts/road_renderer.gd | 256 | Pseudo-3D renderer: 3d-projected segments, curve accumulation, hill clipping, painter's-algorithm sprites, fog, parallax background, player draw |
| scripts/player_car.gd | 66 | Arcade physics: accel/brake/coast, steering, centrifugal force, off-road slowdown + shake |
| scripts/track_builder.gd | 160 | Level authoring API: add_road/add_curve/add_hill/add_s_curves/scenery, easing, start/finish marking |
| scripts/track_level.gd | 39 | Base class all levels extend: name, time limit, traffic count, color theme, build() contract |
| scripts/sprite_catalog.gd | 173 | Placeholder art registry — runtime-generated textures; single swap point for real art later |
| scripts/hud.gd | 56 | HUD: speed, countdown timer, stage name, center message, control hints |
| scripts/levels/level_01_coastal.gd | 56 | Stage 1 (reference example): rolling hills, S-curves, palms, daytime palette |
| scripts/levels/level_02_desert.gd | 53 | Stage 2: harder curves, bigger elevation, more traffic, dusk palette |
| README.md | — | Controls, rendering explanation, level authoring guide, art replacement guide, tuning table |

New levels: drop a .gd extending TrackLevel into scripts/levels/ — auto-discovered, played in filename order.
