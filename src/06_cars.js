// ---------- car models: extruded side profiles with wheel arches, clear-coat paint, glass, light bars ----------
// Profiles are (forward, up) in metres; the car's +z is forward. body: lower shell, cab: greenhouse, roof: painted roof slab.
const CAR_SHAPES = {
  gt:     { L: 4.5, W: 1.96, wr: 0.36, wz: 1.42, body: [[-2.25, 0.32], [2.17, 0.3], [2.27, 0.44], [2.24, 0.62], [1.35, 0.8], [0.6, 0.86], [-1.35, 0.92], [-2.18, 0.96], [-2.27, 0.72]], cab: [[0.68, 0.84], [-0.05, 1.24], [-0.8, 1.23], [-1.5, 0.9]], cabW: 0.8, spoiler: true },
  muscle: { L: 4.8, W: 2.04, wr: 0.38, wz: 1.55, body: [[-2.4, 0.34], [2.36, 0.32], [2.43, 0.52], [2.4, 0.86], [0.62, 0.98], [-1.6, 1.0], [-2.38, 1.0], [-2.43, 0.62]], cab: [[0.6, 0.96], [-0.15, 1.36], [-1.05, 1.36], [-1.75, 0.98]], cabW: 0.8, stripes: true, scoop: true },
  hatch:  { L: 3.95, W: 1.84, wr: 0.34, wz: 1.25, body: [[-1.97, 0.3], [1.88, 0.3], [1.98, 0.46], [1.96, 0.68], [1.15, 0.86], [0.62, 0.92], [-1.62, 0.95], [-1.97, 0.9]], cab: [[0.7, 0.9], [-0.1, 1.42], [-1.55, 1.42], [-1.92, 0.92]], cabW: 0.82 },
  sleek:  { L: 4.6, W: 2.02, wr: 0.35, wz: 1.48, body: [[-2.3, 0.28], [2.22, 0.26], [2.32, 0.36], [2.3, 0.52], [1.0, 0.72], [0.45, 0.78], [-1.2, 0.84], [-2.25, 0.9], [-2.32, 0.62]], cab: [[0.5, 0.76], [-0.35, 1.12], [-0.95, 1.1], [-1.65, 0.84]], cabW: 0.78, spoiler: true },
  jeep:   { L: 4.4, W: 2.02, wr: 0.47, wz: 1.42, body: [[-2.2, 0.56], [2.15, 0.56], [2.23, 0.72], [2.2, 1.15], [1.0, 1.3], [0.55, 1.34], [-2.15, 1.36], [-2.23, 1.2]], cab: [[0.6, 1.32], [0.18, 1.95], [-2.0, 1.95], [-2.12, 1.34]], cabW: 0.88, rack: true },
  van:    { L: 5.3, W: 2.12, wr: 0.38, wz: 1.78, body: [[-2.65, 0.38], [2.56, 0.38], [2.66, 0.56], [2.62, 1.12], [2.0, 1.36], [1.6, 1.4], [-2.65, 1.4]], cab: [[1.66, 1.38], [1.0, 2.36], [-2.6, 2.36], [-2.62, 1.38]], cabW: 0.97, van: true },
};
const CAR_GEO = {};
function extrudeProfile(pts, width, bevel, arches) {
  const sh = new THREE.Shape();
  // bottom edge from tail to nose with semicircular wheel arches cut upward
  const b0 = pts[0], b1 = pts[1];
  sh.moveTo(b0[0], b0[1]);
  if (arches) {
    const topAt = (z) => { let y = -1; for (let i = 2; i < pts.length; i++) { const p = pts[i], q = pts[(i + 1) % pts.length]; if ((p[0] - z) * (q[0] - z) <= 0 && p[0] !== q[0]) y = Math.max(y, p[1] + (q[1] - p[1]) * (z - p[0]) / (q[0] - p[0])); } return y; };
    for (const a of arches) {
      const zc = a[0], R = a[1], yc = a[2], Ry = Math.min(R, topAt(zc) - 0.13 - yc);
      sh.lineTo(zc - R, b0[1]);
      for (let k = 0; k <= 10; k++) { const t = Math.PI - k / 10 * Math.PI; sh.lineTo(zc + Math.cos(t) * R, Math.max(b0[1], yc + Math.sin(t) * Ry)); }
      sh.lineTo(zc + R, b0[1]);
    }
  }
  sh.lineTo(b1[0], b1[1]);
  for (let i = 2; i < pts.length; i++) sh.lineTo(pts[i][0], pts[i][1]);
  sh.closePath();
  const depth = Math.max(0.05, width - bevel * 2);
  const g = new THREE.ExtrudeGeometry(sh, { depth, bevelEnabled: bevel > 0, bevelThickness: bevel, bevelSize: bevel, bevelSegments: 2, curveSegments: 4 });
  g.translate(0, 0, -depth / 2); g.rotateY(-Math.PI / 2);
  g.computeVertexNormals();
  return g;
}
function carGeo(style) {
  if (CAR_GEO[style]) return CAR_GEO[style];
  const S = CAR_SHAPES[style], L = S.L, W = S.W, wr = S.wr;
  const arches = [[-S.wz, wr + 0.06, wr * 0.9], [S.wz, wr + 0.06, wr * 0.9]];
  const body = extrudeProfile(S.body, W, 0.07, arches);
  const cab = extrudeProfile(S.cab, W * S.cabW, 0.06, null);
  // roof slab: follows the top of the cab, a little narrower, painted
  const c = S.cab, roofPts = [[c[1][0] + 0.06, c[1][1] - 0.05], [c[2][0] - 0.04, c[2][1] - 0.05], [c[2][0] - 0.04, c[2][1] + 0.025], [c[1][0] + 0.06, c[1][1] + 0.025]];
  const roof = extrudeProfile(S.van ? [[c[0][0] - 0.25, 2.2], [c[3][0], 2.2], [c[3][0], c[2][1] + 0.03], [c[1][0] - 0.1, c[1][1] + 0.03]] : roofPts, W * S.cabW + 0.02, 0.03, null);
  // details (dark trim): side skirts, bumpers, spoiler, scoop, rack
  const tg = new GB(false), F = F0, k = [1, 1, 1];
  tg.box(F, 0, S.body[0][1] + 0.06, 0, W + 0.16, 0.12, 2 * S.wz - 2 * (wr + 0.14), k);
  tg.box(F, 0, S.body[0][1] + 0.08, L / 2 + 0.02, W * 0.9, 0.16, 0.14, k);
  tg.box(F, 0, S.body[0][1] + 0.08, -L / 2 - 0.02, W * 0.9, 0.16, 0.14, k);
  const topY = S.body[S.body.length - 2][1];
  if (S.spoiler) { tg.box(F, 0, topY + 0.32, -L / 2 + 0.3, W * 0.92, 0.05, 0.36, k); for (const sx of [-0.6, 0.6]) tg.box(F, sx, topY + 0.16, -L / 2 + 0.32, 0.07, 0.3, 0.12, k); }
  if (S.scoop) tg.box(F, 0, S.body[4][1] + 0.08, 1.1, 0.62, 0.14, 0.9, k);
  if (S.rack) tg.box(F, 0, 2.02, -0.9, W * 0.82, 0.06, 1.9, k);
  // lights: headlight pair + full-width tail light bar (Blur look)
  const lg = new GB(false), rg = new GB(false);
  const nose = S.body[3], tail = S.body[S.body.length - 1];
  const hy = nose[1] - 0.07, hz = nose[0] + 0.05, ty = tail[1] - 0.06, tz = tail[0] - 0.05;
  for (const sx of [-1, 1]) lg.box(F, sx * (W / 2 - 0.34), hy, hz, 0.46, 0.08, 0.1, k);
  lg.box(F, 0, hy - 0.14, hz + 0.01, W * 0.5, 0.025, 0.06, k);
  rg.box(F, 0, ty, tz, W * 0.86, 0.07, 0.08, k);
  for (const sx of [-1, 1]) rg.box(F, sx * (W / 2 - 0.22), ty, tz, 0.3, 0.14, 0.09, k);
  // wheels (one shared tyre + rim)
  const tyre = new THREE.CylinderGeometry(wr, wr, 0.3, 20); tyre.rotateZ(Math.PI / 2);
  const rim = new THREE.CylinderGeometry(wr * 0.66, wr * 0.66, 0.31, 10); rim.rotateZ(Math.PI / 2);
  const out = { body, cab, roof, trim: tg.build(), head: lg.build(), tail: rg.build(), tyre, rim, S, tailPts: [[-W * 0.4, ty, tz - 0.06], [W * 0.4, ty, tz - 0.06]], H: S.cab[1][1] };
  CAR_GEO[style] = out; return out;
}
const CAR_MATS = {};
function carMats() {
  if (CAR_MATS.glass) return CAR_MATS;
  CAR_MATS.glass = linMat(new THREE.MeshStandardMaterial({ color: '#0c1118', roughness: 0.05, metalness: 0.9 }));
  CAR_MATS.trim = linMat(new THREE.MeshStandardMaterial({ color: '#141418', roughness: 0.55, metalness: 0.3 }));
  CAR_MATS.tyre = linMat(new THREE.MeshStandardMaterial({ color: '#141414', roughness: 0.92 }));
  CAR_MATS.rim = linMat(new THREE.MeshStandardMaterial({ color: '#c9ccd2', roughness: 0.25, metalness: 1 }));
  CAR_MATS.head = linMat(glowMat('#fff3dc', 6));
  CAR_MATS.tail = linMat(glowMat('#ff1830', 5));
  CAR_MATS.stripe = linMat(new THREE.MeshPhysicalMaterial({ color: '#f4f1ec', roughness: 0.3, clearcoat: 1, clearcoatRoughness: 0.1 }));
  [CAR_MATS.glass, CAR_MATS.rim].forEach(m => { m.envMapIntensity = 2.4; });
  return CAR_MATS;
}
function paintMat(hex) {
  const key = 'p' + hex; if (CAR_MATS[key]) return CAR_MATS[key];
  const m = linMat(new THREE.MeshPhysicalMaterial({ color: hex, roughness: 0.32, metalness: 0.45, clearcoat: 1, clearcoatRoughness: 0.06 }));
  m.envMapIntensity = 2.6; CAR_MATS[key] = m; return m;
}
class CarView {
  constructor(car, scene, opts) {
    this.car = car; opts = opts || {};
    const G = carGeo(car.def.style), M = carMats(), S = G.S, paint = paintMat(car.color);
    this.root = new THREE.Group(); this.body = new THREE.Group(); this.root.add(this.body);
    const add = (geo, mat, cast) => { const m = new THREE.Mesh(geo, mat); m.castShadow = !!cast; m.receiveShadow = !!cast; this.body.add(m); return m; };
    add(G.body, paint, true); add(G.cab, S.van ? paint : M.glass, true); add(G.roof, paint, false); add(G.trim, M.trim, false);
    add(G.head, M.head); this.tailMesh = add(G.tail, M.tail);
    if (S.van) { const wg = new THREE.BoxGeometry(S.W * 0.99, 0.5, S.L - 1.7); wg.translate(0, 1.85, -0.5); add(wg, M.glass); const ws = new THREE.BoxGeometry(S.W * 0.86, 0.9, 0.06); ws.rotateX(-0.6); ws.translate(0, 1.9, 1.39); add(ws, M.glass); }
    this.wheels = [];
    const wx = S.W / 2 - 0.2;
    for (const sz of [1, -1]) for (const sx of [-1, 1]) {
      const wgp = new THREE.Group(); wgp.position.set(sx * wx, S.wr, sz * S.wz); wgp.rotation.order = 'YXZ';
      const t = new THREE.Mesh(G.tyre, M.tyre), rm = new THREE.Mesh(G.rim, M.rim); t.castShadow = true;
      wgp.add(t); wgp.add(rm); this.body.add(wgp); this.wheels.push({ g: wgp, front: sz > 0 });
    }
    this.tail = G.tailPts; this.L = S.L; this.H = G.H;
    const glowCol = new THREE.Color(car.color); if (glowCol.getHSL({}).l < 0.25 || glowCol.getHSL({}).s < 0.15) glowCol.set('#ff3048');
    const ug = new THREE.Mesh(new THREE.PlaneGeometry(S.W + 1.8, S.L + 1.6), linMat(Object.assign(new THREE.MeshBasicMaterial({ map: TEX.glow, color: glowCol, transparent: true, opacity: 0.6, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false }), { userData: { hdr: 1.6 } })));
    ug.rotation.x = -Math.PI / 2; ug.position.y = 0.07; this.body.add(ug); this.under = ug;
    const sh = new THREE.Mesh(new THREE.PlaneGeometry(S.W + 0.8, S.L + 0.5), new THREE.MeshBasicMaterial({ map: TEX.glow, color: 0x000000, transparent: true, opacity: 0.7, depthWrite: false }));
    sh.rotation.x = -Math.PI / 2; sh.position.y = 0.05; this.root.add(sh); this.shadow = sh;
    this.shield = new THREE.Mesh(new THREE.SphereGeometry(3.3, 20, 12), linMat(Object.assign(new THREE.MeshBasicMaterial({ color: '#7fb0ff', transparent: true, opacity: 0.14, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false }), { userData: { hdr: 1.4 } })));
    this.shield.position.y = 0.8; this.shield.visible = false; this.root.add(this.shield);
    if (opts.beams) {
      // headlight pool on the road ahead
      const pool = new THREE.Mesh(new THREE.PlaneGeometry(7, 16), linMat(Object.assign(new THREE.MeshBasicMaterial({ map: TEX.glow, color: '#fff0d8', transparent: true, opacity: 0.38, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false }), { userData: { hdr: 1 } })));
      pool.rotation.x = -Math.PI / 2; pool.position.set(0, 0.09, S.L / 2 + 8); this.body.add(pool); this.beam = pool;
    }
    if (!car.isPlayer && opts.tags) {
      this.tagCanvas = nameTagCanvas(); this.tagTex = new THREE.CanvasTexture(this.tagCanvas); this.tagTex.encoding = THREE.sRGBEncoding; this.lastHp = -1;
      this.tag = new THREE.Sprite(new THREE.SpriteMaterial({ map: this.tagTex, depthWrite: false, transparent: true, sizeAttenuation: false, toneMapped: false }));
      this.tag.scale.set(0.13, 0.0325, 1); this.tag.position.y = this.H + 1.3; this.root.add(this.tag);
      this.updateTag();
    }
    scene.add(this.root);
  }
  spin(dt, v, steer) {
    const a = v * dt / CAR_SHAPES[this.car.def.style].wr;
    for (const w of this.wheels) { w.g.rotation.x += a; if (w.front) w.g.rotation.y = steer * 0.42; }
  }
  updateTag() {
    if (!this.tag) return; const c = this.car, hp = c.health / c.maxHp;
    if (Math.abs(hp - this.lastHp) < 0.02) return; this.lastHp = hp;
    drawNameTag(this.tagCanvas, c.name, hp, c.color); this.tagTex.needsUpdate = true;
  }
  dispose(scene) { scene.remove(this.root); }
}
// ---------- light trails (camera-facing ribbons from the tail lights; HDR so they bloom) ----------
class Trails {
  constructor(scene, n, seg) {
    this.n = n; this.seg = seg; const R = n * 2, V = R * seg * 2;
    this.pos = new Float32Array(V * 3); this.col = new Float32Array(V * 3);
    this.hist = []; for (let i = 0; i < R; i++) this.hist.push({ p: new Float32Array(seg * 3), len: 0, color: [1, 0.2, 0.2] });
    const idx = [];
    for (let r = 0; r < R; r++) for (let k = 0; k < seg - 1; k++) { const a = (r * seg + k) * 2; idx.push(a, a + 1, a + 2, a + 1, a + 3, a + 2); }
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(this.pos, 3).setUsage(THREE.DynamicDrawUsage));
    g.setAttribute('color', new THREE.BufferAttribute(this.col, 3).setUsage(THREE.DynamicDrawUsage));
    g.setIndex(idx);
    this.mesh = new THREE.Mesh(g, new THREE.MeshBasicMaterial({ vertexColors: true, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide, fog: false, toneMapped: false }));
    this.mesh.frustumCulled = false; scene.add(this.mesh);
    this.g = g; this.maxLen = new Array(n).fill(26);
  }
  setColor(ci, hex) {
    const c = new THREE.Color(hex); const hsl = c.getHSL({}); if (hsl.l < 0.3) c.setHSL(hsl.h, Math.max(0.6, hsl.s), 0.5); if (hsl.s < 0.15) c.set('#ff4a5a');
    c.convertSRGBToLinear().multiplyScalar(2.6);
    for (const k of [0, 1]) this.hist[ci * 2 + k].color = [c.r, c.g, c.b];
  }
  push(ci, k, x, y, z) {
    const h = this.hist[ci * 2 + k], p = h.p, seg = this.seg;
    if (h.len > 0) { const dx = p[0] - x, dy = p[1] - y, dz = p[2] - z; if (dx * dx + dy * dy + dz * dz > 400) h.len = 0; }
    p.copyWithin(3, 0, (seg - 1) * 3); p[0] = x; p[1] = y; p[2] = z; h.len = Math.min(seg, h.len + 1);
  }
  update(cam, intens) {
    const seg = this.seg, pos = this.pos, col = this.col, cx = cam.position.x, cy = cam.position.y, cz = cam.position.z;
    for (let r = 0; r < this.hist.length; r++) {
      const h = this.hist[r], p = h.p, I = intens[r >> 1] || 0, cc = h.color, ml = this.maxLen[r >> 1];
      let acc = 0;
      for (let k = 0; k < seg; k++) {
        const vi = (r * seg + k) * 2 * 3; const kk = Math.min(k, h.len - 1);
        if (h.len < 2 || I <= 0.01) { for (let q = 0; q < 6; q++) { pos[vi + q] = 0; col[vi + q] = 0; } continue; }
        const a = Math.max(0, kk - 1), b = Math.min(h.len - 1, kk + 1);
        const x = p[kk * 3], y = p[kk * 3 + 1], z = p[kk * 3 + 2];
        let dx = p[a * 3] - p[b * 3], dy = p[a * 3 + 1] - p[b * 3 + 1], dz = p[a * 3 + 2] - p[b * 3 + 2];
        const tx = cx - x, ty = cy - y, tz = cz - z;
        let sx = dy * tz - dz * ty, sy = dz * tx - dx * tz, sz = dx * ty - dy * tx;
        const l = Math.hypot(sx, sy, sz) || 1, f = 1 - k / (seg - 1), w = 0.13 * (0.35 + 0.65 * f);
        sx = sx / l * w; sy = sy / l * w; sz = sz / l * w;
        pos[vi] = x + sx; pos[vi + 1] = y + sy; pos[vi + 2] = z + sz; pos[vi + 3] = x - sx; pos[vi + 4] = y - sy; pos[vi + 5] = z - sz;
        if (k > 0 && k < h.len) { const q = (k - 1) * 3; acc += Math.hypot(p[q] - x, p[q + 1] - y, p[q + 2] - z); }
        const lf = clamp(1 - acc / ml, 0, 1) * smooth(4, 11, Math.sqrt(tx * tx + ty * ty + tz * tz));
        const fade = (k >= h.len ? 0 : f * f) * I * lf;
        col[vi] = col[vi + 3] = cc[0] * fade; col[vi + 1] = col[vi + 4] = cc[1] * fade; col[vi + 2] = col[vi + 5] = cc[2] * fade;
      }
    }
    this.g.attributes.position.needsUpdate = true; this.g.attributes.color.needsUpdate = true;
  }
}
