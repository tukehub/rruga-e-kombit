// ---------- geometry builder ----------
class GB {
  constructor(hasUV) { this.P = []; this.N = []; this.C = []; this.U = hasUV ? [] : null; this.I = []; }
  get count() { return this.P.length / 3; }
  face(pts, col, uvs, inside) {
    const a = pts[0], b = pts[1], c = pts[2];
    let nx = (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1]);
    let ny = (b[2] - a[2]) * (c[0] - a[0]) - (b[0] - a[0]) * (c[2] - a[2]);
    let nz = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]);
    const l = Math.hypot(nx, ny, nz) || 1; nx /= l; ny /= l; nz /= l;
    if (inside) {
      let cx = 0, cy = 0, cz = 0; for (const p of pts) { cx += p[0]; cy += p[1]; cz += p[2]; }
      cx /= pts.length; cy /= pts.length; cz /= pts.length;
      if ((cx - inside[0]) * nx + (cy - inside[1]) * ny + (cz - inside[2]) * nz < 0) {
        pts = pts.slice().reverse(); if (uvs) uvs = uvs.slice().reverse(); nx = -nx; ny = -ny; nz = -nz;
      }
    }
    const base = this.count;
    for (let k = 0; k < pts.length; k++) {
      const p = pts[k]; this.P.push(p[0], p[1], p[2]); this.N.push(nx, ny, nz); this.C.push(col[0], col[1], col[2]);
      if (this.U) { const uv = uvs ? uvs[k] : null; this.U.push(uv ? uv[0] : 0.01, uv ? uv[1] : 0.01); }
    }
    if (pts.length === 3) this.I.push(base, base + 1, base + 2);
    else this.I.push(base, base + 1, base + 2, base, base + 2, base + 3);
  }
  // axis-aligned (in frame F) box; o: {bottom, taperX, taperZ, shiftZ, uv:(faceIdx,w,h)=>uvs}
  box(F, cx, cy, cz, sx, sy, sz, col, o) {
    o = o || {};
    const x0 = cx - sx / 2, x1 = cx + sx / 2, y0 = cy - sy / 2, y1 = cy + sy / 2, z0 = cz - sz / 2, z1 = cz + sz / 2;
    const tx = (o.taperX == null ? 1 : o.taperX) * sx / 2, tz = (o.taperZ == null ? 1 : o.taperZ) * sz / 2, sh = o.shiftZ || 0;
    const B = [tp(F, x0, y0, z0), tp(F, x1, y0, z0), tp(F, x1, y0, z1), tp(F, x0, y0, z1)];
    const T = [tp(F, cx - tx, y1, cz - tz + sh), tp(F, cx + tx, y1, cz - tz + sh), tp(F, cx + tx, y1, cz + tz + sh), tp(F, cx - tx, y1, cz + tz + sh)];
    const ins = tp(F, cx, cy, cz);
    const walls = [[0, 1], [1, 2], [2, 3], [3, 0]];
    for (let k = 0; k < 4; k++) {
      const a = walls[k][0], b = walls[k][1];
      const w = k % 2 === 0 ? sx : sz;
      this.face([B[a], B[b], T[b], T[a]], o.cols ? o.cols[k] : col, o.uv ? o.uv(k, w, sy) : null, ins);
    }
    if (!o.noTop) this.face([T[0], T[1], T[2], T[3]], o.topCol || col, null, ins);
    if (o.bottom) this.face([B[0], B[1], B[2], B[3]], col, null, ins);
  }
  cyl(F, cx, y0, cz, r0, r1, h, seg, col, o) {
    o = o || {};
    const ins = tp(F, cx, y0 + h * 0.4, cz), a0 = o.rot || 0;
    const ring = (r, y) => { const a = []; for (let i = 0; i < seg; i++) { const t = a0 + i / seg * Math.PI * 2; a.push(tp(F, cx + Math.cos(t) * r, y, cz + Math.sin(t) * r)); } return a; };
    const B = ring(r0, y0), T = r1 > 0 ? ring(r1, y0 + h) : null, apex = tp(F, cx, y0 + h, cz);
    for (let i = 0; i < seg; i++) {
      const j = (i + 1) % seg;
      if (T) this.face([B[i], B[j], T[j], T[i]], col, null, ins); else this.face([B[i], B[j], apex], col, null, ins);
    }
    if (T && o.top !== false) { const c = tp(F, cx, y0 + h, cz); for (let i = 0; i < seg; i++) this.face([T[i], T[(i + 1) % seg], c], o.topCol || col, null, ins); }
  }
  // horizontal-axis cylinder (wheels) along local x
  wheel(F, cx, cy, cz, r, w, seg, col, hub) {
    const ins = tp(F, cx, cy, cz), ring = (x) => { const a = []; for (let i = 0; i < seg; i++) { const t = i / seg * Math.PI * 2; a.push(tp(F, x, cy + Math.cos(t) * r, cz + Math.sin(t) * r)); } return a; };
    const A = ring(cx - w / 2), B = ring(cx + w / 2);
    for (let i = 0; i < seg; i++) { const j = (i + 1) % seg; this.face([A[i], A[j], B[j], B[i]], col, null, ins); }
    const ca = tp(F, cx - w / 2, cy, cz), cb = tp(F, cx + w / 2, cy, cz);
    for (let i = 0; i < seg; i++) { const j = (i + 1) % seg; this.face([A[i], A[j], ca], hub || col, null, ins); this.face([B[i], B[j], cb], hub || col, null, ins); }
  }
  dome(F, cx, y0, cz, r, seg, rings, col, sy) {
    sy = sy || 1; const ins = tp(F, cx, y0 + 0.01, cz);
    const P = [];
    for (let k = 0; k <= rings; k++) { const ph = k / rings * Math.PI / 2, rr = Math.cos(ph) * r, y = y0 + Math.sin(ph) * r * sy; const row = []; for (let i = 0; i < seg; i++) { const t = i / seg * Math.PI * 2; row.push(tp(F, cx + Math.cos(t) * rr, y, cz + Math.sin(t) * rr)); } P.push(row); }
    for (let k = 0; k < rings; k++) for (let i = 0; i < seg; i++) {
      const j = (i + 1) % seg;
      if (k === rings - 1) this.face([P[k][i], P[k][j], P[k + 1][0]], col, null, ins);
      else this.face([P[k][i], P[k][j], P[k + 1][j], P[k + 1][i]], col, null, ins);
    }
  }
  blob(F, cx, cy, cz, r, col, sy, rng) {
    const ins = tp(F, cx, cy, cz);
    for (let f = 0; f < ICO.length; f += 9) {
      const pts = [];
      for (let k = 0; k < 3; k++) { const j = 1 + (rng ? (rng() - 0.5) * 0.25 : 0); pts.push(tp(F, cx + ICO[f + k * 3] * r * j, cy + ICO[f + k * 3 + 1] * r * sy * j, cz + ICO[f + k * 3 + 2] * r * j)); }
      this.face(pts, col, null, ins);
    }
  }
  build() {
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(this.P, 3));
    g.setAttribute('normal', new THREE.Float32BufferAttribute(this.N, 3));
    g.setAttribute('color', new THREE.Float32BufferAttribute(this.C, 3));
    if (this.U) g.setAttribute('uv', new THREE.Float32BufferAttribute(this.U, 2));
    const nv = this.count;
    g.setIndex(nv > 65000 ? new THREE.Uint32BufferAttribute(this.I, 1) : new THREE.Uint16BufferAttribute(this.I, 1));
    g.computeBoundingSphere();
    return g;
  }
}
const ICO = (() => { let g = new THREE.IcosahedronGeometry(1, 0); if (g.index) g = g.toNonIndexed(); return Array.from(g.attributes.position.array); })();
function fr(x, y, z, a) { return { x, y, z, c: Math.cos(a), s: Math.sin(a) }; }
function tp(F, lx, ly, lz) { return [F.x + lx * F.c + lz * F.s, F.y + ly, F.z - lx * F.s + lz * F.c]; }
const F0 = fr(0, 0, 0, 0);
const colCache = {};
function C3(hex) { let c = colCache[hex]; if (!c) { c = colCache[hex] = hexToRgb(hex).map(toLin); } return c; }
function mixC(a, b, t) { return [lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t)]; }
function shadeC(c, f) { return [c[0] * f, c[1] * f, c[2] * f]; }

