class_name SpriteCatalog
extends RefCounted
## Central registry of every sprite the renderer can draw.
##
## All textures are generated at runtime as flat-colored placeholder art.
## To replace with real art later: load a Texture2D from disk in _build_all()
## instead of calling one of the _make_* helpers. The renderer only ever asks
## for a def dictionary, so nothing else in the codebase needs to change.
##
## A "def" dictionary contains:
##   texture    : Texture2D  - what to draw
##   world_w    : float      - width of the object in world units
##   world_h    : float      - height of the object in world units
##   collidable : bool       - whether the player can crash into it
##
## For scale reference: the road is ROAD_WIDTH * 2 = 4000 world units wide
## (three lanes of ~1333 units each).

static var _cache: Dictionary = {}


static func get_def(sprite_name: String) -> Dictionary:
	if _cache.is_empty():
		_build_all()
	if _cache.has(sprite_name):
		return _cache[sprite_name]
	return _cache["sign"]


static func _build_all() -> void:
	_cache["player"] = {
		"texture": _make_car(Color(0.85, 0.12, 0.12)),
		"world_w": 520.0, "world_h": 300.0, "collidable": false,
	}
	_cache["car_blue"] = {
		"texture": _make_car(Color(0.15, 0.35, 0.85)),
		"world_w": 500.0, "world_h": 290.0, "collidable": true,
	}
	_cache["car_yellow"] = {
		"texture": _make_car(Color(0.9, 0.75, 0.1)),
		"world_w": 500.0, "world_h": 290.0, "collidable": true,
	}
	_cache["car_green"] = {
		"texture": _make_car(Color(0.15, 0.6, 0.3)),
		"world_w": 500.0, "world_h": 290.0, "collidable": true,
	}
	_cache["boost_pickup"] = {
		"texture": _make_boost_canister(),
		"world_w": 240.0, "world_h": 300.0, "collidable": false,
	}
	_cache["building"] = {
		"texture": _make_building(Color(0.16, 0.17, 0.24), Color(0.95, 0.85, 0.4)),
		"world_w": 2200.0, "world_h": 5200.0, "collidable": true,
	}
	_cache["building_2"] = {
		"texture": _make_building(Color(0.2, 0.14, 0.22), Color(0.4, 0.85, 0.95)),
		"world_w": 1800.0, "world_h": 3800.0, "collidable": true,
	}
	_cache["streetlight"] = {
		"texture": _make_streetlight(),
		"world_w": 260.0, "world_h": 1500.0, "collidable": false,
	}
	_cache["dead_tree"] = {
		"texture": _make_dead_tree(),
		"world_w": 1100.0, "world_h": 1900.0, "collidable": true,
	}
	_cache["pumpkin"] = {
		"texture": _make_pumpkin(),
		"world_w": 420.0, "world_h": 340.0, "collidable": true,
	}
	_cache["lollipop"] = {
		"texture": _make_lollipop(),
		"world_w": 700.0, "world_h": 1600.0, "collidable": true,
	}
	_cache["tree"] = {
		"texture": _make_tree(Color(0.09, 0.42, 0.16), Color(0.35, 0.22, 0.1)),
		"world_w": 1300.0, "world_h": 2300.0, "collidable": true,
	}
	_cache["palm"] = {
		"texture": _make_palm(Color(0.12, 0.55, 0.2), Color(0.45, 0.32, 0.15)),
		"world_w": 1100.0, "world_h": 2900.0, "collidable": true,
	}
	_cache["rock"] = {
		"texture": _make_rock(Color(0.45, 0.42, 0.4)),
		"world_w": 1000.0, "world_h": 750.0, "collidable": true,
	}
	_cache["cactus"] = {
		"texture": _make_cactus(Color(0.2, 0.5, 0.25)),
		"world_w": 650.0, "world_h": 1500.0, "collidable": true,
	}
	_cache["sign"] = {
		"texture": _make_sign(Color(0.9, 0.9, 0.9), Color(0.8, 0.15, 0.15)),
		"world_w": 1100.0, "world_h": 1300.0, "collidable": true,
	}


# === IMAGE HELPERS ===

static func _new_image(w: int, h: int) -> Image:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


static func _to_texture(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


## Fill a downward-pointing row range as a triangle (apex at top).
static func _fill_triangle(img: Image, cx: int, top: int, bottom: int, half_w: int, color: Color) -> void:
	var height := bottom - top
	if height <= 0:
		return
	for row in range(height):
		var t := float(row) / float(height)
		var hw := int(round(half_w * t))
		if hw > 0:
			img.fill_rect(Rect2i(cx - hw, top + row, hw * 2, 1), color)


static func _fill_ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, color: Color) -> void:
	for row in range(-ry, ry + 1):
		var t := float(row) / float(ry)
		var hw := int(round(rx * sqrt(max(0.0, 1.0 - t * t))))
		if hw > 0:
			img.fill_rect(Rect2i(cx - hw, cy + row, hw * 2, 1), color)


