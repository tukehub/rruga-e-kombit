shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform, fog_disabled;

// Splash crowns where drops hit the road. Each quad lives for a fraction of a
// second at a random spot near the camera, then reappears somewhere else.
uniform float rain = 1.0;
// The road under the player as a plane: a point on it and its height gradient.
uniform vec3 ground_origin = vec3(0.0);
uniform vec2 ground_grad = vec2(0.0);
uniform vec3 to_sun = vec3(0.3, 0.8, 0.2);
uniform vec3 sun_light = vec3(1.0);
uniform vec3 ambient_light = vec3(0.2);

varying vec3 v_col;
varying float v_alpha;
varying float v_life;
varying vec2 v_quad;

vec2 hash2(vec2 p) {
	vec3 q = fract(vec3(p.x, p.y, p.x) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.xx + q.yz) * q.zy);
}

void vertex() {
	vec4 seed = vec4(UV, UV2);
	v_quad = VERTEX.xy;
	float period = 0.26 + 0.14 * seed.z;
	float tt = TIME / period + seed.w * 10.0;
	float cycle = floor(tt);
	float life = fract(tt);
	vec2 r = hash2(seed.xy * 91.7 + cycle * 0.371) - 0.5;
	// Denser near the camera.
	r *= 0.35 + 1.3 * abs(r);
	vec3 cam = CAMERA_POSITION_WORLD;
	vec2 cell = floor(cam.xz / 4.0) * 4.0;
	vec2 xz = cell + r * 44.0;
	float height = ground_origin.y + dot(ground_grad, xz - ground_origin.xz) + 0.02;
	vec3 p = vec3(xz.x, height, xz.y);
	float size = mix(0.10, 0.20, seed.z);
	float wide = size * (0.7 + 1.5 * life);
	float tall = size * (0.4 + 1.3 * sin(life * 3.14159));
	vec3 to_p = p - cam;
	float dist = length(to_p);
	vec3 side = normalize(vec3(to_p.z, 0.0, -to_p.x));
	vec3 wp = p + side * (wide * v_quad.x * 2.0) + vec3(0.0, tall * v_quad.y, 0.0);
	float c = dot(to_p / max(dist, 0.001), to_sun);
	v_col = ambient_light * 1.4 + sun_light * (0.3 + 1.6 * pow(max(c, 0.0), 6.0)) * 0.8;
	v_alpha = (1.0 - life) * (1.0 - smoothstep(16.0, 21.0, dist));
	v_life = life;
	if (fract(seed.w * 5.3 + cycle * 0.17) > 0.2 + 0.8 * rain) {
		VERTEX = vec3(0.0, 0.0, 10.0);
	} else {
		VERTEX = (VIEW_MATRIX * vec4(wp, 1.0)).xyz;
	}
}

void fragment() {
	float x = v_quad.x * 2.0;
	float y = v_quad.y;
	// A small crown: a rim that opens outward around a bright core.
	float dome = 1.0 - smoothstep(0.25, 1.0, length(vec2(x * 1.15, y * 1.5)));
	float crown = dome * (0.35 + 0.65 * smoothstep(0.25, 0.75, length(vec2(x, y * 1.4))));
	float core = (1.0 - smoothstep(0.0, 0.5, length(vec2(x * 1.6, (y - 0.25) * 1.6)))) * (1.0 - v_life);
	ALBEDO = v_col;
	ALPHA = clamp(crown * 0.5 + core * 0.8, 0.0, 1.0) * v_alpha * 0.6;
}
