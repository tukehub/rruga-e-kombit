shader_type spatial;
render_mode unshaded, cull_disabled;

varying vec4 guide;
void vertex() {
	guide = INSTANCE_CUSTOM;
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float x = guide.r > 0.5 ? p.x : -p.x;
	float count = 1.0 + floor(guide.g * 2.0 + 0.5);
	float arrow = 0.0;
	for (int i = 0; i < 3; i++) {
		if (float(i) < count) {
			float q = x * 2.2 - (float(i) - (count - 1.0) * 0.5) * 1.1;
			float edge = abs(q - (0.35 - abs(p.y) * 1.3));
			arrow = max(arrow, (1.0 - smoothstep(0.09, 0.15, edge)) * (1.0 - smoothstep(0.65, 0.78, abs(p.y))));
		}
	}
	float border = smoothstep(0.87, 0.95, max(abs(p.x), abs(p.y)));
	vec3 base = mix(vec3(0.78, 0.57, 0.16), vec3(0.025), max(arrow, border));
	ALBEDO = base;
	ROUGHNESS = 0.9;
}
