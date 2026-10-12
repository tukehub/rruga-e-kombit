// ---------- car models: lofted 2020-style bodies (curved sections, fender bulges, wheel wells),
// greenhouse + painted roof, raycast-placed LED lights / grilles, spoked rims with brake calipers ----------
// Units: metres. Car faces +z. Profiles are keyframes [z, value] interpolated with monotone cubics.
const CAR_SHAPES = {
  gt: { // Benxi GT: long-hood fastback coupé
    L: 4.55, W: 1.96, wr: 0.355, tyreW: 0.28, zF: 1.32, zR: -1.30, n: 3.1, tumble: 0.12,
    top: [[-2.275, 0.66], [-2.22, 0.84], [-2.0, 0.89], [-1.5, 0.875], [-0.9, 0.86], [-0.2, 0.87], [0.4, 0.86], [1.1, 0.8], [1.7, 0.72], [2.1, 0.6], [2.275, 0.46]],
    bot: [[-2.275, 0.44], [-2.15, 0.28], [-1.8, 0.17], [1.8, 0.15], [2.2, 0.2], [2.275, 0.28]],
    half: [[-2.275, 0.8], [-2.05, 0.96], [-1.4, 1.0], [-0.7, 0.95], [0.2, 0.93], [1.0, 0.97], [1.5, 0.99], [2.0, 0.92], [2.275, 0.7]],
    cab: { keys: [[-1.9, 0.87], [-1.3, 1.0], [-0.6, 1.2], [-0.15, 1.25], [0.1, 1.22], [0.55, 0.87]], w0: 0.86, w1: 0.58, n: 3, roof: [-0.85, 0.02] },
    head: { type: 'slim', y: 0.63, x: 0.64, w: 0.42, h: 0.05 }, tail: { type: 'bar', y: 0.8, h: 0.05 },
    grille: { y: 0.42, w: 0.78, h: 0.2 }, spoiler: 'duck', exhaust: [-0.62, -0.5, 0.5, 0.62], rim: { n: 10, sp: 0.36, col: 'dark' }, caliper: '#e01818',
  },
  muscle: { // Kali i Egër: long, wide, flat-nosed fastback
    L: 4.79, W: 1.98, wr: 0.37, tyreW: 0.29, zF: 1.43, zR: -1.29, n: 3.5, tumble: 0.08,
    top: [[-2.395, 0.76], [-2.33, 0.96], [-1.9, 0.95], [-1.0, 0.95], [-0.2, 0.97], [0.6, 0.98], [1.4, 0.95], [2.0, 0.9], [2.3, 0.82], [2.395, 0.6]],
    bot: [[-2.395, 0.42], [-2.25, 0.28], [-1.9, 0.19], [1.95, 0.18], [2.3, 0.24], [2.395, 0.3]],
    half: [[-2.395, 0.88], [-2.15, 0.98], [-1.4, 1.0], [-0.6, 0.94], [0.4, 0.94], [1.3, 0.98], [2.1, 0.95], [2.395, 0.86]],
    cab: { keys: [[-2.0, 0.95], [-1.3, 1.12], [-0.6, 1.33], [-0.15, 1.36], [0.1, 1.33], [0.6, 0.97]], w0: 0.85, w1: 0.6, n: 3, roof: [-0.75, 0.0] },
    head: { type: 'slim', y: 0.8, x: 0.7, w: 0.38, h: 0.07 }, tail: { type: 'tri', y: 0.86, h: 0.16 },
    grille: { y: 0.6, w: 0.64, h: 0.26 }, spoiler: 'lip', exhaust: [-0.66, -0.56, 0.56, 0.66], rim: { n: 10, sp: 0.3, col: 'black' }, caliper: '#d8d8dc',
  },
  hatch: { // Golfi GTI: compact hot hatch
    L: 4.28, W: 1.84, wr: 0.34, tyreW: 0.25, zF: 1.26, zR: -1.37, n: 3.3, tumble: 0.1,
    top: [[-2.14, 0.86], [-2.08, 1.0], [-1.7, 1.0], [-0.8, 0.99], [0.2, 0.98], [0.9, 0.94], [1.5, 0.88], [1.95, 0.8], [2.12, 0.66], [2.14, 0.5]],
    bot: [[-2.14, 0.42], [-2.02, 0.28], [-1.75, 0.2], [1.75, 0.19], [2.08, 0.24], [2.14, 0.3]],
    half: [[-2.14, 0.86], [-1.95, 0.97], [-1.4, 1.0], [0.0, 0.97], [1.3, 0.98], [1.9, 0.92], [2.14, 0.8]],
    cab: { keys: [[-2.0, 1.0], [-1.88, 1.3], [-1.55, 1.42], [-0.6, 1.46], [0.1, 1.43], [0.3, 1.37], [0.85, 0.96]], w0: 0.88, w1: 0.64, n: 3.2, roof: [-1.5, 0.12] },
    head: { type: 'slim', y: 0.77, x: 0.62, w: 0.42, h: 0.07, bar: true }, tail: { type: 'pair', y: 0.94, x: 0.72, w: 0.34, h: 0.08 },
    grille: { y: 0.55, w: 0.72, h: 0.16 }, spoiler: 'roof', exhaust: [-0.6, 0.6], rim: { n: 5, sp: 0.34, col: 'silver' }, caliper: '#e01818',
  },
  sleek: { // Uragani: mid-engine wedge supercar
    L: 4.52, W: 2.0, wr: 0.36, tyreW: 0.3, zF: 1.23, zR: -1.39, n: 2.7, tumble: 0.16,
    top: [[-2.26, 0.62], [-2.18, 0.84], [-1.8, 0.9], [-1.2, 0.9], [-0.6, 0.86], [0.1, 0.8], [0.8, 0.72], [1.5, 0.62], [2.0, 0.5], [2.26, 0.36]],
    bot: [[-2.26, 0.38], [-2.12, 0.24], [-1.75, 0.13], [1.85, 0.12], [2.18, 0.15], [2.26, 0.2]],
    half: [[-2.26, 0.86], [-1.95, 1.0], [-1.3, 1.0], [-0.5, 0.9], [0.4, 0.9], [1.2, 0.98], [1.9, 0.93], [2.26, 0.68]],
    cab: { keys: [[-1.45, 0.9], [-0.95, 1.02], [-0.45, 1.13], [-0.05, 1.15], [0.25, 1.06], [0.95, 0.76]], w0: 0.8, w1: 0.55, n: 2.5, roof: [-0.55, 0.1] },
    head: { type: 'slim', y: 0.48, x: 0.64, w: 0.46, h: 0.04 }, tail: { type: 'pair', y: 0.78, x: 0.62, w: 0.5, h: 0.05 },
    grille: { y: 0.25, w: 0.86, h: 0.13 }, spoiler: 'duck', exhaust: [-0.12, 0.12], rim: { n: 5, sp: 0.42, col: 'black' }, caliper: '#f2c230',
  },
  jeep: { // Gelendvagen: the box that never dies
    L: 4.82, W: 1.98, wr: 0.43, tyreW: 0.3, zF: 1.6, zR: -1.29, n: 5.2, tumble: 0.05,
    top: [[-2.41, 1.08], [-2.37, 1.24], [-1.0, 1.25], [0.5, 1.27], [1.9, 1.24], [2.33, 1.18], [2.41, 0.95]],
    bot: [[-2.41, 0.58], [-2.3, 0.48], [-1.9, 0.44], [2.0, 0.44], [2.33, 0.5], [2.41, 0.58]],
    half: [[-2.41, 0.93], [-2.32, 0.97], [-1.29, 1.0], [-0.4, 0.96], [0.6, 0.96], [1.6, 1.0], [2.3, 0.97], [2.41, 0.93]],
    cab: { keys: [[-2.34, 1.24], [-2.32, 1.9], [-2.2, 1.96], [0.25, 1.97], [0.42, 1.9], [0.66, 1.26]], w0: 0.94, w1: 0.88, n: 8, roof: [-2.25, 0.3] },
    head: { type: 'round', y: 1.05, x: 0.68, r: 0.12 }, tail: { type: 'square', y: 1.12, x: 0.86, w: 0.14, h: 0.32 },
    grille: { y: 0.98, w: 0.62, h: 0.3 }, spare: true, bumpers: true, rim: { n: 6, sp: 0.45, col: 'silver' }, caliper: '#3a3a40',
  },
  van: { // Sprinteri: the national furgon
    L: 5.6, W: 2.02, wr: 0.38, tyreW: 0.25, zF: 1.85, zR: -1.62, n: 4.4, tumble: 0.05, van: true,
    top: [[-2.8, 1.2], [-2.76, 1.3], [1.35, 1.32], [1.9, 1.2], [2.5, 1.08], [2.75, 0.95], [2.8, 0.78]],
    bot: [[-2.8, 0.62], [-2.65, 0.46], [2.45, 0.44], [2.75, 0.5], [2.8, 0.6]],
    half: [[-2.8, 0.95], [-2.7, 1.0], [2.3, 0.99], [2.8, 0.86]],
    cab: { keys: [[-2.76, 1.3], [-2.74, 2.55], [0.85, 2.56], [1.15, 2.42], [1.75, 1.33]], w0: 0.99, w1: 0.92, n: 9 },
    head: { type: 'slim', y: 1.08, x: 0.72, w: 0.36, h: 0.12 }, tail: { type: 'square', y: 1.3, x: 0.92, w: 0.12, h: 0.5 },
    grille: { y: 0.92, w: 0.7, h: 0.3 }, bumpers: true, rim: { steel: true, col: 'silver' }, caliper: null,
  },
};

