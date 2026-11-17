shader_type canvas_item;
// Shows only a centred disc of the texture (the logo's round badge), with a
// one-pixel-soft edge. radius is a fraction of the rect's half size.
uniform float radius = 0.94;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float edge = fwidth(d);
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= 1.0 - smoothstep(radius - edge, radius, d);
}
