'use strict';
// ---------- small math helpers ----------
const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
const lerp = (a, b, t) => a + (b - a) * t;
const smooth = (a, b, x) => { const t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); };
const wrapAng = (a) => { while (a > Math.PI) a -= 2 * Math.PI; while (a < -Math.PI) a += 2 * Math.PI; return a; };
const sign = (v) => (v < 0 ? -1 : 1);
function mulberry32(a) {
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
function strHash(s) { let h = 2166136261; for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); } return h >>> 0; }
// value-noise fbm, deterministic per seed
function makeNoise(seed) {
  const r = mulberry32(seed);
  const perm = []; for (let i = 0; i < 256; i++) perm.push(i);
  for (let i = 255; i > 0; i--) { const j = Math.floor(r() * (i + 1)); const t = perm[i]; perm[i] = perm[j]; perm[j] = t; }
  const P = new Uint16Array(512); for (let i = 0; i < 512; i++) P[i] = perm[i & 255];
  const V = new Float32Array(256); for (let i = 0; i < 256; i++) V[i] = r() * 2 - 1;
  function n2(x, y) {
    const xi = Math.floor(x), yi = Math.floor(y), xf = x - xi, yf = y - yi;
    const u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf);
    const X0 = xi & 255, X1 = (xi + 1) & 255, Y0 = P[yi & 255], Y1 = P[(yi + 1) & 255];
    const a = V[P[X0 + Y0]], b = V[P[X1 + Y0]], c = V[P[X0 + Y1]], d = V[P[X1 + Y1]];
    return lerp(lerp(a, b, u), lerp(c, d, u), v);
  }
  return function fbm(x, y, oct) {
    oct = oct || 3; let s = 0, a = 1, f = 1, t = 0;
    for (let i = 0; i < oct; i++) { s += a * n2(x * f + i * 17.3, y * f - i * 9.1); t += a; a *= 0.5; f *= 2.03; }
    return s / t;
  };
}
function fmtTime(t) {
  if (!isFinite(t) || t < 0) return '--:--.--';
  const m = Math.floor(t / 60), s = t - m * 60;
  return m + ':' + (s < 10 ? '0' : '') + s.toFixed(2);
}
function hexToRgb(hex) { const n = parseInt(hex.slice(1), 16); return [(n >> 16 & 255) / 255, (n >> 8 & 255) / 255, (n & 255) / 255]; }
function pick(arr, r) { return arr[Math.floor(r() * arr.length) % arr.length]; }
