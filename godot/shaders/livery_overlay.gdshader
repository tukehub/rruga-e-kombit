shader_type spatial;
// Drawn as next_pass over a car's paint surface: only the livery's pixels,
// lit like the paint under them.
render_mode blend_mix, depth_draw_never, cull_back, specular_schlick_ggx;

#include "res://shaders/livery.gdshaderinc"

void vertex() {
	livery_pos = VERTEX;
	livery_normal = NORMAL;
}

void fragment() {
	ALBEDO = livery_color.rgb;
	ALPHA = livery_mask();
	METALLIC = 0.35;
	ROUGHNESS = 0.3;
	CLEARCOAT = 0.6;
	CLEARCOAT_ROUGHNESS = 0.2;
}
