// ---------- settings ----------
const IS_TOUCH = (() => { try { return matchMedia('(pointer: coarse)').matches || 'ontouchstart' in window; } catch (e) { return false; } })();
const QUALITY = [
  { name: 'E ulët', pr: 1.0, terrainStep: 16, density: 0.6, rows: 1, trees: 0.4, particles: 360, neon: true, beams: false, weather: 0.5, trailSeg: 14, fogMul: 0.85, msaa: 0, shadows: 0, bloom: 0.35 },
  { name: 'Mesatare', pr: 1.35, terrainStep: 12, density: 0.85, rows: 2, trees: 0.75, particles: 620, neon: true, beams: true, weather: 0.8, trailSeg: 22, fogMul: 1, msaa: 2, shadows: 1024, bloom: 0.5 },
  { name: 'E lartë', pr: 1.75, terrainStep: 10, density: 1, rows: 3, trees: 1, particles: 900, neon: true, beams: true, weather: 1, trailSeg: 28, fogMul: 1.1, msaa: 4, shadows: 2048, bloom: 0.5 },
];
const SKEY = 'kafshimAsfalti.v1';
const SET = { sound: true, steer: 'tilt', tiltSens: 1, tiltInv: false, autoGas: false, assist: true, quality: 2, touch: 'auto', diff: 1, city: 0, car: 0, paint: '#e41e20', best: {}, fans: 0, seen: {}, mode: 'race', ptsMin: 2, pbest: {}, driver: 0 };
function loadSettings() {
  let s = {}; try { s = JSON.parse(localStorage.getItem(SKEY) || '{}'); } catch (e) { }
  // first run on a weak phone starts on the lighter graphics tier
  if (s.quality == null) SET.quality = (navigator.hardwareConcurrency || 8) <= 4 || (navigator.deviceMemory || 8) <= 4 ? 1 : 2;
  Object.assign(SET, s); SET.best = SET.best || {}; SET.seen = SET.seen || {}; SET.pbest = SET.pbest || {};
  if (!(SET.city >= 0 && SET.city < CITIES.length)) SET.city = 0; if (!(SET.car >= 0 && SET.car < CARS.length)) SET.car = 0;
  if (SET.mode !== 'points') SET.mode = 'race'; if (SET.ptsMin !== 3) SET.ptsMin = 2; if (!(SET.driver >= 0 && SET.driver < DRIVERS.length)) SET.driver = 0;
}
function saveSettings() { try { localStorage.setItem(SKEY, JSON.stringify(SET)); } catch (e) { } }
const Q = () => QUALITY[clamp(SET.quality | 0, 0, 2)];

