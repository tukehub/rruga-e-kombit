// ---------- Track: centreline samples, frames, elevation, terrain function ----------
class Track {
  constructor(city) {
    this.city = city;
    const hw = this.halfW = city.halfW || 11;
    this.seed = strHash(city.id);
    const sc = city.scale || 1;
    const pts = city.pts.map(p => new THREE.Vector3(p[0] * sc, 0, p[1] * sc));
    const curve = new THREE.CatmullRomCurve3(pts, true, 'centripetal');
    curve.arcLengthDivisions = Math.max(3000, pts.length * 400);
    const L0 = curve.getLength();
    const M = this.M = Math.round(L0 / 2);
    const X = this.X = new Float32Array(M), Y = this.Y = new Float32Array(M), Z = this.Z = new Float32Array(M);
    const tmp = new THREE.Vector3();
    for (let i = 0; i < M; i++) { curve.getPointAt(i / M, tmp); X[i] = tmp.x; Z[i] = tmp.z; }
    this.dsH = L0 / M;
    // horizontal frames + curvature
    const NX = this.NX = new Float32Array(M), NZ = this.NZ = new Float32Array(M), HD = this.HD = new Float32Array(M);
    for (let i = 0; i < M; i++) {
      const a = (i - 1 + M) % M, b = (i + 1) % M;
      let tx = X[b] - X[a], tz = Z[b] - Z[a]; const l = Math.hypot(tx, tz) || 1; tx /= l; tz /= l;
      NX[i] = -tz; NZ[i] = tx; HD[i] = Math.atan2(-tx, tz);
    }
    const K0 = new Float32Array(M);
    for (let i = 0; i < M; i++) {
      const a = (i - 1 + M) % M, b = (i + 1) % M;
      K0[i] = wrapAng(HD[b] - HD[a]) / (2 * this.dsH);
    }
    const K = this.K = new Float32Array(M);
    for (let i = 0; i < M; i++) { let s = 0; for (let k = -3; k <= 3; k++) s += K0[(i + k + M) % M]; K[i] = s / 7; }
    // bbox
    let minX = 1e9, maxX = -1e9, minZ = 1e9, maxZ = -1e9;
    for (let i = 0; i < M; i++) { minX = Math.min(minX, X[i]); maxX = Math.max(maxX, X[i]); minZ = Math.min(minZ, Z[i]); maxZ = Math.max(maxZ, Z[i]); }
    this.bbox = { minX, maxX, minZ, maxZ, cx: (minX + maxX) / 2, cz: (minZ + maxZ) / 2, r: Math.max(maxX - minX, maxZ - minZ) / 2 };
    // spatial hash of samples
    this.cell = 30; this.grid = new Map();
    for (let i = 0; i < M; i++) {
      const k = this.gkey(Math.floor(X[i] / this.cell), Math.floor(Z[i] / this.cell));
      let arr = this.grid.get(k); if (!arr) { arr = []; this.grid.set(k, arr); } arr.push(i);
    }
    this.L = L0; this.ds = L0 / M; // provisional (needed by placement helpers)
    this.placeFeatures();
    this.H = this.makeTerrain();
    // elevation from terrain, smoothed along the loop
    for (let i = 0; i < M; i++) Y[i] = this.H(X[i], Z[i]);
    const tmpY = new Float32Array(M);
    const smoothPass = (w) => {
      for (let i = 0; i < M; i++) { let s = 0; for (let k = -w; k <= w; k++) s += Y[(i + k + M) % M]; tmpY[i] = s / (2 * w + 1); }
      Y.set(tmpY);
    };
    for (let p = 0; p < 4; p++) smoothPass(16);
    for (let it = 0; it < 12; it++) {
      let maxSlope = 0;
      for (let i = 0; i < M; i++) maxSlope = Math.max(maxSlope, Math.abs(Y[(i + 1) % M] - Y[i]) / this.dsH);
      if (maxSlope < 0.085) break;
      smoothPass(12);
    }
    if (this.water) { for (let i = 0; i < M; i++) Y[i] = Math.max(Y[i], 1.6); smoothPass(6); for (let i = 0; i < M; i++) Y[i] = Math.max(Y[i], 1.4); }
    // 3D tangents and true length
    const TX = this.TX = new Float32Array(M), TY = this.TY = new Float32Array(M), TZ = this.TZ = new Float32Array(M);
    let L = 0;
    for (let i = 0; i < M; i++) {
      const b = (i + 1) % M; L += Math.hypot(X[b] - X[i], Y[b] - Y[i], Z[b] - Z[i]);
      const a = (i - 1 + M) % M;
      let tx = X[b] - X[a], ty = Y[b] - Y[a], tz = Z[b] - Z[a]; const l = Math.hypot(tx, ty, tz) || 1;
      TX[i] = tx / l; TY[i] = ty / l; TZ[i] = tz / l;
    }
    this.L = L; this.ds = L / M;
    // corner speed factor: v = sqrt(aLat) * VC
    const VC = this.VC = new Float32Array(M);
    for (let i = 0; i < M; i++) VC[i] = 1 / Math.sqrt(Math.max(Math.abs(K[i]), 1e-5));
    this._i0 = 0; this._i1 = 0; this._t = 0;
  }
  gkey(ix, iz) { return (ix + 32768) * 65536 + (iz + 32768); }
  nearest(x, z, maxR) {
    const c = this.cell, R = Math.ceil((maxR || 60) / c);
    const cx = Math.floor(x / c), cz = Math.floor(z / c);
    let best = -1, bd = Infinity;
    for (let ix = cx - R; ix <= cx + R; ix++) for (let iz = cz - R; iz <= cz + R; iz++) {
      const arr = this.grid.get(this.gkey(ix, iz)); if (!arr) continue;
      for (let n = 0; n < arr.length; n++) {
        const i = arr[n]; const dx = this.X[i] - x, dz = this.Z[i] - z; const d2 = dx * dx + dz * dz;
        if (d2 < bd) { bd = d2; best = i; }
      }
    }
    return best < 0 ? null : { i: best, d: Math.sqrt(bd) };
  }
  // brute-force distance (for points possibly far from the road)
  distTo(x, z) {
    const n = this.nearest(x, z, 90); if (n) return n.d;
    let bd = Infinity; for (let i = 0; i < this.M; i += 2) { const dx = this.X[i] - x, dz = this.Z[i] - z; bd = Math.min(bd, dx * dx + dz * dz); }
    return Math.sqrt(bd);
  }
  insideLoop(x, z) {
    let inside = false; const X = this.X, Z = this.Z, M = this.M;
    for (let i = 0, j = M - 1; i < M; j = i++) {
      if ((Z[i] > z) !== (Z[j] > z) && x < (X[j] - X[i]) * (z - Z[i]) / (Z[j] - Z[i]) + X[i]) inside = !inside;
    }
    return inside;
  }
  infieldCenter() {
    const b = this.bbox; let best = null, bd = -1;
    for (let x = b.minX; x <= b.maxX; x += 10) for (let z = b.minZ; z <= b.maxZ; z += 10) {
      if (!this.insideLoop(x, z)) continue;
      const d = this.distTo(x, z); if (d > bd) { bd = d; best = { x, z }; }
    }
    return best ? { x: best.x, z: best.z, clear: bd } : { x: b.cx, z: b.cz, clear: 0 };
  }
  // world position of (s, d) on the horizontal plane (before elevation exists)
  rawPos(s, d) {
    this.locate(s); const i0 = this._i0, i1 = this._i1, t = this._t;
    return { x: lerp(this.X[i0], this.X[i1], t) + lerp(this.NX[i0], this.NX[i1], t) * d, z: lerp(this.Z[i0], this.Z[i1], t) + lerp(this.NZ[i0], this.NZ[i1], t) * d, hd: this.HD[i0] };
  }
  placeFeatures() {
    const c = this.city, hw = this.halfW;
    this.hills = []; this.lms = [];
    for (const lm of c.landmarks || []) {
      let p;
      if (lm.center) { const ic = this._ic || (this._ic = this.infieldCenter()); p = { x: ic.x, z: ic.z, hd: 0 }; }
      else {
        const s = lm.at * this.L;
        let side = lm.side || 1;
        if (lm.out || lm.in) { const q = this.rawPos(s, 30); const ins = this.insideLoop(q.x, q.z); side = (lm.out ? ins : !ins) ? -1 : 1; }
        p = this.rawPos(s, side * lm.off);
        // push away from the road if another part of the loop is too close
        const need = lm.hill ? lm.hill.r * 0.8 + hw : (lm.off - 6);
        let off = lm.off;
        for (let k = 0; k < 60 && this.distTo(p.x, p.z) < need; k++) { off += 6; p = this.rawPos(s, side * off); }
        p.off = off; p.side = side;
      }
      const o = Object.assign({}, lm, { x: p.x, z: p.z, hd: p.hd, side: p.side || lm.side || 1 });
      if (lm.center && this.lms.length && this.lms.some(q => q.center)) { /* shares the hill of an earlier centred landmark */ }
      this.lms.push(o);
      if (lm.hill) this.hills.push({ x: p.x, z: p.z, h: lm.hill.h, r: lm.hill.r });
    }
    this.water = null;
    const w = c.water;
    if (w && w.type === 'sea') {
      const dx = w.dir[0], dz = w.dir[1]; let mp = -1e9;
      for (let i = 0; i < this.M; i++) mp = Math.max(mp, this.X[i] * dx + this.Z[i] * dz);
      this.water = { type: 'sea', dx, dz, coast: mp + 42 };
    } else if (w && w.type === 'lake') {
      const s = w.at * this.L; let off = w.off; let p = this.rawPos(s, w.side * off);
      for (let k = 0; k < 40 && this.distTo(p.x, p.z) < w.r + hw + 30; k++) { off += 8; p = this.rawPos(s, w.side * off); }
      this.water = { type: 'lake', x: p.x, z: p.z, r: w.r };
    }
  }
  makeTerrain() {
    const c = this.city, noise = makeNoise(this.seed ^ 0x9e3779b9);
    const amp = c.amp || 3, sc = c.tscale || 400, hills = this.hills, water = this.water;
    const base = water ? (water.type === 'sea' ? amp + 1.8 : 2.4) : 0;
    return (x, z) => {
      let h = base + amp * noise(x / sc, z / sc, 3);
      for (let i = 0; i < hills.length; i++) {
        const hl = hills[i]; const d = Math.hypot(x - hl.x, z - hl.z);
        if (d < hl.r) h += hl.h * (1 - smooth(0.3 * hl.r, hl.r, d));
      }
      if (water) {
        if (water.type === 'sea') { const sd = x * water.dx + z * water.dz - water.coast; h -= smooth(-8, 70, sd) * 16; }
        else { const d = Math.hypot(x - water.x, z - water.z); h -= (1 - smooth(water.r * 0.55, water.r * 1.2, d)) * 12; }
      }
      return h;
    };
  }
  waterDepth(x, z) { // >0 means below sea/lake level region (for placement checks)
    return -this.H(x, z);
  }
  locate(s) {
    const L = this.L; s = s % L; if (s < 0) s += L;
    const f = s / this.ds; const fi = Math.floor(f);
    this._i0 = fi % this.M; this._i1 = (this._i0 + 1) % this.M; this._t = f - fi;
  }
  wrapS(d) { const L = this.L; d = d % L; if (d > L / 2) d -= L; else if (d < -L / 2) d += L; return d; }
  pos(s, d, out) {
    this.locate(s); const i0 = this._i0, i1 = this._i1, t = this._t;
    const nx = lerp(this.NX[i0], this.NX[i1], t), nz = lerp(this.NZ[i0], this.NZ[i1], t);
    out.x = lerp(this.X[i0], this.X[i1], t) + nx * d;
    out.y = lerp(this.Y[i0], this.Y[i1], t);
    out.z = lerp(this.Z[i0], this.Z[i1], t) + nz * d;
    return out;
  }
  tangent(s, out) {
    this.locate(s); const i0 = this._i0, i1 = this._i1, t = this._t;
    out.x = lerp(this.TX[i0], this.TX[i1], t); out.y = lerp(this.TY[i0], this.TY[i1], t); out.z = lerp(this.TZ[i0], this.TZ[i1], t);
    return out;
  }
  normal(s, out) {
    this.locate(s); const i0 = this._i0, i1 = this._i1, t = this._t;
    out.x = lerp(this.NX[i0], this.NX[i1], t); out.y = 0; out.z = lerp(this.NZ[i0], this.NZ[i1], t);
    return out;
  }
  curv(s) { this.locate(s); return lerp(this.K[this._i0], this.K[this._i1], this._t); }
  heading(s) { this.locate(s); return this.HD[this._i0] + wrapAng(this.HD[this._i1] - this.HD[this._i0]) * this._t; }
  // validation helpers (dev)
  stats() {
    let maxK = 0; for (let i = 0; i < this.M; i++) maxK = Math.max(maxK, Math.abs(this.K[i]));
    let minSelf = Infinity, at = -1; const skip = Math.round(90 / this.ds);
    for (let i = 0; i < this.M; i += 2) {
      const c = this.cell, cx = Math.floor(this.X[i] / c), cz = Math.floor(this.Z[i] / c);
      for (let ix = cx - 2; ix <= cx + 2; ix++) for (let iz = cz - 2; iz <= cz + 2; iz++) {
        const arr = this.grid.get(this.gkey(ix, iz)); if (!arr) continue;
        for (const j of arr) {
          let di = Math.abs(i - j); di = Math.min(di, this.M - di); if (di < skip) continue;
          const d = Math.hypot(this.X[i] - this.X[j], this.Z[i] - this.Z[j]); if (d < minSelf) { minSelf = d; at = i; }
        }
      }
    }
    let minY = 1e9, maxY = -1e9; for (let i = 0; i < this.M; i++) { minY = Math.min(minY, this.Y[i]); maxY = Math.max(maxY, this.Y[i]); }
    return { L: Math.round(this.L), minR: Math.round(1 / maxK), minSelf: Math.round(minSelf), selfAt: (at / this.M).toFixed(2), yRange: [minY.toFixed(1), maxY.toFixed(1)] };
  }
}
