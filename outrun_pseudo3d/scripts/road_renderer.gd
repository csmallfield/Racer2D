class_name RoadRenderer
extends Node2D
## Pseudo-3D road renderer.
##
## Uses the "true 3d-projected segments" method (Lou's Pseudo 3D Page /
## codeincomplete's JavaScript racer): the track is a strip of horizontal
## 3D segments that only ever move toward the camera. Curves are faked by
## accumulating a per-segment x-offset (dx += curve) while projecting, which
## produces the classic OutRun road-swing. Hills are real projected geometry.
##
## Everything is drawn immediate-mode in _draw() each frame: road polygons
## front-to-back with a clip line (maxy), then sprites back-to-front
## (painter's algorithm) clipped against each segment's stored clip line.

const ROAD_WIDTH := 2000.0     # half-width of the road in world units
const CAMERA_HEIGHT := 1000.0  # camera height above the road
const FOV_DEG := 100.0
const DRAW_DISTANCE := 300     # segments drawn ahead of the camera
const FOG_DENSITY := 5.0
const LANES := 3

var main: Node2D                 # set by main.gd
var camera_depth: float = 1.0 / tan(deg_to_rad(FOV_DEG * 0.5))
var hill_offset := 0.0           # background parallax scroll (driven by main)
var last_player_y := 0.0         # road altitude under the player this frame


## Distance from camera to the player car along z.
func player_z() -> float:
	return CAMERA_HEIGHT * camera_depth


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if main == null or main.track == null or main.track.segments.is_empty():
		return
	var vp := get_viewport_rect().size
	_draw_background(vp.x, vp.y)
	_draw_road_and_sprites(vp.x, vp.y)
	_draw_player(vp.x, vp.y)


# === BACKGROUND ===

func _draw_background(w: float, h: float) -> void:
	var th: Dictionary = main.level.theme
	var horizon := h * 0.5
	# Sky gradient.
	var pts := PackedVector2Array([
		Vector2(0, 0), Vector2(w, 0), Vector2(w, horizon), Vector2(0, horizon)])
	var cols := PackedColorArray([th.sky_top, th.sky_top, th.sky_bottom, th.sky_bottom])
	draw_polygon(pts, cols)
	# Sun.
	draw_circle(Vector2(w * 0.72, h * 0.18), h * 0.08, th.sun)
	# Distant ground fill below the horizon. This also hides the gap that
	# opens up between the road top and the horizon on downhills (Lotus trick).
	draw_rect(Rect2(0, horizon, w, h - horizon), th.grass_dark.lerp(th.fog, 0.85))
	# Rolling hill silhouette, drawn as columns (parallax-scrolls with curves).
	var hill_col: Color = th.hills.lerp(th.fog, 0.5)
	var step := 16.0
	var x := 0.0
	while x < w:
		var t := (x + hill_offset) * 0.004
		var hh := (sin(t) * 0.5 + 0.5) * h * 0.10 + (sin(t * 2.7 + 1.3) * 0.5 + 0.5) * h * 0.035
		draw_rect(Rect2(x, horizon - hh, step + 1.0, hh + 1.0), hill_col)
		x += step


# === ROAD + SPRITES ===

func _project(p: Dictionary, cam_x: float, cam_y: float, cam_z: float, w: float, h: float) -> void:
	p.camera.x = p.world.x - cam_x
	p.camera.y = p.world.y - cam_y
	p.camera.z = p.world.z - cam_z
	var z: float = max(p.camera.z, 0.0001)
	p.screen.scale = camera_depth / z
	# Rounding avoids sub-pixel seam lines between adjacent road slices.
	p.screen.x = roundf(w * 0.5 + p.screen.scale * p.camera.x * w * 0.5)
	p.screen.y = roundf(h * 0.5 - p.screen.scale * p.camera.y * h * 0.5)
	p.screen.w = roundf(p.screen.scale * ROAD_WIDTH * w * 0.5)


func _fog_amount(n: int) -> float:
	var d := float(n) / float(DRAW_DISTANCE)
	return 1.0 - 1.0 / exp(d * d * FOG_DENSITY)


