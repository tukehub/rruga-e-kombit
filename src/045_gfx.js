// ---------- graphics: colour space, HDR glow materials, reflections, bloom pipeline ----------
// All design colours are written as sRGB hex; linearize() converts materials/lights once so lighting is
// computed in linear space, then the final pass encodes back to sRGB. Materials with userData.hdr are
// multiplied above 1.0 so only they cross the bloom threshold (neon, lights, trails, power-ups).
const _linDone = new WeakSet();
const toLin = (c) => (c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4));
function linMat(m) {
  if (!m || _linDone.has(m)) return m; _linDone.add(m);
  if (m.color) m.color.convertSRGBToLinear();
  if (m.emissive) m.emissive.convertSRGBToLinear();
  if (m.userData && m.userData.hdr) m.color.multiplyScalar(m.userData.hdr);
  return m;
}
function linearize(root) {
  root.traverse((o) => {
    if (o.isLight) {
      if (!_linDone.has(o)) { _linDone.add(o); o.color.convertSRGBToLinear(); if (o.groundColor) o.groundColor.convertSRGBToLinear(); }
      return;
    }
    if (o.material) (Array.isArray(o.material) ? o.material : [o.material]).forEach(linMat);
  });
  return root;
}
// unlit material that glows (blooms) with strength k
function glowMat(hex, k, o) {
  const m = new THREE.MeshBasicMaterial(Object.assign({ color: new THREE.Color(hex), toneMapped: false }, o || {}));
  m.userData.hdr = k; return m;
}
function glowSprite(hex, k, map) {
  const m = new THREE.SpriteMaterial({ map: map || TEX.glow, color: new THREE.Color(hex), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false });
  m.userData.hdr = k; return linMat(m);
}
function linColor(hex) { return new THREE.Color(hex).convertSRGBToLinear(); }

// Reflection environment: sky gradient + a ring of bright city light panels, prefiltered for PBR.
function makeEnvMap(renderer, env, neon) {
  const pm = new THREE.PMREMGenerator(renderer), sc = new THREE.Scene(), dark = env.win >= 0.45;
  const g = new THREE.SphereGeometry(50, 32, 16), pos = g.attributes.position, cols = [];
  const top = linColor(env.sky[0]), hor = linColor(env.sky[1]), gnd = linColor(env.hemi[1]);
  for (let i = 0; i < pos.count; i++) {
    const y = pos.getY(i) / 50, c = new THREE.Color();
    if (y >= 0) c.copy(hor).lerp(top, Math.pow(Math.min(1, y * 1.4), 0.6)); else c.copy(hor).lerp(gnd, Math.min(1, -y * 3));
    cols.push(c.r, c.g, c.b);
  }
  g.setAttribute('color', new THREE.Float32BufferAttribute(cols, 3));
  sc.add(new THREE.Mesh(g, new THREE.MeshBasicMaterial({ vertexColors: true, side: THREE.BackSide, toneMapped: false })));
  const r = mulberry32(7), pg = new THREE.PlaneGeometry(1, 1);
  const warm = linColor('#ffd2a0'), ncol = linColor(neon);
  const n = dark ? 16 : 6;
  for (let i = 0; i < n; i++) {
    const a = i / n * Math.PI * 2 + r() * 0.3;
    const m = new THREE.Mesh(pg, new THREE.MeshBasicMaterial({ color: (i % 3 === 0 ? ncol : warm).clone().multiplyScalar(dark ? 5 : 1.6), toneMapped: false, side: THREE.DoubleSide }));
    m.scale.set(8 + r() * 14, dark ? 0.8 + r() * 1.6 : 4, 1);
    m.position.set(Math.cos(a) * 40, dark ? 1 + r() * 7 : 14, Math.sin(a) * 40); m.lookAt(0, m.position.y, 0); sc.add(m);
  }
  // soft key light from the sun / moon direction
  const sd = new THREE.Vector3().fromArray(env.sun.dir).normalize();
  const key = new THREE.Mesh(new THREE.PlaneGeometry(26, 26), new THREE.MeshBasicMaterial({ color: linColor(env.sun.col).multiplyScalar(dark ? 1.5 : 6), toneMapped: false, side: THREE.DoubleSide }));
  key.position.copy(sd).multiplyScalar(42); key.lookAt(0, 0, 0); sc.add(key);
  const rt = pm.fromScene(sc, 0.02);
  sc.traverse(o => { if (o.geometry) o.geometry.dispose(); if (o.material) o.material.dispose(); });
  pm.dispose();
  return rt;
}

