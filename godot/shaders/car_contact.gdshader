shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float body = 1.0 - smoothstep(0.20, 1.0, length(p * vec2(1.2, 0.9)));
	float tires = 0.0;
	for (int x = 0; x < 2; x++) {
		for (int z = 0; z < 2; z++) {
			vec2 center = vec2(x == 0 ? 0.14 : 0.86, z == 0 ? 0.24 : 0.82);
			float d = length((UV - center) * vec2(9.0, 11.0));
			tires = max(tires, 1.0 - smoothstep(0.18, 1.0, d));
		}
	}
	ALBEDO = vec3(0.012, 0.012, 0.012);
	ALPHA = max(body * 0.22, tires * 0.34);
}
