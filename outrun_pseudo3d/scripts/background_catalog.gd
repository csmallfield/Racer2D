class_name BackgroundCatalog
extends RefCounted
## Registry of horizontally-tileable parallax background layers.
##
## Like SpriteCatalog, every texture here is a generated flat-WHITE standin so
## the level palette can tint it: the renderer draws each layer modulated by a
## theme colour (layer.tint_key) and fogged toward theme.fog. Swap in real art
## later by loading a Texture2D in _build_all() instead of calling _make_*; keep
## it seamless left-to-right (edge column must match column 0) so tiling has no
## visible seam, and keep the silhouette anchored to the BOTTOM of the image
## (peaks grow upward) so the renderer can sit the base on the horizon.
##
## A layer def Dictionary contains:
##   texture : Texture2D  - the (white) tileable strip
##   native_h: int        - pixel height, used for vertical scaling

static var _cache: Dictionary = {}


static func get_layer_def(name: String) -> Dictionary:
	if _cache.is_empty():
		_build_all()
	if _cache.has(name):
		return _cache[name]
	return _cache["hills_mid"]


static func _build_all() -> void:
	# Far mountains: tall, jagged (many harmonics), sit right on the horizon.
	_register("mountains_far", _make_silhouette(512, 190, [
		[2, 0.42, 0.0], [3, 0.20, 1.7], [7, 0.12, 0.4],
		[11, 0.07, 2.2], [17, 0.04, 5.1]], 0.10))
	# Mid hills: rounded, lower, gentler.
	_register("hills_mid", _make_silhouette(512, 150, [
		[1, 0.34, 0.6], [2, 0.18, 2.4], [3, 0.10, 4.0]], 0.14))
	# Near treeline: lumpy canopy band (dense high harmonics).
	_register("treeline_near", _make_silhouette(512, 130, [
		[3, 0.16, 0.0], [5, 0.14, 1.1], [9, 0.11, 3.3],
		[13, 0.09, 0.7], [23, 0.06, 4.4]], 0.34))
	# City skyline: blocky towers of varied height (deterministic per column).
	_register("city_near", _make_skyline(512, 150))
	# Soft cloud band, semi-transparent (floats above the horizon).
	_register("clouds_far", _make_clouds(512, 90))


static func _register(name: String, tex: ImageTexture) -> void:
	_cache[name] = {"texture": tex, "native_h": tex.get_height()}


# === GENERATORS ===

static func _new_image(w: int, h: int) -> Image:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


## Fill each column from the bottom up to a height driven by a sum of sines.
## Frequencies are integer wave-counts across the width, so the strip tiles
## seamlessly. harmonics: Array of [wave_count, amplitude_frac, phase].
## base_frac: minimum silhouette height as a fraction of image height.
static func _make_silhouette(w: int, h: int, harmonics: Array,
		base_frac: float) -> ImageTexture:
	var img := _new_image(w, h)
	for x in range(w):
		var u := float(x) / float(w)
		var amp := 0.0
		for hm in harmonics:
			amp += sin(u * TAU * float(hm[0]) + float(hm[2])) * float(hm[1])
		# Map the signed sum into [base_frac, ~1.0] of the height.
		var frac := clampf(base_frac + (amp * 0.5 + 0.5) * (1.0 - base_frac),
				0.0, 1.0)
		var top := int(round(float(h) * (1.0 - frac)))
		if top < h:
			img.fill_rect(Rect2i(x, top, 1, h - top), Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(img)


## Blocky skyline: towers of pseudo-random height/width, wrapped so the last
## tower meets the first cleanly.
static func _make_skyline(w: int, h: int) -> ImageTexture:
	var img := _new_image(w, h)
	var x := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242            # deterministic standin
	while x < w:
		var tw: int = rng.randi_range(16, 40)
		var frac: float = rng.randf_range(0.35, 0.95)
		var top := int(round(float(h) * (1.0 - frac)))
		var end := mini(x + tw, w)
		img.fill_rect(Rect2i(x, top, end - x, h - top), Color(1, 1, 1, 1))
		x = end + rng.randi_range(0, 6)   # small gap between towers
	return ImageTexture.create_from_image(img)


## Soft cloud band: overlapping low-alpha ellipses positioned on a wrapping
## sine so the strip tiles. Tinted white; the renderer fogs it lightly.
static func _make_clouds(w: int, h: int) -> ImageTexture:
	var img := _new_image(w, h)
	var count := 7
	for c in range(count):
		var u := float(c) / float(count)
		var cx := int(u * float(w))
		var cy := int(float(h) * (0.4 + 0.25 * sin(u * TAU)))
		var rx := 26 + (c % 3) * 10
		var ry := 9 + (c % 2) * 4
		_soft_ellipse(img, cx, cy, rx, ry, 0.5)
		# Wrap copy so an ellipse near an edge appears on the other side too.
		_soft_ellipse(img, cx - w, cy, rx, ry, 0.5)
		_soft_ellipse(img, cx + w, cy, rx, ry, 0.5)
	return ImageTexture.create_from_image(img)


static func _soft_ellipse(img: Image, cx: int, cy: int, rx: int, ry: int,
		peak_a: float) -> void:
	for oy in range(-ry, ry + 1):
		var y := cy + oy
		if y < 0 or y >= img.get_height():
			continue
		for ox in range(-rx, rx + 1):
			var x := cx + ox
			if x < 0 or x >= img.get_width():
				continue
			var d := Vector2(float(ox) / float(rx), float(oy) / float(ry)).length()
			if d >= 1.0:
				continue
			var a := (1.0 - d) * peak_a
			var cur := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(1, 1, 1, maxf(cur.a, a)))
