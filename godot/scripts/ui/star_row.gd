class_name StarRow
extends Control
## Cup stars drawn as shapes: the UI fonts have no star glyph.

var earned := 0: set = set_earned
var total := 3
var star_size := 22.0
var gap := 4.0
var lit := UiTheme.AMBER
var unlit := Color(1, 1, 1, 0.22)


func _init(p_earned := 0, p_size := 22.0) -> void:
	star_size = p_size
	earned = p_earned
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(total * star_size + (total - 1) * gap, star_size)


func set_earned(value: int) -> void:
	earned = clampi(value, 0, total)
	queue_redraw()


func _draw() -> void:
	for i in total:
		var centre := Vector2(star_size * 0.5 + i * (star_size + gap), size.y * 0.5)
		var points := PackedVector2Array()
		for k in 10:
			var radius := star_size * (0.5 if k % 2 == 0 else 0.21)
			var angle := -PI * 0.5 + k * PI / 5.0
			points.append(centre + Vector2.from_angle(angle) * radius)
		draw_colored_polygon(points, lit if i < earned else unlit)