func _draw_road_and_sprites(w: float, h: float) -> void:
	var track: TrackBuilder = main.track
	var segments: Array = track.segments
	var seg_count := segments.size()
	var seg_len: float = TrackBuilder.SEGMENT_LENGTH
	var track_len: float = track.track_length()
	var player: PlayerCar = main.player
	var th: Dictionary = main.level.theme

	# Camera altitude follows the road under the player (interpolated).
	var ahead := fposmod(player.position_z + player_z(), track_len)
	var pseg: Dictionary = main.find_segment(ahead)
	var ppercent := fposmod(ahead, seg_len) / seg_len
	last_player_y = lerpf(pseg.p1.world.y, pseg.p2.world.y, ppercent)
	var cam_y := last_player_y + CAMERA_HEIGHT

	var base: Dictionary = main.find_segment(player.position_z)
	var base_percent := fposmod(player.position_z, seg_len) / seg_len

	# --- Pass 1: road polygons, front to back, tracking the clip line. ---
	var maxy := h
	var x := 0.0
	# Pull the frontmost segment into line as we traverse it, so the curve
	# keeps its shape while scrolling (codeincomplete's dx trick).
	var dx: float = -(base.curve * base_percent)

	for n in range(DRAW_DISTANCE):
		var seg: Dictionary = segments[(base.index + n) % seg_count]
		seg.looped = seg.index < base.index
		seg.clip = maxy
		var cam_z_off := track_len if seg.looped else 0.0

		_project(seg.p1, player.x * ROAD_WIDTH - x, cam_y, player.position_z - cam_z_off, w, h)
		_project(seg.p2, player.x * ROAD_WIDTH - x - dx, cam_y, player.position_z - cam_z_off, w, h)
		x += dx
		dx += seg.curve

		if seg.p1.camera.z <= camera_depth \
				or seg.p2.screen.y >= maxy \
				or seg.p2.screen.y >= seg.p1.screen.y:
			continue

		_draw_segment(seg, w, _fog_amount(n), th)
		maxy = seg.p2.screen.y

	# --- Pass 2: sprites and cars, back to front (painter's algorithm). ---
	for n in range(DRAW_DISTANCE - 1, 0, -1):
		var seg: Dictionary = segments[(base.index + n) % seg_count]
		var fog := _fog_amount(n)
		var fog_mod := Color.WHITE.lerp(th.fog, fog * 0.8)

		for car in seg.cars:
			var percent := fposmod(car.z, seg_len) / seg_len
			var sc := lerpf(seg.p1.screen.scale, seg.p2.screen.scale, percent)
			var sx: float = lerpf(seg.p1.screen.x, seg.p2.screen.x, percent) \
					+ sc * float(car.offset) * ROAD_WIDTH * w * 0.5
			var sy := lerpf(seg.p1.screen.y, seg.p2.screen.y, percent)
			_draw_sprite(car.sprite, sc, sx, sy, seg.clip, w, fog_mod)

		for spr in seg.sprites:
			var sc: float = seg.p1.screen.scale
			var sx: float = seg.p1.screen.x + sc * float(spr.offset) * ROAD_WIDTH * w * 0.5
			var sy: float = seg.p1.screen.y
			_draw_sprite(spr.name, sc, sx, sy, seg.clip, w, fog_mod)


func _draw_segment(seg: Dictionary, w: float, fog: float, th: Dictionary) -> void:
	var light: bool = seg.color == 0
	var grass: Color = th.grass_light if light else th.grass_dark
	var road: Color = th.road_light if light else th.road_dark
	var rumble: Color = th.rumble_light if light else th.rumble_dark
	if seg.special == "start":
		road = th.start
		rumble = th.start
	elif seg.special == "finish":
		road = th.finish
		rumble = th.finish
	elif seg.special == "checkpoint":
		road = th.checkpoint if th.has("checkpoint") else th.start
		rumble = th.checkpoint if th.has("checkpoint") else th.start
	var fogc: Color = th.fog
	grass = grass.lerp(fogc, fog)
	road = road.lerp(fogc, fog)
	rumble = rumble.lerp(fogc, fog)

	var x1: float = seg.p1.screen.x
	var y1: float = seg.p1.screen.y
	var w1: float = seg.p1.screen.w
	var x2: float = seg.p2.screen.x
	var y2: float = seg.p2.screen.y
	var w2: float = seg.p2.screen.w

	# Grass strip for this slice.
	draw_rect(Rect2(0, y2, w, y1 - y2), grass)

	var draw_lanes: bool = light and seg.special == ""
	var lane_col: Color = th.lane.lerp(fogc, fog)
	_draw_ribbon(x1, y1, w1, x2, y2, w2, road, rumble, draw_lanes, lane_col)


