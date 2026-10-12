// ---------- main: renderer, garage, race lifecycle, loop ----------
const G = { state: 'menu', last: 0, acc: 0, t: 0, views: [], ent: new Map(), trans: [], fpsT: 0, fpsN: 0, pr: 1 };
const DT = 1 / 60, V3 = THREE.Vector3;
const tmpA = new V3(), tmpB = new V3(), tmpC = new V3(), tmpT = new V3(), tl = new V3(), fwd = new V3();
let renderer, camera;

function initTextures() {
  TEX.glow = glowTex(); TEX.glow.userData.shared = true;
  TEX.icons = {};
  for (const k of PW_KEYS) { const c = iconCanvas(k, 128); const t = new THREE.CanvasTexture(c); t.encoding = THREE.sRGBEncoding; t.userData = { shared: true }; TEX.icons[k] = { canvas: c, tex: t, url: c.toDataURL() }; }
}
let lazyDone = false;
function lazyTextures() {
  if (lazyDone) return; lazyDone = true;
  TEX.flag = flagTex(); TEX.sidewalk = sidewalkTex(); TEX.ads = adAtlasTex(AD_KEYS); TEX.neonAtlas = neonAtlasTex();
  TEX.vgrad = vGradTex(); TEX.vgrad.userData.shared = true;
  TEX.statue = statueTex(); TEX.clock = clockTex(); TEX.painted = paintedFacadeTex(); TEX.lattice = latticeTex();
  TEX.facade = {}; for (const st of Object.keys(STYLE_INFO)) TEX.facade[st] = facadeTex(st, strHash(st) & 0xffff);
  const mark = (t) => { if (t && t.userData) t.userData.shared = true; };
  ['flag', 'sidewalk', 'ads', 'neonAtlas', 'statue', 'clock', 'painted', 'lattice'].forEach(k => mark(TEX[k]));
  for (const st in TEX.facade) { mark(TEX.facade[st].map); mark(TEX.facade[st].em); }
}
function initRenderer() {
  const q = Q();
  renderer = new THREE.WebGLRenderer({ antialias: false, powerPreference: 'high-performance', stencil: false });
  renderer.setClearColor(0x0d0a10);
  renderer.outputEncoding = THREE.sRGBEncoding; renderer.toneMapping = THREE.ACESFilmicToneMapping; renderer.toneMappingExposure = 1;
  renderer.shadowMap.enabled = true; renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  G.post = new Post(renderer);
  G.pr = Math.min(window.devicePixelRatio || 1, q.pr); renderer.setPixelRatio(G.pr);
  document.getElementById('stage').appendChild(renderer.domElement);
  camera = new THREE.PerspectiveCamera(64, 1, 0.4, 3600);
  onResize();
  addEventListener('resize', onResize);
  addEventListener('orientationchange', () => setTimeout(onResize, 250));
  renderer.domElement.addEventListener('webglcontextlost', (e) => e.preventDefault(), false);
}
function onResize() {
  const w = innerWidth || 800, h = innerHeight || 450;
  renderer.setSize(w, h); camera.aspect = w / h; camera.updateProjectionMatrix(); updatePScale();
  if (G.post) G.post.setSize(w, h, G.pr, Q());
}
function updatePScale() { if (G.fx) G.fx.setScale((innerHeight || 450) * G.pr / (2 * Math.tan(camera.fov * Math.PI / 360))); }
function applyQuality() { G.pr = Math.min(window.devicePixelRatio || 1, Q().pr); renderer.setPixelRatio(G.pr); onResize(); }

// ---------- garage (menu backdrop) ----------
function initGarage() {
  const sc = new THREE.Scene(); sc.background = new THREE.Color('#0d0a10'); sc.fog = new THREE.Fog('#0d0a10', 16, 46);
  const fl = new THREE.CircleGeometry(40, 48); fl.rotateX(-Math.PI / 2);
  const floor = new THREE.Mesh(fl, new THREE.MeshStandardMaterial({ color: 0x141016, roughness: 0.4, metalness: 0.3, envMapIntensity: 0.25 })); floor.receiveShadow = true; sc.add(floor);
  const grid = new THREE.GridHelper(80, 40, 0x3c2b36, 0x221a22); grid.position.y = 0.01; sc.add(grid);
  const rg = new THREE.RingGeometry(4.2, 4.4, 96); rg.rotateX(-Math.PI / 2);
  const ring = new THREE.Mesh(rg, glowMat('#e41e20', 4)); ring.position.y = 0.03; sc.add(ring);
  // neon light bars overhead, like a showroom
  const bar = new THREE.BoxGeometry(0.12, 0.12, 9);
  for (const x of [-3.2, 0, 3.2]) { const b = new THREE.Mesh(bar, glowMat(x ? '#ffffff' : '#e41e20', x ? 3 : 4)); b.position.set(x, 6.5, 0); sc.add(b); }
  sc.add(new THREE.HemisphereLight(0x9c8aa8, 0x1a1012, 0.5));
  const d1 = new THREE.DirectionalLight(0xfff1e0, 1.4); d1.position.set(5, 9, 6); d1.castShadow = true; d1.shadow.mapSize.set(1024, 1024);
  Object.assign(d1.shadow.camera, { left: -6, right: 6, top: 6, bottom: -6, near: 1, far: 30 }); d1.shadow.camera.updateProjectionMatrix(); d1.shadow.bias = -0.0008; sc.add(d1);
  const d2 = new THREE.DirectionalLight(0xff3040, 1.1); d2.position.set(-6, 3, -8); sc.add(d2);
  const envRT = makeEnvMap(renderer, ENV.night, '#e41e20'); sc.environment = envRT.texture;
  const ec = mkCanvas(256, 256), eg = ec.getContext('2d'); drawEagle(eg, 128, 132, 230, '#ffffff');
  const et = new THREE.CanvasTexture(ec);
  const wall = new THREE.Mesh(new THREE.PlaneGeometry(26, 26), new THREE.MeshBasicMaterial({ map: et, color: 0x5a1216, transparent: true, depthWrite: false, fog: false }));
  wall.position.set(0, 9, -18); sc.add(wall);
  linearize(sc); sc.fog.color.convertSRGBToLinear(); sc.background.convertSRGBToLinear();
  G.garage = { scene: sc, view: null, t: 0, wall };
  garageCar();
}
function garageCar() {
  const g = G.garage; if (!g) return;
  if (g.view) g.scene.remove(g.view.root);
  const car = new Car(0, CARS[SET.car], 'TI', true, SET.paint);
  g.view = new CarView(car, g.scene, {}); g.view.root.traverse(o => { if (o.isMesh && o !== g.view.shadow) o.castShadow = true; });
}
function renderGarage(dt) {
  const g = G.garage; g.t += dt;
  const a = g.t * 0.32, r = 8.6;
  camera.position.set(Math.sin(a) * r, 2.3 + Math.sin(g.t * 0.5) * 0.3, Math.cos(a) * r);
  camera.lookAt(0, 0.75, 0);
  g.wall.lookAt(camera.position.x, 9, camera.position.z);
  const w = innerWidth, h = innerHeight;
  if (w > h * 1.1 && UI.cur !== 'scr-city') camera.setViewOffset(w, h, -w * 0.2, 0, w, h); else camera.clearViewOffset();
  if (camera.fov !== 50) { camera.fov = 50; camera.updateProjectionMatrix(); }
  if (G.lookFor !== 'garage') { G.lookFor = 'garage'; G.post.setLook({ bloom: 0.85, sat: 1.1 }); renderer.toneMappingExposure = 1.05; }
  G.post.render(g.scene, camera, dt);
}

