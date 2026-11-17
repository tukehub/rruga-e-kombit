shader_type spatial;
render_mode cull_back, specular_schlick_ggx;
// The ground of the points mode: Skanderbeg Square's paving all the way out.

#include "res://shaders/square_paving.gdshaderinc"

varying vec2 ground;

void vertex() {
	ground = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float rough;
	float joint;
	ALBEDO = square_paving(ground, rough, joint);
	ROUGHNESS = rough;
	METALLIC = 0.0;
	SPECULAR = 0.3;
}
