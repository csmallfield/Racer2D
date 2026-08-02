class_name Contact
## The one place the game decides whether two things are touching.
##
## Before this, every collision site used segment membership as its z test:
## "are we in the same 200-unit bucket". That has two failure modes. At racing
## speed the player covers a whole segment per frame (12000 units/s / 60fps =
## 200 units), and ~1.24 segments per frame while boosting, so segments get
## skipped entirely and contacts are missed — worst exactly when boosting,
## which is when players are hunting canisters. And within a shared bucket,
## two cars register contact whether they are 5 units apart or 195, so the
## contact that does fire often fires at the wrong moment.
##
## The fix is to give things a longitudinal extent and test the SWEPT interval
## each object covers over the frame rather than sampling its end position.
## Everything here is 1D in z, so that is cheap and exact for constant velocity
## across a frame.
##
## Tuning note: the extents below were chosen to reproduce the reach the old
## segment-bucket test already had (a 200-unit bucket), not to change it. The
## rewrite is meant to fix WHEN contact fires, not how hard the game bites.
## CAR_LENGTH is the single number to raise if cars should feel longer.

## Longitudinal extents, world units.
const CAR_LENGTH := 200.0
const SCENERY_LENGTH := 200.0
const PICKUP_LENGTH := 200.0

## Lateral forgiveness per interaction, as a fraction of the drawn widths.
## These were scattered as bare literals across four files; the values are
## preserved exactly, because they are not arbitrary — they encode that the
## harshest outcomes get the most forgiveness. Rear-ending slams your speed
## and shoves you back behind the car, so it is the most generous. Steering
## is the odd one out at >1: the AI deliberately dodges a wider box than it
## collides with, so it starts moving before contact is unavoidable.
const M_REAR := 0.8       # player rear-ends a car
const M_SIDE := 0.9       # side-swipes and AI bonks
const M_SCENERY := 1.0    # roadside props
const M_STEER := 1.2      # avoidance look-ahead

## Lateral half-window for collecting a boost canister. Was 0.4 for the player
## and 0.45 for rivals, which quietly handed rivals contested canisters; one
## value now, set to the player's original so their feel is unchanged.
const PICKUP_LATERAL := 0.4


static func width_of(sprite_name: String) -> float:
	return SpriteCatalog.get_def(sprite_name).world_w / RoadRenderer.ROAD_WIDTH


## Longitudinal extent of a sprite. Defs carry world_w and world_h but no
## depth — these are flat billboards — so cars get CAR_LENGTH and everything
## else is treated as one segment deep, which is what the bucket test gave.
static func length_of(sprite_name: String) -> float:
	return float(SpriteCatalog.get_def(sprite_name).get("world_l", SCENERY_LENGTH))


## Do two boxes overlap laterally? `margin` scales both widths.
static func lateral(x1: float, w1: float, x2: float, w2: float,
		margin: float = 1.0) -> bool:
	var half := margin * 0.5
	return not (x1 + w1 * half < x2 - w2 * half or x1 - w1 * half > x2 + w2 * half)


## Shortest signed distance from b to a on a looping track. Positive = a is
## ahead of b.
static func signed_dz(az: float, bz: float, track_len: float) -> float:
	return fposmod(az - bz + track_len * 0.5, track_len) - track_len * 0.5


## Did the gap between two objects pass through the contact band at any point
## this frame?
##
## `dz_start` is their separation at the top of the frame and `rel_travel` is
## how much that separation changed over it (a's travel minus b's). Sampling
## only the end position is what let a fast car jump clean over a slow one
## between frames; testing the whole interval cannot miss.
static func swept(dz_start: float, rel_travel: float, band: float) -> bool:
	var lo := minf(dz_start, dz_start + rel_travel)
	var hi := maxf(dz_start, dz_start + rel_travel)
	return hi >= -band and lo <= band


## Full swept contact test between two objects over one frame, each given as
## the interval it covered.
##
## Takes explicit from/to for BOTH sides rather than a position plus a travel
## distance. That is deliberate: callers sit at different points in the update
## order, so "z" means start-of-frame for some entities and end-of-frame for
## others, and a signature that hides which one it wants invites mixing the
## two — which reads as contact firing about a car-length early.
static func hit_span(a_from: float, a_to: float, a_len: float,
		b_from: float, b_to: float, b_len: float, track_len: float) -> bool:
	return swept(signed_dz(a_from, b_from, track_len),
			(a_to - a_from) - (b_to - b_from), (a_len + b_len) * 0.5)


## Instantaneous band test, for contacts where a sweep is not meaningful
## (sustained side-by-side contact rather than one object catching another).
static func near(a_z: float, a_len: float, b_z: float, b_len: float,
		track_len: float) -> bool:
	return absf(signed_dz(a_z, b_z, track_len)) <= (a_len + b_len) * 0.5