// ---------- race lifecycle ----------
function startRace() {
  if (G.state === 'loading') return;
  AUD.init(); clearQueued();
  const city = CITIES[SET.city];
  UI.hud(false); UI.centerOff();
  UI.$('load-city').textContent = city.name;
  UI.$('load-region').textContent = REGIONS[city.region] + ' · ' + ENV[city.env].label;
  UI.$('load-tip').textContent = TIPS[Math.floor(Math.random() * TIPS.length)];
  UI.show('scr-load');
  G.state = 'loading';
  setTimeout(() => {
    try { buildRace(city); }
    catch (e) { console.error(e); G.state = 'menu'; UI.show('scr-title'); return; }
    G.state = 'intro'; G.introT = 0; G.last = 0;
    UI.show(null); UI.hud(true); UI.slotState = ''; UI.last = {};
    UI.center(`${city.name}<small>${REGIONS[city.region]} · ${ENV[city.env].label} · ${city.laps} xhiro</small>`, 2.6);
    requestWake();
  }, 90);
}
function disposeRace() {
  if (!G.world) return;
  G.world.scene.traverse(o => {
    if (o.geometry) o.geometry.dispose();
    if (o.material) {
      const ms = Array.isArray(o.material) ? o.material : [o.material];
      for (const m of ms) { for (const k of ['map', 'emissiveMap']) { const t = m[k]; if (t && !(t.userData && t.userData.shared)) t.dispose(); } m.dispose(); }
    }
  });
  if (G.world.envRT) G.world.envRT.dispose();
  G.world = G.race = G.track = G.player = null; G.views = []; G.ent.clear(); G.trans = []; G.fx = null; G.weather = null; G.trails = null;
  renderer.renderLists.dispose();
}
function buildRace(city) {
  disposeRace(); lazyTextures();
  const q = Q(), env = ENV[city.env];
  const track = new Track(city);
  const world = new World(track, q, renderer);
  const race = new Race(track, { playerDef: CARS[SET.car], playerColor: SET.paint, diff: SET.diff, seed: (Math.random() * 1e9) | 0, wet: !!env.wet, assist: SET.assist, laps: city.laps });
  const scene = world.scene;
  G.track = track; G.world = world; G.race = race; G.player = race.player; G.city = city; G.env = env;
  G.views = race.cars.map(c => new CarView(c, scene, { beams: q.beams && env.win >= 0.45, tags: true }));
  G.trails = new Trails(scene, race.cars.length, q.trailSeg); race.cars.forEach((c, i) => G.trails.setColor(i, c.color)); G.trailI = [];
  G.fx = new FX(scene, q); updatePScale();
  G.weather = env.rain ? new Weather(scene, 'rain', q) : env.snow ? new Weather(scene, 'snow', q) : null;
  // pick-ups
  G.res = {
    ring: (() => { const g = new THREE.RingGeometry(1.25, 1.7, 24); g.rotateX(-Math.PI / 2); return g; })(),
    pick: {}, pring: {},
    gm: {}, glow(col) { return this.gm[col] || (this.gm[col] = glowSprite(col, 2.4)); },
    pillar: (() => { const g = new THREE.CylinderGeometry(1.15, 1.15, 9, 28, 1, true); g.translate(0, 4.5, 0); return g; })(), ppm: {},
  };
  G.picks = new Map();
  for (const p of race.pickups) {
    const m = G.res.pick[p.type] || (G.res.pick[p.type] = linMat(Object.assign(new THREE.SpriteMaterial({ map: TEX.icons[p.type].tex, transparent: true, depthWrite: false, toneMapped: false }), { userData: { hdr: 1.3 } })));
    const rm = G.res.pring[p.type] || (G.res.pring[p.type] = linMat(glowMat(PW[p.type].col, 3, { transparent: true, opacity: 0.85, blending: THREE.AdditiveBlending, depthWrite: false })));
    const pm = G.res.ppm[p.type] || (G.res.ppm[p.type] = linMat(glowMat(PW[p.type].col, 1.1, { map: TEX.vgrad, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide, fog: false })));
    const sp = new THREE.Sprite(m); sp.scale.set(2.9, 2.9, 1); const ring = new THREE.Mesh(G.res.ring, rm), pil = new THREE.Mesh(G.res.pillar, pm);
    track.pos(p.s, p.d, tmpA); sp.position.set(tmpA.x, tmpA.y + 1.6, tmpA.z); ring.position.set(tmpA.x, tmpA.y + 0.12, tmpA.z); pil.position.set(tmpA.x, tmpA.y + 0.1, tmpA.z);
    scene.add(sp); scene.add(ring); scene.add(pil);
    G.picks.set(p.id, { sp, ring, pil, y: tmpA.y, ph: Math.random() * 6, pop: 1 });
  }
  linearize(scene); G.post.setLook(env); G.lookFor = 'race'; renderer.toneMappingExposure = env.exp || 1;
  G.acc = 0; G.shake = 0; G.fov = 66; G.camLook = new V3(); G.finT = 0; G.sndT = {};
  G.minimap = (() => { const p = new Path2D(); for (let i = 0; i < track.M; i += 2) { if (i) p.lineTo(track.X[i], track.Z[i]); else p.moveTo(track.X[i], track.Z[i]); } p.closePath(); return p; })();
  camera.clearViewOffset(); camera.fov = 64; camera.updateProjectionMatrix();
  updateViews(0); introCam(0);
}
function toMenu() {
  G.speedO = 0; UI.$('fx-speed').style.opacity = 0;
  disposeRace(); G.state = 'menu'; UI.hud(false); UI.centerOff(); UI.show('scr-title'); UI.updateTotals(); releaseWake();
  AUD.engine(0, false, false, 0); garageCar();
}
function togglePause() {
  if (G.state === 'race' || G.state === 'countdown' || G.state === 'intro' || G.state === 'finish') {
    G.prevState = G.state; G.state = 'paused'; UI.hud(false); UI.show('scr-pause'); AUD.engine(0, false, false, 0); clearQueued();
  } else if (G.state === 'paused') { G.state = G.prevState || 'race'; UI.show(null); UI.hud(true); G.last = 0; }
}
async function requestWake() { try { if (navigator.wakeLock) G.wake = await navigator.wakeLock.request('screen'); } catch (e) { } }
function releaseWake() { try { if (G.wake) G.wake.release(); } catch (e) { } G.wake = null; }
document.addEventListener('visibilitychange', () => { if (document.hidden && (G.state === 'race' || G.state === 'countdown')) togglePause(); });

