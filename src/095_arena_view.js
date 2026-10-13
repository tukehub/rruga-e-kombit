// ---------- Points mode view: Skanderbeg Square as a walled arena, plus its cameras, events and minimap ----------
// Borrows the sky, landmark and building builders from World; everything here sits on flat ground (y = 0).

function arenaPerimeter(ax, az, r, n) {
  const sh = new THREE.Shape();
  sh.moveTo(-ax + r, -az); sh.lineTo(ax - r, -az); sh.absarc(ax - r, -az + r, r, -Math.PI / 2, 0, false);
  sh.lineTo(ax, az - r); sh.absarc(ax - r, az - r, r, 0, Math.PI / 2, false);
  sh.lineTo(-ax + r, az); sh.absarc(-ax + r, az - r, r, Math.PI / 2, Math.PI, false);
  sh.lineTo(-ax, -az + r); sh.absarc(-ax + r, -az + r, r, Math.PI, Math.PI * 1.5, false);
  if (!n) return sh;
  // closed loop of points with outward normals and running length (shape y is world z here)
  const P = sh.getSpacedPoints(n), out = []; let s = 0;
  for (let i = 0; i <= n; i++) {
    const p = P[i % n], q = P[(i + 1) % n], o = P[(i - 1 + n) % n];
    let tx = q.x - o.x, tz = q.y - o.y; const l = Math.hypot(tx, tz) || 1; tx /= l; tz /= l;
    if (i) s += Math.hypot(p.x - P[(i - 1) % n].x, p.y - P[(i - 1) % n].y);
    out.push({ x: p.x, z: p.y, nx: tz, nz: -tx, tx, tz, s });
  }
  return out;
}
// a strip running round the loop from (offset o0, height y0) to (o1, y1); u follows the length
function arenaRibbon(loop, o0, y0, o1, y1, uLen) {
  const P = [], U = [], I = [];
  loop.forEach((p, i) => {
    P.push(p.x + p.nx * o0, y0, p.z + p.nz * o0, p.x + p.nx * o1, y1, p.z + p.nz * o1);
    U.push(p.s / uLen, 0, p.s / uLen, 1);
    if (i) { const a = (i - 1) * 2; I.push(a, a + 2, a + 1, a + 1, a + 2, a + 3); }
  });
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(P, 3)); g.setAttribute('uv', new THREE.Float32BufferAttribute(U, 2));
  g.setIndex(I); g.computeVertexNormals(); return g;
}
function shapeFlat(shape, y) { const g = new THREE.ShapeGeometry(shape, 24); g.rotateX(-Math.PI / 2); g.translate(0, y, 0); return g; }

// ---------- textures made for the square ----------
function pavingTex() { // the square's multicoloured stones, one colour per region of the country
  const r = mulberry32(912), cols = ['#8d7f6e', '#a39383', '#77695c', '#b5a48c', '#6f6a66', '#9a8676', '#8a8f88', '#a8846e', '#7f7468', '#b09a86'];
  return canvasTex(512, 512, (g, w, h) => {
    g.fillStyle = '#3b3631'; g.fillRect(0, 0, w, h);
    const rows = 12, rh = h / rows;
    for (let y = 0; y < rows; y++) {
      let x = -(r() * 40);
      while (x < w) {
        const sw = 26 + r() * 34, c = cols[(r() * cols.length) | 0];
        g.fillStyle = c; g.fillRect(x + 1.5, y * rh + 1.5, sw - 3, rh - 3);
        g.fillStyle = `rgba(255,255,255,${0.04 + r() * 0.06})`; g.fillRect(x + 1.5, y * rh + 1.5, sw - 3, 3);
        g.fillStyle = `rgba(0,0,0,${0.05 + r() * 0.1})`; g.fillRect(x + 1.5, y * rh + rh - 5, sw - 3, 3.5);
        x += sw;
      }
    }
    for (let i = 0; i < 2600; i++) { g.fillStyle = `rgba(${r() < 0.5 ? '0,0,0' : '255,255,255'},${r() * 0.08})`; g.fillRect(r() * w, r() * h, 2, 2); }
  }, { repeat: true, aniso: 8 });
}
function adBoardTex() { // the barrier's inside face: glossy dark panels with lit sponsor boards
  const boards = [['SHESHI SKËNDERBEJ', '#c8102e', '#ffffff'], ['BYREK 60 LEKË', '#f2c230', '#1a1206'], ['LAVAZH 24/7', '#1f6fd1', '#ffffff'], ['KAFE 100 LEKË', '#3b2416', '#f6e2c8'], ['VORTEX', '#2de2ff', '#06121a'], ['SIGURIM MAKINE', '#121418', '#38ff6a']];
  return canvasTex(2048, 128, (g, w, h) => {
    const bw = w / boards.length;
    boards.forEach(([t, bg, fg], i) => {
      const x = i * bw, gr = g.createLinearGradient(0, 0, 0, h); gr.addColorStop(0, bg); gr.addColorStop(1, shadeHex(bg, 0.55));
      g.fillStyle = gr; g.fillRect(x, 0, bw, h);
      g.fillStyle = 'rgba(255,255,255,0.12)'; g.fillRect(x, 0, bw, 10);
      g.fillStyle = 'rgba(0,0,0,0.5)'; g.fillRect(x + bw - 4, 0, 4, h);
      g.fillStyle = fg; g.font = `900 ${t === 'VORTEX' ? 92 : t.length > 14 ? 50 : 64}px ${FONT_D}`; g.textAlign = 'center'; g.textBaseline = 'middle';
      if (t === 'VORTEX') { g.save(); g.translate(x + bw / 2, h / 2 + 4); g.transform(1, 0, -0.18, 1, 0, 0); g.fillText(t, 0, 0); g.restore(); }
      else g.fillText(t, x + bw / 2, h / 2 + 4);
    });
  }, { repeat: true, aniso: 8 });
}
function shadeHex(hex, f) { const c = hexToRgb(hex); return `rgb(${(c[0] * 255 * f) | 0},${(c[1] * 255 * f) | 0},${(c[2] * 255 * f) | 0})`; }
function fenceTex() {
  return canvasTex(64, 64, (g, w, h) => { g.clearRect(0, 0, w, h); g.strokeStyle = 'rgba(200,210,225,1)'; g.lineWidth = 3; g.beginPath(); g.moveTo(0, 0); g.lineTo(w, h); g.moveTo(w, 0); g.lineTo(0, h); g.stroke(); g.fillRect(0, h - 4, w, 4); }, { repeat: true });
}
function decalTex() { // painted arena marking: chevrons round a ring
  return canvasTex(512, 512, (g, w, h) => {
    g.clearRect(0, 0, w, h); g.translate(w / 2, h / 2);
    g.strokeStyle = '#fff'; g.lineWidth = 10; g.beginPath(); g.arc(0, 0, 210, 0, Math.PI * 2); g.stroke();
    g.lineWidth = 4; g.beginPath(); g.arc(0, 0, 170, 0, Math.PI * 2); g.stroke();
    g.fillStyle = '#fff';
    for (let i = 0; i < 12; i++) { g.save(); g.rotate(i / 12 * Math.PI * 2); g.beginPath(); g.moveTo(-18, -238); g.lineTo(0, -222); g.lineTo(18, -238); g.lineTo(18, -228); g.lineTo(0, -212); g.lineTo(-18, -228); g.closePath(); g.fill(); g.restore(); }
    g.font = `900 120px ${FONT_D}`; g.textAlign = 'center'; g.textBaseline = 'middle'; g.transform(1, 0, -0.15, 1, 0, 0); g.fillText('VORTEX', 0, 6);
  });
}
function mosaicTex() { // the National History Museum's mosaic, simplified: the people marching under the flag
  return canvasTex(1024, 300, (g, w, h) => {
    const gr = g.createLinearGradient(0, 0, 0, h); gr.addColorStop(0, '#e9c46a'); gr.addColorStop(1, '#c9822b'); g.fillStyle = gr; g.fillRect(0, 0, w, h);
    const r = mulberry32(5); for (let i = 0; i < 3000; i++) { g.fillStyle = `rgba(${r() < 0.5 ? '120,40,10' : '255,240,200'},${r() * 0.15})`; g.fillRect(r() * w, r() * h, 6, 6); }
    g.fillStyle = '#c8102e'; g.fillRect(w / 2 - 70, 24, 140, 92); drawEagle(g, w / 2, 70, 80, '#111');
    g.fillStyle = '#3a1c14'; g.fillRect(w / 2 - 3, 24, 6, 250);
    const fig = (x, s, c) => { g.fillStyle = c; g.beginPath(); g.arc(x, h - 190 * s, 16 * s, 0, 7); g.fill(); g.fillRect(x - 20 * s, h - 172 * s, 40 * s, 110 * s); g.fillRect(x - 18 * s, h - 64 * s, 14 * s, 64 * s); g.fillRect(x + 4 * s, h - 64 * s, 14 * s, 64 * s); };
    const pal = ['#2b2d42', '#8d1b1b', '#5c3b26', '#1f3b4d', '#6b2737', '#3f4a2b'];
    for (let i = 0; i < 16; i++) { const x = 60 + i * 60 + (i > 7 ? 40 : -40); fig(x, 0.9 + (i % 3) * 0.1, pal[i % pal.length]); }
    g.strokeStyle = '#7a4a1c'; g.lineWidth = 10; g.strokeRect(5, 5, w - 10, h - 10);
  });
}