function monoCurve(keys) {
  const n = keys.length, xs = keys.map(k => k[0]), ys = keys.map(k => k[1]), d = [], m = new Array(n);
  for (let i = 0; i < n - 1; i++) d.push((ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i]));
  m[0] = d[0]; m[n - 1] = d[n - 2];
  for (let i = 1; i < n - 1; i++) m[i] = d[i - 1] * d[i] <= 0 ? 0 : (d[i - 1] + d[i]) / 2;
  for (let i = 0; i < n - 1; i++) {
    if (d[i] === 0) { m[i] = m[i + 1] = 0; continue; }
    const a = m[i] / d[i], b = m[i + 1] / d[i], s = a * a + b * b;
    if (s > 9) { const t = 3 / Math.sqrt(s); m[i] = t * a * d[i]; m[i + 1] = t * b * d[i]; }
  }
  return (x) => {
    if (x <= xs[0]) return ys[0]; if (x >= xs[n - 1]) return ys[n - 1];
    let i = 0; while (x > xs[i + 1]) i++;
    const h = xs[i + 1] - xs[i], t = (x - xs[i]) / h, t2 = t * t, t3 = t2 * t;
    return (2 * t3 - 3 * t2 + 1) * ys[i] + (t3 - 2 * t2 + t) * h * m[i] + (-2 * t3 + 3 * t2) * ys[i + 1] + (t3 - t2) * h * m[i + 1];
  };
}
function mergeGeos(list) {
  const P = [], N = [];
  for (let g of list) {
    if (g.index) g = g.toNonIndexed();
    if (!g.attributes.normal) g.computeVertexNormals();
    P.push(...g.attributes.position.array); N.push(...g.attributes.normal.array);
  }
  const out = new THREE.BufferGeometry();
  out.setAttribute('position', new THREE.Float32BufferAttribute(P, 3)); out.setAttribute('normal', new THREE.Float32BufferAttribute(N, 3));
  out.computeBoundingSphere(); return out;
}
// body: closed loft of superellipse sections; wheel wells cut and fenders raised over the wheels
function loftBody(S, f) {
  const hz = S.L / 2, HW = S.W / 2, n = S.n, tumble = S.tumble, NZ = 120, NS = 18, R = S.wr + 0.06;
  const archY = (z) => { let y = -1; for (const zc of [S.zR, S.zF]) { const dz = z - zc; if (Math.abs(dz) < R) y = Math.max(y, S.wr + Math.sqrt(R * R - dz * dz)); } return y; };
  const P = [], I = [];
  const ringAt = (z, k0, sc) => {
    const yb = f.bot(z), yt = f.top(z), hw = f.half(z) * HW, ym = yb + (yt - yb) * 0.46, xIn = hw - S.tyreW - 0.12, ay = archY(z);
    const pts = [];
    for (let k = 0; k <= NS; k++) {
      const th = -Math.PI / 2 + Math.PI * k / NS, c = Math.cos(th), s = Math.sin(th);
      const ex = Math.pow(Math.abs(c), 2 / n), ey = Math.sign(s) * Math.pow(Math.abs(s), 2 / n);
      let x = hw * ex * (1 - tumble * Math.max(0, s)), y = s < 0 ? ym + ey * (ym - yb) : ym + ey * (yt - ym);
      if (ay > 0) {
        const o = smooth(xIn - 0.05, xIn + 0.07, x);
        if (s < 0.25) { if (y < ay) y = lerp(y, ay, o); }
        else if (y < ay + 0.07) y = lerp(y, ay + 0.07, o);
      }
      pts.push([x * sc, ym + (y - ym) * sc]);
    }
    const ring = pts.slice(); for (let k = NS - 1; k >= 1; k--) ring.push([-pts[k][0], pts[k][1]]);
    for (const p of ring) P.push(p[0], p[1], z);
    return ring.length;
  };
  const zs = []; for (let i = 0; i <= NZ; i++) zs.push(-hz * Math.cos(Math.PI * i / NZ));
  const rings = [];
  rings.push({ z: -hz - 0.035, sc: 0.62 }); rings.push({ z: -hz - 0.012, sc: 0.9 });
  for (const z of zs) rings.push({ z, sc: 1 });
  rings.push({ z: hz + 0.012, sc: 0.9 }); rings.push({ z: hz + 0.035, sc: 0.62 });
  let RL = 0;
  for (const r of rings) RL = ringAt(r.z, 0, r.sc);
  for (let i = 0; i < rings.length - 1; i++) for (let k = 0; k < RL; k++) {
    const a = i * RL + k, b = i * RL + (k + 1) % RL, c = a + RL, d = b + RL; I.push(a, b, c, b, d, c);
  }
  // caps
  for (const [ri, dir] of [[0, -1], [rings.length - 1, 1]]) {
    let cx = 0, cy = 0; for (let k = 0; k < RL; k++) { cy += P[(ri * RL + k) * 3 + 1]; } cy /= RL;
    const ci = P.length / 3; P.push(cx, cy, rings[ri].z + dir * 0.012);
    for (let k = 0; k < RL; k++) { const a = ri * RL + k, b = ri * RL + (k + 1) % RL; if (dir > 0) I.push(a, b, ci); else I.push(b, a, ci); }
  }
  const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.Float32BufferAttribute(P, 3)); g.setIndex(I); g.computeVertexNormals();
  return g;
}
// greenhouse (glass) or the painted roof skin over it
function loftCabin(S, f, roof) {
  const C = S.cab, HW = S.W / 2, ctop = monoCurve(C.keys), n = C.n || 3, K = 9;
  const z0 = roof ? roof[0] : C.keys[0][0], z1 = roof ? roof[1] : C.keys[C.keys.length - 1][0], NZ = roof ? 24 : 44;
  const phi0 = roof ? 0.6 : 0, P = [], I = [];
  for (let i = 0; i <= NZ; i++) {
    const z = lerp(z0, z1, i / NZ), yb = f.top(z) - 0.035, yt = Math.max(ctop(z), yb + 0.001) + (roof ? 0.012 : 0);
    const hb = f.half(z) * HW * C.w0, ht = f.half(z) * HW * C.w1 * (roof ? 1.015 : 1);
    const row = [];
    for (let k = 0; k <= K; k++) {
      const ph = (phi0 + (1 - phi0) * k / K) * Math.PI / 2, ey = Math.pow(Math.sin(ph), 2 / n), ex = Math.pow(Math.cos(ph), 2 / n);
      row.push([lerp(hb, ht, ey) * ex, yb + (yt - yb) * ey]);
    }
    const ring = row.slice(); for (let k = K - 1; k >= 0; k--) ring.push([-row[k][0], row[k][1]]);
    for (const p of ring) P.push(p[0], p[1], z);
  }
  const RL = 2 * K + 1;
  for (let i = 0; i < NZ; i++) for (let k = 0; k < RL - 1; k++) { const a = i * RL + k, b = a + 1, c = a + RL, d = b + RL; I.push(a, b, c, b, d, c); }
  const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.Float32BufferAttribute(P, 3)); g.setIndex(I); g.computeVertexNormals();
  return g;
}
const _rc = new THREE.Raycaster(), _q = new THREE.Quaternion(), _zA = new THREE.Vector3(0, 0, 1);
// place a box (w,h,d) flush on a surface found by casting a ray; returns the geometry or null
function stick(mesh, ox, oy, oz, dx, dy, dz, w, h, d, push) {
  _rc.set(new THREE.Vector3(ox, oy, oz), new THREE.Vector3(dx, dy, dz)); _rc.far = 20;
  const hit = _rc.intersectObject(mesh, false)[0]; if (!hit) return null;
  const nrm = hit.face.normal.clone().normalize();
  const g = new THREE.BoxGeometry(w, h, d);
  _q.setFromUnitVectors(_zA, nrm); const m = new THREE.Matrix4().compose(hit.point.clone().addScaledVector(nrm, d / 2 - (push || 0.012)), _q, new THREE.Vector3(1, 1, 1));
  g.applyMatrix4(m); g.userData.p = hit.point.clone(); return g;
}
function rimGeo(S) {
  const R = S.wr, rr = R * 0.66, tw = S.tyreW, spec = S.rim, sh = new THREE.Shape();
  sh.absarc(0, 0, rr, 0, Math.PI * 2, false);
  if (spec.steel) {
    for (let i = 0; i < 8; i++) { const a = i / 8 * Math.PI * 2, h = new THREE.Path(); h.absarc(Math.cos(a) * rr * 0.62, Math.sin(a) * rr * 0.62, rr * 0.14, 0, Math.PI * 2, true); sh.holes.push(h); }
  } else {
    const N = spec.n, rh = rr * 0.3, ro = rr * 0.86, seg = Math.PI * 2 / N, sp = spec.sp;
    for (let i = 0; i < N; i++) {
      const a0 = i * seg + seg * sp / 2, a1 = (i + 1) * seg - seg * sp / 2, h = new THREE.Path();
      const ai0 = i * seg + seg * sp * 0.9, ai1 = (i + 1) * seg - seg * sp * 0.9;
      h.moveTo(Math.cos(ai0) * rh, Math.sin(ai0) * rh);
      for (let k = 0; k <= 8; k++) { const a = a0 + (a1 - a0) * k / 8; h.lineTo(Math.cos(a) * ro, Math.sin(a) * ro); }
      h.lineTo(Math.cos(ai1) * rh, Math.sin(ai1) * rh); h.closePath(); sh.holes.push(h);
    }
  }
  const depth = 0.03, face = new THREE.ExtrudeGeometry(sh, { depth, bevelEnabled: true, bevelThickness: 0.012, bevelSize: 0.008, bevelSegments: 2, curveSegments: 28 });
  face.rotateY(Math.PI / 2); face.translate(tw / 2 - 0.035 - depth, 0, 0);
  const cap = new THREE.CylinderGeometry(rr * 0.13, rr * 0.15, 0.03, 16); cap.rotateZ(Math.PI / 2); cap.translate(tw / 2 - 0.012, 0, 0);
  const lip = new THREE.TorusGeometry(rr * 0.99, 0.014, 6, 40); lip.rotateY(Math.PI / 2); lip.translate(tw / 2 - 0.03, 0, 0);
  return mergeGeos([face, cap, lip]);
}
function tyreGeo(S) {
  const R = S.wr, tw = S.tyreW, rr = R * 0.66, pts = [];
  const prof = [[rr * 0.98, -tw / 2], [R - 0.045, -tw / 2], [R - 0.012, -tw / 2 + 0.02], [R, -tw / 2 + 0.06], [R, tw / 2 - 0.06], [R - 0.012, tw / 2 - 0.02], [R - 0.045, tw / 2], [rr * 0.98, tw / 2]];
  for (const p of prof) pts.push(new THREE.Vector2(p[0], p[1]));
  const g = new THREE.LatheGeometry(pts, 32); g.rotateZ(-Math.PI / 2);
  const barrel = new THREE.CylinderGeometry(rr * 0.98, rr * 0.98, tw * 0.9, 24, 1, true); barrel.rotateZ(Math.PI / 2);
  const disc = new THREE.CylinderGeometry(rr * 0.8, rr * 0.8, 0.025, 24); disc.rotateZ(Math.PI / 2); disc.translate(0.02, 0, 0);
  return { tyre: g, inner: mergeGeos([barrel, disc]) };
}
const CAR_GEO = {};
function carGeo(style) {
  if (CAR_GEO[style]) return CAR_GEO[style];
  const S = CAR_SHAPES[style], hz = S.L / 2, HW = S.W / 2;
  const f = { top: monoCurve(S.top), bot: monoCurve(S.bot), half: monoCurve(S.half) };
  const body = loftBody(S, f), cab = loftCabin(S, f, null), roof = S.cab.roof ? loftCabin(S, f, S.cab.roof) : null;
  const bm = new THREE.Mesh(body), cm = new THREE.Mesh(cab);
  const paint = [], dark = [], glass = [], head = [], tail = [], chrome = [];
  const push = (arr, g) => { if (g) arr.push(g); return g; };
  // front lights
  const H = S.head;
  for (const sx of [-1, 1]) {
    if (H.type === 'round') {
      const hit = stick(bm, sx * HW * H.x, H.y, 6, 0, 0, -1, 0.01, 0.01, 0.01, 0);
      if (hit) { const p = hit.userData.p, c = new THREE.CylinderGeometry(H.r, H.r, 0.06, 20); c.rotateX(Math.PI / 2); c.translate(p.x, p.y, p.z + 0.02); head.push(c); const ring = new THREE.TorusGeometry(H.r + 0.02, 0.018, 6, 24); ring.translate(p.x, p.y, p.z + 0.03); chrome.push(ring); }
    } else {
      push(head, stick(bm, sx * HW * H.x, H.y, 6, 0, 0, -1, H.w, H.h, 0.05));
      push(head, stick(bm, sx * HW * (H.x + 0.1), H.y - H.h * 1.4, 6, 0, 0, -1, H.w * 0.55, 0.022, 0.04));
    }
  }
  if (H.bar) push(head, stick(bm, 0, H.y + 0.01, 6, 0, 0, -1, HW * 0.75, 0.018, 0.04));
  // continuous LED light bar across the nose (the modern cue; the lamps above sit inside it)
  push(head, stick(bm, 0, H.y + 0.02, 6, 0, 0, -1, HW * 1.45, 0.02, 0.04, 0.03));
  // tail lights
  const T = S.tail;
  // rear LED bar, same width as the nose bar
  push(tail, stick(bm, 0, T.y + 0.04, -6, 0, 0, 1, HW * 1.45, 0.018, 0.04, 0.03));
  if (T.type === 'bar') { for (let i = -6; i <= 6; i++) push(tail, stick(bm, i / 6 * HW * 0.84, T.y, -6, 0, 0, 1, HW * 0.15, T.h, 0.05)); }
  else for (const sx of [-1, 1]) {
    if (T.type === 'tri') for (let k = 0; k < 3; k++) push(tail, stick(bm, sx * HW * (0.5 + k * 0.12), T.y, -6, 0, 0, 1, 0.06, T.h, 0.05));
    else push(tail, stick(bm, sx * HW * T.x, T.y, -6, 0, 0, 1, T.w, T.h, 0.05));
  }
  // grille, splitter, diffuser, skirts, exhausts
  if (S.grille) push(dark, stick(bm, 0, S.grille.y, 6, 0, 0, -1, S.grille.w * S.W * 0.5, S.grille.h, 0.05, 0.02));
  push(dark, stick(bm, 0, f.bot(hz - 0.12) + 0.06, 6, 0, 0, -1, S.W * 0.82, 0.05, 0.12, 0.03));
  push(dark, stick(bm, 0, f.bot(-hz + 0.15) + 0.08, -6, 0, 0, 1, S.W * 0.7, 0.12, 0.1, 0.04));
  for (const sx of [-1, 1]) {
    const z0 = S.zR + S.wr + 0.12, z1 = S.zF - S.wr - 0.12, zm = (z0 + z1) / 2;
    const sk = new THREE.BoxGeometry(0.05, 0.07, z1 - z0); sk.translate(sx * (f.half(zm) * HW - 0.01), f.bot(zm) + 0.05, zm); dark.push(sk);
  }
  for (const x of S.exhaust || []) {
    const hit = stick(bm, x, f.bot(-hz + 0.1) + 0.13, -6, 0, 0, 1, 0.01, 0.01, 0.01, 0);
    if (hit) { const p = hit.userData.p, c = new THREE.CylinderGeometry(0.045, 0.045, 0.14, 14, 1, true); c.rotateX(Math.PI / 2); c.translate(p.x, p.y, p.z - 0.03); chrome.push(c); }
  }
  // mirrors (body colour) on short stalks at the base of the windscreen
  const zc1 = S.cab.keys[S.cab.keys.length - 1][0], zm = zc1 - (S.van ? 0.35 : 0.3), ym = f.top(zm) + (S.van ? 0.35 : 0.12);
  for (const sx of [-1, 1]) {
    const xm = sx * (f.half(zm) * HW * S.cab.w0 + 0.11);
    const m = new THREE.BoxGeometry(0.17, 0.09, 0.09); m.translate(xm + sx * 0.02, ym - 0.02, zm); paint.push(m);
    const st = new THREE.BoxGeometry(0.12, 0.03, 0.05); st.translate(xm - sx * 0.09, ym - 0.03, zm); dark.push(st);
  }
  // spoilers
  if (S.spoiler === 'duck' || S.spoiler === 'lip') {
    const z = -hz + 0.18, w = S.W * (S.spoiler === 'duck' ? 0.84 : 0.7), sp = new THREE.BoxGeometry(w, 0.035, S.spoiler === 'duck' ? 0.32 : 0.2);
    sp.rotateX(-0.12); sp.translate(0, f.top(z) + 0.03, z); paint.push(sp);
  }
  if (S.spoiler === 'roof') { const z = S.cab.keys[1][0] + 0.06, sp = new THREE.BoxGeometry(S.W * 0.7, 0.04, 0.3); sp.rotateX(-0.18); sp.translate(0, S.cab.keys[1][1] + 0.05, z - 0.02); dark.push(sp); }
  // boxy extras: bumpers, spare wheel, van glazing
  if (S.bumpers) {
    for (const [z, dir] of [[hz, -1], [-hz, 1]]) { const b = new THREE.BoxGeometry(S.W * 0.95, 0.2, 0.16); b.translate(0, f.bot(z - dir * 0.1) + 0.12, z + (dir < 0 ? 0.04 : -0.04)); dark.push(b); }
  }
  const TG = tyreGeo(S);
  let spare = null;
  if (S.spare) { spare = TG.tyre.clone(); spare.rotateY(Math.PI / 2); spare.translate(0, 1.22, -hz - S.tyreW / 2 - 0.02); const cv = new THREE.CylinderGeometry(S.wr * 0.98, S.wr * 0.98, 0.04, 28); cv.rotateX(Math.PI / 2); cv.translate(0, 1.22, -hz - S.tyreW - 0.02); paint.push(cv); }
  if (S.van) {
    push(glass, stick(cm, 0, 1.92, 6, 0, 0, -1, S.W * 0.86, 0.95, 0.03, 0.01));
    for (const sx of [-1, 1]) for (const z of [0.55, -0.45, -1.45, -2.25]) push(glass, stick(cm, sx * 6, 1.95, z, -sx, 0, 0, z > 0 ? 0.7 : 0.78, 0.5, 0.03, 0.01));
  }
  // tail-light anchor points for the light trails (outermost lights)
  const tps = tail.map(g => g.userData.p).filter(Boolean).sort((a, b) => a.x - b.x);
  const tailPts = tps.length ? [[tps[0].x, tps[0].y, tps[0].z - 0.05], [tps[tps.length - 1].x, tps[tps.length - 1].y, tps[tps.length - 1].z - 0.05]] : [[-HW * 0.8, 0.8, -hz], [HW * 0.8, 0.8, -hz]];
  const out = {
    S, f, body, cab, roof, tailPts,
    paint: paint.length ? mergeGeos(paint) : null, dark: mergeGeos(dark), glass: glass.length ? mergeGeos(glass) : null,
    head: mergeGeos(head), tail: mergeGeos(tail), chrome: chrome.length ? mergeGeos(chrome) : null, spare,
    tyre: TG.tyre, inner: TG.inner, rim: rimGeo(S), caliper: S.caliper ? new THREE.BoxGeometry(0.07, S.wr * 0.42, S.wr * 0.34) : null,
    H: Math.max(...S.cab.keys.map(k => k[1])), wx: (z) => f.half(z) * HW - S.tyreW / 2 - 0.035,
  };
  CAR_GEO[style] = out; return out;
}
const CAR_MATS = {};
function carMats() {
  if (CAR_MATS.glass) return CAR_MATS;
  CAR_MATS.glass = linMat(new THREE.MeshPhysicalMaterial({ color: '#070a0f', roughness: 0.04, metalness: 0.2, clearcoat: 1, clearcoatRoughness: 0.03 }));
  CAR_MATS.trim = linMat(new THREE.MeshStandardMaterial({ color: '#111114', roughness: 0.32, metalness: 0.5 }));
  CAR_MATS.tyre = linMat(new THREE.MeshStandardMaterial({ color: '#151516', roughness: 0.9, side: THREE.DoubleSide }));
  CAR_MATS.inner = linMat(new THREE.MeshStandardMaterial({ color: '#2a2b2e', roughness: 0.45, metalness: 0.8, side: THREE.DoubleSide }));
  CAR_MATS.chrome = linMat(new THREE.MeshStandardMaterial({ color: '#d8dbe0', roughness: 0.12, metalness: 1 }));
  CAR_MATS.rim_silver = linMat(new THREE.MeshStandardMaterial({ color: '#c9ccd2', roughness: 0.22, metalness: 1 }));
  CAR_MATS.rim_dark = linMat(new THREE.MeshStandardMaterial({ color: '#3a3d42', roughness: 0.28, metalness: 1 }));
  CAR_MATS.rim_black = linMat(new THREE.MeshStandardMaterial({ color: '#121214', roughness: 0.3, metalness: 0.7 }));
  CAR_MATS.head = linMat(glowMat('#f4f7ff', 6));
  CAR_MATS.tail = linMat(glowMat('#ff1830', 5));
  for (const k of ['glass', 'chrome', 'rim_silver', 'rim_dark', 'rim_black', 'trim']) CAR_MATS[k].envMapIntensity = 2.4;
  return CAR_MATS;
}
function paintMat(hex) {
  const key = 'p' + hex; if (CAR_MATS[key]) return CAR_MATS[key];
  const m = linMat(new THREE.MeshPhysicalMaterial({ color: hex, roughness: 0.22, metalness: 0.55, clearcoat: 1, clearcoatRoughness: 0.03 }));
  m.envMapIntensity = 2.6; CAR_MATS[key] = m; return m;
}
function caliperMat(hex) {
  const key = 'c' + hex; if (CAR_MATS[key]) return CAR_MATS[key];
  return (CAR_MATS[key] = linMat(new THREE.MeshStandardMaterial({ color: hex, roughness: 0.35, metalness: 0.3 })));
}
class CarView {
  constructor(car, scene, opts) {
    this.car = car; opts = opts || {};
    const G = carGeo(car.def.style), M = carMats(), S = G.S, paint = paintMat(car.color);
    this.root = new THREE.Group(); this.body = new THREE.Group(); this.root.add(this.body);
    const add = (geo, mat, cast, parent) => { if (!geo) return null; const m = new THREE.Mesh(geo, mat); m.castShadow = !!cast; m.receiveShadow = !!cast; (parent || this.body).add(m); return m; };
    add(G.body, paint, true); add(G.cab, S.van ? paint : M.glass, true); add(G.roof, paint, false); add(G.paint, paint, true);
    add(G.dark, M.trim, false); add(G.glass, M.glass); add(G.chrome, M.chrome); add(G.spare, M.tyre, true);
    add(G.head, M.head); this.tailMesh = add(G.tail, M.tail);
    this.wheels = [];
    const rimM = M['rim_' + (S.rim.col || 'silver')];
    for (const z of [S.zF, S.zR]) for (const sx of [-1, 1]) {
      const holder = new THREE.Group(); holder.position.set(sx * G.wx(z), S.wr, z); holder.rotation.order = 'YXZ'; if (sx < 0) holder.scale.x = -1;
      const spin = new THREE.Group(); holder.add(spin);
      add(G.tyre, M.tyre, true, spin); add(G.rim, rimM, false, spin); add(G.inner, M.inner, false, spin);
      if (G.caliper) { const c = add(G.caliper, caliperMat(S.caliper), false, holder); c.position.set(0.0, S.wr * 0.34, -S.wr * 0.3); c.rotation.x = 0.7; }
      this.body.add(holder); this.wheels.push({ g: holder, spin, front: z > 0 });
    }
    this.tail = G.tailPts; this.L = S.L; this.H = G.H;
    const glowCol = new THREE.Color(car.color); if (glowCol.getHSL({}).l < 0.25 || glowCol.getHSL({}).s < 0.15) glowCol.set('#ff3048');
    const ug = new THREE.Mesh(new THREE.PlaneGeometry(S.W + 1.6, S.L + 1.4), linMat(Object.assign(new THREE.MeshBasicMaterial({ map: TEX.glow, color: glowCol, transparent: true, opacity: 0.5, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false }), { userData: { hdr: 1.4 } })));
    ug.rotation.x = -Math.PI / 2; ug.position.y = 0.07; this.body.add(ug); this.under = ug;
    const sh = new THREE.Mesh(new THREE.PlaneGeometry(S.W + 0.8, S.L + 0.5), new THREE.MeshBasicMaterial({ map: TEX.glow, color: 0x000000, transparent: true, opacity: 0.7, depthWrite: false }));
    sh.rotation.x = -Math.PI / 2; sh.position.y = 0.05; this.root.add(sh); this.shadow = sh;
    this.shield = new THREE.Mesh(new THREE.SphereGeometry(Math.max(3.3, S.L * 0.7), 20, 12), linMat(Object.assign(new THREE.MeshBasicMaterial({ color: '#7fb0ff', transparent: true, opacity: 0.14, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false }), { userData: { hdr: 1.4 } })));
    this.shield.position.y = 0.8; this.shield.visible = false; this.root.add(this.shield);
    if (opts.beams) {
      const pool = new THREE.Mesh(new THREE.PlaneGeometry(7, 16), linMat(Object.assign(new THREE.MeshBasicMaterial({ map: TEX.glow, color: '#fff0d8', transparent: true, opacity: 0.38, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false }), { userData: { hdr: 1 } })));
      pool.rotation.x = -Math.PI / 2; pool.position.set(0, 0.09, S.L / 2 + 8); this.body.add(pool); this.beam = pool;
    }
    if (!car.isPlayer && opts.tags) {
      this.tagCanvas = nameTagCanvas(); this.tagTex = new THREE.CanvasTexture(this.tagCanvas); this.tagTex.encoding = THREE.sRGBEncoding; this.lastHp = -1;
      this.tag = new THREE.Sprite(new THREE.SpriteMaterial({ map: this.tagTex, depthWrite: false, transparent: true, sizeAttenuation: false, toneMapped: false }));
      this.tag.scale.set(0.13, 0.0325, 1); this.tag.position.y = this.H + 1.1; this.root.add(this.tag);
      this.updateTag();
    }
    scene.add(this.root);
  }
  spin(dt, v, steer) {
    const a = v * dt / CAR_SHAPES[this.car.def.style].wr;
    for (const w of this.wheels) { w.spin.rotation.x += a; if (w.front) w.g.rotation.y = steer * 0.42; }
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