// ---------- input ----------
const IN = { kb: {}, steerT: 0, brakeT: false, gasT: false, fireQ: false, backQ: false, cycleQ: false, gp: { steer: 0, gas: false, brake: false }, gpPrev: {}, usedTouch: false };
const KEYMAP = { ArrowLeft: 'left', KeyA: 'left', ArrowRight: 'right', KeyD: 'right', ArrowUp: 'gas', KeyW: 'gas', ArrowDown: 'brake', KeyS: 'brake' };
function initInput() {
  addEventListener('keydown', (e) => {
    if (G.state === 'race' || G.state === 'countdown' || G.state === 'finish') {
      if (KEYMAP[e.code] || e.code === 'Space' || e.code === 'Tab') e.preventDefault();
    }
    if (e.repeat) { if (KEYMAP[e.code]) IN.kb[KEYMAP[e.code]] = true; return; }
    if (KEYMAP[e.code]) IN.kb[KEYMAP[e.code]] = true;
    if (e.code === 'Space' || e.code === 'KeyJ') IN.fireQ = true;
    if (e.code === 'ShiftLeft' || e.code === 'ShiftRight' || e.code === 'KeyX' || e.code === 'KeyK') IN.backQ = true;
    if (e.code === 'KeyQ' || e.code === 'KeyE' || e.code === 'Tab') IN.cycleQ = true;
    if (e.code === 'Escape' || e.code === 'KeyP') togglePause();
  });
  addEventListener('keyup', (e) => { if (KEYMAP[e.code]) IN.kb[KEYMAP[e.code]] = false; });
  addEventListener('blur', () => { IN.kb = {}; });
  const pad = document.getElementById('t-steer'), knob = document.getElementById('t-knob');
  const steerAt = (e) => { const r = pad.getBoundingClientRect(); const x = (e.clientX - r.left) / r.width - 0.5; let v = clamp(x / 0.36, -1, 1); if (Math.abs(v) < 0.1) v = 0; IN.steerT = v; knob.style.transform = `translateX(${v * r.width * 0.36}px)`; };
  const ptrs = new Set();
  pad.addEventListener('pointerdown', (e) => { e.preventDefault(); ptrs.add(e.pointerId); try { pad.setPointerCapture(e.pointerId); } catch (_) { } steerAt(e); markTouch(e); });
  pad.addEventListener('pointermove', (e) => { if (ptrs.has(e.pointerId)) steerAt(e); });
  const endSteer = (e) => { ptrs.delete(e.pointerId); if (!ptrs.size) { IN.steerT = 0; knob.style.transform = ''; } };
  pad.addEventListener('pointerup', endSteer); pad.addEventListener('pointercancel', endSteer);
  const hold = (id, key) => {
    const b = document.getElementById(id);
    const on = (e) => { e.preventDefault(); IN[key] = true; b.classList.add('on'); markTouch(e); };
    const off = () => { IN[key] = false; b.classList.remove('on'); };
    b.addEventListener('pointerdown', on); b.addEventListener('pointerup', off); b.addEventListener('pointercancel', off); b.addEventListener('pointerleave', off);
  };
  hold('t-brake', 'brakeT'); hold('t-gas', 'gasT');
  const zone = (id, key) => {
    const el = document.getElementById(id), ids = new Set();
    const on = (e) => { e.preventDefault(); ids.add(e.pointerId); try { el.setPointerCapture(e.pointerId); } catch (_) { } IN[key] = true; el.classList.add('on'); markTouch(e); };
    const off = (e) => { ids.delete(e.pointerId); if (!ids.size) { IN[key] = false; el.classList.remove('on'); } };
    el.addEventListener('pointerdown', on); el.addEventListener('pointerup', off); el.addEventListener('pointercancel', off); el.addEventListener('lostpointercapture', off);
  };
  zone('z-brake', 'brakeT'); zone('z-gas', 'gasT');
  initTilt();
  const tap = (id, key) => { const b = document.getElementById(id); b.addEventListener('pointerdown', (e) => { e.preventDefault(); IN[key] = true; b.classList.add('on'); setTimeout(() => b.classList.remove('on'), 120); try { navigator.vibrate && navigator.vibrate(12); } catch (_) { } markTouch(e); }); };
  tap('t-fire', 'fireQ'); tap('t-back', 'backQ');
  document.getElementById('h-slots').addEventListener('pointerdown', (e) => { e.preventDefault(); IN.cycleQ = true; });
  document.getElementById('b-pause').addEventListener('click', () => togglePause());
  addEventListener('touchstart', () => markTouch(), { passive: true });
  document.addEventListener('gesturestart', (e) => e.preventDefault());
}
function markTouch(e) { if (e && e.pointerType && e.pointerType !== 'touch') return; if (!IN.usedTouch) { IN.usedTouch = true; UI.syncTouch(); } }
function pollGamepad() {
  let pads; try { pads = navigator.getGamepads ? navigator.getGamepads() : null; } catch (e) { pads = null; }
  const gp = pads && Array.from(pads).find(p => p && p.connected);
  if (!gp) { IN.gp.steer = 0; IN.gp.gas = false; IN.gp.brake = false; return; }
  const b = (i) => !!(gp.buttons[i] && gp.buttons[i].pressed), ax = gp.axes[0] || 0;
  IN.gp.steer = Math.abs(ax) > 0.15 ? ax : (b(14) ? -1 : b(15) ? 1 : 0);
  IN.gp.gas = b(7) || b(0); IN.gp.brake = b(6) || b(1);
  const edge = (i, k) => { const p = b(i); if (p && !IN.gpPrev[i]) IN[k] = true; IN.gpPrev[i] = p; };
  edge(2, 'fireQ'); edge(5, 'fireQ'); edge(3, 'backQ'); edge(4, 'cycleQ');
  const st = b(9); if (st && !IN.gpPrev[9]) togglePause(); IN.gpPrev[9] = st;
}
// ---------- tilt steering (phone held like a wheel) ----------
const TILT = { roll: 0, steer: 0, ok: false, t: 0 };
function initTilt() {
  addEventListener('devicemotion', (e) => {
    const g = e.accelerationIncludingGravity; if (!g || g.x == null || g.y == null) return;
    let ang = 0;
    try { ang = screen.orientation && screen.orientation.angle != null ? screen.orientation.angle : (window.orientation || 0); } catch (_) { ang = window.orientation || 0; }
    ang = ((ang % 360) + 360) % 360;
    // component of gravity along the screen's horizontal axis -> roll angle, independent of how far the phone leans back
    const lat = ang === 90 ? g.y : ang === 270 ? -g.y : ang === 180 ? g.x : -g.x;
    const mag = Math.hypot(g.x, g.y, g.z || 0) || 9.81;
    TILT.roll = Math.asin(clamp(lat / mag, -1, 1)) * (SET.tiltInv ? -1 : 1);
    TILT.ok = true;
  });
}
function tiltActive() { return SET.steer === 'tilt' && !UI.$('touch').hidden; }
function tiltSteer() {
  const now = performance.now(), dt = Math.min(0.1, (now - (TILT.t || now)) / 1000); TILT.t = now;
  const full = [32, 23, 15][SET.tiltSens | 0] * Math.PI / 180, dead = 2.2 * Math.PI / 180, r = TILT.roll;
  const target = Math.abs(r) < dead ? 0 : clamp((r - Math.sign(r) * dead) / (full - dead), -1, 1);
  TILT.steer += (target - TILT.steer) * Math.min(1, dt * 14);
  return TILT.steer;
}
function readControls(car) {
  const kbS = (IN.kb.right ? 1 : 0) - (IN.kb.left ? 1 : 0);
  car.ctrl.steer = kbS || (tiltActive() ? tiltSteer() : IN.steerT) || IN.gp.steer;
  car.ctrl.brake = !!(IN.kb.brake || IN.brakeT || IN.gp.brake);
  car.ctrl.gas = SET.autoGas ? true : !!(IN.kb.gas || IN.gasT || IN.gp.gas);
  if (IN.fireQ) car.ctrl.fire = true; if (IN.backQ) car.ctrl.back = true; if (IN.cycleQ) car.ctrl.cycle = true;
  IN.fireQ = IN.backQ = IN.cycleQ = false;
}
function clearQueued() { IN.fireQ = IN.backQ = IN.cycleQ = false; }