// ---------- World ----------
const BAND_COLS = ['#ff2d6f', '#2de2ff', '#ffd23a', '#b45cff', '#38ff6a', '#ff7a3d', '#ffffff'];
class World {
  constructor(track, quality, renderer) {
    this.track = track; this.city = track.city; this.env = ENV[this.city.env]; this.q = quality;
    this.rng = mulberry32(track.seed ^ 0x51ed27);
    this.scene = new THREE.Scene();
    this.dyn = []; this.wavers = []; this.neonMats = [];
    const hw = this.hw = track.halfW;
    this.renderer = renderer;
    this.maxAniso = renderer ? renderer.capabilities.getMaxAnisotropy() : 4;
    this.setupOcc();
    this.buildSky();
    this.buildTerrain();
    this.buildWater();
    this.buildRoad();
    this.buildStart();
    this.buildLandmarks();
    this.buildBuildings();
    this.buildProps();
    this.buildMountains();
    if (this.city.canyon) this.buildCanyon();
    if (renderer) { this.envRT = makeEnvMap(renderer, this.env, this.city.neon); this.scene.environment = this.envRT.texture; }
    const envI = this.env.win >= 0.45 ? 0.55 : 0.8;
    this.scene.traverse(o => { const m = o.material; if (m && m.isMeshStandardMaterial && m.userData.envI == null) m.envMapIntensity = envI; });
    linearize(this.scene);
    this.scene.fog.color.convertSRGBToLinear(); this.scene.background.convertSRGBToLinear();
  }
  // ground height used by everything placed on the terrain (road-flattened)
  groundAt(x, z) {
    const T = this.track, hw = this.hw; const h = T.H(x, z);
    const n = T.nearest(x, z, 75); if (!n) return h;
    const w = 1 - smooth(hw + 9, hw + 42, n.d);
    return lerp(h, T.Y[n.i] - 0.25, w);
  }
  setupOcc() {
    const b = this.track.bbox; this.oc = { x0: b.minX - 700, z0: b.minZ - 700, cs: 4 };
    this.oc.nx = Math.ceil((b.maxX - b.minX + 1400) / 4); this.oc.nz = Math.ceil((b.maxZ - b.minZ + 1400) / 4);
    this.occ = new Uint8Array(this.oc.nx * this.oc.nz);
  }
  occIdx(x, z) { const ix = Math.floor((x - this.oc.x0) / 4), iz = Math.floor((z - this.oc.z0) / 4); if (ix < 0 || iz < 0 || ix >= this.oc.nx || iz >= this.oc.nz) return -1; return iz * this.oc.nx + ix; }
  occRect(cx, cz, tx, tz, hl, hd, mark) { // rect centred at c with axes t (len hl) and n (len hd)
    const nx = -tz, nz = tx;
    for (let a = -hl; a <= hl + 0.01; a += 2) for (let b = -hd; b <= hd + 0.01; b += 2) {
      const i = this.occIdx(cx + tx * a + nx * b, cz + tz * a + nz * b);
      if (i < 0) { if (!mark) return false; continue; }
      if (mark) this.occ[i] = 1; else if (this.occ[i]) return false;
    }
    return true;
  }
  occCircle(cx, cz, r) { for (let a = -r; a <= r; a += 3) for (let b = -r; b <= r; b += 3) { if (a * a + b * b > r * r) continue; const i = this.occIdx(cx + a, cz + b); if (i >= 0) this.occ[i] = 1; } }
  isWater(x, z) { return this.track.water ? this.track.H(x, z) < 1.1 : false; }
  // ---------------- sky ----------------
  buildSky() {
    const env = this.env, sc = this.scene;
    const top = new THREE.Color(env.sky[0]), hor = new THREE.Color(env.sky[1]), fogc = new THREE.Color(env.fog[0]), glow = env.glow ? new THREE.Color(env.glow) : null;
    sc.fog = new THREE.Fog(fogc, env.fog[1], env.fog[2] * (this.q.fogMul || 1));
    sc.background = fogc.clone();
    const g = new THREE.SphereGeometry(3000, 32, 16), pos = g.attributes.position, cols = [];
    for (let i = 0; i < pos.count; i++) {
      const y = pos.getY(i) / 3000; let c;
      if (y > 0) c = hor.clone().lerp(top, Math.pow(Math.min(1, y * 1.6), 0.7)); else c = hor.clone().lerp(fogc, Math.min(1, -y * 4));
      if (glow && y > -0.05 && y < 0.2) c.lerp(glow, Math.pow(1 - Math.abs(y - 0.02) / 0.2, 2) * 0.55);
      c.convertSRGBToLinear(); cols.push(c.r, c.g, c.b);
    }
    g.setAttribute('color', new THREE.Float32BufferAttribute(cols, 3));
    this.sky = new THREE.Mesh(g, new THREE.MeshBasicMaterial({ vertexColors: true, side: THREE.BackSide, fog: false, depthWrite: false, toneMapped: false })); _linDone.add(this.sky.material);
    this.sky.renderOrder = -10; sc.add(this.sky);
    const sd = new THREE.Vector3().fromArray(env.sun.dir).normalize(); this.sunDir = sd;
    const sunM = new THREE.SpriteMaterial({ map: TEX.glow, color: new THREE.Color(env.sun.col), fog: false, depthWrite: false, transparent: true, blending: THREE.AdditiveBlending, toneMapped: false }); sunM.userData.hdr = env.moon ? 2.2 : 2.6;
    this.sun = new THREE.Sprite(sunM); const ss = env.moon ? 160 : (sd.y < 0.3 ? 520 : 300); this.sun.scale.set(ss, ss, 1); this.sun.renderOrder = -9; sc.add(this.sun);
    if (env.stars) {
      const r = this.rng, p = [];
      for (let i = 0; i < 900; i++) { const th = r() * Math.PI * 2, y = 0.08 + r() * 0.92, rr = Math.sqrt(1 - y * y); p.push(Math.cos(th) * rr * 2800, y * 2800, Math.sin(th) * rr * 2800); }
      const sg = new THREE.BufferGeometry(); sg.setAttribute('position', new THREE.Float32BufferAttribute(p, 3));
      this.stars = new THREE.Points(sg, new THREE.PointsMaterial({ color: 0xdfe6ff, size: 1.6, sizeAttenuation: false, fog: false, transparent: true, opacity: 0.9, depthWrite: false, toneMapped: false }));
      this.stars.renderOrder = -9; sc.add(this.stars);
    }
    const hemi = new THREE.HemisphereLight(new THREE.Color(env.hemi[0]), new THREE.Color(env.hemi[1]), env.hemi[2]);
    sc.add(hemi);
    const dl = new THREE.DirectionalLight(new THREE.Color(env.sun.col), env.sun.i); dl.position.copy(sd).multiplyScalar(100); sc.add(dl); sc.add(dl.target); this.dl = dl;
    if (this.q.shadows) {
      dl.castShadow = true; dl.shadow.mapSize.set(this.q.shadows, this.q.shadows);
      const sc2 = dl.shadow.camera; sc2.left = -70; sc2.right = 70; sc2.top = 70; sc2.bottom = -70; sc2.near = 1; sc2.far = 400; sc2.updateProjectionMatrix();
      dl.shadow.bias = -0.0006; dl.shadow.normalBias = 0.04;
    }
  }
  // ---------------- terrain ----------------
  buildTerrain() {
    const T = this.track, b = T.bbox, c = this.city, q = this.q, hw = this.hw, noise = makeNoise(T.seed + 99);
    const inner = q.terrainStep, ext = 900;
    const axis = (lo, hi) => {
      const a = [];
      for (let x = lo - ext, st = 60; x < lo - 320; x += st) a.push(x);
      for (let x = lo - 320; x <= hi + 320; x += inner) a.push(x);
      for (let x = hi + 320 + 30; x <= hi + ext; x += 60) a.push(x);
      return a;
    };
    const xs = axis(b.minX, b.maxX), zs = axis(b.minZ, b.maxZ), nx = xs.length, nz = zs.length;
    const pos = new Float32Array(nx * nz * 3), col = new Float32Array(nx * nz * 3);
    const G = {
      urban: [C3('#6c6964'), C3('#5d6b44'), C3('#76684f')], grass: [C3('#5e7a3c'), C3('#4f6b34'), C3('#7a7a50')],
      dry: [C3('#8c8257'), C3('#6f7a46'), C3('#a08d63')], snow: [C3('#e9eef6'), C3('#d5dde8'), C3('#bfc8d4')],
    }[c.ground] || [C3('#5e7a3c'), C3('#4f6b34'), C3('#7a7a50')];
    const sand = C3('#d8c69a'), wet = C3('#5b6a60'), rock = C3('#7d776d'), concrete = C3('#77736d');
    for (let j = 0; j < nz; j++) for (let i = 0; i < nx; i++) {
      const x = xs[i], z = zs[j], k = (j * nx + i) * 3;
      let h = T.H(x, z); const n = T.nearest(x, z, 75);
      let dist = n ? n.d : 999;
      if (n) h = lerp(h, T.Y[n.i] - 0.25, 1 - smooth(hw + 9, hw + 42, n.d));
      pos[k] = x; pos[k + 1] = h; pos[k + 2] = z;
      const nv = noise(x / 60, z / 60, 2);
      let cc = nv > 0.1 ? mixC(G[0], G[1], smooth(0.1, 0.5, nv)) : mixC(G[0], G[2], smooth(0.1, -0.4, nv));
      if (c.ground === 'urban' && dist < hw + 70) cc = mixC(concrete, cc, smooth(hw + 20, hw + 70, dist));
      else if (dist < hw + 16) cc = mixC(shadeC(G[0], 0.82), cc, smooth(hw + 5, hw + 16, dist));
      if (T.water) { if (h < 1.6 && h > -0.6) cc = mixC(sand, cc, smooth(1.0, 1.6, h)); if (h <= -0.6) cc = mixC(wet, sand, smooth(-5, -0.6, h)); }
      if (c.ground !== 'snow' && h > 30) cc = mixC(cc, rock, smooth(30, 55, h) * 0.6);
      col[k] = cc[0]; col[k + 1] = cc[1]; col[k + 2] = cc[2];
    }
    const idx = [];
    for (let j = 0; j < nz - 1; j++) for (let i = 0; i < nx - 1; i++) { const a = j * nx + i, b2 = a + 1, c2 = a + nx, d = c2 + 1; idx.push(a, c2, b2, b2, c2, d); }
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(pos, 3)); g.setAttribute('color', new THREE.BufferAttribute(col, 3));
    g.setIndex(nx * nz > 65000 ? new THREE.Uint32BufferAttribute(idx, 1) : new THREE.Uint16BufferAttribute(idx, 1));
    g.computeVertexNormals();
    const m = new THREE.Mesh(g, new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.95 })); m.receiveShadow = true;
    this.scene.add(m); this.terrain = m;
    this.groundCol = G[0];
  }
  buildWater() {
    const w = this.track.water; if (!w) return;
    const night = this.env.win >= 0.45, col = w.type === 'sea' ? (night ? '#071a28' : '#1f6d8c') : (night ? '#0a1e2c' : '#2f7380');
    const mat = new THREE.MeshStandardMaterial({ color: new THREE.Color(col), roughness: 0.1, metalness: 0.3, transparent: true, opacity: 0.92 }); mat.userData.envI = 1.4; mat.envMapIntensity = 1.4;
    let g;
    if (w.type === 'sea') { g = new THREE.PlaneGeometry(9000, 9000, 1, 1); }
    else { g = new THREE.CircleGeometry(w.r * 1.3, 48); }
    g.rotateX(-Math.PI / 2);
    const m = new THREE.Mesh(g, mat);
    if (w.type === 'lake') m.position.set(w.x, 0, w.z);
    m.position.y = 0; this.scene.add(m); this.water = m;
  }
  // ---------------- road, sidewalks, barriers ----------------
  ribbon(fn, uvFn, mat, extra) {
    const T = this.track, M = T.M, P = [], U = [], C = [], I = [];
    const v = new THREE.Vector3();
    for (let i = 0; i <= M; i++) {
      const k = i % M, s = i * T.ds;
      const rows = fn(k, s);
      for (let r = 0; r < rows.length; r++) {
        const [d, dy] = rows[r];
        P.push(T.X[k] + T.NX[k] * d, T.Y[k] + dy, T.Z[k] + T.NZ[k] * d);
        const uv = uvFn(r, s, d); U.push(uv[0], uv[1]);
        if (extra) { const cc = extra(r, k); C.push(cc[0], cc[1], cc[2]); }
      }
    }
    const R = fn(0, 0).length;
    for (let i = 0; i < M; i++) for (let r = 0; r < R - 1; r++) {
      const a = i * R + r, b = a + 1, c = a + R, d = c + 1;
      I.push(a, b, c, b, d, c);
    }
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(P, 3)); g.setAttribute('uv', new THREE.Float32BufferAttribute(U, 2));
    if (extra) g.setAttribute('color', new THREE.Float32BufferAttribute(C, 3));
    g.setIndex(P.length / 3 > 65000 ? new THREE.Uint32BufferAttribute(I, 1) : new THREE.Uint16BufferAttribute(I, 1));
    g.computeVertexNormals();
    const m = new THREE.Mesh(g, mat); m.receiveShadow = true; this.scene.add(m); return m;
  }
  buildRoad() {
    const hw = this.hw, env = this.env, c = this.city;
    const rt = roadTex(c.road === 'cobble' ? 'cobble' : (env.snow ? 'snow' : 'asphalt'), env.wet); rt.anisotropy = Math.min(8, this.maxAniso);
    const roadM = new THREE.MeshStandardMaterial({ map: rt, color: env.wet ? 0xb8c0cc : 0xffffff, roughness: env.wet ? 0.2 : (env.win >= 0.45 ? 0.42 : 0.62), metalness: 0.05 }); roadM.userData.envI = env.wet ? 1.6 : 1.0; roadM.envMapIntensity = roadM.userData.envI;
    this.ribbon((k) => [[-hw - 0.2, 0.05], [hw + 0.2, 0.05]], (r, s) => [r ? 1 : 0, s / 16], roadM);
    const sw = TEX.sidewalk;
    for (const sd of [-1, 1]) {
      const rows = (k) => sd > 0 ? [[hw + 0.45, 0.22], [hw + 4.2, 0.22], [hw + 4.2, -0.6]] : [[-hw - 4.2, -0.6], [-hw - 4.2, 0.22], [-hw - 0.45, 0.22]];
      this.ribbon(rows, (r, s, d) => [Math.abs(d) / 4, s / 4], new THREE.MeshStandardMaterial({ map: sw, color: env.snow ? 0xf2f6ff : 0xffffff, roughness: 0.85 }));
      // barrier: inner face (banner), top, outer face
      const bt = this.barrierT || (this.barrierT = barrierTex(c.neon));
      const inner = sd > 0 ? [[hw + 0.12, -0.45], [hw + 0.12, 1.05]] : [[-hw - 0.12, 1.05], [-hw - 0.12, -0.45]];
      this.ribbon(() => inner, (r, s) => [-s / 12 * sd, (sd > 0 ? r : 1 - r) ? 1 : -0.5], new THREE.MeshStandardMaterial({ map: bt, emissive: 0xffffff, emissiveMap: bt, emissiveIntensity: env.win > 0.5 ? 0.25 : 0.04, roughness: 0.5 }));
      const top = sd > 0 ? [[hw + 0.12, 1.05], [hw + 0.42, 1.05], [hw + 0.42, -0.4]] : [[-hw - 0.42, -0.4], [-hw - 0.42, 1.05], [-hw - 0.12, 1.05]];
      this.ribbon(() => top, () => [0, 0], new THREE.MeshStandardMaterial({ color: 0x2a2630, roughness: 0.4, metalness: 0.6 }));
      // neon reflected on the asphalt (fake wet-street reflection)
      if (env.win >= 0.45) {
        const nc = C3(c.neon), refl = (env.wet ? 0.55 : 0.32), cc = [nc[0] * refl, nc[1] * refl, nc[2] * refl], z = [0, 0, 0];
        const rows = [[sd * (hw - 0.05), 0.08], [sd * (hw - 1.2), 0.08], [sd * (hw - 4.5), 0.08]];
        const rm = new THREE.MeshBasicMaterial({ vertexColors: true, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false, side: THREE.DoubleSide });
        _linDone.add(rm); this.ribbon(() => rows, () => [0, 0], rm, (r) => (r === 0 ? cc : r === 1 ? [cc[0] * 0.45, cc[1] * 0.45, cc[2] * 0.45] : z));
      }
      // neon strip (blooms)
      const ns = sd > 0 ? [[hw + 0.07, 0.84], [hw + 0.07, 1.12]] : [[-hw - 0.07, 1.12], [-hw - 0.07, 0.84]];
      this.ribbon(() => ns, () => [0, 0], this.neonStripM || (this.neonStripM = glowMat(c.neon, env.win >= 0.45 ? 4.5 : 2.2)));
    }
  }
  buildStart() {
    const T = this.track, hw = this.hw, sc = this.scene, c = this.city;
    const p = new THREE.Vector3(); T.pos(0, 0, p); const hd = T.heading(0);
    const ang = Math.atan2(T.NZ[0], -T.NX[0]); // rotation so local +z = track tangent
    const tang = Math.atan2(T.TX[0], T.TZ[0]);
    // checkered line
    const ck = canvasTex(256, 32, (g) => { for (let i = 0; i < 16; i++) for (let j = 0; j < 2; j++) { g.fillStyle = (i + j) % 2 ? '#111' : '#f4f4f4'; g.fillRect(i * 16, j * 16, 16, 16); } });
    const lg = new THREE.PlaneGeometry(hw * 2, 2.6); lg.rotateX(-Math.PI / 2);
    const line = new THREE.Mesh(lg, new THREE.MeshStandardMaterial({ map: ck, roughness: 0.6 })); line.receiveShadow = true; line.position.set(p.x, p.y + 0.08, p.z); line.rotation.y = tang; sc.add(line);
    // gantry
    const gb = new GB(false), F = fr(p.x, p.y, p.z, tang);
    const steel = C3('#2b2733'), red = C3('#c4161c');
    for (const sd of [-1, 1]) { gb.box(F, sd * (hw + 1.2), 5, 0, 1.4, 10.5, 1.4, steel); gb.box(F, sd * (hw + 1.2), 0.4, 0, 2.4, 1.2, 2.4, red); }
    gb.box(F, 0, 9.6, 0, hw * 2 + 4, 2.2, 1.0, steel);
    const gm = new THREE.Mesh(gb.build(), new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.45, metalness: 0.5 })); gm.castShadow = true; sc.add(gm);
    const gl = new GB(false); gl.box(F, 0, 8.4, 0.25, hw * 2 + 2, 0.18, 0.18, [1, 1, 1]); gl.box(F, 0, 8.4, -0.25, hw * 2 + 2, 0.18, 0.18, [1, 1, 1]);
    for (const sd of [-1, 1]) gl.box(F, sd * (hw + 0.45), 4.5, 0, 0.12, 8, 0.12, [1, 1, 1]);
    sc.add(new THREE.Mesh(gl.build(), glowMat(c.neon, 4, { vertexColors: true })));
    const st = signTex('KAFSHIM ASFALTI', c.name.toUpperCase() + ' · ' + REGIONS[c.region].toUpperCase(), '#141016', '#ffffff');
    const sm = new THREE.MeshBasicMaterial({ map: st, toneMapped: false }); sm.userData.hdr = 1.15;
    for (const fz of [-0.52, 0.52]) {
      const sg = new THREE.PlaneGeometry(hw * 2 + 2, 3.2); const s = new THREE.Mesh(sg, sm);
      const q = tp(F, 0, 9.6, fz); s.position.set(q[0], q[1], q[2]); s.rotation.y = tang + (fz < 0 ? Math.PI : 0); sc.add(s);
    }
    // flags on the pillars
    for (const sd of [-1, 1]) this.addFlag(tp(F, sd * (hw + 1.2), 10.4, 0), tang + Math.PI / 2, 3.2, true);
  }
  addFlag(base, ang, size, wave) {
    if (!wave) { // merged static flags
      const fg = this.flagGB || (this.flagGB = new GB(true)), F = fr(base[0], base[1], base[2], ang);
      const a = tp(F, 0, -size, 0), b = tp(F, size * 1.4, -size, 0), c = tp(F, size * 1.4, 0, 0), d = tp(F, 0, 0, 0);
      fg.face([a, b, c, d], [1, 1, 1], [[0, 0], [1, 0], [1, 1], [0, 1]]);
      return;
    }
    const g = new THREE.PlaneGeometry(size * 1.4, size, 10, 1); g.translate(size * 0.7, -size / 2, 0);
    const m = new THREE.Mesh(g, this.flagMat || (this.flagMat = new THREE.MeshStandardMaterial({ map: TEX.flag, side: THREE.DoubleSide, roughness: 0.9 })));
    m.position.set(base[0], base[1], base[2]); m.rotation.y = ang; this.scene.add(m);
    this.wavers.push({ m, base: Float32Array.from(g.attributes.position.array), w: size * 1.4, ph: this.rng() * 6 });
  }
  // ---------------- buildings ----------------
  styleGB(st) {
    if (!this.bgb) this.bgb = {};
    if (!this.bgb[st]) this.bgb[st] = new GB(true);
    return this.bgb[st];
  }
  addBuilding(cx, cz, tx, tz, w, dp, h, st, colHex, opts) {
    opts = opts || {};
    const info = STYLE_INFO[st], gb = this.styleGB(st), rg = this.roofGB || (this.roofGB = new GB(false));
    const nx = -tz, nz = tx;
    const corners = [[-1, -1], [1, -1], [1, 1], [-1, 1]].map(([a, b]) => [cx + tx * a * w / 2 + nx * b * dp / 2, cz + tz * a * w / 2 + nz * b * dp / 2]);
    let gmin = 1e9, gmax = -1e9;
    for (const q of corners) { const g = this.groundAt(q[0], q[1]); gmin = Math.min(gmin, g); gmax = Math.max(gmax, g); }
    gmin = Math.min(gmin, this.groundAt(cx, cz));
    const y0 = gmin - 1.5, y1 = gmax + h;
    const B = corners.map(q => [q[0], y0, q[1]]), Tt = corners.map(q => [q[0], y1, q[1]]);
    const ins = [cx, (y0 + y1) / 2, cz];
    const col = C3(colHex);
    const floors = (y1 - y0) / info.floorH, uo = (this.rng() * 8 | 0) / 8, vo = 0;
    for (let k = 0; k < 4; k++) {
      const a = k, b = (k + 1) % 4; const len = k % 2 === 0 ? w : dp;
      const u1 = uo + len / (8 * info.winX), v1 = floors / 8;
      const shade = k % 2 === 0 ? 1 : 0.9;
      gb.face([B[a], B[b], Tt[b], Tt[a]], shadeC(col, shade), [[uo, vo], [u1, vo], [u1, v1], [uo, v1]], ins);
    }
    const roofType = opts.roof || info.roof;
    const snow = this.env.snow;
    if (roofType === 'flat') {
      gb.face([Tt[0], Tt[1], Tt[2], Tt[3]], snow ? C3('#eef2f8') : shadeC(col, 0.75), null, ins);
      if (this.rng() < 0.5 && h > 12) { const F = fr(cx, y1, cz, Math.atan2(tx, tz)); rg.box(F, (this.rng() - 0.5) * w * 0.4, 1.4, (this.rng() - 0.5) * dp * 0.3, 3 + this.rng() * 3, 2.8, 3 + this.rng() * 2, snow ? C3('#e6ebf2') : C3('#8a857c')); }
    } else {
      gb.face([Tt[0], Tt[1], Tt[2], Tt[3]], shadeC(col, 0.7), null, ins);
      const rc = snow ? C3('#f0f4f9') : (roofType === 'slate' ? mixC(C3('#59585a'), C3('#6e6a64'), this.rng()) : mixC(C3('#a5432b'), C3('#b8553a'), this.rng()));
      const rh = Math.min(w, dp) * 0.32, o = 0.6;
      const E = corners.map(([x, z], i) => { const sx = (i === 0 || i === 3) ? -1 : 1, sz = i < 2 ? -1 : 1; return [x + tx * sx * o + nx * sz * o, y1, z + tz * sx * o + nz * sz * o]; });
      const ridgeA = [(E[0][0] + E[3][0]) / 2 + tx * 0, y1 + rh, (E[0][2] + E[3][2]) / 2], ridgeB = [(E[1][0] + E[2][0]) / 2, y1 + rh, (E[1][2] + E[2][2]) / 2];
      const rins = [cx, y1 + rh * 0.3, cz];
      rg.face([E[0], E[1], ridgeB, ridgeA], rc, null, rins);
      rg.face([E[2], E[3], ridgeA, ridgeB], shadeC(rc, 0.85), null, rins);
      rg.face([E[3], E[0], ridgeA], shadeC(rc, 0.75), null, rins);
      rg.face([E[1], E[2], ridgeB], shadeC(rc, 0.75), null, rins);
    }
    if (opts.sign && this.neonGB) this.addNeonSign(cx, cz, tx, tz, w, dp, gmin, opts.signSide);
    if (opts.band && this.bandGB) {
      const F = fr(cx, 0, cz, Math.atan2(tx, tz)), nc = C3(pick(BAND_COLS, this.rng));
      this.bandGB.box(F, 0, y1 - 0.5, 0, dp + 0.14, 0.32, w + 0.14, nc, { noTop: true });
      if (h > 22 && this.rng() < 0.5) for (const sx of [-1, 1]) this.bandGB.box(F, sx * (dp / 2 + 0.05), (gmin + y1) / 2 + 2, -sx * (w / 2 + 0.05), 0.16, y1 - gmin - 4, 0.16, nc);
    }
    return { y0, y1, gmin };
  }
  addNeonSign(cx, cz, tx, tz, w, dp, gmin, side) {
    const nx = -tz, nz = tx, f = -side * (dp / 2 + 0.25); // face toward the road
    const sw = Math.min(w * 0.7, 9), sh = sw / 2.2, y = gmin + 4 + this.rng() * 3;
    const ccx = cx + nx * f, ccz = cz + nz * f;
    const wi = Math.floor(this.rng() * NEON_WORDS.length), u0 = (wi % 2) * 0.5, v0 = 1 - (Math.floor(wi / 2) + 1) * 0.25;
    const a = [ccx - tx * sw / 2, y, ccz - tz * sw / 2], b = [ccx + tx * sw / 2, y, ccz + tz * sw / 2], c2 = [b[0], y + sh, b[2]], d = [a[0], y + sh, a[2]];
    const flip = side > 0;
    this.neonGB.face(flip ? [b, a, d, c2] : [a, b, c2, d], [1, 1, 1], [[u0, v0], [u0 + 0.5, v0], [u0 + 0.5, v0 + 0.25], [u0, v0 + 0.25]], null);
  }
  pickStyle() { const st = this.city.styles; let tot = 0; for (const s of st) tot += s[1]; let x = this.rng() * tot; for (const s of st) { x -= s[1]; if (x <= 0) return s[0]; } return st[0][0]; }
  inCanyon(s) { const cy = this.city.canyon; if (!cy) return false; const f = s / this.track.L; return f > cy[0] - 0.01 && f < cy[1] + 0.01; }
  canPlace(cx, cz, tx, tz, w, dp) {
    const T = this.track, hw = this.hw, nx = -tz, nz = tx;
    for (const [a, b] of [[-1, -1], [1, -1], [1, 1], [-1, 1], [0, 0], [0, -1], [0, 1]]) {
      const x = cx + tx * a * w / 2 + nx * b * dp / 2, z = cz + tz * a * w / 2 + nz * b * dp / 2;
      const n = T.nearest(x, z, 60); if (n && n.d < hw + 5) return false;
      if (this.isWater(x, z)) return false;
    }
    return this.occRect(cx, cz, tx, tz, w / 2 + 0.5, dp / 2 + 0.5, false);
  }
  buildBuildings() {
    const T = this.track, hw = this.hw, c = this.city, r = this.rng, q = this.q, env = this.env;
    const hR = c.hRange;
    this.signsOn = env.win > 0.3 && q.neon;
    if (this.signsOn && !this.neonGB) this.neonGB = new GB(true);
    if (env.win >= 0.45) this.bandGB = new GB(false);
    const place = (s, side, off, w, dp, h, st, row) => {
      const P = T.rawPos(s, side * off);
      T.locate(s); const k = T._i0; const tx = T.NZ[k], tz = -T.NX[k];
      if (!this.canPlace(P.x, P.z, tx, tz, w, dp)) return false;
      const info = STYLE_INFO[st]; const colHex = info.cols[Math.floor(r() * info.cols.length)];
      const sign = row === 0 && this.signsOn && r() < 0.28 && h > 7, band = row < 2 && this.bandGB && h > 9 && r() < 0.32;
      this.addBuilding(P.x, P.z, tx, tz, w, dp, h, st, colHex, { sign, signSide: side, band });
      this.occRect(P.x, P.z, tx, tz, w / 2 + 0.5, dp / 2 + 0.5, true);
      return true;
    };
    for (const side of [-1, 1]) {
      let s = r() * 12;
      while (s < T.L) {
        const st = this.pickStyle(), small = st === 'old' || st === 'stone';
        let w = small ? 7 + r() * 7 : 11 + r() * 13, dp = small ? 8 + r() * 6 : 11 + r() * 10;
        let h = hR[0] + r() * (hR[1] - hR[0]); if (r() < (c.tall || 0)) h *= 1.7 + r() * 0.6;
        const sm = s + w / 2;
        if (r() < q.density && !this.inCanyon(sm)) {
          const off = hw + 5.6 + r() * 3.5 + dp / 2;
          place(sm, side, off, w, dp, h, st, 0);
          if (q.rows > 1 && r() < 0.8) {
            const st2 = this.pickStyle(), w2 = (st2 === 'old' || st2 === 'stone') ? 8 + r() * 6 : 12 + r() * 12, dp2 = 10 + r() * 10;
            let h2 = (hR[0] + r() * (hR[1] - hR[0])) * 1.15; if (r() < (c.tall || 0) * 1.5) h2 *= 1.8;
            place(sm + (r() - 0.5) * 6, side, off + dp / 2 + 5 + r() * 8 + dp2 / 2, w2, dp2, h2, st2, 1);
            if (q.rows > 2 && r() < 0.5) place(sm + (r() - 0.5) * 8, side, off + dp / 2 + dp2 + 24 + r() * 12, 14 + r() * 10, 12 + r() * 8, h2 * 1.2, this.pickStyle(), 2);
          }
        }
        s += w + 1.5 + r() * 4;
      }
    }
    // materials
    const night = env.win;
    for (const st in this.bgb) {
      const ft = TEX.facade[st];
      const mat = new THREE.MeshStandardMaterial({ map: ft.map, vertexColors: true, emissive: 0xffffff, emissiveMap: ft.em, emissiveIntensity: night * 0.5, roughness: st === 'modern' ? 0.35 : 0.85, metalness: st === 'modern' ? 0.4 : 0 });
      const bm = new THREE.Mesh(this.bgb[st].build(), mat); bm.castShadow = true; bm.receiveShadow = true; this.scene.add(bm);
    }
    if (this.roofGB) { const rm = new THREE.Mesh(this.roofGB.build(), new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.8 })); rm.castShadow = true; this.scene.add(rm); }
    if (this.bandGB && this.bandGB.count) this.scene.add(new THREE.Mesh(this.bandGB.build(), glowMat('#ffffff', 1.5, { vertexColors: true })));
    if (this.neonGB && this.neonGB.count) {
      const nm = new THREE.MeshBasicMaterial({ map: TEX.neonAtlas, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide, toneMapped: false }); nm.userData.hdr = 1.6;
      this.scene.add(new THREE.Mesh(this.neonGB.build(), nm)); this.neonMats.push(nm);
    }
  }
  // ---------------- props: lamps, trees, flags, billboards, bunkers ----------------
  buildProps() {
    const T = this.track, hw = this.hw, c = this.city, r = this.rng, env = this.env, q = this.q;
    const pg = new GB(false), eg = new GB(false), lp = new GB(true);
    const pole = C3('#3a3a40'), lampC = C3(env.win > 0.3 ? '#ffd9a0' : '#e8e2d0');
    // street lamps (every 36 m, alternating)
    let side = 1;
    for (let s = 10; s < T.L; s += 36) {
      side = -side; if (this.inCanyon(s)) continue;
      T.locate(s); const k = T._i0; const tx = T.NZ[k], tz = -T.NX[k];
      const P = T.rawPos(s, side * (hw + 2.6)); const y = T.Y[k] + 0.2;
      const F = fr(P.x, y, P.z, Math.atan2(tx, tz));
      pg.box(F, 0, 4, 0, 0.22, 8, 0.22, pole);
      pg.box(F, side * 1.2, 7.9, 0, 2.6, 0.18, 0.2, pole);
      eg.box(F, side * 2.3, 7.75, 0, 0.8, 0.22, 0.45, lampC);
      if (env.lamps) { // light pool on the road
        const Q = T.rawPos(s, side * (hw - 1.5)); const R = 7.5;
        const a = [Q.x - R, T.Y[k] + 0.09, Q.z - R], b = [Q.x + R, T.Y[k] + 0.09, Q.z - R], cc = [Q.x + R, T.Y[k] + 0.09, Q.z + R], d = [Q.x - R, T.Y[k] + 0.09, Q.z + R];
        lp.face([a, d, cc, b], [1, 1, 1], [[0, 0], [0, 1], [1, 1], [1, 0]]);
      }
      if ((s / 36 | 0) % 3 === 0) { const fq = tp(F, 0, 6.6, 0); this.addFlag(fq, Math.atan2(tx, tz) + (side > 0 ? 0 : Math.PI), 1.3, false); }
    }
    // billboards
    const ads = c.ads || AD_KEYS, adIdx = (k) => AD_KEYS.indexOf(k);
    const bb = new GB(true);
    for (let s = 120, n = 0; s < T.L - 60; s += 230 + r() * 120, n++) {
      if (this.inCanyon(s)) continue;
      const sd = n % 2 ? 1 : -1; T.locate(s); const k = T._i0; const tx = T.NZ[k], tz = -T.NX[k];
      const P = T.rawPos(s, sd * (hw + 6.5)); if (this.isWater(P.x, P.z)) continue;
      const gy = this.groundAt(P.x, P.z);
      const ang = Math.atan2(tx, tz) + Math.PI + sd * 0.45; // face oncoming cars
      const F = fr(P.x, gy, P.z, ang);
      pg.box(F, -2.6, 3.5, 0, 0.35, 7, 0.35, pole); pg.box(F, 2.6, 3.5, 0, 0.35, 7, 0.35, pole);
      pg.box(F, 0, 7, -0.2, 8.6, 4.4, 0.3, C3('#1c1a20'));
      const ai = adIdx(ads[n % ads.length]), u0 = (ai % 4) / 4, v1 = 1 - Math.floor(ai / 4) / 4, v0 = v1 - 0.25;
      const A = tp(F, -4, 5, 0), B = tp(F, 4, 5, 0), Cc = tp(F, 4, 9, 0), D = tp(F, -4, 9, 0);
      bb.face([A, B, Cc, D], [1, 1, 1], [[u0, v0], [u0 + 0.25, v0], [u0 + 0.25, v1], [u0, v1]]);
    }
    if (bb.count) { const at = TEX.ads; this.scene.add(new THREE.Mesh(bb.build(), new THREE.MeshStandardMaterial({ map: at, emissive: 0xffffff, emissiveMap: at, emissiveIntensity: env.win * 0.55, side: THREE.DoubleSide, roughness: 0.5 }))); }
    // trees: sidewalk rows + scattered
    const treeKind = c.trees || 'deciduous';
    const addTree = (x, z, scale) => {
      const gy = this.groundAt(x, z), F = fr(x, gy, z, r() * 6);
      const kind = treeKind === 'mixed' ? pick(['deciduous', 'pine', 'cypress'], r) : treeKind;
      const trunk = C3('#5a4330'), sn = env.snow;
      const leaf = sn ? mixC(C3('#2f4a3a'), C3('#dfe7ef'), 0.45) : (kind === 'pine' ? C3('#2d4a32') : kind === 'cypress' ? C3('#2f4a2c') : kind === 'palm' ? C3('#4e7a34') : mixC(C3('#4f7a35'), C3('#6a8c3a'), r()));
      const sc = scale * (0.8 + r() * 0.5);
      if (kind === 'palm') {
        pg.cyl(F, 0, 0, 0, 0.32 * sc, 0.22 * sc, 7.5 * sc, 5, C3('#8a6b48'));
        for (let i = 0; i < 6; i++) { const a = i / 6 * Math.PI * 2; const G = fr(tp(F, 0, 0, 0)[0], gy + 7.4 * sc, tp(F, 0, 0, 0)[2], a); pg.box(G, 0, -0.5 * sc, 1.8 * sc, 0.9 * sc, 0.12, 3.6 * sc, leaf, { taperX: 0.2, shiftZ: 0.8 * sc }); }
      } else if (kind === 'cypress') {
        pg.cyl(F, 0, 0, 0, 0.2 * sc, 0.2 * sc, 1.2 * sc, 5, trunk, { top: false });
        pg.cyl(F, 0, 1.0 * sc, 0, 1.1 * sc, 0, 8.5 * sc, 6, leaf);
      } else if (kind === 'pine') {
        pg.cyl(F, 0, 0, 0, 0.25 * sc, 0.25 * sc, 1.6 * sc, 5, trunk, { top: false });
        for (let i = 0; i < 3; i++) pg.cyl(F, 0, (1.4 + i * 1.9) * sc, 0, (2.6 - i * 0.7) * sc, 0, 3.2 * sc, 7, shadeC(leaf, 1 - i * 0.06));
      } else {
        pg.cyl(F, 0, 0, 0, 0.25 * sc, 0.2 * sc, 2.6 * sc, 5, trunk, { top: false });
        pg.blob(F, 0, 4 * sc, 0, 2.5 * sc, leaf, 0.85, r);
      }
    };
    for (const sd of [-1, 1]) for (let s = 4 + r() * 10; s < T.L; s += 14 + r() * 14) {
      if (this.inCanyon(s) || r() > q.trees) continue;
      const P = T.rawPos(s, sd * (hw + 3.4)); if (this.isWater(P.x, P.z)) continue;
      if (Math.abs(T.wrapS(s)) < 25) continue;
      addTree(P.x, P.z, treeKind === 'palm' ? 1 : 0.85);
    }
    const b = T.bbox, nScatter = Math.round(420 * q.trees);
    for (let i = 0; i < nScatter; i++) {
      const x = b.minX - 260 + r() * (b.maxX - b.minX + 520), z = b.minZ - 260 + r() * (b.maxZ - b.minZ + 520);
      const n = T.nearest(x, z, 60); if (n && n.d < hw + 12) continue;
      if (this.isWater(x, z)) continue;
      const oi = this.occIdx(x, z); if (oi < 0 || this.occ[oi]) continue;
      addTree(x, z, 1); this.occCircle(x, z, 3);
    }
    // bunkers
    const nb = c.bunkers || 0, bunkerC = C3('#9a968c');
    for (let i = 0, tries = 0; i < nb && tries < 400; tries++) {
      let x, z;
      if (c.umbrellas && i < nb * 0.6 && T.water) { // on the beach
        const s = r() * T.L; const P = T.rawPos(s, 0); const sdist = (P.x * T.water.dx + P.z * T.water.dz) - T.water.coast;
        if (sdist < -90) continue; const off = hw + 8 + r() * 18; const Q = T.rawPos(s, -off); const Q2 = T.rawPos(s, off);
        const pick2 = (Q.x * T.water.dx + Q.z * T.water.dz) > (Q2.x * T.water.dx + Q2.z * T.water.dz) ? Q : Q2; x = pick2.x; z = pick2.z;
      } else { const s = r() * T.L, sd = r() < 0.5 ? -1 : 1; const P = T.rawPos(s, sd * (hw + 14 + r() * 50)); x = P.x; z = P.z; }
      const n = T.nearest(x, z, 60); if (n && n.d < hw + 7) continue;
      const gy = this.groundAt(x, z); if (gy < 0.3 && T.water) continue;
      const oi = this.occIdx(x, z); if (oi < 0 || this.occ[oi]) continue;
      const F = fr(x, gy - 0.3, z, r() * 6), R = 2.2 + r() * 0.8;
      pg.cyl(F, 0, 0, 0, R * 1.05, R * 1.05, 0.5, 10, shadeC(bunkerC, 0.9), { top: false });
      pg.dome(F, 0, 0.5, 0, R, 10, 3, bunkerC, 0.75);
      pg.box(F, 0, 0.95, R * 0.92, R * 0.9, 0.22, 0.3, C3('#1a1a1a'));
      this.occCircle(x, z, R + 2); i++;
    }
    // beach umbrellas
    if (c.umbrellas && T.water) {
      const stripes = [C3('#e41e20'), C3('#f2c230'), C3('#2a6fdb'), C3('#f4f4f4')];
      for (let i = 0, tries = 0; i < 70 && tries < 900; tries++) {
        const s = r() * T.L, P = T.rawPos(s, 0);
        const off = hw + 9 + r() * 26; const Q = T.rawPos(s, -off), Q2 = T.rawPos(s, off);
        const pk = (Q.x * T.water.dx + Q.z * T.water.dz) > (Q2.x * T.water.dx + Q2.z * T.water.dz) ? Q : Q2;
        const gy = this.groundAt(pk.x, pk.z); if (gy < 0.4 || gy > 2.2) continue;
        const n = T.nearest(pk.x, pk.z, 60); if (n && n.d < hw + 7) continue;
        const F = fr(pk.x, gy, pk.z, r() * 6);
        pg.cyl(F, 0, 0, 0, 0.05, 0.05, 2.4, 4, C3('#ddd'), { top: false });
        pg.cyl(F, 0, 2.0, 0, 1.6, 0, 0.7, 8, stripes[i % stripes.length]);
        i++;
      }
    }
    const pm = new THREE.Mesh(pg.build(), new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.8 })); pm.castShadow = true; pm.receiveShadow = true; this.scene.add(pm);
    if (this.flagGB) this.scene.add(new THREE.Mesh(this.flagGB.build(), new THREE.MeshStandardMaterial({ map: TEX.flag, side: THREE.DoubleSide, roughness: 0.9 })));
    if (eg.count) this.scene.add(new THREE.Mesh(eg.build(), glowMat('#ffffff', env.win >= 0.45 ? 5 : 1.2, { vertexColors: true })));
    if (lp.count) { const lm = new THREE.MeshBasicMaterial({ map: TEX.glow, color: new THREE.Color('#ffb070'), transparent: true, opacity: 0.55 * env.win + 0.05, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false }); this.scene.add(new THREE.Mesh(lp.build(), lm)); }
  }
  buildMountains() {
    const T = this.track, b = T.bbox, mc = this.city.mountains; if (!mc) return;
    const r = mulberry32(T.seed + 5), g = new GB(false), hor = C3(this.env.fog[0]);
    const base = C3(mc.col), snowC = C3('#f2f5fa'), cx = b.cx, cz = b.cz;
    const water = T.water;
    const n = 26;
    for (let i = 0; i < n; i++) {
      const a = i / n * Math.PI * 2 + r() * 0.2;
      const dx = Math.cos(a), dz = Math.sin(a);
      if (water && water.type === 'sea' && dx * water.dx + dz * water.dz > 0.35) {
        if (this.city.island && r() < 0.25) { /* distant island */ } else continue;
      }
      if (mc.side && dx * mc.side[0] + dz * mc.side[1] < -0.2 && r() < 0.7) continue;
      const near = mc.near && r() < 0.5;
      const R = b.r + (near ? 680 + r() * 300 : 1000 + r() * 650);
      const rad = Math.min((mc.h[0] + r() * (mc.h[1] - mc.h[0])) * (1.5 + r() * 0.8), (R - b.r - 380) / 1.2);
      const H = Math.min(mc.h[0] + r() * (mc.h[1] - mc.h[0]) * (near ? 0.75 : 1), rad * 1.15);
      const x = cx + dx * R, z = cz + dz * R, seg = 7;
      const fade = near ? 0.25 : 0.45;
      const P = [];
      for (let k = 0; k < seg; k++) { const t = k / seg * Math.PI * 2 + r(); const rr = rad * (0.75 + r() * 0.45); P.push([x + Math.cos(t) * rr, -20, z + Math.sin(t) * rr]); }
      const mid = [];
      for (let k = 0; k < seg; k++) { const t = k / seg * Math.PI * 2 + r(); const rr = rad * (0.35 + r() * 0.2); mid.push([x + Math.cos(t) * rr, H * (0.45 + r() * 0.15), z + Math.sin(t) * rr]); }
      const apex = [x + (r() - 0.5) * rad * 0.2, H, z + (r() - 0.5) * rad * 0.2], ins = [x, H * 0.2, z];
      const low = mixC(base, hor, fade), hi = mc.snow ? mixC(snowC, hor, fade * 0.7) : mixC(shadeC(base, 1.15), hor, fade);
      for (let k = 0; k < seg; k++) {
        const j = (k + 1) % seg;
        g.face([P[k], P[j], mid[j], mid[k]], mixC(low, hor, r() * 0.15), null, ins);
        g.face([mid[k], mid[j], apex], k % 2 ? hi : shadeC(hi, 0.9), null, ins);
      }
    }
    const m = new THREE.Mesh(g.build(), new THREE.MeshLambertMaterial({ vertexColors: true, fog: false }));
    m.renderOrder = -5; this.scene.add(m);
  }
  buildCanyon() {
    const T = this.track, hw = this.hw, cy = this.city.canyon, noise = makeNoise(T.seed + 3);
    const s0 = cy[0] * T.L, s1 = cy[1] * T.L, P = [], C = [], I = [];
    const rock = C3('#7a7268'), rock2 = C3('#5f5a54'), moss = C3('#5a6b45');
    for (const sd of [-1, 1]) {
      const start = P.length / 3; let rows = 0;
      for (let s = s0; s <= s1; s += 6) {
        T.locate(s); const k = T._i0; const fadeIn = smooth(s0, s0 + 60, s) * (1 - smooth(s1 - 60, s1, s));
        const ring = [[hw + 6, -2], [hw + 9 + noise(s / 30, sd * 3, 2) * 4, 18 * fadeIn + 3], [hw + 16 + noise(s / 20, sd * 5, 2) * 8, 45 * fadeIn + 4], [hw + 30, 70 * fadeIn + 2]];
        for (const [d, h] of ring) {
          const x = T.X[k] + T.NX[k] * d * sd, z = T.Z[k] + T.NZ[k] * d * sd;
          P.push(x, T.Y[k] + h + noise(x / 8, z / 8, 2) * 2.5 * fadeIn, z);
          const cc = mixC(rock, h > 30 ? rock2 : moss, Math.abs(noise(x / 15, z / 15, 2)));
          C.push(cc[0], cc[1], cc[2]);
        }
        rows++;
      }
      for (let i = 0; i < rows - 1; i++) for (let j = 0; j < 3; j++) {
        const a = start + i * 4 + j, b = a + 1, c = a + 4, d = c + 1;
        if (sd > 0) I.push(a, b, c, b, d, c); else I.push(a, c, b, b, c, d);
      }
    }
    const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.Float32BufferAttribute(P, 3)); g.setAttribute('color', new THREE.Float32BufferAttribute(C, 3));
    g.setIndex(I); g.computeVertexNormals();
    this.scene.add(new THREE.Mesh(g, new THREE.MeshStandardMaterial({ vertexColors: true, side: THREE.DoubleSide, roughness: 0.95 })));
  }
  // ---------------- landmarks ----------------
  buildLandmarks() {
    const T = this.track, lg = this.lmGB = new GB(false);
    const clear = { skanderbeg: 24, mosque: 26, clocktower: 10, pyramid: 42, flagpole: 6, venetian: 16, amphi: 50, cranes: 30, indep: 18, castle: 60, mangalem: 0, cathedral: 32, newborn: 24, library: 34, hotel: 26, bridge: 36, paintedmosque: 22 };
    for (const lm of T.lms) {
      const gy = this.groundAt(lm.x, lm.z);
      const n = T.nearest(lm.x, lm.z, 400);
      const tx = n ? T.X[n.i] - lm.x : 0, tz = n ? T.Z[n.i] - lm.z : 1;
      const ang = Math.atan2(tx, tz); // local +z faces the road
      const F = fr(lm.x, gy, lm.z, ang);
      const fn = this['lm_' + lm.type]; if (fn) fn.call(this, F, lm, lg);
      const cr = lm.type === 'castle' ? (lm.r || 50) + 12 : (clear[lm.type] || 20) * (lm.big ? 1.5 : 1);
      if (cr) this.occCircle(lm.x, lm.z, cr);
    }
    const dark = this.env.win >= 0.45;
    if (lg.count) { const lmm = new THREE.Mesh(lg.build(), new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.7, emissive: dark ? 0x2a221c : 0x000000 })); lmm.castShadow = true; lmm.receiveShadow = true; this.scene.add(lmm); }
    if (dark) {
      const fm = new THREE.SpriteMaterial({ map: TEX.glow, color: new THREE.Color('#ffb870'), transparent: true, opacity: 0.45, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false });
      for (const lm of T.lms) {
        if (lm.type === 'mangalem' || lm.type === 'flagpole' || lm.type === 'cranes') continue;
        const gy = this.groundAt(lm.x, lm.z), sz = lm.type === 'castle' ? 90 : lm.type === 'pyramid' ? 70 : 34;
        const sp = new THREE.Sprite(fm); sp.scale.set(sz, sz * 0.7, 1); sp.position.set(lm.x, gy + sz * 0.22, lm.z); this.scene.add(sp);
      }
    }
  }
  texMesh(geo, tex, F, lx, ly, lz, rotY, o) {
    o = o || {};
    const m = new THREE.Mesh(geo, new THREE.MeshStandardMaterial(Object.assign({ map: tex, side: THREE.DoubleSide, alphaTest: o.alpha ? 0.5 : 0, transparent: false, roughness: 0.7 }, o.mat || {}))); m.castShadow = true;
    const p = tp(F, lx, ly, lz); m.position.set(p[0], p[1], p[2]); m.rotation.y = Math.atan2(F.s, F.c) + (rotY || 0);
    this.scene.add(m); return m;
  }
  lm_skanderbeg(F, lm, g) {
    const stone = C3('#a39d92');
    g.box(F, 0, 0.4, 0, 12, 0.8, 10, shadeC(stone, 0.9)); g.box(F, 0, 3, 0, 8.5, 4.6, 6, stone);
    for (const dz of [-0.35, 0, 0.35]) this.texMesh(new THREE.PlaneGeometry(13, 13), TEX.statue, F, 0, 5.3 + 6.5, dz, 0, { alpha: true, mat: { color: dz ? 0xbbbbbb : 0xffffff, emissive: 0x8a6a3c, emissiveMap: TEX.statue, emissiveIntensity: this.env.win >= 0.45 ? 1.4 : 0.15 } });
  }
  lm_mosque(F, lm, g) {
    const R = lm.dome || 5, wall = C3(lm.lead ? '#ddd3bf' : '#ebe1cb'), lead = C3('#7d8890'), w = R * 2.6;
    g.box(F, 0, R * 0.75, 0, w, R * 1.5, w, wall);
    g.cyl(F, 0, R * 1.5, 0, R * 1.05, R * 1.05, R * 0.35, 12, shadeC(wall, 0.95));
    g.dome(F, 0, R * 1.85, 0, R, 12, 4, lead);
    g.cyl(F, 0, R * 2.85, 0, 0.18, 0, R * 0.5, 4, C3('#c9a24a'));
    g.box(F, 0, R * 0.55, w / 2 + 0.05, R * 0.7, R * 1.1, 0.2, C3('#2a2226'));
    if (lm.domes) { // portico with small domes
      g.box(F, 0, R * 0.45, w / 2 + R * 0.6, w, R * 0.9, R * 1.2, shadeC(wall, 0.95));
      const n = lm.domes; for (let i = 0; i < n; i++) g.dome(F, (i - (n - 1) / 2) * (w / n), R * 0.9, w / 2 + R * 0.6, w / n * 0.42, 8, 3, lead);
    }
    const mh = lm.minaret || 24, mx = w / 2 + 1.6, mz = -w / 2 + 1.6;
    g.cyl(F, mx, 0, mz, 1.15, 1.0, mh, 8, wall, { top: false });
    g.cyl(F, mx, mh * 0.78, mz, 1.7, 1.7, 0.5, 8, shadeC(wall, 0.9));
    g.cyl(F, mx, mh, mz, 1.05, 0, 4.5, 8, lead);
  }
  lm_clocktower(F, lm, g) {
    const h = lm.h || 34, stone = C3('#bfae92');
    g.box(F, 0, h / 2, 0, 4.4, h, 4.4, stone);
    g.box(F, 0, h + 1.2, 0, 5.2, 2.4, 5.2, shadeC(stone, 0.9));
    g.cyl(F, 0, h + 2.4, 0, 3.6, 0, 4.2, 4, C3('#4f6e5f'), { rot: Math.PI / 4 });
    for (let k = 0; k < 4; k++) this.texMesh(new THREE.PlaneGeometry(3, 3), TEX.clock, fr(...tp(F, 0, 0, 0), Math.atan2(F.s, F.c) + k * Math.PI / 2), 0, h - 2.5, 2.25, 0, { mat: { emissive: 0xffffff, emissiveMap: TEX.clock, emissiveIntensity: this.env.win * 0.6, side: THREE.FrontSide } });
  }
  lm_pyramid(F, lm, g) {
    g.cyl(F, 0, 0, 0, 34, 0, 24, 4, C3('#b9b4ab'), { rot: Math.PI / 4 });
    const cols = ['#e94f37', '#f6c445', '#3fa7d6', '#59cd90', '#ee6352', '#f4f1ec'], r = mulberry32(11);
    for (let i = 0; i < 26; i++) {
      const t = r() * Math.PI * 2, rr = 6 + r() * 20, y = 24 * (1 - rr / 34) * Math.min(1, 1);
      g.box(F, Math.cos(t) * rr, y * 0.9, Math.sin(t) * rr, 2.6, 2.6, 2.6, C3(cols[i % cols.length]));
    }
    g.box(F, 0, 12, 23.2, 3, 24, 0.6, C3('#e8e4dc'), { taperX: 1, shiftZ: -17 });
  }
  lm_flagpole(F, lm, g) {
    const h = lm.h || 30;
    g.cyl(F, 0, 0, 0, 0.35, 0.2, h, 8, C3('#d9dce0'));
    g.cyl(F, 0, 0, 0, 2.2, 2.2, 0.6, 8, C3('#8f8a80'));
    this.addFlag(tp(F, 0, h - 0.2, 0), Math.atan2(F.s, F.c) + Math.PI / 2, lm.big ? 8 : 5, true);
  }
  lm_venetian(F, lm, g) {
    const st = C3('#b49a78');
    g.cyl(F, 0, 0, 0, 8.5, 8, 15, 18, st);
    for (let i = 0; i < 18; i++) { const a = i / 18 * Math.PI * 2; if (i % 2) g.box(fr(...tp(F, 0, 0, 0), Math.atan2(F.s, F.c) + a), 0, 15.7, 7.6, 2, 1.4, 0.9, shadeC(st, 0.92)); }
    g.box(F, 0, 2.2, 8.2, 2.4, 4.4, 0.6, C3('#2b2420'));
  }
  lm_amphi(F, lm, g) {
    const st = C3('#a8916f');
    for (let i = 0; i < 14; i++) {
      const a0 = Math.PI * 0.15 + i / 14 * Math.PI * 0.7, R = 38;
      const G = fr(...tp(F, Math.cos(a0) * R, 0, -Math.sin(a0) * R + 10), Math.atan2(F.s, F.c) - a0 + Math.PI / 2);
      g.box(G, 0, 4, 0, 7.6, 8 - (i % 3) * 1.2, 2.2, shadeC(st, 0.9 + (i % 2) * 0.1));
      g.box(G, 0, 1.8, 0.2, 3.2, 3.6, 2.4, C3('#3a3028'));
    }
  }
  lm_cranes(F, lm, g) {
    const conc = C3('#8c8a86');
    g.box(F, 0, -2.5, -8, 44, 8, 30, conc);
    const cols = [C3('#e2b13c'), C3('#c0392b')];
    for (let k = 0; k < 2; k++) {
      const x = -10 + k * 20, c = cols[k];
      for (const [a, b] of [[-3, -3], [3, -3], [-3, 3], [3, 3]]) g.box(F, x + a, 1.5 + 10, -8 + b, 0.9, 20, 0.9, c);
      g.box(F, x, 22, -8, 8, 2, 8, c);
      g.box(F, x, 23.5, -18, 1.4, 1.4, 36, c);
      g.box(F, x, 26, -4, 1, 6, 1, c);
    }
    const cc = ['#2a6fdb', '#e41e20', '#3f6d3b', '#f2c230', '#8e44ad'];
    for (let i = 0; i < 8; i++) g.box(F, -16 + (i % 4) * 7, 2.8 + Math.floor(i / 4) * 2.6, 2, 6, 2.6, 2.5, C3(cc[i % cc.length]));
  }
  lm_indep(F, lm, g) {
    const st = C3('#8d8476'), br = C3('#4a3f33');
    g.box(F, 0, 0.7, 0, 16, 1.4, 16, shadeC(st, 1.1)); g.box(F, 0, 2.2, 0, 11, 1.6, 11, st);
    g.box(F, 0, 13, 0, 3.2, 20, 2.4, st, { taperX: 0.7, taperZ: 0.7 });
    for (let i = 0; i < 6; i++) { const a = i / 6 * Math.PI * 2; const x = Math.cos(a) * 4, z = Math.sin(a) * 4; g.cyl(F, x, 3, z, 0.55, 0.45, 3.6, 6, br); g.blob(F, x, 7, z, 0.5, br, 1.1); }
    this.addFlag(tp(F, 0, 25.5, 0), Math.atan2(F.s, F.c) + Math.PI / 2, 2.6, true);
  }
  lm_castle(F, lm, g) {
    const R = lm.r || 50, st = C3(this.city.id === 'gjirokaster' ? '#9d968a' : '#a8977c'), r = mulberry32(strHash(lm.type + this.city.id));
    const n = 11, pts = [];
    for (let i = 0; i < n; i++) { const a = i / n * Math.PI * 2; const rr = R * (0.8 + r() * 0.35); const p = tp(F, Math.cos(a) * rr, 0, Math.sin(a) * rr); pts.push([p[0], this.groundAt(p[0], p[2]), p[2]]); }
    let top = -1e9, topI = 0;
    for (let i = 0; i < n; i++) {
      const a = pts[i], b = pts[(i + 1) % n];
      const mx = (a[0] + b[0]) / 2, mz = (a[2] + b[2]) / 2, len = Math.hypot(b[0] - a[0], b[2] - a[2]);
      const gyl = Math.min(a[1], b[1]), gyh = Math.max(a[1], b[1]);
      const G = fr(mx, gyl - 4, mz, Math.atan2(b[0] - a[0], b[2] - a[2]));
      const H = gyh - gyl + 4 + 8;
      g.box(G, 0, H / 2, 0, 2.6, H, len, st);
      for (let c = -len / 2 + 1.5; c < len / 2 - 1; c += 3) g.box(G, 0, H + 0.6, c, 2.8, 1.2, 1.4, shadeC(st, 0.92));
      const T = fr(a[0], a[1] - 4, a[2], 0);
      const th = 16 + r() * 6; g.cyl(T, 0, 0, 0, 4, 3.6, th + 4, 8, shadeC(st, 0.95)); g.cyl(T, 0, th + 4, 0, 4.4, 0, 3.5, 8, C3('#6b4e3c'));
      if (a[1] + th > top) { top = a[1] + th; topI = i; }
    }
    if (lm.clock) { const p = pts[2]; const T = fr(p[0], p[1] - 2, p[2], Math.atan2(F.s, F.c)); g.box(T, 0, 14, 0, 5, 28, 5, shadeC(st, 1.05)); g.cyl(T, 0, 28, 0, 4, 0, 5, 4, C3('#5a5a5e'), { rot: Math.PI / 4 }); this.texMesh(new THREE.PlaneGeometry(3.4, 3.4), TEX.clock, T, 0, 24, 2.55, 0, { mat: { side: THREE.FrontSide } }); }
    const tp2 = pts[topI]; this.addFlag([tp2[0], tp2[1] + 28, tp2[2]], Math.atan2(F.s, F.c) + Math.PI / 2, 5, true);
  }
  lm_mangalem(F, lm) {
    const T = this.track, hill = this.track.hills[0], r = mulberry32(99);
    if (!hill) return;
    for (let ring = 0; ring < 6; ring++) {
      const rr = hill.r * (0.4 + ring * 0.1), n = Math.round(rr * 2 * Math.PI / 11);
      for (let i = 0; i < n; i++) {
        const a = i / n * Math.PI * 2 + ring * 0.37 + r() * 0.1;
        const x = hill.x + Math.cos(a) * rr, z = hill.z + Math.sin(a) * rr;
        const nn = T.nearest(x, z, 60); if (nn && nn.d < this.hw + 8) continue;
        const tx = -Math.sin(a), tz = Math.cos(a);
        if (!this.occRect(x, z, tx, tz, 4.5, 4.5, false)) continue;
        this.addBuilding(x, z, tx, tz, 7 + r() * 3, 7 + r() * 2, 7 + r() * 4, 'old', pick(STYLE_INFO.old.cols, r), {});
        this.occRect(x, z, tx, tz, 4.5, 4.5, true);
      }
    }
  }
  lm_cathedral(F, lm, g) {
    const wall = C3('#efe6d6'), dome = C3('#c9a24a'), roof = C3('#8a3b2a');
    g.box(F, 0, 7, -4, 22, 14, 30, wall); g.box(F, 0, 15, -4, 22.5, 2.5, 30.5, roof, { taperX: 0.2 });
    g.cyl(F, 0, 14, -6, 5.2, 5.2, 5, 12, wall); g.dome(F, 0, 19, -6, 5.2, 12, 4, dome); g.cyl(F, 0, 24, -6, 0.2, 0, 3, 4, dome);
    for (const sx of [-8, 8]) { g.box(F, sx, 12, 11, 6, 24, 6, wall); g.cyl(F, sx, 24, 11, 2.8, 2.8, 2.2, 8, wall); g.dome(F, sx, 26.2, 11, 2.8, 8, 3, dome); g.cyl(F, sx, 28.9, 11, 0.15, 0, 2.4, 4, dome); }
    g.box(F, 0, 3.5, 13.2, 3.4, 7, 0.4, C3('#3a2c22'));
  }
  lm_newborn(F, lm) {
    const word = 'NEWBORN', cols = ['#e41e20', '#f2c230', '#2a6fdb', '#38c172', '#ff6a1a', '#8e44ad', '#f4f1ec'];
    for (let i = 0; i < word.length; i++) {
      const t = letterTex(word[i], cols[i]);
      for (const dz of [-0.45, 0, 0.45]) this.texMesh(new THREE.PlaneGeometry(4.6, 5.8), t, F, (i - 3) * 4.8, 3.2, dz, 0, { alpha: true, mat: { emissive: new THREE.Color(cols[i]), emissiveIntensity: this.env.win * 0.4, color: dz ? 0xb0b0b0 : 0xffffff } });
    }
    this.lmGB.box(F, 0, 0.15, 0, 36, 0.3, 4, C3('#8a8780'));
  }
  lm_library(F, lm, g) {
    const geo = new THREE.BoxGeometry(34, 20, 34);
    const lt = TEX.lattice; lt.repeat.set(3, 2);
    this.texMesh(geo, lt, F, 0, 10, 0, 0, { mat: { side: THREE.FrontSide, emissive: 0x334455, emissiveIntensity: this.env.win * 0.5 } });
    const w = C3('#e8eaec');
    for (let i = 0; i < 4; i++) for (let j = 0; j < 4; j++) { if ((i === 1 || i === 2) && (j === 1 || j === 2)) continue; g.dome(F, -12 + i * 8, 20, -12 + j * 8, 2.8, 8, 3, w); }
    g.cyl(F, 0, 20, 0, 6.5, 6.5, 1.2, 12, w); g.dome(F, 0, 21.2, 0, 6.5, 12, 4, w);
  }
  lm_hotel(F, lm) {
    const tx = F.s, tz = F.c; // local +z toward road
    const res = this.addBuilding(F.x, F.z, -tz, tx, 34, 16, 62, 'soviet', '#c9c0b0', { roof: 'flat' });
    if (!this.neonGB) this.neonGB = new GB(true);
    const y = res.y1 + 0.5, w = 26, h = 7, c = tp(F, 0, 0, 0);
    const wi = NEON_WORDS.indexOf('HOTEL'), u0 = (wi % 2) * 0.5, v0 = 1 - (Math.floor(wi / 2) + 1) * 0.25;
    const a = tp(F, -w / 2, 0, 6), b = tp(F, w / 2, 0, 6);
    this.neonGB.face([[a[0], y, a[2]], [b[0], y, b[2]], [b[0], y + h, b[2]], [a[0], y + h, a[2]]], [1, 1, 1], [[u0, v0], [u0 + 0.5, v0], [u0 + 0.5, v0 + 0.25], [u0, v0 + 0.25]]);
  }
  lm_bridge(F, lm, g) {
    const st = C3('#b9a68a');
    const wg = new THREE.PlaneGeometry(90, 13); wg.rotateX(-Math.PI / 2);
    const wm = new THREE.Mesh(wg, new THREE.MeshStandardMaterial({ color: 0x2f6f7a, roughness: 0.1, metalness: 0.3 }));
    const p = tp(F, 0, 0.12, 0); wm.position.set(p[0], p[1], p[2]); wm.rotation.y = Math.atan2(F.s, F.c); this.scene.add(wm);
    const n = 12, R = 9;
    for (let i = 0; i < n; i++) {
      const a0 = i / n * Math.PI, a1 = (i + 1) / n * Math.PI;
      const z0 = -Math.cos(a0) * R, z1 = -Math.cos(a1) * R, y0 = Math.sin(a0) * R * 0.75, y1 = Math.sin(a1) * R * 0.75;
      const G = fr(...tp(F, 0, 0, (z0 + z1) / 2), Math.atan2(F.s, F.c));
      g.box(G, 0, (y0 + y1) / 2 + 0.6, 0, 3.6, 1.4, Math.abs(z1 - z0) + 0.3, st);
    }
    g.box(F, 0, 0.5, -R - 3, 4, 1.4, 6, shadeC(st, 0.9)); g.box(F, 0, 0.5, R + 3, 4, 1.4, 6, shadeC(st, 0.9));
    for (const sx of [-1.9, 1.9]) for (let i = 0; i <= n; i++) { const a = i / n * Math.PI; g.box(F, sx, Math.sin(a) * R * 0.75 + 1.6, -Math.cos(a) * R, 0.25, 0.9, 1.6, shadeC(st, 0.85)); }
  }
  lm_paintedmosque(F, lm, g) {
    const geo = new THREE.BoxGeometry(16, 9, 16);
    this.texMesh(geo, TEX.painted, F, 0, 4.5, 0, 0, { mat: { side: THREE.FrontSide } });
    g.cyl(F, 0, 9, 0, 12.5, 0, 5.5, 4, C3('#7a5638'), { rot: Math.PI / 4 });
    g.box(F, 0, 2, 9.2, 10, 4, 2.4, C3('#8a6a48'));
    const mx = 9.5, mz = -6;
    g.cyl(F, mx, 0, mz, 1.1, 0.95, 28, 8, C3('#efe9df'), { top: false });
    g.cyl(F, mx, 22, mz, 1.7, 1.7, 0.5, 8, C3('#d9d0c0'));
    g.cyl(F, mx, 28, mz, 1.0, 0, 5, 8, C3('#7d8890'));
  }
  update(dt, t, cam) {
    this.sky.position.copy(cam.position);
    if (this.stars) this.stars.position.copy(cam.position);
    this.sun.position.copy(cam.position).addScaledVector(this.sunDir, 2400);
    for (const w of this.wavers) {
      const a = w.m.geometry.attributes.position, b = w.base;
      for (let i = 0; i < a.count; i++) { const x = b[i * 3]; const k = x / w.w; a.array[i * 3 + 2] = Math.sin(x * 0.9 - t * 5 + w.ph) * 0.35 * k * (w.w / 4); }
      a.needsUpdate = true;
    }
  }
}
