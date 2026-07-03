# OutRun Pseudo-3D — First Pass

An OutRun-style pseudo-3D arcade racer prototype for **Godot 4.7**. All art is
runtime-generated placeholder graphics designed to be swapped out later.
Levels are authored entirely in standalone scripts — no track data is
hard-coded into the engine.

Open the project folder in Godot and press Play. `scenes/main.tscn` is the
main scene.

## Controls

| Input | Action |
|---|---|
| Up / W | Accelerate |
| Down / S | Brake |
| Left / A, Right / D | Steer |
| R | Restart current stage |
| N | Skip to next stage (debug) |

Reach the finish line (dark stripe) before the timer runs out. Hitting
scenery or slower traffic kills your speed. Driving on the grass slows you
down hard.

## How the rendering works

This uses the **3D-projected segments** technique (the "Road Rash / Test
Drive II" method from Lou's Pseudo 3D Page, as popularized by
codeincomplete's JavaScript racer):

- The track is a list of ~200-unit-long horizontal segments, each with a
  `curve` value (x-acceleration per segment) and real world-space `y`
  altitudes for hills.
- Each frame, segments ahead of the camera are perspective-projected
  (`screen = world * depth / z`). Curves are faked by accumulating a lateral
  offset per segment (`x += dx; dx += curve`) — this produces the classic
  OutRun road-swing where the camera appears to look around bends.
- The `dx = -(base.curve * base_percent)` correction keeps the curve shape
  stable as segments scroll through the camera (codeincomplete's fix for
  segment-boundary jitter).
- Road polygons draw front-to-back with a rising clip line (`maxy`), so
  hill crests correctly occlude the road behind them. Sprites then draw
  back-to-front (painter's algorithm), bottom-clipped against each segment's
  stored clip line so trees sink behind crests.
- Fog is a per-segment color lerp toward the theme's fog color.

Everything renders immediate-mode via `CanvasItem._draw()` in
`road_renderer.gd` — ~300 segments × a few polygons per frame, which GDScript
handles comfortably at 60 fps at this scale.

## Project layout

```
project.godot
scenes/main.tscn                  # boots main.gd
scripts/
  main.gd                         # orchestrator: levels, traffic, collisions, states
  road_renderer.gd                # pseudo-3D projection + all drawing
  player_car.gd                   # arcade physics + input
  track_builder.gd                # level authoring API (segments, curves, hills, scenery)
  track_level.gd                  # base class every level extends
  sprite_catalog.gd               # placeholder art generator / sprite registry
  hud.gd                          # speed, timer, stage, messages
  levels/
    level_01_coastal.gd           # example stage (reference for the API)
    level_02_desert.gd            # second stage, different theme + layout
```

## Authoring a new level

1. Create `scripts/levels/level_03_whatever.gd`. Levels are **auto-discovered
   at startup** and played in filename order — no registration needed.
2. Extend `TrackLevel`, set metadata in `_init()`, describe the road in
   `build()`:

```gdscript
extends TrackLevel

func _init() -> void:
    level_name = "STAGE 3 — ALPINE"
    time_limit = 90.0
    traffic_count = 14
    theme.sky_top = Color(0.6, 0.7, 0.9)   # override any theme colors

func build(b: TrackBuilder) -> void:
    var R := TrackBuilder.ROAD
    b.add_straight(R.LENGTH.SHORT)
    b.add_curve(R.LENGTH.MEDIUM, R.CURVE.HARD, R.HILL.LOW)  # length, curve, hill
    b.add_s_curves()
    b.add_hill(R.LENGTH.LONG, R.HILL.HIGH)
    b.add_downhill_to_end()      # always finish with this: returns altitude to 0
    b.add_scenery("tree", 20, b.segments.size(), 8, -1.0)   # left side, every 8 segs
    b.add_sprite(50, "sign", 1.3)                           # single placed sprite
```

Notes:
- `add_road(enter, hold, leave, curve, hill)` is the fundamental piece; the
  convenience methods wrap it. Positive curve = right, negative = left.
- Hill values are altitude change in segment-length units.
- Sprite offsets are in half-road-widths: ±1.0 is the road edge, so scenery
  belongs at |offset| ≥ ~1.3.
- End every track with `add_downhill_to_end()` so the loop point (finish →
  start) doesn't pop in altitude.

## Replacing the placeholder art

All sprites live in `sprite_catalog.gd`. Each entry is:

```gdscript
_cache["tree"] = {
    "texture": <Texture2D>,   # swap this for load("res://assets/tree.png")
    "world_w": 1300.0,        # size in world units (road is 4000 wide)
    "world_h": 2300.0,
    "collidable": true,
}
```

Drop PNGs into an `assets/` folder, replace the `_make_*()` call with a
`load()`, adjust `world_w/world_h` to taste. Nothing else needs to change —
the renderer and collision system only read these defs. Sprites are drawn
bottom-anchored and stretched to `world_w × world_h`, so texture aspect
ratio doesn't need to match.

Road/grass/sky colors are per-level in each level's `theme` dictionary.

## Tuning cheat sheet

| What | Where |
|---|---|
| Top speed, accel, off-road drag, centrifugal force | constants in `player_car.gd` |
| Draw distance, fog density, FOV, camera height, road width, lane count | constants in `road_renderer.gd` |
| Segment length, stripe width, curve/hill presets | constants in `track_builder.gd` |
| Timer, traffic density, palette | per level in `scripts/levels/*.gd` |

## Known limitations / obvious next steps

- No audio yet (engine pitch tied to `player.speed` is the natural first add).
- Traffic drives in fixed lanes with no avoidance AI.
- Keyboard only; add gamepad events to the actions in Project Settings → Input Map.
- Single road ribbon — OutRun's forks/wide freeway use a second overlapped
  road, which this architecture supports but doesn't implement.
- If you later want thousands of draw calls (dense scenery), move sprite
  drawing from `_draw()` to a `MultiMesh` or `RenderingServer` batching pass.