const FINAL_SHADER = {
  uniforms: { tDiffuse: { value: null }, uVig: { value: 0.32 }, uSat: { value: 1.1 }, uHit: { value: 0 }, uHitCol: { value: new THREE.Vector3(1, 0.1, 0.1) } },
  vertexShader: 'varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }',
  fragmentShader: [
    'uniform sampler2D tDiffuse; uniform float uVig, uSat, uHit; uniform vec3 uHitCol; varying vec2 vUv;',
    'void main(){',
    '  vec3 col = texture2D(tDiffuse, vUv).rgb;',
    '  float l = dot(col, vec3(0.2126, 0.7152, 0.0722)); col = max(mix(vec3(l), col, uSat), 0.0);',
    '  vec2 d = vUv - 0.5; float v = dot(d, d);',
    '  col *= 1.0 - uVig * v * 2.4;',
    '  col = mix(col, uHitCol, uHit * smoothstep(0.08, 0.35, v));',
    '  gl_FragColor = LinearTosRGB(vec4(col, 1.0));',
    '}'].join('\n'),
};

class Post {
  constructor(renderer) {
    this.r = renderer;
    this.gl2 = renderer.capabilities.isWebGL2;
    this.hdr = this.gl2 && !!renderer.extensions.get('EXT_color_buffer_float');
    this.fsq = new THREE.FullScreenQuad(new THREE.ShaderMaterial({ uniforms: THREE.UniformsUtils.clone(FINAL_SHADER.uniforms), vertexShader: FINAL_SHADER.vertexShader, fragmentShader: FINAL_SHADER.fragmentShader, depthTest: false, depthWrite: false }));
    this.u = this.fsq.material.uniforms;
    this.rt = null; this.bloom = null; this.key = ''; this.strength = 1;
  }
  setSize(w, h, pr, q) {
    const W = Math.max(2, Math.round(w * pr)), H = Math.max(2, Math.round(h * pr));
    const samples = this.gl2 ? (q.msaa || 0) : 0, key = samples + '|' + q.bloom;
    if (!this.rt || key !== this.key) {
      if (this.rt) this.rt.dispose();
      const opt = { type: this.hdr ? THREE.HalfFloatType : THREE.UnsignedByteType, format: THREE.RGBAFormat, minFilter: THREE.LinearFilter, magFilter: THREE.LinearFilter, depthBuffer: true, stencilBuffer: false };
      if (samples && THREE.WebGLMultisampleRenderTarget) { this.rt = new THREE.WebGLMultisampleRenderTarget(W, H, opt); this.rt.samples = samples; }
      else this.rt = new THREE.WebGLRenderTarget(W, H, opt);
      if (this.bloom) { this.bloom.dispose(); this.bloom = null; }
      if (q.bloom) this.bloom = new THREE.UnrealBloomPass(new THREE.Vector2(W * q.bloom, H * q.bloom), 1, 0.6, this.hdr ? 1.0 : 0.82);
      this.key = key;
    } else this.rt.setSize(W, H);
    if (this.bloom) this.bloom.setSize(Math.round(W * q.bloom), Math.round(H * q.bloom));
  }
  setLook(env) {
    if (this.bloom) { this.bloom.strength = env.bloom == null ? 0.9 : env.bloom; this.bloom.radius = 0.55; }
    this.u.uSat.value = env.sat || 1.1; this.u.uVig.value = env.vig == null ? 0.32 : env.vig;
  }
  hit(col, a) { this.u.uHitCol.value.set(col.r, col.g, col.b); this.u.uHit.value = Math.max(this.u.uHit.value, a); }
  render(scene, cam, dt) {
    const r = this.r;
    r.setRenderTarget(this.rt); r.clear(); r.render(scene, cam);
    if (this.bloom) this.bloom.render(r, null, this.rt, 0, false);
    this.u.tDiffuse.value = this.rt.texture;
    r.setRenderTarget(null); this.fsq.render(r);
    if (this.u.uHit.value > 0) this.u.uHit.value = Math.max(0, this.u.uHit.value - (dt || 0.016) * 2.2);
  }
}
