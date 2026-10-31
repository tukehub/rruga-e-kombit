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

// Final grade, Blur-style: speed-driven radial blur + chromatic split at the edges, anamorphic streaks on hot lights, sharpen, filmic contrast, split toning, fine grain, vignette, hit tint
const FINAL_SHADER = {
  uniforms: {
    tDiffuse: { value: null }, uVig: { value: 0.32 }, uSat: { value: 1.1 }, uHit: { value: 0 }, uHitCol: { value: new THREE.Vector3(1, 0.1, 0.1) },
    uSpeed: { value: 0 }, uAber: { value: 0 }, uTime: { value: 0 }, uGrain: { value: 0.028 }, uContrast: { value: 1.1 }, uShadow: { value: new THREE.Vector3(0.0, 0.004, 0.012) }, uCenter: { value: new THREE.Vector2(0.5, 0.56) },
    uTexel: { value: new THREE.Vector2(1 / 1280, 1 / 720) }, uSharp: { value: 0.22 }, uStreak: { value: 0.0 }, uStreakThr: { value: 1.0 }, uHigh: { value: new THREE.Vector3(0.03, 0.012, -0.012) },
  },
  vertexShader: 'varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }',
  fragmentShader: [
    'uniform sampler2D tDiffuse; uniform float uVig, uSat, uHit, uSpeed, uAber, uTime, uGrain, uContrast, uSharp, uStreak, uStreakThr; uniform vec3 uHitCol, uShadow, uHigh; uniform vec2 uCenter, uTexel; varying vec2 vUv;',
    'float hash(vec2 p){ p = fract(p * vec2(443.897, 441.423)); p += dot(p, p.yx + 19.19); return fract((p.x + p.y) * p.x); }',
    'void main(){',
    '  vec2 d = vUv - uCenter; float v = dot(d, d);',
    // radial blur: strong at the edges, sharp around the car
    '  float blurK = uSpeed * smoothstep(0.04, 0.3, v);',
    '  vec3 col;',
    '  if (blurK > 0.002) {',
    '    vec2 step = d * blurK * 0.065; col = vec3(0.0); float wsum = 0.0;',
    '    for (int i = 0; i < 8; i++) { float t = (float(i) + hash(vUv + float(i) + uTime)) / 8.0; float w = 1.0 - t * 0.5; col += texture2D(tDiffuse, vUv - step * t).rgb * w; wsum += w; }',
    '    col /= wsum;',
    '  } else {',
    '    col = texture2D(tDiffuse, vUv).rgb;',
    // unsharp mask where the frame is not being blurred: crisp edges even at reduced pixel ratio
    '    vec3 n = texture2D(tDiffuse, vUv + vec2(uTexel.x, 0.0)).rgb + texture2D(tDiffuse, vUv - vec2(uTexel.x, 0.0)).rgb + texture2D(tDiffuse, vUv + vec2(0.0, uTexel.y)).rgb + texture2D(tDiffuse, vUv - vec2(0.0, uTexel.y)).rgb;',
    '    col = max(col + (col - n * 0.25) * uSharp * (1.0 - smoothstep(0.0, 0.03, uSpeed)), 0.0);',
    '  }',
    // chromatic aberration: R and B pulled apart along the radius
    '  float ab = uAber * smoothstep(0.02, 0.3, v);',
    '  if (ab > 0.0005) { vec2 o = d * ab * 0.03; col.r = mix(col.r, texture2D(tDiffuse, vUv - o).r, 0.85); col.b = mix(col.b, texture2D(tDiffuse, vUv + o).b, 0.85); }',
    // anamorphic streaks: hot pixels smeared horizontally, cool-tinted like a cine lens
    '  if (uStreak > 0.001) {',
    '    vec3 st = vec3(0.0);',
    '    for (int i = 1; i <= 8; i++) { float fi = float(i); vec2 o = vec2(uTexel.x * fi * 4.5, 0.0); float w = 1.0 / (1.0 + fi * 0.55);',
    '      st += (max(texture2D(tDiffuse, vUv + o).rgb - uStreakThr, 0.0) + max(texture2D(tDiffuse, vUv - o).rgb - uStreakThr, 0.0)) * w; }',
    '    col += st * uStreak * vec3(0.8, 0.9, 1.15);',
    '  }',
    '  float l = dot(col, vec3(0.2126, 0.7152, 0.0722)); col = max(mix(vec3(l), col, uSat), 0.0);',
    // filmic contrast around mid-grey, cool lift in the shadows, warm push in the highlights
    '  col = max((col - 0.18) * uContrast + 0.18, 0.0);',
    '  col += uShadow * (1.0 - smoothstep(0.0, 0.25, l));',
    '  col += uHigh * smoothstep(0.45, 1.1, l);',
    '  col *= 1.0 - uVig * v * 2.4;',
    '  col = mix(col, uHitCol, uHit * smoothstep(0.08, 0.35, v));',
    '  vec3 srgb = LinearTosRGB(vec4(col, 1.0)).rgb;',
    '  float g = hash(vUv * 1013.0 + fract(uTime * 7.31)) - 0.5; srgb += g * uGrain * (1.0 - smoothstep(0.0, 0.9, dot(srgb, vec3(0.333))));',
    '  gl_FragColor = vec4(srgb, 1.0);',
    '}'].join('\n'),
};

