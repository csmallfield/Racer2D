# OutRun Pseudo-3D — First Pass

An OutRun-style pseudo-3D arcade racer prototype for **Godot 4.7**. All art is
runtime-generated placeholder graphics designed to be swapped out later.
Levels are authored entirely in standalone scripts — no track data is
hard-coded into the engine.

Open the project folder in Godot and press Play. `scenes/main.tscn` is the
main scene.

## Controls

| Keyboard | Gamepad | Action |
|---|---|---|
| Up / W | A / right trigger (analog) | Accelerate |
| Down / S | X / left trigger (analog) | Brake |
| Left / A, Right / D | Left stick (analog) / d-pad | Steer |
| R | Back/Select | Restart current stage |
| N | Start | Skip to next stage (debug) |

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

## Audio

The game is fully wired for sound but ships with **no audio files** — every
sound is a silent no-op until a matching file appears in `assets/audio/`.
The complete list of expected filenames with descriptions lives in
**`assets/audio/SOUNDS.md`**. Drop files in one at a time; nothing errors
when files are missing.

What's wired up: engine loop pitch-shifted with speed (0.7×–1.9×), off-road
rumble loop, skid on hard high-speed steering, crash (scenery) and bump
(traffic) impacts, per-second countdown beeps in the final 10 seconds,
stage-clear and game-over stings, and per-level looping music (levels name
their track via `music = "music_coastal"`; see `TrackLevel`).

Mix levels are constants at the top of `scripts/audio_manager.gd` (an
autoload registered as `Audio`).

## Tuning via resources

Every gameplay tunable lives in editable `.tres` resources under
`resources/` (open them in the Godot inspector, or as text):

- `player_settings.tres` — car physics: speed, handling, air, slipstream.
- `camera_settings.tres` — view: height, FOV, draw distance, fog, and the
  camera-aim strength/delay.
- `race_settings.tres` — pack AI (cornering, dodging, rubber-banding,
  collisions) plus the **roster**: an ordered list of rival profiles.
  Roster order is grid order — the last entry starts on pole.
- `resources/rivals/*.tres` — one profile per opponent: display name,
  livery color (drives the placeholder car and the progress-bar dot),
  cruise speed as a fraction of yours, preferred racing lane, and an
  optional `car_texture` to point at real sprite art.

Missing or broken resource files fall back to identical script defaults,
so the game always boots. Adding a tenth rival = new profile + append to
the roster; levels' `rival_count` takes the first N.

## Menu, modes, and best times

The game boots to a title menu (over an idle stage backdrop): **RACE**
(you versus the rival pack), **TIME TRIAL** (no rivals — you, the traffic,
and the clock), **BEST TIMES**, and QUIT. Menus navigate with arrows /
d-pad and confirm with Enter / Space / gamepad A; Esc backs out, including
from a running race.

Both modes go through a stage picker. Finishing any stage records your time
to a persistent per-stage, per-mode top-10 (saved as JSON in `user://`),
browsable from BEST TIMES (steer to flip through stages). Race finishes show
the race results board (with "BEST #n" in the title when you set one); time
trial finishes show the stage's all-time top 10 with your run highlighted.
In time trial the checkpoint flash has no delta — there's nobody to be
behind.

## Driving techniques and race HUD

**Slipstream**: tuck in close behind any car at speed (within its wake, up
to ~7 segments back) and after ~half a second the tow gives +80%
acceleration and lets you overshoot top speed by 5% — then pull out and
sling past. Stay tucked too long and you'll rear-end them. This is your
deliberate passing tool against rivals who match your top speed; rivals
don't get it.

**Boost**: every racer carries limited boost fuel (Shift / gamepad B; the
orange gauge bottom-left). It raises top speed and acceleration but grants
zero extra steering — and centrifugal force scales with your real speed, so
corners punish it twice. Burn it on straights and passes. Glowing canisters
on the track refill it, first racer through takes them (they respawn after
a while); rivals contest them and burn their own fuel per personality —
`boost_aggression` in each profile. Camera kicks on ignition.

**Progress bar**: the strip along the bottom maps the whole track —
checkpoint ticks, gold finish tick at the end, rival dots in their livery
colors, and your larger gold marker. In time trial it's just you against
the ticks.

**Shadows and air**: every car casts a soft 15%-opacity shadow on the road.
Crest a hill fast enough and the car launches — grounded motion carries the
terrain's vertical speed, so steeper + faster = bigger air (capped so jumps
stay readable). Airborne you have almost no steering, no throttle, no
centrifugal grip — and you sail clean over traffic, scenery, and grass. The
shadow stays on the road and shrinks with height; the camera absorbs most
of the jump so the road visibly drops away beneath you. Stage 6 is built
around this.

**Pause**: P or gamepad Start freezes everything mid-countdown or mid-race
(Start no longer skips stages; N remains the debug skip).

## Race structure

Races start with a 3…2…1…GO countdown — everyone gridded and held, you
last. The overall race clock (counting up, top center) starts on GO.

Checkpoint stripes divide each stage into equal sections (`checkpoint_count`
per level, default 2); the countdown timer is per-section, and crossing a
checkpoint adds the section allotment on top of whatever you had left,
OutRun style. Each crossing flashes your racing-standard
time delta against the fastest rival through that checkpoint — "+" behind
(red), "-" ahead (green), with tenths. If you're first there, it shows your
cushion over the best chaser ("-0:02.3 (LEADER)", green).

Finishing brings up the results board: finished racers with real times,
still-racing rivals below in live running order (dimmed, times filling in
as they cross — the race clock keeps running behind the board). Your row is
highlighted. Press accelerate to continue to the next stage.

## Traffic AI

NPC cars scan up to 20 segments ahead and swerve around slower cars and the
player (steering harder the closer the obstacle), then drift back toward the
road if they've wandered wide — a port of codeincomplete's `updateCarOffset`.
Cars outside the drawn window skip AI entirely.

## AI opponents

Nine named rivals (VIPER, NATASHA, BIFF, ...) race the same start-to-finish
run — Road Rash's pack model, minus the combat. You grid up last and race
through them; the HUD shows your live position bottom-right ("3rd / 10"),
nearby overtakes flash on screen, and the stage-clear message reports where
you finished.

What makes them beatable: each rival has a personality cruise speed (the
roster is a ladder from easy prey to genuinely fast), and they all brake for
curves proportionally to severity — holding your nerve through corners is
where you gain. Mild rubber-banding keeps the pack alive without feeling
rigged. They swerve around traffic, each other, and you; a failed dodge into
slow traffic costs them half their speed.

Rivals share the traffic infrastructure (same per-segment car lists), so
rendering, avoidance, and collisions need no special cases. Tuning constants
live at the top of `scripts/rivals.gd`; per-level pack size via
`rival_count` in the level script.

## Known limitations / obvious next steps

- Rivals never crash out entirely or vary behavior per lap — no rivalry
  memory, no aggression personalities beyond speed. Easy extensions in
  `rivals.gd` if the racing needs more texture. — OutRun's forks/wide freeway use a second overlapped
  road, which this architecture supports but doesn't implement.
- If you later want thousands of draw calls (dense scenery), move sprite
  drawing from `_draw()` to a `MultiMesh` or `RenderingServer` batching pass.
