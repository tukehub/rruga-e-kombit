shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;
// Flags on the poles around the square: a travelling wave that grows toward
// the free edge (UV.x = 0 at the pole). INSTANCE_CUSTOM.a offsets each flag.

uniform vec3 cloth : source_color = vec3(0.78, 0.06, 0.08);
uniform vec3 emblem : source_color = vec3(0.05, 0.04, 0.04);

void vertex() {
	float t = TIME * 3.2 + INSTANCE_CUSTOM.a * 6.2832;
	float free_edge = UV.x;
	VERTEX.z += sin(UV.x * 7.0 - t) * 0.22 * free_edge;
	VERTEX.y -= free_edge * free_edge * 0.12;
}

void fragment() {
	// A dark diamond in the middle stands in for the eagle at this distance.
	vec2 d = abs(UV - vec2(0.5));
	float mark = step(d.x * 1.1 + d.y * 1.5, 0.28);
	ALBEDO = mix(cloth, emblem, mark);
	ROUGHNESS = 0.8;
	SPECULAR = 0.2;
}
