shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

void fragment() {
	// UV is measured in metres. Two opposing strands form each diamond.
	vec2 grid = (vec2(UV.x + UV.y, UV.x - UV.y)) * 9.5;
	vec2 distance_to_wire = abs(fract(grid + 0.5) - 0.5);
	vec2 line_width = clamp(fwidth(grid) * 0.23, vec2(0.033), vec2(0.062));
	line_width *= 1.0 - smoothstep(75.0, 190.0, -VERTEX.z);
	ALPHA = 1.0 - step(1.0, min(distance_to_wire.x / max(0.0001, line_width.x), distance_to_wire.y / max(0.0001, line_width.y)));
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALBEDO = vec3(0.075, 0.087, 0.094);
	ROUGHNESS = 0.72;
}
