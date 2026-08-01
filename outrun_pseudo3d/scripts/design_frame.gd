class_name DesignFrame
extends Control
## Centres the fixed 1920x1080 authoring space that every full-screen menu
## overlay is composed in, inside whatever the logical viewport currently is.
##
## With the adaptive logical viewport (see DisplayConfig) an ultrawide display
## hands the game a frame wider than 16:9. RoadRenderer treats that extra width
## as peripheral view, which is right for the race — but menus are composed
## shots, and smearing a title screen across 32:9 looks broken. So overlays keep
## authoring in 1920x1080 coordinates and parent their content to one of these;
## the frame uniformly scales and centres it, and re-fits when the frame changes.
##
## The scrim behind a menu is the exception: it has to cover the whole picture,
## so it is anchored to the viewport instead. Use backdrop() for that.

const DESIGN := Vector2(1920.0, 1080.0)


## Create a frame and parent it to `layer`. Overlay layers call this once and
## then add all their content to the returned node.
static func attach(layer: CanvasLayer) -> DesignFrame:
	var f := DesignFrame.new()
	layer.add_child(f)
	return f


## Full-viewport scrim, added behind everything else on `layer`.
static func backdrop(layer: CanvasLayer, col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(r)
	layer.move_child(r, 0)
	return r


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = DESIGN
	_fit()
	get_viewport().size_changed.connect(_deferred_fit)


## Deferred so a resize that also changes content_scale_size settles first.
func _deferred_fit() -> void:
	_fit.call_deferred()


func _fit() -> void:
	if not is_inside_tree():
		return
	var vp := get_viewport().get_visible_rect().size
	var k := minf(vp.x / DESIGN.x, vp.y / DESIGN.y)
	scale = Vector2(k, k)
	position = (vp - DESIGN * k) * 0.5