// ---------- events → effects, sound, HUD ----------
function wpos(s, d, out, dy) { G.track.pos(s, d, out); out.y += dy || 0; return out; }
function nearVol(s) { const p = G.player; if (!p) return 1; return clamp(1 - Math.abs(G.track.wrapS(s - p.s)) / 220, 0, 1); }
function limited(key, gap) { const t = G.t; if ((G.sndT[key] || 0) > t) return false; G.sndT[key] = t + gap; return true; }
function processEvents() {
  const race = G.race, P = G.player, fx = G.fx;
  for (const e of race.events) {
    const c = e.car;
    switch (e.t) {
      case 'pickup': {
        const v = G.picks.get(e.p.id); if (v) { v.sp.visible = false; v.ring.visible = false; v.pil.visible = false; fx.burst('pickup', v.sp.position.x, v.sp.position.y, v.sp.position.z, { col: PW[e.type].col }); }
        if (c === P) {
          AUD.play('pickup'); UI.feed('+ ' + PW[e.type].name, PW[e.type].col, 1.6);
          if (!SET.seen[e.type]) { SET.seen[e.type] = 1; saveSettings(); UI.feed(PW[e.type].desc, PW[e.type].col, 4.5); }
        }
        break;
      }
      case 'pickupBack': { const v = G.picks.get(e.p.id); if (v) { v.sp.visible = true; v.ring.visible = true; v.pil.visible = true; v.pop = 0; } break; }
      case 'fire': {
        const vol = nearVol(c.s);
        const snd = { eagle: 'eagle', bolt: 'bolt', barge: 'barge', mine: 'mine', shock: 'shock', nitro: e.back ? 'brake' : 'nitro', shield: 'shield', repair: 'repair' }[e.type];
        if (vol > 0.05) AUD.play(snd, vol);
        break;
      }
      case 'hit': {
        wpos(c.s, c.d, tmpA, 0.8); fx.burst('hit', tmpA.x, tmpA.y, tmpA.z, { col: PW[e.kind] ? PW[e.kind].col : '#ffffff' });
        AUD.play('hit', nearVol(c.s));
        const col = PW[e.kind] ? PW[e.kind].col : '#ffffff';
        if (c === P) { UI.flash(e.kind === 'shock' ? 'rgba(255,224,58,0.8)' : 'rgba(228,30,32,0.85)'); G.shake = Math.max(G.shake, e.kind === 'eagle' ? 1.2 : 0.6); UI.feed(`${e.by ? e.by.name : '?'} → TI`, col); }
        else if (e.by === P) UI.feed(`TI → ${c.name}  +${FANS[e.kind] || 0}`, col);
        if (G.views[c.id] && G.views[c.id].tag) G.views[c.id].updateTag();
        break;
      }
      case 'blocked': {
        wpos(c.s, c.d, tmpA, 0.8); fx.burst('ring', tmpA.x, tmpA.y, tmpA.z, { col: PW.shield.col }); AUD.play('shield', nearVol(c.s) * 0.6);
        if (c === P) UI.feed('Mburoja e priti!', PW.shield.col); else if (e.by === P) UI.feed(`${c.name} kishte mburojë`, PW.shield.col);
        break;
      }
      case 'wreck': {
        wpos(c.s, c.d, tmpA, 0.6); fx.burst('explode', tmpA.x, tmpA.y, tmpA.z, 1); AUD.play('boom', nearVol(c.s));
        if (c === P) { UI.center('U bëre copë!<small>Rikthehesh pas dy sekondash</small>', 2.2); UI.flash('rgba(255,120,30,0.9)', 1); G.shake = 1.6; }
        else if (e.by === P) UI.feed(`${c.name} u bë copë!  +${FANS.wreck}`, '#ffb547');
        else if (nearVol(c.s) > 0.6) UI.feed(`${c.name} u bë copë`, '#a2959f', 1.8);
        break;
      }
      case 'respawn': { wpos(c.s, c.d, tmpA, 1); fx.burst('pickup', tmpA.x, tmpA.y, tmpA.z, { col: '#ffffff' }); if (G.views[c.id]) G.views[c.id].updateTag(); break; }
      case 'wall': {
        const v = G.views[c.id]; wpos(c.s, c.d + e.side * 1.0, tmpA, 0.5); fx.burst('spark', tmpA.x, tmpA.y, tmpA.z, 1);
        if (c === P && limited('wall', 0.15)) { AUD.play('wall', clamp(e.imp / 20, 0.3, 1)); G.shake = Math.max(G.shake, Math.min(0.5, e.imp / 40)); }
        break;
      }
      case 'bump': {
        if ((e.a === P || e.b === P) && limited('bump', 0.22)) { AUD.play('bump', 0.7); wpos((e.a.s + G.track.wrapS(e.b.s - e.a.s) / 2), (e.a.d + e.b.d) / 2, tmpA, 0.6); fx.burst('spark', tmpA.x, tmpA.y, tmpA.z, 1); }
        break;
      }
      case 'boom': {
        wpos(e.s, e.d, tmpA, 0.5); fx.burst(e.kind === 'bolt' ? 'hit' : 'explode', tmpA.x, tmpA.y, tmpA.z, e.kind === 'bolt' ? { col: PW.bolt.col } : 0.6);
        AUD.play(e.kind === 'bolt' ? 'hit' : 'boom', nearVol(e.s) * 0.8);
        break;
      }
      case 'fizzle': { wpos(e.s, e.d, tmpA, 1); fx.burst('hit', tmpA.x, tmpA.y, tmpA.z, { col: PW[e.kind].col }); break; }
      case 'zap': { wpos(c.s, c.d, tmpA, 0.8); fx.burst('zap', tmpA.x, tmpA.y, tmpA.z); if (limited('zap', 0.2)) AUD.play('shock', nearVol(c.s)); break; }
      case 'barge': {
        wpos(c.s, c.d, tmpA, 0.3); fx.burst('ring', tmpA.x, tmpA.y, tmpA.z, { col: PW.barge.col });
        const m = new THREE.Mesh(G.res.ring, linMat(glowMat(PW.barge.col, 3, { transparent: true, blending: THREE.AdditiveBlending, depthWrite: false })));
        m.position.copy(tmpA); G.world.scene.add(m); G.trans.push({ m, t: 0, dur: 0.45, kind: 'ring', max: 9 });
        if (c === P) G.shake = Math.max(G.shake, 0.5);
        break;
      }
      case 'shock': {
        if (e.target === P) { UI.center('Stuhia!<small>Kupola elektrike përpara</small>', 1.6); UI.feed(`${c.name} lëshoi Stuhinë`, PW.shock.col); }
        else if (c === P) UI.feed(`Stuhia për ${e.target.name}`, PW.shock.col);
        break;
      }
      case 'nitro': if (c === P && !e.back) UI.flash('rgba(56,255,106,0.5)', 0.5); break;
      case 'repair': { wpos(c.s, c.d, tmpA, 0.5); fx.burst('repair', tmpA.x, tmpA.y, tmpA.z); if (c === P) UI.feed('Usta Ramizi e rregulloi', PW.repair.col); if (G.views[c.id]) G.views[c.id].updateTag(); break; }
      case 'denied': if (c === P) { AUD.play('denied'); UI.feed(e.why === 'first' ? 'Je i pari. S’ka kë të godasë Stuhia.' : 'Makina s’ka asnjë gërvishtje. Ende.', '#a2959f'); } break;
      case 'cycle': if (c === P) AUD.play('cycle'); break;
      case 'lap': if (c === P) { AUD.play('lap'); UI.center(e.lap === race.laps ? 'Xhiro e fundit!' : `Xhiro ${e.lap}/${race.laps}`, 1.6); } break;
      case 'finish': {
        if (c === P) {
          G.state = 'finish'; G.finT = 0; P.autopilot = true; AUD.play('finish'); UI.flash('rgba(255,181,71,0.7)', 0.8);
          UI.center(`${ORD[P.place - 1]}!<small>${fmtTime(P.finishTime)}</small>`, 3.6);
        }
        break;
      }
    }
  }
  race.events.length = 0;
}
// ---------- views ----------
function updateViews(dt) {
  const T = G.track, race = G.race, fx = G.fx, env = G.env, t = G.t;
  race.cars.forEach((c, i) => {
    const v = G.views[i], root = v.root;
    T.pos(c.s, c.d, tmpA); tmpA.y += c.hop;
    const psi = T.heading(c.s) + c.yaw; T.tangent(c.s, tmpT);
    fwd.set(-Math.sin(psi), tmpT.y, Math.cos(psi));
    root.position.copy(tmpA); tmpB.copy(tmpA).add(fwd); root.lookAt(tmpB);
    let ry = -c.steer * c.drift * 0.5;
    if (c.spinT > 0) ry += c.spinDir * (1 - c.spinT / 1.15) * Math.PI * 2;
    v.body.rotation.y = ry;
    v.body.rotation.z = clamp(c.steer * Math.min(1, Math.abs(c.v) / 40), -1, 1) * 0.05;
    v.body.rotation.x = c.hop > 0 ? -clamp(c.hopV * 0.03, -0.3, 0.35) : (c.braking ? 0.025 : 0);
    if (dt) v.spin(dt, c.v, c.steer);
    const wrecked = c.wreckT > 0;
    root.visible = !wrecked;
    v.body.visible = !(c.invulnT > 0 && Math.floor(t * 12) % 2 === 0);
    v.shield.visible = c.shieldT > 0 && !wrecked;
    if (v.shield.visible) { v.shield.material.opacity = 0.11 + 0.05 * Math.sin(t * 9); const s = 1 + 0.03 * Math.sin(t * 13); v.shield.scale.set(s, s * 0.8, s); }
    v.under.material.opacity = c.nitroT > 0 ? 0.95 : 0.5;
    root.updateMatrixWorld(true);
    for (let k = 0; k < 2; k++) { tl.fromArray(v.tail[k]); v.body.localToWorld(tl); G.trails.push(i, k, tl.x, tl.y, tl.z); }
    G.trailI[i] = wrecked ? 0 : clamp((Math.abs(c.v) - 12) / 26, 0, 1) * (c.nitroT > 0 ? 1.5 : 1);
    G.trails.maxLen[i] = c.isPlayer ? 4.5 : 16;
    if (!dt) return;
    c._pt = (c._pt || 0) + dt;
    if (wrecked) { if (c._pt > 0.05) { c._pt = 0; T.pos(c.s, c.d, tmpB); fx.burst('smoke', tmpB.x, tmpB.y + 0.6, tmpB.z); fx.flame(tmpB.x, tmpB.y + 0.5, tmpB.z, 0, 4, 0); } return; }
    if (c._pt > 0.033) {
      c._pt = 0;
      const sp = Math.abs(c.v);
      tl.fromArray(v.tail[0]); v.body.localToWorld(tl); tmpB.fromArray(v.tail[1]); v.body.localToWorld(tmpB);
      if (c.drift > 0.5 && sp > 15) { fx.burst(env.snow ? 'snowspray' : 'dust', tl.x, tl.y - 0.5, tl.z); fx.burst(env.snow ? 'snowspray' : 'dust', tmpB.x, tmpB.y - 0.5, tmpB.z); }
      else if (sp > 22 && (env.wet || env.snow) && Math.random() < 0.6) fx.burst(env.snow ? 'snowspray' : 'splash', (tl.x + tmpB.x) / 2, tl.y - 0.6, (tl.z + tmpB.z) / 2);
      if (c.nitroT > 0) { fx.flame(tl.x, tl.y - 0.15, tl.z, -fwd.x * 12, 0.5, -fwd.z * 12); fx.flame(tmpB.x, tmpB.y - 0.15, tmpB.z, -fwd.x * 12, 0.5, -fwd.z * 12); }
      if (c.health < c.maxHp * 0.35) { tmpC.set(0, 1.0, v.L * 0.35); v.body.localToWorld(tmpC); fx.burst('smoke', tmpC.x, tmpC.y, tmpC.z); }
      if (c.scrape > 0.4) { const sd = c.d > 0 ? 1 : -1; wpos(c.s, c.d + sd * 1.0, tmpC, 0.4); fx.burst('spark', tmpC.x, tmpC.y, tmpC.z, 0.5); }
    }
    if (v.tag) {
      const cd = camera.position.distanceToSquared(root.position); v.tag.visible = !c.finished && !wrecked && cd > 10 * 10 && cd < 170 * 170;
      if ((v.tagT = (v.tagT || 0) + dt) > 0.4) { v.tagT = 0; v.updateTag(); }
    }
  });
}
function syncEntities(dt) {
  const race = G.race, T = G.track, sc = G.world.scene, t = G.t, seen = G.seen || (G.seen = new Set());
  seen.clear();
  for (const p of race.projs) {
    seen.add(p.id); let e = G.ent.get(p.id);
    if (!e) {
      const obj = new THREE.Group();
      if (p.kind === 'eagle') {
        const gl = new THREE.Sprite(G.res.glow(PW.eagle.col)); gl.scale.set(6.5, 6.5, 1); obj.add(gl);
        const ic = new THREE.Sprite(linMat(Object.assign(new THREE.SpriteMaterial({ map: TEX.icons.eagle.tex, transparent: true, depthWrite: false, toneMapped: false }), { userData: { hdr: 1.6 } }))); ic.scale.set(2.6, 2.6, 1); obj.add(ic);
        e = { obj, icon: ic };
      } else {
        const gl = new THREE.Sprite(G.res.glow(PW.bolt.col)); gl.scale.set(3.6, 3.6, 1); obj.add(gl);
        const cg = new THREE.CylinderGeometry(0.14, 0.14, 3.4, 6); cg.rotateX(Math.PI / 2);
        obj.add(new THREE.Mesh(cg, G.res.boltM || (G.res.boltM = linMat(glowMat('#cfeaff', 5)))));
        e = { obj };
      }
      sc.add(obj); G.ent.set(p.id, e);
    }
    T.pos(p.s, p.d, tmpA); e.obj.position.set(tmpA.x, tmpA.y + 1.1, tmpA.z);
    T.tangent(p.s, tmpB); tmpC.copy(e.obj.position).addScaledVector(tmpB, p.dir); e.obj.lookAt(tmpC);
    if (p.kind === 'eagle') { G.fx.trail(tmpA.x, tmpA.y + 1.1, tmpA.z, PW.eagle.col, 1.6, 0.45); e.icon.material.rotation = Math.sin(t * 18) * 0.25; }
    else G.fx.trail(tmpA.x, tmpA.y + 1.1, tmpA.z, PW.bolt.col, 0.9, 0.2);
  }
  for (const m of race.mines) {
    const id = m.id; seen.add(id); let e = G.ent.get(id);
    if (!e) {
      const obj = new THREE.Group();
      const dg = new THREE.CircleGeometry(1.5, 14); dg.rotateX(-Math.PI / 2);
      obj.add(new THREE.Mesh(dg, linMat(new THREE.MeshStandardMaterial({ color: 0x120c08, roughness: 0.9 }))));
      const ring = new THREE.Mesh(G.res.ring, linMat(glowMat(PW.mine.col, 3, { transparent: true, blending: THREE.AdditiveBlending, depthWrite: false })));
      ring.position.y = 0.02; obj.add(ring);
      const gl = new THREE.Sprite(G.res.glow(PW.mine.col)); gl.scale.set(2.6, 2.6, 1); gl.position.y = 0.4; obj.add(gl);
      sc.add(obj); e = { obj, ring }; G.ent.set(id, e);
    }
    T.pos(m.s, m.d, tmpA); let y = tmpA.y + 0.1; if (m.fly > 0) y += Math.sin(Math.PI * (1 - m.fly / m.fly0)) * 7;
    e.obj.position.set(tmpA.x, y, tmpA.z);
    const pulse = 1 + 0.15 * Math.sin(t * 8 + id); e.ring.scale.set(pulse, 1, pulse); e.ring.material.opacity = m.arm > 0 ? 0.3 : 0.85;
  }
  for (const d of race.domes) {
    const id = d.id; seen.add(id); let e = G.ent.get(id);
    if (!e) {
      const obj = new THREE.Group();
      const dm = new THREE.Mesh(new THREE.SphereGeometry(d.r, 20, 10, 0, Math.PI * 2, 0, Math.PI / 2), linMat(glowMat(PW.shock.col, 2, { transparent: true, opacity: 0.3, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide })));
      obj.add(dm);
      const rg = new THREE.RingGeometry(d.r - 0.4, d.r, 32); rg.rotateX(-Math.PI / 2);
      const ring = new THREE.Mesh(rg, linMat(glowMat(PW.shock.col, 3, { transparent: true, blending: THREE.AdditiveBlending, depthWrite: false })));
      ring.position.y = 0.1; obj.add(ring);
      sc.add(obj); e = { obj, dome: dm, ring }; G.ent.set(id, e);
    }
    T.pos(d.s, d.d, tmpA); e.obj.position.copy(tmpA);
    if (d.warn > 0) { e.dome.visible = false; e.ring.material.opacity = 0.4 + 0.4 * Math.sin(t * 22); }
    else { e.dome.visible = true; e.dome.material.opacity = 0.22 + 0.12 * Math.random(); e.ring.material.opacity = 0.9; if (Math.random() < 0.35) G.fx.burst('zap', tmpA.x, tmpA.y + 1, tmpA.z); }
  }
  for (const [id, e] of G.ent) if (!seen.has(id)) { sc.remove(e.obj); e.obj.traverse(o => { if (o.geometry && o.geometry !== G.res.ring) o.geometry.dispose(); }); G.ent.delete(id); }
  // pick-ups bob, transient rings
  for (const [, v] of G.picks) {
    if (!v.sp.visible) continue;
    v.pop = Math.min(1, v.pop + dt * 3); const s = 2.9 * (v.pop < 1 ? 0.3 + 0.7 * v.pop : 1);
    v.sp.scale.set(s, s, 1); v.sp.position.y = v.y + 1.6 + Math.sin(t * 3 + v.ph) * 0.25; v.sp.material.rotation = Math.sin(t * 1.7 + v.ph) * 0.15;
    v.pil.scale.set(v.pop, 0.85 + 0.15 * Math.sin(t * 4 + v.ph), v.pop);
  }
  for (let i = G.trans.length - 1; i >= 0; i--) {
    const tr = G.trans[i]; tr.t += dt; const k = tr.t / tr.dur;
    if (k >= 1) { G.world.scene.remove(tr.m); tr.m.material.dispose(); G.trans.splice(i, 1); continue; }
    const s = 1 + k * tr.max; tr.m.scale.set(s, 1, s); tr.m.material.opacity = 1 - k;
  }
}
// ---------- cameras ----------
function chaseCam(dt) {
  const c = G.player, T = G.track, sp = Math.abs(c.v);
  const back = 6.3 + sp * 0.03, h = 1.95 + sp * 0.009;
  T.pos(c.s - back, c.d * 0.82, tmpA); tmpA.y += h + c.hop * 0.5;
  T.pos(c.s, c.d, tmpB); tmpB.y += c.hop;
  const psi = T.heading(c.s) + c.yaw * 0.5; T.tangent(c.s, tmpT);
  tmpC.set(tmpB.x - Math.sin(psi) * 9, tmpB.y + 1.15 + tmpT.y * 9, tmpB.z + Math.cos(psi) * 9);
  const snap = !dt || G.snapCam || camera.position.distanceToSquared(tmpA) > 900; G.snapCam = false;
  const k = snap ? 1 : 1 - Math.exp(-dt * 8), kl = snap ? 1 : 1 - Math.exp(-dt * 12);
  camera.position.lerp(tmpA, k); G.camLook.lerp(tmpC, kl);
  if (G.shake > 0) { G.shake = Math.max(0, G.shake - dt * 2.5); const s = G.shake * 0.5; camera.position.x += (Math.random() - 0.5) * s; camera.position.y += (Math.random() - 0.5) * s; }
  camera.lookAt(G.camLook);
  const fov = 64 + clamp(sp / 60, 0, 1.3) * 12 + (c.nitroT > 0 ? 10 : 0);
  G.fov += (fov - G.fov) * (dt ? 1 - Math.exp(-dt * 4) : 1);
  if (Math.abs(camera.fov - G.fov) > 0.05) { camera.fov = G.fov; camera.updateProjectionMatrix(); updatePScale(); }
  const so = c.nitroT > 0 ? 0.9 : sp > 52 ? 0.35 : 0; if (G.speedO !== so) { G.speedO = so; UI.$('fx-speed').style.opacity = so; }
}
function orbitAround(c, ang, r, h, dt, k) {
  const T = G.track; T.pos(c.s, c.d, tmpB);
  const psi = T.heading(c.s), a = psi + ang;
  tmpA.set(tmpB.x + Math.sin(a) * r, tmpB.y + h, tmpB.z - Math.cos(a) * r);
  const kk = k == null ? 1 : k; camera.position.lerp(tmpA, kk);
  tmpC.set(tmpB.x, tmpB.y + 1, tmpB.z); G.camLook.lerp(tmpC, kk); camera.lookAt(G.camLook);
}
function introCam(dt) {
  const c = G.player, T = G.track, t = clamp((G.introT || 0) / 2.8, 0, 1), e = t * t * (3 - 2 * t);
  T.pos(c.s + lerp(26, -7.6, e), c.d * lerp(0.2, 0.82, e), tmpA); tmpA.y += lerp(2.2, 2.6, e) + Math.sin(e * Math.PI) * 7;
  camera.position.copy(tmpA);
  T.pos(c.s, c.d, tmpB); const psi = T.heading(c.s);
  tmpC.set(tmpB.x - Math.sin(psi) * 7 * e, tmpB.y + 1.0, tmpB.z + Math.cos(psi) * 7 * e);
  G.camLook.copy(tmpC); camera.lookAt(G.camLook);
}
function orbitCam(dt) { G.orbA = (G.orbA || 0) + dt * 0.35; orbitAround(G.player, G.orbA, 10, 3.6, dt, 1 - Math.exp(-dt * 3)); }
function drawMinimap() {
  const cv = UI.$('minimap'), g = cv.getContext('2d'), W = cv.width, H = cv.height, c = G.player, T = G.track, race = G.race;
  const sc = W / 620, psi = T.heading(c.s) + c.yaw * 0.3; T.pos(c.s, c.d, tmpA);
  const rot = -Math.PI / 2 - Math.atan2(Math.cos(psi), -Math.sin(psi)), cr = Math.cos(rot), sr = Math.sin(rot), ox = W / 2, oy = H * 0.62;
  g.setTransform(1, 0, 0, 1, 0, 0); g.clearRect(0, 0, W, H);
  g.save(); g.translate(ox, oy); g.rotate(rot); g.scale(sc, sc); g.translate(-tmpA.x, -tmpA.z);
  g.lineJoin = 'round'; g.strokeStyle = 'rgba(0,0,0,0.55)'; g.lineWidth = 34; g.stroke(G.minimap);
  g.strokeStyle = 'rgba(244,237,230,0.8)'; g.lineWidth = 13; g.stroke(G.minimap);
  g.restore();
  const dot = (x, z, r, col, ring) => { const dx = x - tmpA.x, dz = z - tmpA.z; const X = ox + (dx * cr - dz * sr) * sc, Y = oy + (dx * sr + dz * cr) * sc; if (X < -10 || Y < -10 || X > W + 10 || Y > H + 10) return; g.beginPath(); g.arc(X, Y, r, 0, 7); g.fillStyle = col; g.fill(); if (ring) { g.lineWidth = 3; g.strokeStyle = ring; g.stroke(); } };
  for (const d of race.domes) { T.pos(d.s, d.d, tmpB); dot(tmpB.x, tmpB.z, 6, PW.shock.col); }
  for (const m of race.mines) { T.pos(m.s, m.d, tmpB); dot(tmpB.x, tmpB.z, 4, PW.mine.col); }
  T.pos(0, 0, tmpB); dot(tmpB.x, tmpB.z, 5, '#ffffff');
  for (const o of race.cars) { if (o === c) continue; T.pos(o.s, o.d, tmpB); dot(tmpB.x, tmpB.z, 8, o.color, 'rgba(0,0,0,0.7)'); }
  g.beginPath(); g.moveTo(ox, oy - 15); g.lineTo(ox + 10, oy + 10); g.lineTo(ox, oy + 5); g.lineTo(ox - 10, oy + 10); g.closePath(); g.fillStyle = '#e41e20'; g.fill(); g.lineWidth = 3; g.strokeStyle = '#fff'; g.stroke();
}
function showResults() {
  G.state = 'results'; UI.hud(false); releaseWake(); AUD.engine(0, false, false, 0); G.speedO = 0; UI.$('fx-speed').style.opacity = 0;
  const race = G.race, P = G.player, city = G.city; race.estimate();
  const rows = race.cars.slice().sort((a, b) => a.est - b.est);
  const place = P.place;
  UI.$('res-city').textContent = `${city.name} · ${REGIONS[city.region]} · ${DIFFS[SET.diff].name}`;
  UI.$('res-place').textContent = ORD[place - 1];
  UI.$('res-msg').textContent = PLACE_MSG[place - 1];
  UI.$('res-body').innerHTML = rows.map((c, i) => `<tr class="${c === P ? 'me' : ''}"><td class="n">${i + 1}</td><td>${c === P ? 'TI' : c.name}</td><td>${c.def.name}</td><td>${fmtTime(c.est)}${c.finished ? '' : '*'}</td><td>${c.fans}</td></tr>`).join('');
  const prev = SET.best[city.id];
  const best = { place: Math.min(prev ? prev.place : 9, place), lap: Math.min(prev && prev.lap ? prev.lap : Infinity, P.bestLap) };
  UI.$('res-best').textContent = `Xhiroja jote më e mirë: ${fmtTime(P.bestLap)} · Rekordi në ${city.name}: ${fmtTime(best.lap)}${rows.some(c => !c.finished) ? ' · * kohë e parashikuar' : ''}`;
  SET.best[city.id] = best; SET.fans += P.fans; saveSettings(); UI.buildCities(); UI.updateTotals();
  UI.show('scr-res');
}
function render(dt) {
  const w = G.world, P = G.player;
  if (w.dl && w.dl.castShadow && P) { G.track.pos(P.s + 22, 0, tmpA); w.dl.target.position.copy(tmpA); w.dl.position.copy(tmpA).addScaledVector(w.sunDir, 160); }
  G.post.render(w.scene, camera, dt);
}