// Skanderbeg on his horse, bronze with gold-lit edges so it reads at dusk (same outline as statueTex, at 4x)
function statueBronzeTex() {
  const parts = [[[92, 128], [78, 96], [70, 74], [82, 62], [98, 70], [110, 108], [118, 128]], [[70, 74], [56, 84], [46, 96], [52, 102], [64, 96], [80, 82], [86, 64], [80, 60]], [[80, 62], [76, 50], [87, 60]],
    [[93, 140], [101, 140], [104, 206], [96, 206]], [[106, 140], [92, 164], [80, 170], [78, 163], [89, 158], [99, 138]], [[166, 146], [175, 146], [180, 206], [171, 206]], [[182, 140], [191, 140], [194, 206], [186, 206]],
    [[193, 118], [212, 150], [206, 180], [198, 152], [188, 128]], [[128, 110], [124, 70], [132, 58], [146, 62], [149, 106]], [[138, 40], [152, 28], [162, 32], [151, 38], [143, 46]], [[128, 74], [106, 94], [102, 89], [122, 69]],
    [[146, 62], [172, 98], [161, 113], [148, 104]], [[130, 104], [121, 130], [131, 133], [141, 108]]];
  return canvasTex(1024, 1024, (g) => {
    g.scale(4, 4);
    // each part is its own path: the parts overlap with mixed winding, and one combined path would punch holes
    const each = (fn) => { g.beginPath(); g.ellipse(140, 132, 58, 26, 0, 0, 7); fn(); g.beginPath(); g.arc(136, 47, 10, 0, 7); fn(); for (const p of parts) { g.beginPath(); p.forEach((q, i) => (i ? g.lineTo(q[0], q[1]) : g.moveTo(q[0], q[1]))); g.closePath(); fn(); } };
    g.lineJoin = 'round'; g.strokeStyle = '#ffd890'; g.lineWidth = 3.2; g.shadowColor = '#ffb44a'; g.shadowBlur = 6; each(() => g.stroke()); g.shadowBlur = 0;
    const gr = g.createLinearGradient(0, 30, 0, 210); gr.addColorStop(0, '#6b5434'); gr.addColorStop(0.45, '#3d3020'); gr.addColorStop(1, '#241c13'); g.fillStyle = gr; each(() => g.fill());
    g.globalCompositeOperation = 'source-atop'; const hl = g.createLinearGradient(40, 0, 220, 0); hl.addColorStop(0, 'rgba(255,200,120,0.35)'); hl.addColorStop(0.5, 'rgba(255,200,120,0)'); hl.addColorStop(1, 'rgba(255,200,120,0.25)'); g.fillStyle = hl; g.fillRect(0, 0, 256, 256);
  });
}
function neonTextTex(text, col) {
  return canvasTex(1024, 160, (g, w, h) => {
    g.clearRect(0, 0, w, h); g.font = `900 112px ${FONT_D}`; g.textAlign = 'center'; g.textBaseline = 'middle';
    g.shadowColor = col; g.shadowBlur = 24; g.fillStyle = col; g.fillText(text, w / 2, h / 2 + 6); g.shadowBlur = 6; g.fillStyle = '#fff'; g.fillText(text, w / 2, h / 2 + 6);
  });
}

