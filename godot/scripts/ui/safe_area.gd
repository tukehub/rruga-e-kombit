extends MarginContainer
## Native safe pixels are converted through the same transform as touch input.
## The single plain Control child keeps anchored UI free of Container layout.

var _last_safe := Rect2i()
var _last_transform := Transform2D()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	resized.connect(_refresh)
	_refresh()


func _process(_dt: float) -> void:
	var safe := DisplayServer.get_display_safe_area() if OS.get_name() in ["Android", "iOS"] else Rect2i()
	var transform := get_screen_transform()
	if safe != _last_safe or transform != _last_transform:
		_refresh()


static func logical_rect(bounds: Rect2, native_safe: Rect2i, screen_transform: Transform2D) -> Rect2:
	if not native_safe.has_area():
		return bounds
	var mapped := screen_transform.affine_inverse() * Rect2(native_safe)
	var clipped := bounds.intersection(mapped)
	return clipped if clipped.has_area() else bounds


func _refresh() -> void:
	_last_safe = DisplayServer.get_display_safe_area() if OS.get_name() in ["Android", "iOS"] else Rect2i()
	_last_transform = get_screen_transform()
	var safe := logical_rect(Rect2(Vector2.ZERO, size), _last_safe, _last_transform)
	add_theme_constant_override("margin_left", int(ceil(safe.position.x)))
	add_theme_constant_override("margin_top", int(ceil(safe.position.y)))
	add_theme_constant_override("margin_right", int(ceil(size.x - safe.end.x)))
	add_theme_constant_override("margin_bottom", int(ceil(size.y - safe.end.y)))
