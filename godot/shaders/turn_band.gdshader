shader_type spatial;
render_mode unshaded, cull_disabled;
// Black chevrons on amber, repeating along the band. UV.x grows in the race
// direction, one chevron per unit, so every chevron points the way to go.

void fragment() {
	float x = fract(UV.x);
	float y = UV.y * 2.0 - 1.0;
	// A ">" whose tip sits at x = 0.68 on the band's centre line.
	float edge = abs(x - (0.68 - abs(y) * 0.32));
	float arrow = (1.0 - smoothstep(0.1, 0.15, edge)) * (1.0 - smoothstep(0.72, 0.8, abs(y)));
	float border = smoothstep(0.84, 0.9, abs(y));
	vec3 base = mix(vec3(0.78, 0.57, 0.16), vec3(0.025), max(arrow, border));
	ALBEDO = base;
}
