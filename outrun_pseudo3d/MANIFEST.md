# Delivery Manifest — outrun_pseudo3d v31

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
| scripts/menu.gd | ~110 | MenuLayer: title menu, stage picker, best-times board (visual only) |
| scripts/records.gd | ~55 | Records: persistent top-10 times per stage per mode (JSON in user://) |
| scripts/game_config.gd | ~30 | GameConfig autoload: loads the .tres settings with default fallbacks |
| scripts/resources/*.gd | ~120 | Resource classes: PlayerSettings, CameraSettings, RaceSettings, RivalProfile |
| resources/*.tres + rivals/*.tres | — | The editable tuning data: 3 settings files + 9 rival profiles |
| scripts/levels/level_04_city.gd | ~60 | Stage 4: flat street grid, hard corners, heavy traffic, skyline |
| scripts/levels/level_05_jungle.gd | ~60 | Stage 5: winding hilly dirt road, dense canopy, green haze |
| scripts/levels/level_06_mountains.gd | ~60 | Stage 6: 2x-extreme hills, ballistic crests, alpine palette |
| scripts/levels/level_07_halloween.gd | ~55 | Stage 7: creepy fog, dead trees, pumpkins, twisty |
| scripts/levels/level_08_candy.gd | ~55 | Stage 8: candy land, lollipop forest, bouncy hills |
| scripts/levels/level_09..11_circuit_*.gd | ~60 ea | Circuits: Seaside Ring, Neon Loop, Sugar Ring (3 laps each) |
| scripts/levels/level_01_coastal.gd | 56 | Stage 1 (reference example): rolling hills, S-curves, palms, daytime palette |
| scripts/levels/level_02_desert.gd | 53 | Stage 2: harder curves, bigger elevation, more traffic, dusk palette |
| scripts/levels/level_03_night.gd | ~55 | Stage 3: night palette, long twin-road fork section, hard corner |
| README.md | — | Controls, rendering explanation, level authoring guide, art replacement guide, tuning table |

v31 hardens the AI substantially: the hunter is REPLACED by pack momentum (a capped per-nearby-rival speed bonus — the fake extension of drafting; trains and splinter groups bridge to lone leaders); cruise ladder raised past the player (0.94-1.03, VIPER faster than your flat-out); per-race form variance (+/-2.5% rolled at the grid, finish order varies); rubber clamp 0.99->1.0, rubber_behind 1.08, range 9000; sharper cornering (slowdown 0.028, cap 0.2, lookahead 40, dodge_rate 1.5); boost capacity 4s + aggression ladder 0.4-1.0, attack range 10000, sprint from 80%.

Previously: v30 is the AI challenge package: rivals draft (player slipstream physics off traffic/each other/player mirrors, applied after the rubber clamp — the honest gap-closer), smarter boost AI (corner-exit bursts at 2x take-rate, gap-closing when far behind), pickup seeking (hungry rivals steer for canisters ahead), the hunter (lead too long and the fastest surviving rival gets +2.5% and max aggression, announced by name, until they retake the lead), and rhythmic traffic (packs, loners, 3-abreast rolling roadblocks; counts +50%). New RaceSettings groups: Hunter, Traffic Placement.

Previously: v29 fixes the v26 track scaling, which stretched individual pieces (10-second grinding corners where the AI's flat curve-speed advantage shows). Piece presets revert to v25 sizes; every level (tours, circuits, halloween, candy) is re-authored to the same ~4x total length via MORE v25-scale sections — short punchy corners and hills, straights as braking zones before hard corners, the occasional long climb for scale (mountains keeps its 2x-preset ballistic crests). Boost economy rebalanced: pickup density cut ~4x (one per ~450 segments), respawn 15->25s, so the leader can't stay permanently fueled.

Previously: v27 adds CIRCUIT mode: the original mode is renamed TOUR; circuits are short, turn-biased looping tracks raced over laps (laps property on TrackLevel; time_limit = per-lap), with lap counting, lap-line timer refills, lap-aware checkpoint splits, lapping of opponents via total-progress ranking, per-lap progress-bar positions, LAP x/y HUD, circuit best-times column, and three new circuits reusing existing themes: Seaside Ring (left-biased), Neon Loop (right-biased), Sugar Ring (left-biased, bouncy).

Previously: v26: retro filter defaults move to resources/retro_filter.tres (incl. resource-only flicker + scanline density); all tracks scaled 4x with slopes exactly preserved (LENGTH and HILL presets x4, mountain literals x4, downhill span x4, checkpoints 2->11 keeping identical section rhythm, time limits and traffic x4, density-based pickup scatter); two new stages: Hollow Ridge (Halloween — blood moon, dead trees, jack-o'-lanterns, dense fog, twisty) and Sugar Rush (candy land — lollipop forest, candy-stripe rumbles, bouncy hills).

Previously: v25 adds a settings menu (fullscreen, music/SFX volume via a dedicated Music bus, persisted to user://settings.json) and a custom full-resolution retro/VHS screen shader — luminance-preserving scanlines, chromatic fringe, animated grain + flicker, vignette, optional barrel distortion — applied over the whole window via a Settings autoload, every look parameter tunable live from the menu.

Previously: v24 adds 2/4-player local split screen: SubViewport per player (uniform even solo) each with its own renderer, camera, and scale-aware HUD; per-player input actions (P1 WASD+Shift, P2 Arrows+Ctrl, P3/P4 pads); players mirrored as world car entities so player-vs-player collisions, mutual slipstream, and AI avoidance reuse the traffic code paths; player liveries + progress-bar markers; MP drops the countdown timer (pure race, 20s finish grace, merged results boards); per-view draw distance scaling; records solo-only.

Previously: v23 adds the boost system: limited per-racer boost fuel (Shift / gamepad B) with +18% top speed and +100% accel but capped steering authority; camera shake + sound on ignition; contested boost canisters (level-authored via add_boost_pickup or auto-scattered), respawning, collectible by rivals too; rival boost AI (straights + attacking/sprinting, per-profile aggression ladder 0.25-0.9); HUD fuel gauge. All tunables in the .tres resources.

Previously: v22 is the resource refactor: all tunables move to editable .tres resources (player_settings, camera_settings, race_settings + 9 per-rival profiles with name/color/cruise/lane/optional car art) loaded via a GameConfig autoload with script-default fallbacks. Rivals are roster-driven (VIPER now genuinely on pole at 1.0 cruise, matching the docs). Base resolution moves to 1920x1080 with the HUD/menu re-laid-out to match (renderer was already resolution-independent).

Previously: v21 fixes the post-race camera dive: the coast path (stage clear / game over) advanced the car without running its vertical physics, freezing y_pos while the terrain climbed — the aiming camera chased the stale altitude underground. The vertical step is now extracted (PlayerCar.step_vertical) and runs in both the race and coast paths.

Previously: v20 fixes camera aim smoothing: v19 filtered the camera's absolute altitude, which made it trail the terrain on sustained slopes (underground on climbs, high on descents). Terrain-following is now instantaneous; only the aim offset toward the car is smoothed.

Previously: v19 adds camera aim: the camera altitude blends between terrain-following and locking onto the car (CAM_AIM_STRENGTH, default 0.5) with an exponential chase lag (CAM_AIM_DELAY, default 0.2s) — crest dips and jumps still read as motion, then the camera eases after the car. Replaces the fixed 65% air absorption.

Previously: v18 fixes the crest float for real: the player sprite was pinned to a fixed screen anchor and could never drop relative to the camera. The camera altitude now follows the ground under its own z, and the car is projected at its true world altitude — over a sharp crest it visibly drops low in the frame (briefly toward the bottom edge) until the camera crests, exactly matching the road. Flat framing and airborne rise are numerically identical to before.

Previously: v16 fixes the remaining crest float: on climbs the nearest drawn road slice projects up-screen and the near-plane cull left an empty band at the bottom of the frame — the car sat pinned in that band, visibly above the road. A road 'apron' now extrudes the nearest segment's near edge down to the screen bottom, so the road always reaches the car.

Previously: v15 fixes the air-landing bug properly: player vertical physics now samples the ground under the drawn car (position_z + player_z(), ~840 units ahead of the camera) instead of under the camera — landings register exactly when the visible car meets the visible road. The v14 asymmetric-gravity change is reverted (wrong diagnosis; it degraded jump feel without touching the cause).

Previously: v14 fixes: floaty landings over plunging descents (asymmetric gravity — falling pulls 1.7x harder, so the car catches a dropping road quickly while crest pop is unchanged); background parallax direction (was sweeping with the curve instead of against it); and levels without a dedicated/present music track now pick a random existing one at race start.

Previously: v13 adds car shadows (15% opacity, all cars incl. player), ballistic air over hill crests (terrain-slope launch model shared by player/rivals/traffic, capped launch velocity, camera absorbs 65% of player air, airborne = reduced control + collision flyover), landing sound, and Stage 6 Rocky Mountains with 2x hill presets built around the jumps.

Previously: v12 adds the arcade-completeness pass: track progress bar (checkpoint ticks, rival livery dots, player marker), pause (P / gamepad Start, new input action; Start removed from next_level), and player slipstream (+80% accel, +5% top-speed overshoot when tucked behind a car — the passing technique vs speed-matched rivals), with a new optional 'slipstream' sound.

Previously: v11 adds: title menu (RACE / TIME TRIAL / BEST TIMES / QUIT) over an idle backdrop with menu music; stage picker; time-trial mode (no rivals, no deltas); persistent per-stage per-mode top-10 best times (user://best_times.json) with a browsable board; two new stages (Neon City, Jungle Run) with building/streetlight sprites; Esc-to-menu from any race state.

Previously: v10 switches deltas to racing convention (+ behind in red, - ahead in green), and raises difficulty again: cruise ladder 0.86-1.0, better rival cornering, 35-segment rival lookahead (fewer traffic bonks), softer bonk penalty, and near-zero leader rubber-banding.

Previously: v9 fixes checkpoint deltas (sign convention: + ahead / - behind, tenths precision, projected lead when first through), makes the leaderboard live (no projections; racers fill in as they finish), and raises difficulty (faster cruise ladder 0.84-0.99, better rival cornering, weaker rubber-banding).

Previously: v7 fixes the finish-rank bug (rank now derives from finish times, not wrapped progress) and rival dodge jitter (committed dodges with hysteresis), and adds: 3-2-1-GO countdown, checkpoint sections with timer extension and leader time deltas, an overall race clock, and an end-of-race leaderboard.

Previously: v6 removes the fork system entirely and adds Road Rash-style AI opponents: a 9-rival named roster with personality speeds, curve braking, apex hugging, rubber-banding, and traffic avoidance, plus live position ranking in the HUD ("3rd / 10"), nearby-overtake flashes, and finish position on stage clear.

New levels: drop a .gd extending TrackLevel into scripts/levels/ — auto-discovered, played in filename order.