## One road ribbon: rumble strips, surface, lane lines.
func _draw_ribbon(x1: float, y1: float, w1: float, x2: float, y2: float,
		w2: float, road: Color, rumble: Color, draw_lanes: bool,
		lane_col: Color) -> void:
	# Rumble strips.
	var r1 := w1 / maxf(6.0, 2.0 * LANES)
	var r2 := w2 / maxf(6.0, 2.0 * LANES)
	_quad(x1 - w1 - r1, y1, x1 - w1, y1, x2 - w2, y2, x2 - w2 - r2, y2, rumble)
	_quad(x1 + w1 + r1, y1, x1 + w1, y1, x2 + w2, y2, x2 + w2 + r2, y2, rumble)

	# Road surface.
	_quad(x1 - w1, y1, x1 + w1, y1, x2 + w2, y2, x2 - w2, y2, road)

	# Lane lines on light stripes only (classic dashed look).
	if draw_lanes:
		var l1 := w1 / maxf(32.0, 8.0 * LANES)
		var l2 := w2 / maxf(32.0, 8.0 * LANES)
		var lw1 := w1 * 2.0 / LANES
		var lw2 := w2 * 2.0 / LANES
		var lx1 := x1 - w1 + lw1
		var lx2 := x2 - w2 + lw2
		for _lane in range(1, LANES):
			_quad(lx1 - l1 * 0.5, y1, lx1 + l1 * 0.5, y1,
					lx2 + l2 * 0.5, y2, lx2 - l2 * 0.5, y2, lane_col)
			lx1 += lw1
			lx2 += lw2


func _quad(ax: float, ay: float, bx: float, by: float,
		cx: float, cy: float, dx: float, dy: float, col: Color) -> void:
	var pts := PackedVector2Array([
		Vector2(ax, ay), Vector2(bx, by), Vector2(cx, cy), Vector2(dx, dy)])
	draw_polygon(pts, PackedColorArray([col]))


## Draws one billboard sprite bottom-anchored at (x, y), scaled by the
## segment's projection scale, clipped against the road's crest line.
func _draw_sprite(sprite_name: String, scale_factor: float, x: float, y: float,
		clip_y: float, w: float, fog_mod: Color) -> void:
	var def: Dictionary = SpriteCatalog.get_def(sprite_name)
	var dest_w: float = def.world_w * scale_factor * w * 0.5
	var dest_h: float = def.world_h * scale_factor * w * 0.5
	if dest_w < 1.5 or dest_h < 1.5:
		return
	var dest_x := x - dest_w * 0.5
	var dest_y := y - dest_h

	# Clip the bottom of sprites hidden behind a nearer hill crest.
	var clip_h := 0.0
	if clip_y > 0.0:
		clip_h = maxf(0.0, dest_y + dest_h - clip_y)
	if clip_h >= dest_h:
		return
	var visible_ratio := 1.0 - clip_h / dest_h

	var tex: Texture2D = def.texture
	draw_texture_rect_region(
		tex,
		Rect2(dest_x, dest_y, dest_w, dest_h * visible_ratio),
		Rect2(0, 0, tex.get_width(), tex.get_height() * visible_ratio),
		fog_mod)


# === PLAYER ===

func _draw_player(w: float, h: float) -> void:
	var player: PlayerCar = main.player
	var def: Dictionary = SpriteCatalog.get_def("player")
	var sc := 1.0 / CAMERA_HEIGHT   # projection scale at the player's z
	var dw: float = def.world_w * sc * w * 0.5
	var dh: float = def.world_h * sc * w * 0.5
	var cx := w * 0.5
	var cy := h * 0.92 - dh * 0.5 + player.bounce
	var tilt: float = 0.06 * player.steer_dir * (player.speed / PlayerCar.MAX_SPEED)
	draw_set_transform(Vector2(cx, cy), tilt, Vector2.ONE)
	draw_texture_rect(def.texture, Rect2(-dw * 0.5, -dh * 0.5, dw, dh), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