// ---------- main loop ----------
function loop(ts) {
  requestAnimationFrame(loop);
  const now = ts / 1000; let dt = G.last ? now - G.last : 0.016; G.last = now; dt = clamp(dt, 0.001, 0.1); G.t += dt;
  pollGamepad();
  const st = G.state;
  if (st === 'menu') { renderGarage(dt); return; }
  if (st === 'loading' || !G.race) return;
  if (st === 'paused') { render(dt); return; }
  if (st === 'race' || st === 'finish' || st === 'countdown') {
    G.fpsT += dt; G.fpsN++;
    if (G.fpsT > 2.5 && !window.__noAdapt) {
      const fps = G.fpsN / G.fpsT, target = Math.min(window.devicePixelRatio || 1, Q().pr); G.fpsT = 0; G.fpsN = 0;
      if (fps < 42 && G.pr > 0.6) { G.pr = Math.max(0.6, G.pr - 0.15); renderer.setPixelRatio(G.pr); onResize(); }
      else if (fps > 57 && G.pr < target - 0.01) { G.pr = Math.min(target, G.pr + 0.1); renderer.setPixelRatio(G.pr); onResize(); }
    }
  }
  if (st === 'intro') {
    G.introT += dt; introCam(dt);
    if (G.introT > 2.8) { G.state = 'countdown'; G.cdT = 3.2; G.cdN = 4; }
  } else if (st === 'countdown') {
    G.cdT -= dt; const n = Math.ceil(G.cdT);
    if (n !== G.cdN && n >= 1 && n <= 3) { G.cdN = n; UI.center(String(n), 0.9); AUD.play('beep'); }
    if (G.cdT <= 0) { G.race.started = true; G.state = 'race'; UI.center('Hajde!', 1.0); AUD.play('go'); G.acc = 0; }
    AUD.engine(0.12 + (SET.autoGas || IN.kb.gas ? 0.25 : 0), true, true, 0);
    chaseCam(dt);
  } else {
    if (st === 'race') readControls(G.player); else clearQueued();
    G.acc += dt; let n = 0;
    while (G.acc >= DT && n < 5) { G.race.step(DT); G.acc -= DT; n++; }
    if (n >= 5) G.acc = 0;
    processEvents();
    if (st === 'race') chaseCam(dt); else orbitCam(dt);
    const P = G.player;
    if (st === 'race' || st === 'finish') AUD.engine(Math.abs(P.v) / P.def.vmax, P.gasOn, P.wreckT <= 0, P.scrape);
    if (st === 'finish') { G.finT += dt; if (G.finT > 4.2) showResults(); }
  }
  syncEntities(dt); updateViews(dt);
  G.fx.update(dt); G.trails.update(camera, G.trailI);
  if (G.weather) G.weather.update(dt, camera, null);
  G.world.update(dt, G.t, camera);
  if (G.state === 'race' || G.state === 'finish' || G.state === 'countdown' || G.state === 'intro') {
    UI.updateHud(G.race, G.player);
    if ((G.mmN = (G.mmN || 0) + 1) % 2 === 0) drawMinimap();
  }
  render(dt);
}