// ---------- UI ----------
const UI = {
  cur: null, feedN: 0,
  $(id) { return document.getElementById(id); },
  init() {
    const $ = (id) => this.$(id);
    // city grid + difficulty
    const seg = $('diffseg');
    DIFFS.forEach((d) => { const b = document.createElement('button'); b.textContent = d.name; b.setAttribute('aria-pressed', String(SET.diff === d.id)); b.onclick = () => { SET.diff = d.id; saveSettings(); [...seg.children].forEach((x, i) => x.setAttribute('aria-pressed', String(i === d.id))); AUD.play('ui'); }; seg.appendChild(b); });
    this.buildCities();
    // mode: a normal race, or points in the roundabout for 2 or 3 minutes
    const MODES = [{ mode: 'race', label: 'Garë' }, { mode: 'points', min: 2, label: 'Pikë · 2 min' }, { mode: 'points', min: 3, label: 'Pikë · 3 min' }];
    const ms = $('modeseg');
    MODES.forEach((m) => { const b = document.createElement('button'); b.textContent = m.label; b.onclick = () => { SET.mode = m.mode; if (m.min) SET.ptsMin = m.min; saveSettings(); this.paintMode(); AUD.play('ui'); }; ms.appendChild(b); });
    this.paintMode = () => {
      const pts = SET.mode === 'points';
      [...ms.children].forEach((b, i) => b.setAttribute('aria-pressed', String(MODES[i].mode === SET.mode && (!MODES[i].min || MODES[i].min === SET.ptsMin))));
      $('citygrid').hidden = pts; $('arena-info').hidden = !pts;
      if (pts) $('arena-info').innerHTML = `<div class="eyebrow">Pikë · ${SET.ptsMin} minuta</div><div class="nm">${ARENA.name}</div><p>${ARENA.blurb}</p>`
        + `<div class="rules"><div><b>Godit</b>Sa më shpejt përplasesh, aq më shumë pikë.</div><div><b>×5</b>Goditjet radhazi shumëzojnë pikët.</div><div><b>KO +300</b>Kush e bën copë një makinë merr bonus.</div></div>`;
    };
    // cars + paints
    const cl = $('carlist');
    const norm = (v, a, b) => clamp((v - a) / (b - a), 0.08, 1);
    CARS.forEach((c, i) => {
      const b = document.createElement('button'); b.className = 'carcard'; b.setAttribute('aria-pressed', String(SET.car === i));
      b.innerHTML = `<div class="nm">${c.name}</div><div class="muted" style="font:600 11px/1 var(--f-ui);letter-spacing:.12em;align-self:center">${Math.round(c.vmax * 3.6)} KM/H</div><div class="ds">${c.desc}</div>
        <div class="stats"><span>SHPEJTËSIA</span><i><b style="width:${norm(c.vmax, 48, 63) * 100}%"></b></i><span>NXITIMI</span><i><b style="width:${norm(c.acc, 12, 19.5) * 100}%"></b></i><span>TIMONI</span><i><b style="width:${norm(c.grip, 0.82, 1.18) * 100}%"></b></i><span>BLINDA</span><i><b style="width:${norm(c.hp, 70, 180) * 100}%"></b></i></div>`;
      b.onclick = () => { SET.car = i; saveSettings(); [...cl.children].forEach((x, j) => x.setAttribute('aria-pressed', String(i === j))); AUD.play('ui'); garageCar(); };
      cl.appendChild(b);
    });
    // drivers: you are one of the five; the other four are your rivals. Each has its own colour on track.
    const dl = $('drivers');
    const paintDrv = () => { [...dl.children].forEach((x, j) => x.setAttribute('aria-pressed', String(j === SET.driver))); $('drv-tag').textContent = DRIVERS[SET.driver].tag; };
    DRIVERS.forEach((d, i) => {
      const b = document.createElement('button'); b.className = 'drv'; b.style.setProperty('--c', d.col); b.setAttribute('aria-label', 'Shoferi ' + d.name);
      b.innerHTML = `<i>${d.name[0]}</i><span>${d.name}</span>`;
      b.onclick = () => { SET.driver = i; saveSettings(); paintDrv(); AUD.play('ui'); garageCar(); };
      dl.appendChild(b);
    });
    paintDrv();
    // help legend
    const lg = $('legend');
    PW_KEYS.forEach((k) => { const d = document.createElement('div'); d.innerHTML = `<img alt="" src="${TEX.icons[k].url}"><b style="color:${PW[k].col}">${PW[k].name}</b><span>${PW[k].desc}</span>`; lg.appendChild(d); });
    $('help-keys').innerHTML = `<b>Me telefon:</b> anoje telefonin majtas-djathtas për të kthyer · mbaj gishtin në gjysmën e <kbd>djathtë</kbd> për gaz dhe në të <kbd>majtën</kbd> për frena (frena + kthesë = drift) · <kbd>GJUAJ</kbd> në mes përdor fuqinë · <kbd>PRAPA</kbd> e gjuan pas · prek fuqitë e vogla për t’i ndërruar. Në Cilësimet mund të zgjedhësh timonin me prekje.<br>
      <b>Me tastierë:</b> <kbd>←</kbd><kbd>→</kbd> ose <kbd>A</kbd><kbd>D</kbd> timoni · <kbd>↑</kbd>/<kbd>W</kbd> gazi · <kbd>↓</kbd>/<kbd>S</kbd> frena dhe drift · <kbd>Hapësirë</kbd> gjuaj · <kbd>Shift</kbd> ose <kbd>X</kbd> gjuaj prapa · <kbd>Q</kbd>/<kbd>E</kbd> ndërro fuqinë · <kbd>P</kbd> pauzë.<br>
      <b>Me levë:</b> leva e majtë timoni · RT gazi · LT frena · X gjuaj · Y gjuaj prapa · LB ndërro.`;
    this.buildSettings();
    // buttons
    $('b-play').onclick = () => { AUD.init(); AUD.play('ui'); tryFullscreen(); this.show('scr-city'); };
    $('b-help').onclick = () => { AUD.init(); this.back = 'scr-title'; this.show('scr-help'); };
    $('b-set').onclick = () => { AUD.init(); this.back = 'scr-title'; this.show('scr-set'); };
    $('b-help2').onclick = () => { this.back = 'scr-pause'; this.show('scr-help'); };
    $('b-set2').onclick = () => { this.back = 'scr-pause'; this.show('scr-set'); };
    $('b-help-done').onclick = () => { AUD.play('ui'); this.show(this.back || 'scr-title'); };
    $('b-set-done').onclick = () => { AUD.play('ui'); this.show(this.back || 'scr-title'); };
    $('b-city-back').onclick = () => { AUD.play('ui'); this.show('scr-title'); };
    $('b-city-next').onclick = () => { AUD.play('ui'); this.show('scr-car'); garageCar(); };
    $('b-car-back').onclick = () => { AUD.play('ui'); this.show('scr-city'); };
    $('b-start').onclick = () => { AUD.init(); AUD.play('go'); startRace(); };
    $('b-resume').onclick = () => togglePause();
    $('b-restart').onclick = () => { startRace(); };
    $('b-quit').onclick = () => { toMenu(); };
    $('b-again').onclick = () => { startRace(); };
    $('b-nextcity').onclick = () => { SET.city = (SET.city + 1) % CITIES.length; saveSettings(); this.buildCities(); startRace(); };
    $('b-menu').onclick = () => { toMenu(); };
    this.slots = [...$('h-slots').children]; this.slotState = '';
    this.syncTouch(); this.updateTotals(); this.paintMode();
  },
  buildCities() {
    const grid = this.$('citygrid'); grid.innerHTML = '';
    CITIES.forEach((c, i) => {
      const b = document.createElement('button'); b.className = 'card'; b.setAttribute('aria-pressed', String(SET.city === i));
      const env = ENV[c.env], best = SET.best[c.id];
      const medal = best ? ['#f2c230', '#c9ccd2', '#c47a3a'][best.place - 1] : null;
      b.innerHTML = `${medal ? `<i class="medal" style="background:${medal}" title="Vendi më i mirë: ${best.place}"></i>` : ''}<canvas width="380" height="172"></canvas><div class="nm">${c.name}</div>
        <div class="meta"><span>${REGIONS[c.region]}</span><span>${env.icon}︎ ${env.label}</span><span>${c.laps} xhiro · ${(trackLen(c) / 1000).toFixed(1)} km</span></div><div class="blurb">${c.blurb}</div>`;
      b.onclick = () => { SET.city = i; saveSettings(); [...grid.children].forEach((x, j) => x.setAttribute('aria-pressed', String(i === j))); AUD.play('ui'); };
      b.ondblclick = () => { SET.city = i; this.show('scr-car'); garageCar(); };
      grid.appendChild(b);
      drawTrackThumb(b.querySelector('canvas'), c);
    });
  },
  buildSettings() {
    const list = this.$('setlist'); list.innerHTML = '';
    const tog = (key, label, note, after) => {
      const row = document.createElement('div'); row.className = 'setrow glass';
      row.innerHTML = `<label for="set-${key}">${label}<small>${note}</small></label><div class="seg"><button id="set-${key}" aria-pressed="${SET[key]}">${SET[key] ? 'Po' : 'Jo'}</button></div>`;
      const b = row.querySelector('button'); b.onclick = () => { SET[key] = !SET[key]; b.textContent = SET[key] ? 'Po' : 'Jo'; b.setAttribute('aria-pressed', String(SET[key])); saveSettings(); after && after(); AUD.play('ui'); };
      list.appendChild(row);
    };
    const choice = (key, label, note, opts, after) => {
      const row = document.createElement('div'); row.className = 'setrow glass';
      row.innerHTML = `<label>${label}<small>${note}</small></label><div class="seg"></div>`;
      const sg = row.querySelector('.seg');
      opts.forEach(([v, t]) => { const b = document.createElement('button'); b.textContent = t; b.setAttribute('aria-pressed', String(SET[key] === v)); b.onclick = () => { SET[key] = v; [...sg.children].forEach((x) => x.setAttribute('aria-pressed', String(x === b))); saveSettings(); after && after(); AUD.play('ui'); }; sg.appendChild(b); });
      list.appendChild(row);
    };
    tog('sound', 'Zëri', 'Motori, goditjet dhe Shqiponja.', () => AUD.setOn(SET.sound));
    choice('steer', 'Timoni', 'Anim: anoje telefonin si timon. Prekje: rrëshqit gishtin majtas-djathtas.', [['tilt', 'Anim'], ['pad', 'Prekje']], () => this.syncTouch());
    choice('tiltSens', 'Ndjeshmëria e animit', 'Sa shumë duhet ta anosh telefonin për kthesë të plotë.', [[0, 'E butë'], [1, 'Normale'], [2, 'E fortë']]);
    tog('tiltInv', 'Animi i kundërt', 'Ndize nëse makina kthen në anën e gabuar.');
    tog('autoGas', 'Gaz automatik', 'Makina e shtyp gazin vetë. Ti drejton dhe gjuan.');
    tog('assist', 'Ndihmë në timon', 'Makina drejtohet pak vetë pas kthesës.');
    choice('quality', 'Grafika', 'E larta për telefona të rinj. Hije dhe dritat ndryshojnë në garën tjetër.', QUALITY.map((q, i) => [i, q.name]), () => applyQuality());
    choice('touch', 'Butonat në ekran', 'Auto i shfaq vetëm në ekran me prekje.', [['auto', 'Auto'], ['on', 'Po'], ['off', 'Jo']], () => this.syncTouch());
  },
  syncTouch() {
    const show = SET.touch === 'on' || (SET.touch === 'auto' && (IS_TOUCH || IN.usedTouch));
    this.$('touch').hidden = !show; this.$('t-gas').hidden = !show || SET.autoGas;
    this.$('app').classList.toggle('tilt', show && SET.steer === 'tilt');
    this.$('rotate').classList.toggle('can', show);
  },
  updateTotals() {
    const wins = Object.values(SET.best).filter(b => b.place === 1).length;
    this.$('t-total').textContent = SET.fans > 0 ? `Tifozë gjithsej: ${SET.fans.toLocaleString('sq-AL')} · Fitore: ${wins} nga ${CITIES.length} qytete` : 'Nisu nga Tirana. Ose nga Prizreni. Shqiponja s’pyet.';
  },
  show(id) { for (const s of document.querySelectorAll('.scr')) s.hidden = s.id !== id; this.cur = id; if (id) { const s = this.$(id); s.scrollTop = 0; } },
  hud(on) { this.$('hud').hidden = !on; if (on) this.syncTouch(); },
  feed(text, col, ttl) {
    const f = this.$('h-feed'), d = document.createElement('div'); d.textContent = text; if (col) d.style.setProperty('--c', col);
    f.appendChild(d); while (f.children.length > 4) f.removeChild(f.firstChild);
    setTimeout(() => d.remove(), (ttl || 2.6) * 1000);
  },
  center(html, dur) {
    const c = this.$('h-center'); c.innerHTML = html; c.classList.add('on'); clearTimeout(this.ct);
    if (dur) this.ct = setTimeout(() => c.classList.remove('on'), dur * 1000);
  },
  centerOff() { this.$('h-center').classList.remove('on'); },
  flash(col, a) { const f = this.$('fx-flash'); f.style.setProperty('--fc', col); f.style.transition = 'none'; f.style.opacity = a || 0.8; void f.offsetWidth; f.style.transition = 'opacity .45s'; f.style.opacity = 0; },
  last: {},
  set(id, v, html) { if (this.last[id] === v) return; this.last[id] = v; const e = this.$(id); if (html) e.innerHTML = v; else e.textContent = v; },
  // speed fills the outer 270° arc, health the inner one
  gauge(p) {
    const sp = Math.round(Math.abs(p.v) * 3.6), vf = clamp(Math.abs(p.v) / (p.def.vmax * (G.arena ? ARENA_SPEED : 1) * 1.05), 0, 1);
    this.set('h-speed', `${sp}<small>KM/H</small>`, true);
    const a = Math.round(vf * 245); if (this.last.arc !== a) { this.last.arc = a; this.$('h-arc').setAttribute('stroke-dasharray', `${a} 400`); }
    const hp = clamp(p.health / p.maxHp, 0, 1), hk = Math.round(hp * 50);
    if (this.last.hp !== hk) {
      this.last.hp = hk; const e = this.$('h-hp');
      e.setAttribute('stroke-dasharray', `${Math.round(hp * 202)} 400`); e.setAttribute('stroke', hp > 0.5 ? '#2bff88' : hp > 0.25 ? '#ffc21a' : '#ff3b4e');
    }
    if (this.last.me !== p.name) { this.last.me = p.name; const m = this.$('h-me'); m.style.setProperty('--c', p.color); m.querySelector('span').textContent = p.name; }
  },
  pop(text, combo) {
    const e = this.$('h-pop'); e.innerHTML = `<span class="grad">${text}</span>${combo > 1 ? `<em>×${combo}</em>` : ''}`;
    e.classList.remove('go'); void e.offsetWidth; e.classList.add('go');
  },
  updateHud(race, p) {
    this.gauge(p);
    if (race.points) {
      // points mode: score up front, combo and rank on the lap line, time left on the clock, hits in the fans slot
      this.set('h-pos', `${p.score}<small>PIKË</small>`, true);
      this.set('h-lap', `KOMBO ×${p.combo} · ${p.place}/${race.cars.length}`);
      const left = Math.max(0, race.timeLimit - race.time), m = Math.floor(left / 60), s = Math.floor(left % 60);
      this.set('h-time', `${m}:${String(s).padStart(2, '0')}`);
      this.set('h-fans', `${p.hitsN}<small>GODITJE</small>`, true);
      return;
    }
    this.set('h-pos', `${p.place}<small>/${race.cars.length}</small>`, true);
    const lap = clamp(p.lap + 1, 1, race.laps);
    this.set('h-lap', p.finished ? 'MBËRRITE' : `XHIRO ${lap}/${race.laps}`);
    this.set('h-time', fmtTime(p.finished ? p.finishTime : race.time));
    this.set('h-fans', `${p.fans}<small>TIFOZË</small>`, true);
    const st = p.slots.map(s => s.type + s.ammo).join(',');
    if (st !== this.slotState) {
      this.slotState = st;
      this.slots.forEach((el, i) => { const s = p.slots[i]; el.innerHTML = s ? `<img alt="" src="${TEX.icons[s.type].url}">${s.type === 'bolt' ? `<em>${s.ammo}</em>` : ''}` : ''; });
      const s0 = p.slots[0]; this.$('h-slotname').textContent = s0 ? PW[s0.type].name.toUpperCase() : '';
      const fi = this.$('t-fire').querySelector('img'); if (s0) { fi.src = TEX.icons[s0.type].url; fi.style.visibility = ''; } else fi.style.visibility = 'hidden';
    }
  },
};
function trackLen(c) {
  if (c._len) return c._len; const sc = c.scale || 1;
  const cv = new THREE.CatmullRomCurve3(c.pts.map(p => new THREE.Vector3(p[0] * sc, 0, p[1] * sc)), true, 'centripetal');
  c._pts = cv.getSpacedPoints(160); c._len = cv.getLength(); return c._len;
}
function drawTrackThumb(cv, c) {
  trackLen(c); const g = cv.getContext('2d'), P = c._pts, W = cv.width, H = cv.height;
  let a = 1e9, b = -1e9, d = 1e9, e = -1e9; for (const p of P) { a = Math.min(a, p.x); b = Math.max(b, p.x); d = Math.min(d, p.z); e = Math.max(e, p.z); }
  const sc = Math.min((W - 30) / (b - a), (H - 30) / (e - d)), ox = (W - (b - a) * sc) / 2, oy = (H - (e - d) * sc) / 2;
  const X = (p) => ox + (p.x - a) * sc, Y = (p) => oy + (p.z - d) * sc;
  g.lineJoin = 'round'; g.lineCap = 'round';
  const path = () => { g.beginPath(); P.forEach((p, i) => (i ? g.lineTo(X(p), Y(p)) : g.moveTo(X(p), Y(p)))); g.closePath(); };
  g.strokeStyle = 'rgba(0,0,0,0.6)'; g.lineWidth = 10; path(); g.stroke();
  g.strokeStyle = c.neon; g.shadowColor = c.neon; g.shadowBlur = 10; g.lineWidth = 4; path(); g.stroke(); g.shadowBlur = 0;
  g.fillStyle = '#fff'; g.beginPath(); g.arc(X(P[0]), Y(P[0]), 6, 0, 7); g.fill();
}
function drawLogo(cv) { const g = cv.getContext('2d'); g.fillStyle = '#e41e20'; g.fillRect(0, 0, 200, 200); drawEagle(g, 100, 104, 172, '#0d0a10'); }
function tryFullscreen() {
  if (!IS_TOUCH) return;
  try { const el = document.documentElement; const p = el.requestFullscreen ? el.requestFullscreen({ navigationUI: 'hide' }) : null; if (p && p.then) p.then(() => { try { screen.orientation && screen.orientation.lock && screen.orientation.lock('landscape').catch(() => { }); } catch (e) { } }).catch(() => { }); } catch (e) { }
}
