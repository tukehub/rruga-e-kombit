// Skanderbeg Square's paving: rows of rectangular stone slabs of uneven
// width, each a different stone from a small palette (cream, ochre, greys,
// slate, brown, rose), with thin dark joints and a soft sheen.
// `p` is the position on the ground in metres.

const float SQ_ROW = 1.2;      // depth of a row of slabs, metres
const float SQ_CELL = 1.35;     // mean width of a slab

float sq_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float sq_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(sq_hash(i), sq_hash(i + vec2(1.0, 0.0)), f.x),
		mix(sq_hash(i + vec2(0.0, 1.0)), sq_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Where the joint on the left of slab `i` in `row` lies: slabs differ in width.
float sq_joint(float i, float row) {
	return (i + (sq_hash(vec2(i, row * 7.3 + 1.7)) - 0.5) * 0.62 + sq_hash(vec2(row, 91.0))) * SQ_CELL;
}

vec3 sq_stone(float pick) {
	// Weighted towards the light stones, as on the square.
	if (pick < 0.17) return vec3(0.80, 0.74, 0.60);   // cream limestone
	if (pick < 0.31) return vec3(0.70, 0.59, 0.40);   // ochre
	if (pick < 0.46) return vec3(0.68, 0.65, 0.60);   // light grey
	if (pick < 0.60) return vec3(0.52, 0.50, 0.47);   // mid grey
	if (pick < 0.72) return vec3(0.36, 0.34, 0.34);   // dark slate
	if (pick < 0.83) return vec3(0.50, 0.39, 0.31);   // brown
	if (pick < 0.92) return vec3(0.66, 0.50, 0.46);   // rose
	return vec3(0.58, 0.55, 0.46);                    // olive grey
}

// Returns the paving colour; `rough` and `joint` (1 on a joint) come back too.
vec3 square_paving(vec2 p, out float rough, out float joint) {
	float row = floor(p.y / SQ_ROW);
	float i = floor(p.x / SQ_CELL - sq_hash(vec2(row, 91.0)));
	float left = sq_joint(i, row);
	float right = sq_joint(i + 1.0, row);
	if (p.x < left) {
		i -= 1.0;
		right = left;
		left = sq_joint(i, row);
	} else if (p.x >= right) {
		i += 1.0;
		left = right;
		right = sq_joint(i + 1.0, row);
	}
	vec2 slab = vec2(i, row);
	vec3 stone = sq_stone(sq_hash(slab + vec2(3.1, 5.7)));
	// Each slab has its own tone, mottling and a few veins.
	float tone = 0.88 + 0.24 * sq_hash(slab + vec2(11.0, 2.0));
	float mottle = sq_noise(p * 2.3 + slab * 13.0) * 0.6 + sq_noise(p * 7.0 + slab * 5.0) * 0.4;
	float vein = smoothstep(0.47, 0.5, sq_noise(p * vec2(1.1, 3.4) + slab * 9.0))
		* (1.0 - smoothstep(0.5, 0.53, sq_noise(p * vec2(1.1, 3.4) + slab * 9.0)));
	vec3 col = stone * tone * (0.86 + 0.26 * mottle);
	col = mix(col, col * 1.12 + 0.02, vein * 0.2);
	// Weathered stone is less colourful than a fresh sample.
	col = mix(vec3(dot(col, vec3(0.299, 0.587, 0.114))), col, 0.68);
	// Joints, kept about a pixel wide in the distance.
	float edge = min(min(p.x - left, right - p.x), min(p.y - row * SQ_ROW, (row + 1.0) * SQ_ROW - p.y));
	float px = max(fwidth(p.x), fwidth(p.y));
	joint = 1.0 - smoothstep(0.008, 0.008 + max(px, 0.005), edge);
	// Far away, slabs smaller than a pixel settle into the square's mean tone.
	float far = smoothstep(SQ_ROW * 0.35, SQ_ROW * 1.4, px);
	col = mix(col, vec3(0.58, 0.54, 0.47), far);
	joint *= 1.0 - smoothstep(0.02, 0.12, px);
	col = mix(col, col * 0.45, joint);
	// The palette above is written as display colours; shading wants linear light.
	col = pow(col, vec3(2.2));
	// Honed stone with a soft sheen: slabs differ a little, joints are matt.
	rough = mix(0.62 + 0.16 * sq_hash(slab + vec2(7.0, 19.0)), 0.95, joint);
	return col;
}
