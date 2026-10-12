// ---------- particles ----------
const PVS = 'attribute float size; attribute vec4 pcol; varying vec4 vC; uniform float uScale;\nvoid main(){ vC = pcol; vec4 mv = modelViewMatrix * vec4(position,1.0); float d = max(0.5, -mv.z); gl_PointSize = min(size * uScale / d, uScale * 0.16); vC.a *= smoothstep(1.0, 4.0, d); gl_Position = projectionMatrix * mv; }';
const PFS = 'varying vec4 vC; uniform float uBoost;\nvoid main(){ vec2 c = gl_PointCoord - 0.5; float d = dot(c,c) * 4.0; float a = 1.0 - d; if (a <= 0.0) discard; gl_FragColor = vec4(vC.rgb * uBoost, vC.a * a * a); }';
class Particles {
  constructor(scene, n, additive) {
    this.n = n; this.head = 0;
    this.pos = new Float32Array(n * 3); this.col = new Float32Array(n * 4); this.size = new Float32Array(n);
    this.vel = new Float32Array(n * 3); this.life = new Float32Array(n); this.max = new Float32Array(n);
    this.s0 = new Float32Array(n); this.s1 = new Float32Array(n); this.a0 = new Float32Array(n); this.grav = new Float32Array(n); this.drag = new Float32Array(n);
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(this.pos, 3).setUsage(THREE.DynamicDrawUsage));
    g.setAttribute('pcol', new THREE.BufferAttribute(this.col, 4).setUsage(THREE.DynamicDrawUsage));
    g.setAttribute('size', new THREE.BufferAttribute(this.size, 1).setUsage(THREE.DynamicDrawUsage));
    this.mat = new THREE.ShaderMaterial({ uniforms: { uScale: { value: 400 }, uBoost: { value: additive ? 1.8 : 1 } }, vertexShader: PVS, fragmentShader: PFS, transparent: true, depthWrite: false, blending: additive ? THREE.AdditiveBlending : THREE.NormalBlending });
    this.pts = new THREE.Points(g, this.mat); this.pts.frustumCulled = false; scene.add(this.pts); this.g = g; this.alive = 0;
  }
  spawn(x, y, z, vx, vy, vz, life, s0, s1, r, gg, b, a, grav, drag) {
    const i = this.head; this.head = (this.head + 1) % this.n;
    this.pos[i * 3] = x; this.pos[i * 3 + 1] = y; this.pos[i * 3 + 2] = z;
    this.vel[i * 3] = vx; this.vel[i * 3 + 1] = vy; this.vel[i * 3 + 2] = vz;
    this.life[i] = life; this.max[i] = life; this.s0[i] = s0; this.s1[i] = s1; this.a0[i] = a; this.grav[i] = grav || 0; this.drag[i] = drag || 0;
    this.col[i * 4] = r; this.col[i * 4 + 1] = gg; this.col[i * 4 + 2] = b; this.col[i * 4 + 3] = a; this.size[i] = s0;
  }
  update(dt) {
    let alive = 0;
    for (let i = 0; i < this.n; i++) {
      if (this.life[i] <= 0) { if (this.size[i] !== 0) { this.size[i] = 0; this.col[i * 4 + 3] = 0; } continue; }
      alive++;
      this.life[i] -= dt; const t = 1 - Math.max(0, this.life[i]) / this.max[i];
      const dr = Math.exp(-this.drag[i] * dt);
      this.vel[i * 3] *= dr; this.vel[i * 3 + 1] = this.vel[i * 3 + 1] * dr - this.grav[i] * dt; this.vel[i * 3 + 2] *= dr;
      this.pos[i * 3] += this.vel[i * 3] * dt; this.pos[i * 3 + 1] += this.vel[i * 3 + 1] * dt; this.pos[i * 3 + 2] += this.vel[i * 3 + 2] * dt;
      this.size[i] = this.s0[i] + (this.s1[i] - this.s0[i]) * t;
      this.col[i * 4 + 3] = this.a0[i] * (1 - t);
    }
    this.alive = alive;
    this.g.attributes.position.needsUpdate = true; this.g.attributes.pcol.needsUpdate = true; this.g.attributes.size.needsUpdate = true;
  }
  setScale(s) { this.mat.uniforms.uScale.value = s; }
}
class FX {
  constructor(scene, q) {
    this.add = new Particles(scene, q.particles, true);
    this.smoke = new Particles(scene, Math.round(q.particles * 0.6), false);
    this.r = mulberry32(31);
  }
  setScale(s) { this.add.setScale(s); this.smoke.setScale(s); }
  update(dt) { this.add.update(dt); this.smoke.update(dt); }
  burst(kind, x, y, z, k) {
    const r = this.r, A = this.add, S = this.smoke; k = k || 1;
    const rnd = (a) => (r() - 0.5) * a;
    const col = (hex) => C3(hex);
    switch (kind) {
      case 'spark': { for (let i = 0; i < 8 * k; i++) A.spawn(x, y, z, rnd(14), 2 + r() * 6, rnd(14), 0.3 + r() * 0.3, 0.35, 0.05, 1, 0.75 + r() * 0.2, 0.35, 1, 18, 1); break; }
      case 'explode': {
        for (let i = 0; i < 40 * k; i++) A.spawn(x, y + 0.5, z, rnd(22), r() * 14, rnd(22), 0.5 + r() * 0.5, 2.6, 0.4, 1, 0.45 + r() * 0.4, 0.1, 1, 6, 2);
        for (let i = 0; i < 26 * k; i++) S.spawn(x + rnd(2), y + 0.5, z + rnd(2), rnd(6), 2 + r() * 5, rnd(6), 1.4 + r() * 1.2, 2.5, 7, 0.12, 0.11, 0.1, 0.85, -1.5, 1.2);
        for (let i = 0; i < 18 * k; i++) A.spawn(x, y + 0.4, z, rnd(30), 4 + r() * 16, rnd(30), 0.6 + r() * 0.6, 0.4, 0.1, 1, 0.8, 0.4, 1, 22, 0.5);
        break;
      }
      case 'hit': { const c = col(k.col || '#ffffff'); for (let i = 0; i < 26; i++) A.spawn(x, y + 0.8, z, rnd(18), r() * 9, rnd(18), 0.35 + r() * 0.35, 1.6, 0.2, c[0], c[1], c[2], 1, 8, 2.5); break; }
      case 'ring': { const c = col(k.col); for (let i = 0; i < 40; i++) { const a = i / 40 * Math.PI * 2; A.spawn(x, y + 0.5, z, Math.cos(a) * 24, 1, Math.sin(a) * 24, 0.45, 1.4, 0.3, c[0], c[1], c[2], 1, 0, 3); } break; }
      case 'pickup': { const c = col(k.col); for (let i = 0; i < 16; i++) A.spawn(x, y, z, rnd(8), 2 + r() * 6, rnd(8), 0.5, 1.2, 0.1, c[0], c[1], c[2], 1, 4, 2); break; }
      case 'repair': { const c = col(PW.repair.col); for (let i = 0; i < 30; i++) A.spawn(x + rnd(3), y + r() * 1.5, z + rnd(3), rnd(2), 3 + r() * 3, rnd(2), 0.8, 0.8, 0.1, c[0], c[1], c[2], 1, -1, 1); break; }
      case 'zap': { const c = col(PW.shock.col); for (let i = 0; i < 30; i++) A.spawn(x + rnd(4), y + r() * 3, z + rnd(4), rnd(20), rnd(20), rnd(20), 0.25 + r() * 0.2, 0.9, 0.1, c[0], c[1], c[2], 1, 0, 4); break; }
      case 'dust': { for (let i = 0; i < 2; i++) S.spawn(x + rnd(1.5), y + 0.2, z + rnd(1.5), rnd(2), 0.6 + r(), rnd(2), 0.9 + r() * 0.6, 1.2, 4.2, 0.82, 0.82, 0.84, 0.32, -0.3, 1.5); break; }
      case 'snowspray': { for (let i = 0; i < 2; i++) S.spawn(x + rnd(1.5), y + 0.2, z + rnd(1.5), rnd(3), 1 + r() * 2, rnd(3), 0.7, 0.7, 2.6, 0.95, 0.97, 1, 0.55, 2, 1.5); break; }
      case 'splash': { for (let i = 0; i < 2; i++) S.spawn(x + rnd(1.5), y + 0.15, z + rnd(1.5), rnd(2), 0.8 + r(), rnd(2), 0.5, 0.8, 3.0, 0.75, 0.8, 0.86, 0.35, 3, 1.5); break; }
      case 'smoke': { S.spawn(x + rnd(0.6), y, z + rnd(0.6), rnd(1.5), 2 + r() * 1.5, rnd(1.5), 1.2 + r() * 0.8, 0.8, 3.5, 0.08, 0.08, 0.08, 0.6, -0.8, 1); break; }
    }
  }
  trail(x, y, z, hex, size, life) { const c = C3(hex), r = this.r; this.add.spawn(x + (r() - 0.5) * 0.4, y + (r() - 0.5) * 0.4, z + (r() - 0.5) * 0.4, 0, 0.5, 0, life || 0.35, size || 1.4, 0.1, c[0], c[1], c[2], 0.9, 0, 0); }
  flame(x, y, z, vx, vy, vz) { const r = this.r; this.add.spawn(x, y, z, vx + (r() - 0.5) * 2, vy + (r() - 0.5) * 2, vz + (r() - 0.5) * 2, 0.16 + r() * 0.1, 0.9, 0.2, 0.3, 0.9, 1, 1, 0, 2); this.add.spawn(x, y, z, vx * 0.8, vy, vz * 0.8, 0.12, 0.6, 0.1, 1, 0.6, 0.2, 0.9, 0, 2); }
}
// ---------- weather ----------
class Weather {
  constructor(scene, kind, q) {
    this.kind = kind; const n = this.n = Math.round((kind === 'rain' ? 1100 : 900) * q.weather);
    this.r = mulberry32(9); const r = this.r;
    this.box = [70, 34, 70];
    this.p = new Float32Array(n * 3);
    for (let i = 0; i < n; i++) { this.p[i * 3] = (r() - 0.5) * 70; this.p[i * 3 + 1] = r() * 34; this.p[i * 3 + 2] = (r() - 0.5) * 70; }
    if (kind === 'rain') {
      this.pos = new Float32Array(n * 6);
      const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.BufferAttribute(this.pos, 3).setUsage(THREE.DynamicDrawUsage));
      this.obj = new THREE.LineSegments(g, new THREE.LineBasicMaterial({ color: 0xb8c8d8, transparent: true, opacity: 0.38, depthWrite: false, fog: false }));
    } else {
      this.pos = new Float32Array(n * 3);
      const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.BufferAttribute(this.pos, 3).setUsage(THREE.DynamicDrawUsage));
      this.obj = new THREE.Points(g, new THREE.PointsMaterial({ color: 0xffffff, size: 0.28, map: TEX.glow, transparent: true, opacity: 0.95, depthWrite: false, fog: false }));
    }
    this.obj.frustumCulled = false; scene.add(this.obj); this.t = 0;
  }
  update(dt, cam, vel) {
    const n = this.n, p = this.p, rain = this.kind === 'rain'; this.t += dt;
    const cx = cam.position.x, cy = cam.position.y - 8, cz = cam.position.z;
    const fall = rain ? 26 : 2.2, vx = vel ? -vel.x * 0.2 : 0, vz = vel ? -vel.z * 0.2 : 0;
    for (let i = 0; i < n; i++) {
      let x = p[i * 3], y = p[i * 3 + 1], z = p[i * 3 + 2];
      y -= fall * dt; if (!rain) { x += Math.sin(this.t * 1.3 + i) * 0.6 * dt; z += Math.cos(this.t * 1.1 + i * 0.7) * 0.6 * dt; }
      if (y < 0) y += 34;
      p[i * 3 + 1] = y; p[i * 3] = x; p[i * 3 + 2] = z;
      // wrap relative to camera
      let wx = ((x - cx) % 70 + 105) % 70 - 35 + cx, wz = ((z - cz) % 70 + 105) % 70 - 35 + cz;
      const wy = cy + y;
      if (rain) { const o = i * 6; this.pos[o] = wx; this.pos[o + 1] = wy; this.pos[o + 2] = wz; this.pos[o + 3] = wx + vx * 0.05; this.pos[o + 4] = wy + 0.9; this.pos[o + 5] = wz + vz * 0.05; }
      else { const o = i * 3; this.pos[o] = wx; this.pos[o + 1] = wy; this.pos[o + 2] = wz; }
    }
    this.obj.geometry.attributes.position.needsUpdate = true;
  }
}