class Post {
  constructor(renderer) {
    this.r = renderer;
    this.gl2 = renderer.capabilities.isWebGL2;
    this.hdr = this.gl2 && !!renderer.extensions.get('EXT_color_buffer_float');
    this.fsq = new THREE.FullScreenQuad(new THREE.ShaderMaterial({ uniforms: THREE.UniformsUtils.clone(FINAL_SHADER.uniforms), vertexShader: FINAL_SHADER.vertexShader, fragmentShader: FINAL_SHADER.fragmentShader, depthTest: false, depthWrite: false }));
    this.u = this.fsq.material.uniforms;
    this.rt = null; this.bloom = null; this.key = ''; this.strength = 1; this.speedT = 0; this.aberT = 0; this.t = 0;
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
    this.u.uTexel.value.set(1 / W, 1 / H);
    // streaks need the HDR headroom to find hot pixels; low quality skips them
    this.u.uStreak.value = q.msaa ? 0.55 : 0; this.u.uStreakThr.value = this.hdr ? 1.05 : 0.86; this.u.uSharp.value = pr < 1.2 ? 0.3 : 0.18;
  }
  setLook(env) {
    if (this.bloom) { this.bloom.strength = env.bloom == null ? 0.9 : env.bloom; this.bloom.radius = 0.6; }
    this.u.uSat.value = env.sat || 1.1; this.u.uVig.value = env.vig == null ? 0.32 : env.vig;
    this.u.uContrast.value = env.contrast == null ? 1.1 : env.contrast; this.u.uGrain.value = env.grain == null ? 0.028 : env.grain;
  }
  hit(col, a) { this.u.uHitCol.value.set(col.r, col.g, col.b); this.u.uHit.value = Math.max(this.u.uHit.value, a); }
  // speed 0..1 drives the radial blur, aber 0..1 the chromatic split (nitro pushes both)
  speed(k, aber) { this.speedT = clamp(k, 0, 1); this.aberT = clamp(aber == null ? k : aber, 0, 1); }
  render(scene, cam, dt) {
    const r = this.r; dt = dt || 0.016; this.t += dt;
    r.setRenderTarget(this.rt); r.clear(); r.render(scene, cam);
    if (this.bloom) this.bloom.render(r, null, this.rt, 0, false);
    this.u.tDiffuse.value = this.rt.texture; this.u.uTime.value = this.t % 100;
    const k = 1 - Math.exp(-dt * 6);
    this.u.uSpeed.value += (this.speedT - this.u.uSpeed.value) * k; this.u.uAber.value += (this.aberT - this.u.uAber.value) * k;
    r.setRenderTarget(null); this.fsq.render(r);
    if (this.u.uHit.value > 0) this.u.uHit.value = Math.max(0, this.u.uHit.value - dt * 2.2);
  }
}