class ArenaWorld {
  constructor(q, renderer, env) {
    this.q = q; this.env = env; this.city = { id: 'arena', neon: ARENA.neon, styles: [['painted', 5], ['soviet', 3], ['modern', 2]] };
    this.rng = mulberry32(4242); this.scene = new THREE.Scene(); this.wavers = []; this.dyn = []; this.neonMats = [];
    this.buildSky();
    this.buildGround(); this.buildWalls(); this.buildIsland(); this.buildSquare(); this.buildCity(); this.buildLamps();
    if (renderer) { this.envRT = makeEnvMap(renderer, env, ARENA.neon); this.scene.environment = this.envRT.texture; }
    const envI = env.win >= 0.45 ? 0.55 : 0.8;
    this.scene.traverse(o => { const m = o.material; if (m && m.isMeshStandardMaterial && m.userData.envI == null) m.envMapIntensity = envI; });
    linearize(this.scene);
    this.scene.fog.color.convertSRGBToLinear(); this.scene.background.convertSRGBToLinear();
  }
  groundAt() { return 0; }
  mesh(geo, mat, shadow) { const m = new THREE.Mesh(geo, mat); if (shadow) { m.receiveShadow = true; m.castShadow = shadow === 2; } this.scene.add(m); return m; }
  buildGround() {
    const A = ARENA_DEF, s = this.scene;
    const base = new THREE.PlaneGeometry(2400, 2400); base.rotateX(-Math.PI / 2); base.translate(0, -0.05, 0);
    this.mesh(base, new THREE.MeshStandardMaterial({ color: '#2a2a2f', roughness: 1 }), 1);
    // ring road round the square, then the sidewalk
    const road = arenaPerimeter(A.AX + 34, A.AZ + 34, A.R + 34); road.holes.push(arenaPerimeter(A.AX + 10, A.AZ + 10, A.R + 10));
    this.mesh(shapeFlat(road, -0.02), new THREE.MeshStandardMaterial({ color: '#1b1b20', roughness: 0.55, metalness: 0.1 }), 1);
    const walk = arenaPerimeter(A.AX + 10, A.AZ + 10, A.R + 10); walk.holes.push(arenaPerimeter(A.AX + 1.5, A.AZ + 1.5, A.R + 1.5));
    this.mesh(shapeFlat(walk, 0.0), new THREE.MeshStandardMaterial({ color: '#56524c', roughness: 0.9 }), 1);
    // lane lines on the ring road
    const lane = arenaPerimeter(A.AX + 22.2, A.AZ + 22.2, A.R + 22.2); lane.holes.push(arenaPerimeter(A.AX + 21.8, A.AZ + 21.8, A.R + 21.8));
    this.mesh(shapeFlat(lane, 0.0), new THREE.MeshStandardMaterial({ color: '#d8d2c2', roughness: 0.7 }));
    // the square: coloured stone, glossy enough to catch the neon
    const floor = shapeFlat(arenaPerimeter(A.AX + 1.5, A.AZ + 1.5, A.R + 1.5), 0.01), pv = pavingTex(); pv.repeat.set(1 / 7, 1 / 7);
    this.mesh(floor, new THREE.MeshStandardMaterial({ map: pv, roughness: 0.42, metalness: 0.05 }), 1);
    // painted boundary line and the two big VORTEX rings
    const line = arenaPerimeter(A.AX - 3, A.AZ - 3, A.R - 3); line.holes.push(arenaPerimeter(A.AX - 3.6, A.AZ - 3.6, A.R - 3.6));
    this.mesh(shapeFlat(line, 0.02), new THREE.MeshStandardMaterial({ color: '#efe9dc', roughness: 0.6, emissive: '#efe9dc', emissiveIntensity: 0.08 }));
    const dt = decalTex();
    for (const [x, col] of [[-A.AX * 0.58, ARENA.neon], [A.AX * 0.58, '#2de2ff']]) {
      const d = new THREE.PlaneGeometry(30, 30); d.rotateX(-Math.PI / 2); d.translate(x, 0.03, 0);
      const m = glowMat(col, 1.1, { map: dt, transparent: true, opacity: 0.55, blending: THREE.AdditiveBlending, depthWrite: false });
      s.add(new THREE.Mesh(d, linMat(m)));
    }
    const ring = new THREE.RingGeometry(A.island + 5.5, A.island + 6.1, 96); ring.rotateX(-Math.PI / 2); ring.translate(0, 0.03, 0);
    s.add(new THREE.Mesh(ring, linMat(glowMat('#ffc21a', 1.6, { transparent: true, opacity: 0.8, blending: THREE.AdditiveBlending, depthWrite: false }))));
  }
  buildWalls() {
    const A = ARENA_DEF, loop = arenaPerimeter(A.AX, A.AZ, A.R, 220);
    // barrier: inside face carries the lit ad boards, then a cap and the back face
    const ad = adBoardTex();
    const face = arenaRibbon(loop, 0, 0, 0, 1.2, 36);
    this.mesh(face, new THREE.MeshStandardMaterial({ map: ad, emissive: 0xffffff, emissiveMap: ad, emissiveIntensity: 0.55, roughness: 0.3, metalness: 0.2, side: THREE.DoubleSide }), 1);
    const cap = arenaRibbon(loop, 0, 1.2, 0.8, 1.2, 4), back = arenaRibbon(loop, 0.8, 1.2, 0.8, 0, 4);
    const grey = new THREE.MeshStandardMaterial({ color: '#2a2c33', roughness: 0.5, metalness: 0.35, side: THREE.DoubleSide });
    this.mesh(cap, grey, 1); this.mesh(back, grey);
    // neon strips: magenta along the top edge, cyan along the foot
    this.scene.add(new THREE.Mesh(arenaRibbon(loop, -0.03, 1.12, -0.03, 1.22, 4), glowMat(ARENA.neon, 4, { side: THREE.DoubleSide })));
    this.scene.add(new THREE.Mesh(arenaRibbon(loop, -0.03, 0.02, -0.03, 0.1, 4), glowMat('#2de2ff', 3, { side: THREE.DoubleSide })));
    // catch fence on posts behind the barrier
    const ft = fenceTex();
    this.mesh(arenaRibbon(loop, 1.3, 1.2, 1.3, 5.2, 1.4), new THREE.MeshStandardMaterial({ map: ft, transparent: true, alphaTest: 0.4, side: THREE.DoubleSide, color: '#9aa3b5', roughness: 0.4, metalness: 0.7 }));
    const posts = [];
    loop.forEach((p, i) => { if (i % 6) return; const c = new THREE.CylinderGeometry(0.09, 0.11, 5.4, 6); c.translate(p.x + p.nx * 1.3, 2.7, p.z + p.nz * 1.3); posts.push(c); });
    this.mesh(mergeGeos(posts), new THREE.MeshStandardMaterial({ color: '#3a3e47', roughness: 0.4, metalness: 0.8 }));
  }
  buildIsland() {
    const A = ARENA_DEF, R = A.island;
    const base = new THREE.CylinderGeometry(R, R + 0.25, 0.55, 64); base.translate(0, 0.27, 0);
    this.mesh(base, new THREE.MeshStandardMaterial({ color: '#8c8478', roughness: 0.6 }), 2);
    const top = new THREE.CylinderGeometry(R - 0.7, R - 0.7, 0.6, 64); top.translate(0, 0.3, 0);
    this.mesh(top, new THREE.MeshStandardMaterial({ color: '#2f4a2c', roughness: 0.95 }));
    const rim = new THREE.TorusGeometry(R + 0.02, 0.07, 6, 128); rim.rotateX(Math.PI / 2); rim.translate(0, 0.55, 0);
    this.scene.add(new THREE.Mesh(rim, glowMat('#2de2ff', 3)));
    // plinth in three steps with a bronze plaque, then the statue (a billboard that turns to face the camera)
    const g = new GB(false), F = fr(0, 0.55, 0, 0), stone = C3('#b8b1a5');
    g.box(F, 0, 0.5, 0, 17, 1, 14, shadeC(stone, 0.8)); g.box(F, 0, 1.5, 0, 14, 1, 11, shadeC(stone, 0.9)); g.box(F, 0, 5, 0, 11, 6, 8, stone);
    for (const z of [4.02, -4.02]) g.box(F, 0, 5, z, 5, 2, 0.06, C3('#6b5434'));
    const dark = this.env.win >= 0.45;
    const m = new THREE.Mesh(g.build(), new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.6, emissive: 0x3a2e22, emissiveIntensity: dark ? 1 : 0.4 }));
    m.castShadow = true; m.receiveShadow = true; this.scene.add(m);
    const st = statueBronzeTex();
    const sm = new THREE.MeshStandardMaterial({ map: st, emissive: 0xffffff, emissiveMap: st, emissiveIntensity: 0.3, roughness: 0.45, metalness: 0.4, alphaTest: 0.5, side: THREE.DoubleSide });
    this.statue = new THREE.Mesh(new THREE.PlaneGeometry(26, 26), sm); this.statue.position.set(0, 0.55 + 8 + 11.2, 0); this.statue.castShadow = true; this.scene.add(this.statue);
    // floodlights at the four corners of the island, beams up at the rider, and a warm halo behind
    const beamG = new THREE.ConeGeometry(4.5, 18, 20, 1, true); beamG.translate(0, -9, 0); beamG.rotateX(Math.PI);
    const beamM = linMat(glowMat('#ffd59a', 0.45, { transparent: true, opacity: 0.16, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide }));
    for (const [x, z] of [[9, 9], [-9, 9], [9, -9], [-9, -9]]) {
      const lamp = new THREE.Mesh(new THREE.BoxGeometry(0.7, 0.5, 0.7), glowMat('#fff2d6', 4)); lamp.position.set(x * 0.95, 0.85, z * 0.95); this.scene.add(lamp);
      const b = new THREE.Mesh(beamG, beamM); b.position.set(x * 0.95, 0.85, z * 0.95); b.lookAt(0, 16, 0); b.rotateX(Math.PI / 2); this.scene.add(b);
    }
    const halo = new THREE.Sprite(glowSprite('#ffb870', 0.8)); halo.scale.set(40, 34, 1); halo.position.set(0, 16, -2); this.scene.add(halo);
  }
  update(dt, t, cam) {
    World.prototype.update.call(this, dt, t, cam);
    if (this.statue) this.statue.rotation.y = Math.atan2(cam.position.x - this.statue.position.x, cam.position.z - this.statue.position.z);
  }
  // the real neighbours of the square
  buildSquare() {
    const A = ARENA_DEF, lg = new GB(false), s = this.scene, dark = this.env.win >= 0.45;
    // National History Museum, north side, with its mosaic over the door
    const mz = -(A.AZ + 58);
    this.addBuilding(0, mz, 1, 0, 78, 26, 20, 'soviet', '#c9c0b0', {});
    const mo = new THREE.Mesh(new THREE.PlaneGeometry(34, 10), new THREE.MeshStandardMaterial({ map: mosaicTex(), emissive: 0xffffff, emissiveMap: null, emissiveIntensity: 0, roughness: 0.6 }));
    mo.material.emissiveMap = mo.material.map; mo.material.emissiveIntensity = dark ? 0.45 : 0.08;
    mo.position.set(0, 14.5, mz + 13.1); s.add(mo);
    const nm = new THREE.Mesh(new THREE.PlaneGeometry(56, 8.75), linMat(glowMat('#ffffff', 1.6, { map: neonTextTex('SHESHI SKËNDERBEJ', '#ff2d6f'), transparent: true, depthWrite: false })));
    nm.position.set(0, 25.5, mz + 12); s.add(nm);
    // Palace of Culture on the east, mosque and clock tower at its north end, hotels to the west
    this.addBuilding(A.AX + 64, 6, 0, 1, 92, 30, 17, 'modern', '#a8bccb', {});
    this.lm_mosque(fr(A.AX + 50, 0, -(A.AZ + 14), -Math.PI / 2), { dome: 5.5, minaret: 26 }, lg);
    this.lm_clocktower(fr(A.AX + 30, 0, -(A.AZ + 34), -Math.PI / 2), { h: 35 }, lg);
    this.addBuilding(-(A.AX + 56), -30, 0, 1, 22, 22, 74, 'modern', '#7d9cb3', { band: true });
    this.addBuilding(-(A.AX + 58), 20, 0, 1, 18, 18, 92, 'modern', '#8fb3c9', { band: true });
    this.addBuilding(-(A.AX + 50), 56, 0, 1, 30, 20, 26, 'painted', '#e94f37', { band: true });
    // the ministries along the south side, leaving the boulevard open in the middle
    for (const x of [-70, -38, 38, 70]) this.addBuilding(x, A.AZ + 54, 1, 0, 28, 20, 18, 'old', '#e8c36a', {});
    this.lm_flagpole(fr(-30, 0, -(A.AZ + 22), 0), { h: 34, big: true }, lg);
    const lmm = new THREE.Mesh(lg.build(), new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.7, emissive: dark ? 0x2a221c : 0x000000 }));
    lmm.castShadow = true; s.add(lmm);
    if (dark) for (const [x, z, k] of [[A.AX + 50, -(A.AZ + 14), 40], [A.AX + 30, -(A.AZ + 34), 34], [0, mz + 14, 60]]) {
      const sp = new THREE.Sprite(glowSprite('#ffb870', 0.9)); sp.scale.set(k, k * 0.7, 1); sp.position.set(x, k * 0.25, z); s.add(sp);
    }
    // the boulevard heading south
    const bl = new THREE.PlaneGeometry(26, 400); bl.rotateX(-Math.PI / 2); bl.translate(0, -0.02, A.AZ + 34 + 200);
    this.mesh(bl, new THREE.MeshStandardMaterial({ color: '#1b1b20', roughness: 0.55, metalness: 0.1 }), 1);
  }
  // Tirana's painted blocks all round, a ring further out
  buildCity() {
    const A = ARENA_DEF, r = this.rng, env = this.env;
    this.signsOn = env.win > 0.3 && this.q.neon; if (this.signsOn) this.neonGB = new GB(true);
    if (env.win >= 0.45) this.bandGB = new GB(false);
    const ring = arenaPerimeter(A.AX + 92, A.AZ + 92, A.R + 92, 64);
    for (let i = 0; i < 64; i++) {
      const p = ring[i]; if (Math.abs(p.x) < 30 && p.z > 0) continue; // the boulevard
      if (r() > this.q.density + 0.1) continue;
      const st = r() < 0.55 ? 'painted' : r() < 0.6 ? 'soviet' : 'modern', info = STYLE_INFO[st];
      const w = 14 + r() * 12, dp = 12 + r() * 10, h = 16 + r() * 34 * (r() < 0.15 ? 2 : 1);
      const off = r() * 14, x = p.x + p.nx * off, z = p.z + p.nz * off;
      this.addBuilding(x, z, p.tx, p.tz, w, dp, h, st, info.cols[(r() * info.cols.length) | 0], { sign: this.signsOn && r() < 0.35, signSide: -1, band: !!this.bandGB && r() < 0.4 });
    }
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
  buildLamps() {
    const A = ARENA_DEF, loop = arenaPerimeter(A.AX + 6, A.AZ + 6, A.R + 6, 28), poles = [], heads = [], tg = new GB(false), r = this.rng;
    const lampM = glowSprite('#ffd9a0', 1.4);
    loop.forEach((p, i) => {
      if (i === loop.length - 1) return;
      const c = new THREE.CylinderGeometry(0.12, 0.16, 9, 6); c.translate(p.x, 4.5, p.z); poles.push(c);
      const arm = new THREE.BoxGeometry(0.1, 0.1, 2.2); arm.rotateY(Math.atan2(-p.nx, -p.nz)); arm.translate(p.x - p.nx * 1, 8.9, p.z - p.nz * 1); poles.push(arm);
      const hd = new THREE.BoxGeometry(0.9, 0.18, 0.5); hd.translate(p.x - p.nx * 2, 8.8, p.z - p.nz * 2); heads.push(hd);
      if (this.env.win > 0.2) { const sp = new THREE.Sprite(lampM); sp.scale.set(7, 7, 1); sp.position.set(p.x - p.nx * 2, 8.6, p.z - p.nz * 2); this.scene.add(sp); }
      // trees between the lamps
      const q = loop[i + 1]; if (!q) return;
      const tx = (p.x + q.x) / 2 + p.nx * 2.5, tz = (p.z + q.z) / 2 + p.nz * 2.5, F = fr(tx, 0, tz, 0);
      tg.cyl(F, 0, 0, 0, 0.25, 0.18, 3.2, 6, C3('#4a3626')); tg.blob(F, 0, 4.6, 0, 2.3 + r() * 0.8, C3(r() < 0.5 ? '#34552c' : '#2c4a28'), 1.1, r);
    });
    this.mesh(mergeGeos(poles), new THREE.MeshStandardMaterial({ color: '#2c2f36', roughness: 0.4, metalness: 0.8 }));
    this.scene.add(new THREE.Mesh(mergeGeos(heads), glowMat('#fff1d8', 3)));
    const tm = new THREE.Mesh(tg.build(), new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.9 })); tm.castShadow = true; this.scene.add(tm);
  }
}
for (const k of ['buildSky', 'texMesh', 'addFlag', 'styleGB', 'addBuilding', 'addNeonSign', 'lm_skanderbeg', 'lm_mosque', 'lm_clocktower', 'lm_flagpole']) ArenaWorld.prototype[k] = World.prototype[k];

