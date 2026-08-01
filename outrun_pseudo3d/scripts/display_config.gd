class_name DisplayConfig
## Display policy: how the 1920x1080 authored frame maps onto real monitors.
##
## The rule, in one line: the logical viewport is always exactly 1080 tall, and
## its width tracks the window's aspect — never narrower than 16:9, never wider
## than MAX_ASPECT. Consequences:
##
##   * 16:9 displays are pixel-for-pixel what the game was authored against.
##   * Wider displays get a wider logical frame. RoadRenderer already locks its
##     world scale to min(w, h * 16/9), so the surplus becomes peripheral view
##     with no change to composition, draw distance, or how far up the road you
##     can see — no competitive difference between aspect ratios.
##   * Narrower displays (16:10, 3:2, 4:3) letterbox onto the authored frame
##     rather than exposing dead sky and grass.
##
## Nothing here ever changes the desktop video mode. Fullscreen is borderless at
## the native resolution; performance is traded with content_scale_factor
## (render scale) instead, which is the modern-desktop expectation and avoids
## mode-switch flicker and alt-tab pain.

const DESIGN := Vector2i(1920, 1080)
const BASE_ASPECT := 16.0 / 9.0
## 32:9 (3.56) is a real gaming monitor, so it stays inside the cap. Past that
## we assume a multi-head desktop span and pillarbox, rather than build a
## 5760-wide logical frame nobody composed for.
const MAX_ASPECT := 3.6
## Window heights offered in windowed mode; widths follow the monitor's shape.
const HEIGHTS: Array[int] = [720, 900, 1080, 1200, 1440, 1800, 2160]

enum { MODE_FULLSCREEN, MODE_EXCLUSIVE, MODE_WINDOWED }
enum { ASPECT_AUTO, ASPECT_PILLARBOX }


## True when a real display server is present (false under --headless, where
## every screen query would error).
static func available() -> bool:
	return DisplayServer.get_screen_count() > 0


## The logical viewport for a window of size `win`.
static func logical_size(win: Vector2i, aspect_mode: int) -> Vector2i:
	if aspect_mode == ASPECT_PILLARBOX or win.x <= 0 or win.y <= 0:
		return DESIGN
	var a := clampf(float(win.x) / float(win.y), BASE_ASPECT, MAX_ASPECT)
	return Vector2i(int(round(float(DESIGN.y) * a)), DESIGN.y)


## Resolve a stored monitor preference (-1 = follow the window) to an index.
static func screen_index(explicit: int) -> int:
	var n := DisplayServer.get_screen_count()
	if n <= 0:
		return 0
	if explicit >= 0 and explicit < n:
		return explicit
	return DisplayServer.window_get_current_screen()


## Window sizes that fit on `screen`, shaped like that screen. Built at runtime
## rather than from a fixed 16:9 table, so an ultrawide user gets ultrawide
## windows instead of a letterboxed 16:9 box inside their monitor.
static func presets(screen: int) -> Array[Vector2i]:
	if not available():
		var fallback: Array[Vector2i] = [DESIGN]
		return fallback
	return presets_for(DisplayServer.screen_get_size(screen),
			DisplayServer.screen_get_usable_rect(screen).size)


## Pure form of presets(), split out so the sizing rule is testable without a
## display server attached.
static func presets_for(screen_size: Vector2i, usable: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var a := float(screen_size.x) / maxf(float(screen_size.y), 1.0)
	for h in HEIGHTS:
		var w := int(round(float(h) * a))
		w += w % 2
		if (float(w) <= float(usable.x) * 0.98
				and float(h) <= float(usable.y) * 0.94):
			out.append(Vector2i(w, h))
	if out.is_empty():
		out.append(Vector2i(maxi(640, usable.x - 120), maxi(360, usable.y - 120)))
	return out


## Largest preset that still sits comfortably inside the desktop — the windowed
## size picked on first run, before the player has expressed a preference.
static func default_preset_index(screen: int) -> int:
	if not available():
		return 0
	return default_index_for(presets(screen),
			DisplayServer.screen_get_usable_rect(screen).size)


static func default_index_for(list: Array[Vector2i], usable: Vector2i) -> int:
	var best := 0
	for i in range(list.size()):
		if (float(list[i].x) <= float(usable.x) * 0.85
				and float(list[i].y) <= float(usable.y) * 0.85):
			best = i
	return best