// ---------- boot ----------
function boot(data) {
  if (G.booted) return; G.booted = true;
  loadSettings(); AUD.on = SET.sound; AUD.musicOn = SET.music;
  try { if (document.fonts && document.fonts.load) { document.fonts.load('900 40px "Big Shoulders Display"'); document.fonts.load('700 20px "Chakra Petch"'); } } catch (e) { }
  initTextures(); initRenderer(); initGarage(); UI.init(); initInput();
  const scr = data && data.scr; UI.show(['scr-city', 'scr-car', 'scr-help', 'scr-set'].includes(scr) ? scr : 'scr-title');
  requestAnimationFrame(loop);
  window.__cam = camera; window.__ren = renderer; window.__garageCar = () => { garageCar(); G.garage.t = G.garage.t; };
  window.__rk = { IN, G, SET, startRace, toMenu, showResults, UI, CITIES, Track, Race, AUD, togglePause, saveSettings };
}
try { if (window.claude && window.claude.hot && window.claude.hot.snapshot) window.claude.hot.snapshot(() => ({ scr: UI.cur })); } catch (e) { }
(function () {
  const hot = window.claude && window.claude.hot;
  const go = () => { try { if (hot && hot.ready) hot.ready(boot); else boot((hot && hot.data) || {}); } catch (e) { console.error(e); boot({}); } };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', go); else go();
})();