// ---------- lifecycle ----------
function buildArena() {
  disposeRace(); lazyTextures();
  const q = Q(), env = ENV[ARENA.env];
  const world = new ArenaWorld(q, renderer, env);
  const race = new ArenaSim({ playerDef: CARS[SET.car], driver: SET.driver, diff: SET.diff, seed: (Math.random() * 1e9) | 0, time: SET.ptsMin * 60 });
  const scene = world.scene;
  G.arena = true; G.track = null; G.world = world; G.race = race; G.player = race.player; G.city = ARENA; G.env = env;
  UI.$('hud').classList.add('pts');
  G.views = race.cars.map(c => new CarView(c, scene, { beams: q.beams && env.win >= 0.45, tags: true }));
  G.trails = new Trails(scene, race.cars.length, q.trailSeg); race.cars.forEach((c, i) => G.trails.setColor(i, c.color)); G.trailI = []; G.trails.mesh.visible = SHOW_TRAILS;
  G.fx = new FX(scene, q); updatePScale(); G.weather = null;
  setupPickups(scene, race.pickups, (p, out) => out.set(p.x, 0, p.z));
  linearize(scene); G.post.setLook(env); G.lookFor = 'race'; renderer.toneMappingExposure = env.exp || 1;
  G.acc = 0; G.shake = 0; G.fov = 66; G.camLook = new V3(); G.camH = null; G.finT = 0; G.sndT = {};
  camera.clearViewOffset(); camera.fov = 64; camera.updateProjectionMatrix();
  arenaUpdateViews(0); arenaIntroCam(0);
}

