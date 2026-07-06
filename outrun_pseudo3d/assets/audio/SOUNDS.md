# Sound files — drop them in this folder

Name files exactly as below (extension can be `.ogg`, `.wav`, or `.mp3` —
`.ogg` recommended, especially for loops). Every sound is optional: missing
files are silent no-ops, so you can add them one at a time. Names ending in
`_loop` or starting with `music_` get looping forced on at load, regardless
of import settings.

## Loops

| File | Description |
|---|---|
| `engine_loop` | Sustained engine tone at steady mid RPM, 1–3 s seamless loop, no fades. The game pitch-shifts it 0.7×–1.9× with speed, so record it clean and monotone — any RPM wobble in the source gets exaggerated. |
| `offroad_loop` | Gravel/grass rumble, ~1 s seamless loop. Plays only while driving on the grass. |
| `music_coastal` | Stage 1 background music, loops for the whole stage. Upbeat synth/FM in the OutRun idiom fits the palette. |
| `music_desert` | Stage 2 background music. Duskier/driving mood. |
| `music_night` | Stage 3 background music. Nocturnal, moodier. |
| `music_city` | Stage 4 background music. Synthwave — it's a neon city at dusk. |
| `music_jungle` | Stage 5 background music. Percussive, humid, driving. |
| `music_menu` | Title menu loop. Sets the tone for the whole game — attract-mode energy. |
| `music_mountain` | Stage 6 background music. Soaring, wide-open — big-sky driving. |
| `music_halloween` | Stage 7 background music. Creepy — minor-key synth, distant howls welcome. |
| `music_candy` | Stage 8 background music. Saccharine, bouncy, relentlessly cheerful. |

New stages reference music by name (`music = "music_whatever"` in the level
script) — add matching files here. Stages whose named track is missing (or
who name none) pick a random existing stage track at each race start.

## One-shots

| File | Description |
|---|---|
| `skid` | Tire screech, 0.5–1 s. Fires when steering hard above ~85% top speed (0.9 s cooldown). |
| `crash` | Heavy impact with roadside scenery (tree/rock/sign). Big, punchy, short. |
| `bump` | Softer thud for rear-ending traffic. Clearly lighter than `crash`. |
| `menu_move` | Tiny tick when moving the menu selection. Very short, unobtrusive. |
| `menu_select` | Confirm blip when choosing a menu item. Slightly bigger than `menu_move`. |
| `countdown_beep` | Short low blip for the 3…2…1 pre-race countdown (plays three times). |
| `countdown_go` | Higher, punchier "GO!" tone as the race starts. |
| `checkpoint` | Bright chime when crossing a checkpoint stripe. |
| `boost` | Nitro ignition — a punchy whoosh/thump when boost fires (0.3 s cooldown). |
| `pickup` | Bright collect blip when grabbing a boost canister. |
| `land` | Suspension thud when the car lands after real air time (mountain crests). |
| `slipstream` | Soft airy whoosh when the slipstream tow reaches full strength (tucked close behind another car at speed). |
| `stage_clear` | Short victory jingle, 1–3 s, plays once at the finish line. |
| `game_over` | Descending sting for time-up. |
| `time_warning` | Single short beep. Fires once per second during the last 10 seconds, so keep it under ~0.4 s and not annoying at 10 repetitions. |

## Notes

- After dropping files in, switch focus to the Godot editor once so it
  imports them; running from the editor picks them up immediately after.
- Levels of all sounds are balanced in code (see constants at the top of
  `scripts/audio_manager.gd`) — deliver everything at roughly uniform
  loudness and tune the dB offsets there.
