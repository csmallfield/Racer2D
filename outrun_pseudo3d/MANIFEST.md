# Delivery Manifest — outrun_pseudo3d v9

Full drop-in Godot 4.7 project. Open the folder in Godot and press Play.
All files verified against source; all .gd files parse-checked with gdtoolkit.

| File | Lines | Purpose |
|---|---|---|
| project.godot | 61 | Project config: 1280×720 canvas_items stretch, gl_compatibility, input map (WASD/arrows, R, N) |
| scenes/main.tscn | 6 | Boot scene — single Node2D running main.gd; everything else is built in code |
| scripts/main.gd | ~270 | Orchestrator: level discovery, traffic + avoidance AI, collisions, timer, game states, audio triggers |
| scripts/audio_manager.gd | ~170 | "Audio" autoload: one-shot pool, engine/off-road loops, music; missing files are silent no-ops |
| assets/audio/SOUNDS.md | — | Spec of every expected sound file name + description (drop files into this folder) |
| scripts/road_renderer.gd | 256 | Pseudo-3D renderer: 3d-projected segments, curve accumulation, hill clipping, painter's-algorithm sprites, fog, parallax background, player draw |
| scripts/player_car.gd | 66 | Arcade physics: accel/brake/coast, steering, centrifugal force, off-road slowdown + shake |
| scripts/track_builder.gd | 160 | Level authoring API: add_road/add_curve/add_hill/add_s_curves/scenery, easing, start/finish marking |
| scripts/track_level.gd | 39 | Base class all levels extend: name, time limit, traffic count, color theme, build() contract |
| scripts/sprite_catalog.gd | 173 | Placeholder art registry — runtime-generated textures; single swap point for real art later |
| scripts/hud.gd | ~95 | HUD: speed, timer, stage name, center message, race position, overtake flashes |
| scripts/rivals.gd | ~180 | RivalManager: Road Rash-style opponent AI, ranking, overtake events |
| scripts/levels/level_01_coastal.gd | 56 | Stage 1 (reference example): rolling hills, S-curves, palms, daytime palette |
| scripts/levels/level_02_desert.gd | 53 | Stage 2: harder curves, bigger elevation, more traffic, dusk palette |
| scripts/levels/level_03_night.gd | ~55 | Stage 3: night palette, long twin-road fork section, hard corner |
| README.md | — | Controls, rendering explanation, level authoring guide, art replacement guide, tuning table |

v9 fixes checkpoint deltas (sign convention: + ahead / - behind, tenths precision, projected lead when first through), makes the leaderboard live (no projections; racers fill in as they finish), and raises difficulty (faster cruise ladder 0.84-0.99, better rival cornering, weaker rubber-banding).

Previously: v7 fixes the finish-rank bug (rank now derives from finish times, not wrapped progress) and rival dodge jitter (committed dodges with hysteresis), and adds: 3-2-1-GO countdown, checkpoint sections with timer extension and leader time deltas, an overall race clock, and an end-of-race leaderboard.

Previously: v6 removes the fork system entirely and adds Road Rash-style AI opponents: a 9-rival named roster with personality speeds, curve braking, apex hugging, rubber-banding, and traffic avoidance, plus live position ranking in the HUD ("3rd / 10"), nearby-overtake flashes, and finish position on stage clear.

New levels: drop a .gd extending TrackLevel into scripts/levels/ — auto-discovered, played in filename order.
