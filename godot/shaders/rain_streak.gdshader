shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform, fog_disabled;

// Falling rain as camera-facing streaks. Each quad carries a random seed in
// UV (x, y) and UV2 (z, w); the vertex shader places it inside a box that
// wraps around the camera, so no drop is ever simulated on the CPU.
uniform float rain = 1.0;
uniform vec3 fall_velocity = vec3(-2.6, -9.4, 1.1);
uniform vec3 camera_velocity = vec3(0.0);
uniform vec3 box = vec3(26.0, 15.0, 26.0);
uniform vec3 to_sun = vec3(0.3, 0.8, 0.2);
uniform vec3 sun_light = vec3(1.0);
uniform vec3 ambient_light = vec3(0.2);
// World size of one screen pixel at one metre: keeps far streaks one pixel
// wide (and proportionally fainter) instead of letting them shimmer.
uniform float pixel_size = 0.002;
uniform float exposure_time = 0.03;

varying vec3 v_col;
varying float v_alpha;
varying vec2 v_quad;

void vertex() {
	vec4 seed = vec4(UV, UV2);
	v_quad = VERTEX.xy;
	vec3 cam = CAMERA_POSITION_WORLD;
	vec3 vel = fall_velocity * (0.82 + 0.36 * seed.w);
	vec3 p = seed.xyz * box + vel * TIME;
	p = mod(p - cam + 0.5 * box, box) - 0.5 * box + cam;
	// A streak is the drop's path during one exposure as seen from the moving
	// camera, so rain rushes towards a fast car instead of falling straight.
	vec3 rel = vel - camera_velocity;
	float speed = length(rel);
	vec3 dir = rel / max(speed, 0.001);
	float len = min(exposure_time * speed, 2.5);
	vec3 to_p = p - cam;
	float dist = length(to_p);
	vec3 side = normalize(cross(dir, to_p));
	float w0 = 0.005 + 0.004 * fract(seed.w * 3.7);
	float w = max(w0, dist * pixel_size * 0.75);
	vec3 wp = p + dir * (len * (v_quad.y - 0.5)) + side * (w * v_quad.x);
	float a = (w0 / w) * smoothstep(0.7, 2.6, dist) * (1.0 - smoothstep(0.38, 0.5, dist / box.x));
	// Drops glint when looking towards the light.
	float c = dot(to_p / max(dist, 0.001), to_sun);
	float phase = 0.3 + 1.6 * pow(max(c, 0.0), 6.0);
	v_col = ambient_light + sun_light * phase;
	v_alpha = a * (0.55 + 0.45 * fract(seed.w * 13.3));
	if (fract(seed.w * 7.13 + seed.x) > rain) {
		// Thinned out: collapse behind the camera.
		VERTEX = vec3(0.0, 0.0, 10.0);
	} else {
		VERTEX = (VIEW_MATRIX * vec4(wp, 1.0)).xyz;
	}
}

void fragment() {
	float across = 1.0 - abs(v_quad.x) * 2.0;
	float along = smoothstep(0.0, 0.12, v_quad.y) * (1.0 - smoothstep(0.55, 1.0, v_quad.y));
	ALBEDO = v_col;
	ALPHA = v_alpha * across * along;
}