# === SPRITE BUILDERS ===

static func _make_car(body: Color) -> ImageTexture:
	var img := _new_image(96, 56)
	var dark := body.darkened(0.35)
	var glass := Color(0.15, 0.2, 0.3)
	# wheels
	img.fill_rect(Rect2i(6, 40, 18, 14), Color(0.05, 0.05, 0.05))
	img.fill_rect(Rect2i(72, 40, 18, 14), Color(0.05, 0.05, 0.05))
	# body
	img.fill_rect(Rect2i(2, 26, 92, 20), body)
	img.fill_rect(Rect2i(2, 42, 92, 6), dark)
	# cabin
	img.fill_rect(Rect2i(20, 8, 56, 20), body)
	img.fill_rect(Rect2i(26, 12, 44, 14), glass)
	# tail lights
	img.fill_rect(Rect2i(4, 30, 8, 6), Color(1.0, 0.2, 0.1))
	img.fill_rect(Rect2i(84, 30, 8, 6), Color(1.0, 0.2, 0.1))
	return _to_texture(img)


## A rival car: the standard car body plus a white racing stripe.
## Register (or re-register) a rival's sprite from its profile: real art if
## the profile assigns car_texture, otherwise a generated placeholder in the
## livery color. map_color always follows the profile (progress-bar dot).
static func register_rival(index: int, profile: RivalProfile) -> void:
	get_def("player")   # ensure the base catalog is built first
	var tex: Texture2D = profile.car_texture
	if tex == null:
		tex = _make_rival(profile.color)
	_cache["rival_%d" % index] = {
		"texture": tex,
		"world_w": 510.0, "world_h": 295.0, "collidable": true,
		"map_color": profile.color,
	}


## Per-player liveries for split screen: player_0..player_3 share the
## player car's world size; colors are fixed (P1 red, P2 blue, P3 green,
## P4 yellow) and drive both the sprite and progress-bar markers.
const PLAYER_COLORS: Array[Color] = [
	Color(0.85, 0.12, 0.12), Color(0.15, 0.35, 0.95),
	Color(0.1, 0.8, 0.3), Color(0.95, 0.85, 0.1),
]


static func register_player(index: int) -> void:
	get_def("player")
	var color := PLAYER_COLORS[index % PLAYER_COLORS.size()]
	_cache["player_%d" % index] = {
		"texture": _make_car(color),
		"world_w": 520.0, "world_h": 300.0, "collidable": true,
		"map_color": color,
	}


## Register a player slot's car from a chosen racer profile: real art if the
## profile assigns car_texture, otherwise a placeholder in the livery color.
## Lets a player drive their selected racer instead of the fixed slot livery.
static func register_player_from_profile(index: int, profile: RivalProfile) -> void:
	get_def("player")
	var tex: Texture2D = profile.car_texture
	if tex == null:
		tex = _make_car(profile.color)
	_cache["player_%d" % index] = {
		"texture": tex,
		"world_w": 520.0, "world_h": 300.0, "collidable": true,
		"map_color": profile.color,
	}


static func _make_rival(body: Color) -> ImageTexture:
	var tex := _make_car(body)
	var img := tex.get_image()
	img.fill_rect(Rect2i(42, 6, 12, 44), Color(0.97, 0.97, 0.97))
	return _to_texture(img)


## Tower block with a lit-window grid — city skyline placeholder.
static func _make_building(body: Color, window: Color) -> ImageTexture:
	var img := _new_image(64, 128)
	img.fill_rect(Rect2i(2, 2, 60, 124), body)
	for row in range(6, 120, 10):
		for col in range(8, 54, 12):
			if randf() < 0.72:
				img.fill_rect(Rect2i(col, row, 7, 6), window)
			else:
				img.fill_rect(Rect2i(col, row, 7, 6), body.darkened(0.35))
	return _to_texture(img)


## Roadside street light: pole with an arm and a warm lamp head.
static func _make_streetlight() -> ImageTexture:
	var img := _new_image(48, 96)
	var pole := Color(0.4, 0.42, 0.48)
	img.fill_rect(Rect2i(6, 8, 5, 88), pole)
	img.fill_rect(Rect2i(6, 8, 34, 4), pole)
	img.fill_rect(Rect2i(34, 12, 10, 6), Color(1.0, 0.92, 0.6))
	return _to_texture(img)


## Glowing boost canister — bright, unmistakable, hovers over the road.
static func _make_boost_canister() -> ImageTexture:
	var img := _new_image(48, 60)
	img.fill_rect(Rect2i(10, 8, 28, 46), Color(1.0, 0.55, 0.05))
	img.fill_rect(Rect2i(14, 12, 20, 38), Color(1.0, 0.8, 0.2))
	img.fill_rect(Rect2i(18, 0, 12, 10), Color(0.85, 0.9, 0.95))
	img.fill_rect(Rect2i(20, 20, 8, 22), Color(1.0, 0.98, 0.85))
	return _to_texture(img)