// ---------- views ----------
function arenaUpdateViews(dt) {
  const race = G.race, fx = G.fx, t = G.t;
  race.cars.forEach((c, i) => {
    const v = G.views[i], root = v.root, wrecked = c.wreckT > 0;
    const fwx = -Math.sin(c.h), fwz = Math.cos(c.h);
    root.position.set(c.x, c.hop, c.z); tmpB.set(c.x + fwx, c.hop, c.z + fwz); root.lookAt(tmpB);
    // body language: slide angle while drifting, lean in turns, squat under braking
    const slip = Math.atan2(c.lat || 0, Math.max(4, Math.abs(c.v)));
    v.body.rotation.y = clamp(-slip * 0.6, -0.5, 0.5);
    v.body.rotation.z = clamp(c.steer * Math.min(1, Math.abs(c.v) / 30), -1, 1) * 0.05;
    v.body.rotation.x = c.hop > 0 ? -clamp(c.hopV * 0.03, -0.3, 0.35) : (c.braking ? 0.025 : 0);
    if (dt) v.spin(dt, c.v, c.steer);
    root.visible = !wrecked;
    v.body.visible = !(c.invulnT > 0 && Math.floor(t * 12) % 2 === 0);
    v.shield.visible = c.shieldT > 0 && !wrecked;
    if (v.shield.visible) { v.shield.material.opacity = 0.11 + 0.05 * Math.sin(t * 9); const s = 1 + 0.03 * Math.sin(t * 13); v.shield.scale.set(s, s * 0.8, s); }
    v.under.material.opacity = c.nitroT > 0 || c.ramT > 0 ? 0.95 : 0.55;
    root.updateMatrixWorld(true);
    for (let k = 0; k < 2; k++) { tl.fromArray(v.tail[k]); v.body.localToWorld(tl); G.trails.push(i, k, tl.x, tl.y, tl.z); }
    G.trailI[i] = wrecked ? 0 : clamp((Math.abs(c.v) - 10) / 20, 0, 1);
    G.trails.maxLen[i] = c.isPlayer ? 4.5 : 12;
    if (!dt) return;
    c._pt = (c._pt || 0) + dt;
    if (wrecked) { if (c._pt > 0.05) { c._pt = 0; fx.burst('smoke', c.x, 0.6, c.z); fx.flame(c.x, 0.5, c.z, 0, 4, 0); } return; }
    if (c._pt > 0.033) {
      c._pt = 0;
      tl.fromArray(v.tail[0]); v.body.localToWorld(tl); tmpC.fromArray(v.tail[1]); v.body.localToWorld(tmpC);
      if ((c.drift > 0.4 || Math.abs(c.lat || 0) > 6) && Math.abs(c.v) > 8) { fx.burst('dust', tl.x, tl.y - 0.5, tl.z); fx.burst('dust', tmpC.x, tmpC.y - 0.5, tmpC.z); }
      if (c.health < c.maxHp * 0.35) { tmpA.set(0, 1.0, v.L * 0.35); v.body.localToWorld(tmpA); fx.burst('smoke', tmpA.x, tmpA.y, tmpA.z); }
      if (c.scrape > 0.4) fx.burst('spark', c.x, 0.4, c.z, 0.5);
      if (c.nitroT > 0 || c.ramT > 0) { fx.flame(tl.x, tl.y - 0.15, tl.z, -fwx * 12, 0.5, -fwz * 12); fx.flame(tmpC.x, tmpC.y - 0.15, tmpC.z, -fwx * 12, 0.5, -fwz * 12); }
    }
    if (v.tag) {
      const cd = camera.position.distanceToSquared(root.position); v.tag.visible = !wrecked && cd > 6 * 6 && cd < 150 * 150;
      if ((v.tagT = (v.tagT || 0) + dt) > 0.4) { v.tagT = 0; v.updateTag(); }
    }
  });
}
// ---------- cameras ----------
function arenaCam(dt) {
  const c = G.player, sp = Math.abs(c.v);
  // the camera follows the heading with a little lag, so a drift swings the car on screen rather than the world
  if (G.camH == null || !dt || G.snapCam) G.camH = c.h;
  G.camH += wrapAng(c.h - G.camH) * (dt ? 1 - Math.exp(-dt * 7) : 1);
  const fx = -Math.sin(G.camH), fz = Math.cos(G.camH), back = 3.4 + sp * 0.02, h = 1.25 + sp * 0.006;
  tmpA.set(c.x - fx * back, h + c.hop * 0.5, c.z - fz * back);
  tmpC.set(c.x + fx * 8, 0.9 + c.hop, c.z + fz * 8);
  const snap = !dt || G.snapCam; G.snapCam = false;
  const k = snap ? 1 : 1 - Math.exp(-dt * 14), kl = snap ? 1 : 1 - Math.exp(-dt * 16);
  camera.position.lerp(tmpA, k); G.camLook.lerp(tmpC, kl);
  if (G.shake > 0) { G.shake = Math.max(0, G.shake - dt * 2.5); const s = G.shake * 0.5; camera.position.x += (Math.random() - 0.5) * s; camera.position.y += (Math.random() - 0.5) * s; }
  camera.lookAt(G.camLook);
  const fov = 66 + clamp(sp / 40, 0, 1.2) * 10;
  G.fov += (fov - G.fov) * (dt ? 1 - Math.exp(-dt * 4) : 1);
  if (Math.abs(camera.fov - G.fov) > 0.05) { camera.fov = G.fov; camera.updateProjectionMatrix(); updatePScale(); }
  const so = sp > 34 ? 0.3 : 0; if (G.speedO !== so) { G.speedO = so; UI.$('fx-speed').style.opacity = so; }
}
function arenaOrbit(ang, r, h, k) {
  const c = G.player, a = c.h + ang;
  tmpA.set(c.x + Math.sin(a) * r, h, c.z - Math.cos(a) * r); camera.position.lerp(tmpA, k);
  tmpC.set(c.x, 1, c.z); G.camLook.lerp(tmpC, k); camera.lookAt(G.camLook);
}
function arenaIntroCam(dt) {
  const t = clamp((G.introT || 0) / 2.8, 0, 1);
  if (t < 0.5) { // round the rider, low, looking up
    const k = t / 0.5, a = 0.5 + k * 1.4;
    camera.position.set(Math.sin(a) * 28, 4 + k * 5, Math.cos(a) * 28); G.camLook.set(0, 15, 0); camera.lookAt(G.camLook); return;
  }
  const k = (t - 0.5) / 0.5, e = k * k * (3 - 2 * k);
  arenaOrbit(Math.PI * (1 - e), lerp(12, 3.4, e), lerp(3.4, 1.25, e) + Math.sin(e * Math.PI) * 3, 1);
}
function arenaOrbitCam(dt) { G.orbA = (G.orbA || 0) + dt * 0.35; arenaOrbit(G.orbA, 10, 3.6, 1 - Math.exp(-dt * 3)); }
// ---------- events → effects, sound, HUD ----------
function arenaNear(x, z) { const p = G.player; return p ? clamp(1 - Math.hypot(x - p.x, z - p.z) / 120, 0.15, 1) : 1; }
function arenaEvents() {
  const race = G.race, P = G.player, fx = G.fx;
  for (const e of race.events) {
    const c = e.car;
    switch (e.t) {
      case 'bump': {
        fx.burst('spark', e.x, 0.6, e.z, Math.min(2, e.imp / 8));
        if ((e.a === P || e.b === P) && limited('bump', 0.15)) { AUD.play('bump', clamp(e.imp / 18, 0.4, 1)); G.shake = Math.max(G.shake, Math.min(0.9, e.imp / 30)); }
        break;
      }
      case 'score': {
        if (c === P) {
          fx.burst('hit', e.x, 0.2, e.z, { col: e.combo > 1 ? '#ffe03a' : P.color });
          UI.feed(`+${e.pts}${e.combo > 1 ? `  ×${e.combo}` : ''}  ·  ${e.victim.name}`, e.combo > 1 ? '#ffe03a' : P.color, 1.4); AUD.play('hit', 1);
          UI.pop(e.ram ? `DASHI +${e.pts}` : `+${e.pts}`, e.combo);
        } else if (e.victim === P) { UI.flash('rgba(228,30,32,0.55)', 0.6); UI.feed(`${c.name} → ${P.name}`, c.color, 1.2); }
        break;
      }
      case 'wall': {
        fx.burst('spark', e.x, 0.5, e.z, 1);
        if (c === P && limited('wall', 0.15)) { AUD.play('wall', clamp(e.imp / 20, 0.3, 1)); G.shake = Math.max(G.shake, Math.min(0.5, e.imp / 40)); }
        break;
      }
      case 'wreck': {
        fx.burst('explode', e.x, 0.6, e.z, 1); AUD.play('boom', arenaNear(e.x, e.z));
        if (c === P) { UI.center('U bëre copë!<small>Rikthehesh pas dy sekondash</small>', 2.2); UI.flash('rgba(255,120,30,0.9)', 1); G.shake = 1.6; }
        else if (e.by === P) { UI.feed(`${c.name} u bë copë!  +${e.pts}`, '#ffb547', 2.2); UI.pop(`KO +${e.pts}`, P.combo); }
        else UI.feed(`${e.by ? e.by.name + ' → ' : ''}${c.name} copë`, '#a2959f', 1.6);
        break;
      }
      case 'pickup': {
        const v = G.picks.get(e.p.id); if (v) { v.grp.visible = false; fx.burst('pickup', e.p.x, 1.75, e.p.z, { col: PW[e.type].col }); fx.burst('ring', e.p.x, 0, e.p.z, { col: PW[e.type].col }); }
        if (c === P) { AUD.play('pickup'); UI.feed('+ ' + PW[e.type].name, PW[e.type].col, 1.6); if (!SET.seen[e.type]) { SET.seen[e.type] = 1; saveSettings(); UI.feed(PW[e.type].desc, PW[e.type].col, 4.5); } }
        break;
      }
      case 'pickupBack': { const v = G.picks.get(e.p.id); if (v) { v.grp.visible = true; v.pop = 0; } break; }
      case 'fire': {
        const snd = { eagle: 'eagle', bolt: 'bolt', barge: 'barge', mine: 'mine', shock: 'shock', nitro: e.back ? 'brake' : 'nitro', shield: 'shield', repair: 'repair', ram: 'nitro', cluster: 'bolt' }[e.type];
        AUD.play(snd, arenaNear(e.x, e.z));
        break;
      }
      case 'hit': {
        const col = PW[e.kind] ? PW[e.kind].col : '#ffffff'; fx.burst('hit', e.x, 0.8, e.z, { col }); AUD.play('hit', arenaNear(e.x, e.z));
        if (c === P) { UI.flash(e.kind === 'shock' ? 'rgba(255,224,58,0.8)' : 'rgba(228,30,32,0.85)'); G.shake = Math.max(G.shake, e.kind === 'eagle' ? 1.2 : 0.6); UI.feed(`${e.by ? e.by.name : '?'} → ${P.name}`, col); }
        else if (e.by === P) { UI.feed(`${PW[e.kind].name} → ${c.name}  +${e.pts}`, col); UI.pop(`+${e.pts}`, e.combo); }
        if (G.views[c.id] && G.views[c.id].tag) G.views[c.id].updateTag();
        break;
      }
      case 'blocked': {
        fx.burst('ring', e.x, 0.8, e.z, { col: PW.shield.col }); AUD.play('shield', arenaNear(e.x, e.z) * 0.6);
        if (c === P) UI.feed('Mburoja e priti!', PW.shield.col); else if (e.by === P) UI.feed(`${c.name} kishte mburojë`, PW.shield.col);
        break;
      }
      case 'boom': fx.burst(e.kind === 'bolt' ? 'hit' : 'explode', e.x, 0.5, e.z, e.kind === 'bolt' ? { col: PW.bolt.col } : 0.6); AUD.play(e.kind === 'bolt' ? 'hit' : 'boom', arenaNear(e.x, e.z) * 0.8); break;
      case 'fizzle': fx.burst('hit', e.x, 1, e.z, { col: PW[e.kind].col }); break;
      case 'zap': fx.burst('zap', e.x, 0.8, e.z); if (limited('zap', 0.2)) AUD.play('shock', arenaNear(e.x, e.z)); break;
      case 'barge': {
        fx.burst('ring', e.x, 0.3, e.z, { col: PW.barge.col });
        const m = new THREE.Mesh(G.res.ring, linMat(glowMat(PW.barge.col, 3, { transparent: true, blending: THREE.AdditiveBlending, depthWrite: false })));
        m.position.set(e.x, 0.3, e.z); G.world.scene.add(m); G.trans.push({ m, t: 0, dur: 0.45, kind: 'ring', max: 9 });
        if (c === P) G.shake = Math.max(G.shake, 0.5);
        break;
      }
      case 'shock': if (e.target === P) { UI.center('Stuhia!<small>Kupola elektrike rreth teje</small>', 1.6); UI.feed(`${c.name} lëshoi Stuhinë`, PW.shock.col); } else if (c === P) UI.feed(`Stuhia për ${e.target.name}`, PW.shock.col); break;
      case 'nitro': if (c === P && !e.back) UI.flash('rgba(56,255,106,0.5)', 0.5); break;
      case 'ram': if (c === P) { UI.flash('rgba(255,61,154,0.55)', 0.5); UI.feed('Dashi! Godit dikë tani', PW.ram.col, 1.6); } break;
      case 'repair': fx.burst('repair', e.x, 0.5, e.z); if (c === P) UI.feed('Usta Ramizi e rregulloi', PW.repair.col); if (G.views[c.id]) G.views[c.id].updateTag(); break;
      case 'denied': if (c === P) { AUD.play('denied'); UI.feed(e.why === 'first' ? 'Je i pari. S’ka kë të godasë Stuhia.' : 'Makina s’ka asnjë gërvishtje. Ende.', '#a2959f'); } break;
      case 'cycle': if (c === P) AUD.play('cycle'); break;
      case 'respawn': { fx.burst('pickup', e.x, 1, e.z, { col: c.color }); if (G.views[c.id]) G.views[c.id].updateTag(); break; }
      case 'timeup': {
        if (G.state === 'race') {
          G.state = 'finish'; G.finT = 0; P.ctrl.gas = P.ctrl.brake = false; P.ctrl.steer = 0;
          AUD.play('finish'); UI.flash('rgba(255,181,71,0.7)', 0.8); UI.center(`Koha mbaroi!<small>${P.score} pikë · ${P.hitsN} goditje</small>`, 3.2);
        }
        break;
      }
    }
  }
  race.events.length = 0;
}
function arenaMinimap() {
  const cv = UI.$('minimap'), g = cv.getContext('2d'), W = cv.width, H = cv.height, c = G.player, A = ARENA_DEF;
  const sc = W / (A.AX * 2 + 20) * 1.15, rot = -Math.PI / 2 - Math.atan2(Math.cos(c.h), -Math.sin(c.h)), ox = W / 2, oy = H / 2;
  g.setTransform(1, 0, 0, 1, 0, 0); g.clearRect(0, 0, W, H);
  g.save(); g.translate(ox, oy); g.rotate(rot); g.scale(sc, sc); g.translate(-c.x, -c.z);
  const path = new Path2D(); arenaPerimeter(A.AX, A.AZ, A.R, 48).forEach((p, i) => (i ? path.lineTo(p.x, p.z) : path.moveTo(p.x, p.z))); path.closePath();
  g.fillStyle = 'rgba(255,255,255,0.08)'; g.fill(path); g.lineWidth = 3 / sc; g.strokeStyle = 'rgba(255,45,111,0.9)'; g.stroke(path);
  g.beginPath(); g.arc(0, 0, A.island, 0, 7); g.fillStyle = 'rgba(45,226,255,0.35)'; g.fill();
  for (const o of G.race.cars) { if (o === c || o.wreckT > 0) continue; g.beginPath(); g.arc(o.x, o.z, 4.2, 0, 7); g.fillStyle = o.color; g.fill(); g.lineWidth = 1.5 / sc; g.strokeStyle = 'rgba(0,0,0,0.7)'; g.stroke(); }
  g.restore();
  g.beginPath(); g.moveTo(ox, oy - 12); g.lineTo(ox + 8, oy + 8); g.lineTo(ox, oy + 4); g.lineTo(ox - 8, oy + 8); g.closePath(); g.fillStyle = c.color; g.fill(); g.lineWidth = 2.5; g.strokeStyle = '#fff'; g.stroke();
}
function arenaRender(dt) {
  const w = G.world, P = G.player;
  if (w.dl && w.dl.castShadow && P) { tmpA.set(P.x, 0, P.z); w.dl.target.position.copy(tmpA); w.dl.position.copy(tmpA).addScaledVector(w.sunDir, 160); }
  G.post.render(w.scene, camera, dt);
  renderMirror(w.scene);
}
