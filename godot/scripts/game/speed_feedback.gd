extends CanvasLayer
## Draw after the world and before every HUD/control/mirror canvas item.

var overlay: ColorRect
var material: ShaderMaterial
var strength := 0.0

func _ready() -> void:
	layer = -1
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = ShaderMaterial.new()
	material.shader = preload("res://shaders/speed_post.gdshader")
	overlay.material = material
	add_child(overlay)
	Quality.budget_changed.connect(_apply_budget)
	_apply_budget()

func _apply_budget() -> void:
	if not bool(Quality.p.speed_post):
		strength = 0.0
		material.set_shader_parameter("strength", 0.0)
	overlay.visible = bool(Quality.p.speed_post) and strength > 0.001

func update(c: CarState, active: bool, dt: float) -> void:
	if not active or c.wreck_t > 0.0 or not bool(Quality.p.speed_post):
		strength = 0.0
	else:
		var ratio := maxf(0.0, c.v) / maxf(1.0, float(c.def.vmax))
		var target := clampf((ratio - 0.55) / 0.65, 0.0, 0.7)
		if c.nitro_t > 0.0 and ratio > 0.2:
			target = minf(1.0, target + 0.3)
		strength = lerpf(strength, target, 1.0 - exp(-8.0 * maxf(dt, 0.0)))
	material.set_shader_parameter("strength", strength)
	overlay.visible = bool(Quality.p.speed_post) and strength > 0.001