## Bare, twisted silhouette for the Halloween stage.
static func _make_dead_tree() -> ImageTexture:
	var img := _new_image(64, 96)
	var bark := Color(0.12, 0.09, 0.11)
	img.fill_rect(Rect2i(28, 40, 8, 56), bark)
	img.fill_rect(Rect2i(20, 26, 6, 26), bark)
	img.fill_rect(Rect2i(12, 14, 5, 18), bark)
	img.fill_rect(Rect2i(38, 20, 6, 30), bark)
	img.fill_rect(Rect2i(44, 8, 5, 18), bark)
	img.fill_rect(Rect2i(30, 6, 5, 38), bark)
	return _to_texture(img)


## Squat jack-o'-lantern.
static func _make_pumpkin() -> ImageTexture:
	var img := _new_image(48, 40)
	var body := Color(0.95, 0.45, 0.05)
	img.fill_rect(Rect2i(4, 10, 40, 28), body)
	img.fill_rect(Rect2i(2, 16, 44, 16), body)
	img.fill_rect(Rect2i(21, 2, 6, 10), Color(0.25, 0.4, 0.1))
	var glow := Color(1.0, 0.9, 0.3)
	img.fill_rect(Rect2i(12, 18, 6, 6), glow)
	img.fill_rect(Rect2i(30, 18, 6, 6), glow)
	img.fill_rect(Rect2i(14, 28, 20, 5), glow)
	return _to_texture(img)


## Giant swirl lollipop on a white stick.
static func _make_lollipop() -> ImageTexture:
	var img := _new_image(56, 128)
	img.fill_rect(Rect2i(25, 52, 6, 76), Color(0.98, 0.98, 0.98))
	var c := Vector2(28, 28)
	for y in range(0, 56):
		for x in range(0, 56):
			var d := Vector2(x, y).distance_to(c)
			if d <= 26.0:
				var swirl := fposmod(atan2(float(y) - c.y, float(x) - c.x) * 2.0 + d * 0.45, TAU)
				img.set_pixel(x, y, Color(0.95, 0.2, 0.45) if swirl < PI
						else Color(0.99, 0.95, 0.97))
	return _to_texture(img)


static func _make_tree(leaf: Color, trunk: Color) -> ImageTexture:
	var img := _new_image(80, 128)
	img.fill_rect(Rect2i(34, 96, 12, 32), trunk)
	_fill_triangle(img, 40, 0, 52, 24, leaf)
	_fill_triangle(img, 40, 30, 78, 32, leaf.darkened(0.1))
	_fill_triangle(img, 40, 58, 104, 38, leaf.darkened(0.2))
	return _to_texture(img)


static func _make_palm(leaf: Color, trunk: Color) -> ImageTexture:
	var img := _new_image(80, 160)
	# leaning trunk
	for row in range(56, 160):
		var lean := int((row - 56) * 0.12)
		img.fill_rect(Rect2i(36 - lean, row, 10, 1), trunk)
	# fronds: fan of ellipses
	_fill_ellipse(img, 40, 44, 36, 10, leaf)
	_fill_ellipse(img, 22, 34, 22, 8, leaf.darkened(0.15))
	_fill_ellipse(img, 58, 34, 22, 8, leaf.darkened(0.15))
	_fill_ellipse(img, 40, 24, 14, 10, leaf.lightened(0.1))
	return _to_texture(img)


static func _make_rock(base: Color) -> ImageTexture:
	var img := _new_image(96, 72)
	_fill_ellipse(img, 48, 60, 46, 30, base)
	_fill_ellipse(img, 32, 44, 24, 20, base.lightened(0.12))
	_fill_ellipse(img, 66, 50, 20, 16, base.darkened(0.12))
	return _to_texture(img)


static func _make_cactus(body: Color) -> ImageTexture:
	var img := _new_image(64, 128)
	img.fill_rect(Rect2i(26, 12, 14, 116), body)
	img.fill_rect(Rect2i(6, 40, 12, 10), body.darkened(0.1))
	img.fill_rect(Rect2i(6, 20, 10, 30), body.darkened(0.1))
	img.fill_rect(Rect2i(46, 56, 14, 10), body.darkened(0.1))
	img.fill_rect(Rect2i(50, 32, 10, 34), body.darkened(0.1))
	return _to_texture(img)


static func _make_sign(panel: Color, accent: Color) -> ImageTexture:
	var img := _new_image(96, 112)
	# posts
	img.fill_rect(Rect2i(14, 56, 8, 56), Color(0.3, 0.3, 0.3))
	img.fill_rect(Rect2i(74, 56, 8, 56), Color(0.3, 0.3, 0.3))
	# billboard panel with border
	img.fill_rect(Rect2i(2, 2, 92, 58), accent)
	img.fill_rect(Rect2i(8, 8, 80, 46), panel)
	# stripe to suggest an arrow/ad
	img.fill_rect(Rect2i(14, 24, 68, 14), accent)
	return _to_texture(img)
