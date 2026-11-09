shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_schlick_ggx;

// Facades from the OSM pipeline: UV.x = metres along facade, UV.y = height in metres.
// COLOR.rgb = tint, COLOR.a = 1 glass tower / 0 plaster (any value between blends).
uniform sampler2D tex_facade : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_facade_small : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_facade_double : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_plaster : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_plaster_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_concrete : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform float floor_h = 3.1;
uniform float window_w = 2.6;
uniform vec3 window_warm : source_color = vec3(1.0, 0.78, 0.45);
uniform vec3 window_cool : source_color = vec3(0.75, 0.85, 1.0);
uniform float window_glow = 2.4;
uniform float seed = 0.0;
// A small preview area near the Tirana starting grid. Outside it the original
// facade is retained, keeping this visual trial local to one stretch.
uniform float detail_preview = 0.0;
uniform vec2 detail_origin = vec2(0.0);
uniform float detail_radius = 220.0;

varying vec3 wpos;
varying vec4 vcol;
varying vec2 fuv;

float hash(vec2 p) {
	return fract(sin(dot(p + seed, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vcol = COLOR;
	fuv = UV;
}

void fragment() {
	float glass_w = vcol.a;
	// window grid
	float fx = fuv.x / window_w;
	float fy = fuv.y / floor_h;
	vec2 cell = floor(vec2(fx, fy));
	vec2 fr = fract(vec2(fx, fy));
	// window opening (centre of the cell), inset for plaster, near full for glass
	vec2 inset = mix(vec2(0.28, 0.3), vec2(0.06, 0.08), glass_w);
	float win = step(inset.x, fr.x) * step(fr.x, 1.0 - inset.x) * step(inset.y, fr.y) * step(fr.y, 1.0 - inset.y);
	// ground floor is a shop front / no windows row
	win *= step(0.95, fy);

	vec2 tuv = vec2(fuv.x, fuv.y) / 3.0;
	// Plaster and concrete only show through on partly glazed buildings: fully
	// masonry walls are replaced by the facade tile below and glass towers by
	// their tint, so neither needs these two fetches.
	vec2 tuv_dx = dFdx(tuv);
	vec2 tuv_dy = dFdy(tuv);
	vec3 wall = vcol.rgb;
	if (glass_w > 0.001 && glass_w < 0.999) {
		vec3 plaster = textureGrad(tex_plaster, tuv, tuv_dx, tuv_dy).rgb * vcol.rgb * 1.15;
		vec3 concrete = textureGrad(tex_concrete, tuv * 1.3, tuv_dx * 1.3, tuv_dy * 1.3).rgb * vcol.rgb;
		wall = mix(plaster, concrete, step(0.5, hash(floor(wpos.xz * 0.002))));
	}
	vec3 glass_wall = vcol.rgb * 0.35;
	vec3 base = mix(wall, glass_wall, glass_w);
	vec3 nrm = mix(texture(tex_plaster_n, tuv).rgb, vec3(0.5, 0.5, 1.0), glass_w);

	// window glass
	vec3 glass = mix(vec3(0.05, 0.07, 0.09), vec3(0.08, 0.1, 0.13), glass_w);
	vec3 col = mix(base, glass, win);
	float rough = mix(mix(0.85, 0.5, glass_w), 0.12, win);
	float metal = mix(0.0, 0.2, win);

	// Give windows a thin frame, inset shadow and subtle daylight reflection.
	// This adds no meshes or texture fetches and fades out beyond the preview.
	float preview = detail_preview * (1.0 - smoothstep(detail_radius - 35.0, detail_radius, distance(wpos.xz, detail_origin)));
	if (preview > 0.001) {
		float inner = smoothstep(inset.x + 0.035, inset.x + 0.055, fr.x)
			* (1.0 - smoothstep(1.0 - inset.x - 0.055, 1.0 - inset.x - 0.035, fr.x))
			* smoothstep(inset.y + 0.035, inset.y + 0.055, fr.y)
			* (1.0 - smoothstep(1.0 - inset.y - 0.055, 1.0 - inset.y - 0.035, fr.y)) * win;
		float frame = max(win - inner, 0.0);
		float pane_var = hash(cell + floor(wpos.xz * 0.011));
		float reflect_amount = mix(0.1, 0.36, pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0));
		vec3 pane = mix(vec3(0.11, 0.16, 0.19), vec3(0.37, 0.48, 0.52), reflect_amount + pane_var * 0.14);
		vec3 detailed_col = mix(col, mix(vec3(0.16, 0.17, 0.16), vec3(0.35, 0.36, 0.34), glass_w), frame);
		detailed_col = mix(detailed_col, pane, inner * (1.0 - night * 0.5));
		// Pale sills below masonry windows add a little depth at street level.
		float sill = step(inset.x - 0.04, fr.x) * step(fr.x, 1.0 - inset.x + 0.04)
			* step(inset.y - 0.045, fr.y) * step(fr.y, inset.y) * step(0.95, fy) * (1.0 - glass_w);
		detailed_col = mix(detailed_col, wall * 0.78, sill);
		col = mix(col, detailed_col, preview);
	}

	// A photographic-style facade tile rendered from Poly Haven's CC0 urban
	// window module. Apply it to masonry; glass towers retain their materials.
	// Building tint is constant across its walls, so the selected window style
	// stays consistent even as the camera moves or a wall crosses a chunk.
	float variant = hash(vcol.rg * 97.0 + vcol.b);
	vec2 facade_uv = vec2(fuv.x / 3.0, -fuv.y / 3.0);
	vec3 tile;
	if (variant < 0.33) {
		tile = texture(tex_facade_small, facade_uv).rgb;
	} else if (variant < 0.66) {
		tile = texture(tex_facade_double, facade_uv).rgb;
	} else {
		tile = texture(tex_facade, facade_uv).rgb;
	}
	float luminance = dot(tile, vec3(0.2126, 0.7152, 0.0722));
	// Preserve the source's blue glazing instead of converting the whole tile
	// to gray. The mask comes from the existing sample, so it costs no texture
	// reads and leaves the architectural frames in the neutral wall material.
	float pane_mask = smoothstep(0.02, 0.12, tile.b - tile.r);
	vec3 tint = mix(vec3(0.88, 0.86, 0.82), vcol.rgb, 0.24);
	vec3 masonry = vec3(luminance) * tint * 1.38;
	float grazing = 1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float fresnel = grazing * grazing * grazing;
	float pane_variation = 0.87 + 0.13 * vcol.r;
	vec3 window_color = tile * vec3(0.82, 0.96, 1.12) * pane_variation + vec3(0.08, 0.12, 0.15) * fresnel;
	vec3 detailed_facade = mix(masonry, window_color, pane_mask);
	col = mix(detailed_facade, col, glass_w);
	rough = mix(rough, mix(0.82, 0.28, pane_mask), 1.0 - glass_w);

	// lit windows at night (per window random, with slow flicker-free stability).
	// Daylight emits nothing, so the whole block is skipped.
	float emis = 0.0;
	vec3 emis_col = vec3(0.0);
	if (night > 0.001) {
		float lit = step(0.62 - 0.1 * glass_w, hash(cell + floor(wpos.xz * 0.013)));
		float warm_sel = hash(cell * 1.7 + 3.0);
		vec3 wcol = mix(window_cool, window_warm, step(0.35, warm_sel));
		emis = win * lit * night * window_glow;
		// dimmer upper floors so skyline is not uniform
		emis *= 0.6 + 0.4 * hash(cell.yy);

		// ground floor shop signage glow strip
		float sign = step(0.78, fract(fy)) * step(fy, 1.0) * step(0.2, fr.x) * step(fr.x, 0.8);
		vec3 sign_col = mix(vec3(1.0, 0.3, 0.6), vec3(0.2, 0.9, 1.0), step(0.5, hash(cell.xx + 11.0)));
		emis += sign * night * 1.5 * step(0.55, hash(floor(wpos.xz * 0.05) + 5.0));
		emis_col = mix(wcol, sign_col, sign);
	}

	// wet facades darken slightly at the base
	float wet = wetness * (1.0 - smoothstep(0.0, 3.0, fuv.y));
	col *= 1.0 - 0.3 * wet;
	rough = mix(rough, 0.2, wet);

	// dirt gradient at the bottom
	col *= 0.78 + 0.22 * smoothstep(0.0, 2.5, fuv.y);

	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.5;
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = 0.5 * (1.0 - win);
	EMISSION = emis_col * emis;
}
