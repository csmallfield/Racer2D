class_name DifficultyProfile
extends Resource
## One difficulty level, expressed as multipliers over the base tuning in
## player_settings.tres / race_settings.tres. Edit resources/difficulties/*.tres.
##
## Design rules this file encodes:
##  - Script defaults ARE Normal. A missing/broken .tres therefore degrades to
##    the game's baseline tuning rather than to something silly.
##  - HARD changes the OPPOSITION ONLY. Every assist field below stays neutral
##    outside Easy, so muscle memory carries across difficulties.
##  - The fairness invariant: a rival's CORNER-LIMITED pace must stay below the
##    player's max speed. Note the top of the roster already cruises slightly
##    ABOVE player max on straights (Viper 1.03, Natasha 1.01) — that is the
##    shipped Normal tuning and it works, because they shed curve_slowdown_cap
##    in bends while a cleanly-driven player does not. Corners are the player's
##    edge; boost and slipstream are the answer on straights. Hard narrows that
##    corner margin — it must never erase it.

@export var display_name := "NORMAL"


@export_group("Field")
## Hard cap on rivals fielded, whatever the level asks for. 0 = no cap.
@export var rival_count_cap := 0
## The roster is a ladder from beatable to fast. Normally we field from the
## beatable end; Hard fields from the fast end instead — the top seeds show
## up. Costs nothing to tune and does more work than most multipliers.
@export var field_top_of_ladder := false


@export_group("Opposition Pace")
## Scales each rival's personality cruise. The roster's fast end already sits
## just above player max on straights, so raising this erodes the corner
## margin fast — see the fairness invariant above.
@export_range(0.5, 1.0) var cruise_scale := 1.0
## Scales how much speed rivals shed in corners — BOTH the per-unit rate and
## the cap, so the knob still bites on sharp bends. Above 1.0 they corner
## worse (Easy), below 1.0 they corner better (Hard). The purest difficulty
## knob: it narrows the player's main edge without touching straight speed.
@export var curve_slowdown_scale := 1.0
## Scales the per-race cruise roll. LOW on Hard is deliberate: less variance
## means the fast cars reliably turn up, which makes the challenge learnable
## instead of luck-driven.
@export var form_variance_scale := 1.0
## Scales pack momentum (rivals in a group carrying each other).
@export var pack_bonus_scale := 1.0
## Scales the catch-up push for stragglers. Left at 1.0 on Hard on purpose —
## this is the knob that reads as cheating when it climbs.
@export var rubber_behind_scale := 1.0


@export_group("Opposition Skill")
## Scales avoidance lookahead. Lower = rivals blunder into traffic and hand
## you positions; higher = they stop gifting them. Scaling AI MISTAKE RATE is
## the fairest-feeling difficulty axis, since your gains still come from
## errors you can watch happen.
@export var lookahead_scale := 1.0
## Scales how hard rivals cut toward the apex (racing line quality).
@export var apex_bias_scale := 1.0
## Scales boost aggression — how promptly a rival takes a good opening.
@export var aggression_scale := 1.0


@export_group("Tour")
## Scales the per-section time limit on tours.
@export var time_limit_scale := 1.0


@export_group("Player Assists")
## EASY ONLY. Everything below stays neutral on Normal and Hard.
##
## Fraction of max speed retained when clipping roadside scenery. The baseline
## 0.06 is close to a dead stop — brutal for a young player.
@export_range(0.0, 1.0) var crash_speed_keep := 0.06
## Scales centrifugal force (how hard curves push the car outward). Lower
## reads as extra grip and never fights player input.
@export var centrifugal_scale := 1.0
## Scales the speed below which off-road costs you nothing.
@export var off_road_limit_scale := 1.0
## Scales off-road deceleration.
@export var off_road_decel_scale := 1.0
## Gentle inward nudge near the road edge, as a fraction of full steering
## authority. 0 disables it. Suppressed whenever the player is actively
## steering outward, so deliberate cuts across the grass still work.
@export_range(0.0, 1.0) var edge_assist := 0.0
