// ---------- Points mode: free driving in an open, walled square. 2D arcade physics, no track. ----------
// World axes: x/z metres, heading h with forward = (-sin h, cos h) and right = (cos h, sin h), same convention as the race view.
// The square is a rounded rectangle (half extents AX/AZ, corner radius R) with a round statue island in the middle.
const ARENA_DEF = { AX: 120, AZ: 84, R: 26, island: 12.5 };
// power-up stations on the square (x, z), clear of the statue island
const ARENA_PADS = [[-92, -56], [0, -64], [92, -56], [-92, 56], [0, 64], [92, 56], [-60, 0], [60, 0], [-96, 0], [96, 0], [-38, -36], [38, 36], [-38, 36], [38, -36], [0, -32], [0, 32]];
const ARENA_WPTS = { eagle: 300, bolt: 90, barge: 160, mine: 200, shock: 180, cluster: 90 }; // points for landing a power-up on someone
const CAR_HALF_L = { gt: 2.27, muscle: 2.4, hatch: 2.14, sleek: 2.26, jeep: 2.41, van: 2.8 };
const ARENA_SPEED = 0.74; // top speeds are scaled down: the square is big, but not 200 km/h big

class ArenaCar {
  constructor(id, def, name, isPlayer, color) {
    this.id = id; this.def = def; this.name = name; this.isPlayer = isPlayer; this.color = color;
    this.x = 0; this.z = 0; this.h = 0; this.vx = 0; this.vz = 0; this.w = 0; this.v = 0; this.lat = 0;
    this.steer = 0; this.drift = 0; this.hop = 0; this.hopV = 0; this.yaw = 0;
    this.ctrl = { steer: 0, gas: false, brake: false, fire: false, back: false, cycle: false };
    this.maxHp = def.hp; this.health = def.hp; this.slots = [];
    this.wreckT = 0; this.spinT = 0; this.spinDir = 1; this.invulnT = 0; this.shieldT = 0; this.nitroT = 0; this.stunT = 0;
    this.scrape = 0; this.braking = false; this.gasOn = false; this.finished = false; this.place = 0; this.fans = 0;
    this.score = 0; this.combo = 1; this.comboN = 0; this.comboT = -99; this.hitsN = 0; this.wrecks = 0; this.kills = 0;
    this.lastHitBy = null; this.lastHitT = -99; this.vmaxMul = 1; this.ramT = 0; this.ai = null; this.autopilot = false; this.est = 0;
    const hl = CAR_HALF_L[def.style] || 2.3; this.cr = 1.02; this.co = hl - this.cr; // two circles along the body
  }
}

// signed distance to the wall (positive inside), and the outward normal at the closest wall point
function arenaWall(x, z, out) {
  const A = ARENA_DEF, ix = A.AX - A.R, iz = A.AZ - A.R;
  const cx = clamp(x, -ix, ix), cz = clamp(z, -iz, iz), dx = x - cx, dz = z - cz, d = Math.hypot(dx, dz);
  if (d > 1e-6) { out.nx = dx / d; out.nz = dz / d; return A.R - d; }
  // inside the core rectangle: the nearest straight wall
  const ex = A.AX - Math.abs(x), ez = A.AZ - Math.abs(z);
  if (ex < ez) { out.nx = Math.sign(x) || 1; out.nz = 0; return ex; }
  out.nx = 0; out.nz = Math.sign(z) || 1; return ez;
}

class ArenaSim {
  constructor(opt) {
    this.arena = true; this.points = true; this.mode = 'points'; this.opt = opt;
    this.diff = DIFFS[opt.diff == null ? 1 : opt.diff];
    this.rng = mulberry32(opt.seed || 1234);
    this.time = 0; this.timeLimit = opt.time || 120; this.over = false; this.started = false;
    this.events = []; this.cars = []; this.order = []; this.pairT = new Map();
    this.pickups = []; this.projs = []; this.mines = []; this.domes = []; this.laps = 1; this.nextId = 1;
    const r = this.rng, pi = opt.noPlayer ? -1 : (opt.driver | 0), rivals = rivalsOf(pi, r);
    const roster = opt.noPlayer ? rivals : [DRIVERS[pi] || DRIVERS[0], ...rivals];
    roster.forEach((d, i) => {
      const isP = !opt.noPlayer && i === 0;
      const c = new ArenaCar(i, isP ? (opt.playerDef || CARS[0]) : CARS[Math.floor(r() * (CARS.length - 1))], d.name, isP, d.col);
      // spread round the island, facing it, so the first seconds are a charge into the middle
      const a = i / roster.length * Math.PI * 2 + 0.6;
      c.x = Math.sin(a) * (ARENA_DEF.AX - 26); c.z = Math.cos(a) * (ARENA_DEF.AZ - 22); c.h = Math.atan2(c.x, -c.z);
      c.ai = { tgt: null, retargetT: 0, backT: 0, backSteer: 1, stuckT: 0, skill: 0.95 + r() * 0.1, react: 0.8 + r() * 0.5 };
      if (isP) this.player = c;
      this.cars.push(c);
    });
    if (!this.player) this.player = null;
    const wsum = PW_ARENA.reduce((a, k) => a + PW[k].w, 0);
    this.pickType = () => { let x = r() * wsum; for (const k of PW_ARENA) { x -= PW[k].w; if (x <= 0) return k; } return 'bolt'; };
    for (const [x, z] of ARENA_PADS) this.pickups.push({ id: this.nextId++, x, z, type: this.pickType(), alive: true, t: 0 });
    this.computeOrder();
  }
  emit(e) { this.events.push(e); }
  computeOrder() {
    this.order = this.cars.slice().sort((a, b) => b.score - a.score || a.id - b.id);
    this.order.forEach((c, i) => { c.place = i + 1; });
  }
  estimate() { for (const c of this.cars) c.est = this.time; }
  step(dt) {
    this.time += dt;
    if (!this.over && this.time >= this.timeLimit) { this.over = true; this.emit({ t: 'timeup' }); }
    for (const c of this.cars) {
      if (c.isPlayer) { c.vmaxMul = 1; continue; }
      c.vmaxMul = this.diff.speed * c.ai.skill;
    }
    for (const c of this.cars) if (!c.isPlayer || c.autopilot) this.aiDrive(c, dt);
    for (const c of this.cars) this.physics(c, dt);
    // two passes settle stacks of cars without visible overlap
    this.collide(true); this.collide(false);
    for (const c of this.cars) this.walls(c);
    for (const c of this.cars) {
      if (c.ctrl.cycle) { c.ctrl.cycle = false; if (c.slots.length > 1) { c.slots.push(c.slots.shift()); this.emit({ t: 'cycle', car: c }); } }
      if (c.ctrl.select) { const k = c.ctrl.select; c.ctrl.select = 0; if (k < c.slots.length) { c.slots.unshift(c.slots.splice(k, 1)[0]); this.emit({ t: 'cycle', car: c }); } }
      if (c.ctrl.fire) { c.ctrl.fire = false; this.useItem(c, false); }
      if (c.ctrl.back) { c.ctrl.back = false; this.useItem(c, true); }
    }
    this.updatePickups(dt); this.updateProjs(dt); this.updateMines(dt); this.updateDomes(dt);
    this.computeOrder();
  }
  physics(c, dt) {
    c.invulnT = Math.max(0, c.invulnT - dt); c.scrape = Math.max(0, c.scrape - dt * 3);
    c.shieldT = Math.max(0, c.shieldT - dt); c.nitroT = Math.max(0, c.nitroT - dt); c.ramT = Math.max(0, c.ramT - dt); c.stunT = Math.max(0, c.stunT - dt);
    if (c.hop > 0 || c.hopV > 0) { c.hopV -= 30 * dt; c.hop += c.hopV * dt; if (c.hop <= 0) { c.hop = 0; c.hopV = 0; } }
    if (c.wreckT > 0) {
      c.wreckT -= dt; c.vx *= Math.exp(-3 * dt); c.vz *= Math.exp(-3 * dt); c.x += c.vx * dt; c.z += c.vz * dt;
      if (c.wreckT <= 0) this.respawn(c);
      return;
    }
    const def = c.def;
    let fx = -Math.sin(c.h), fz = Math.cos(c.h), rx = Math.cos(c.h), rz = Math.sin(c.h);
    let vf = c.vx * fx + c.vz * fz, vl = c.vx * rx + c.vz * rz;
    let steerIn = c.ctrl.steer, gas = c.ctrl.gas, brake = c.ctrl.brake;
    if (!this.started) { gas = false; brake = true; steerIn = 0; }
    if (c.spinT > 0) { c.spinT -= dt; steerIn = 0; gas = false; brake = false; }
    const boost = c.ramT > 0 ? 1.45 : c.nitroT > 0 ? 1.35 : 1;
    const vmax = def.vmax * ARENA_SPEED * c.vmaxMul * boost * (c.stunT > 0 ? 0.55 : 1), acc = def.acc * 1.15 * (c.ramT > 0 ? 2.6 : c.nitroT > 0 ? 2.1 : 1);
    const drifting = brake && Math.abs(c.steer) > 0.35 && vf > 12;
    c.drift = drifting ? Math.min(1, c.drift + dt * 4) : Math.max(0, c.drift - dt * 3);
    if (gas && !(brake && !drifting)) {
      if (vf < vmax) vf = Math.min(vmax, vf + acc * (1 - 0.75 * Math.max(0, vf / vmax) ** 2) * dt * (vf < 0 ? 2.2 : 1));
    } else if (brake) {
      if (drifting) vf -= 5 * dt;
      else if (vf > 0.5) vf = Math.max(0, vf - 30 * dt);
      else if (this.started) vf = Math.max(-13, vf - 14 * dt); // hold to reverse
    } else {
      const drag = (2.2 + Math.abs(vf) * 0.03) * dt; vf = Math.abs(vf) <= drag ? 0 : vf - Math.sign(vf) * drag;
    }
    if (vf > vmax * 1.02) vf -= (vf - vmax) * 2 * dt;
    // steering: tight at parking speed, calmer flat out; reversing flips it like a real car
    const rate = c.isPlayer && !c.autopilot ? 6 : 9;
    c.steer += clamp(steerIn - c.steer, -rate * dt, rate * dt);
    const sp = Math.abs(vf), turn = clamp(sp / 4.5, 0, 1) * (2.9 - 1.2 * clamp(sp / vmax, 0, 1)) * def.grip * (1 + c.drift * 0.45);
    c.h += (c.steer * turn * (vf < -0.3 ? -1 : 1) + c.w) * dt;
    c.w *= Math.exp(-3.2 * dt);
    // grip eats sideways speed; less of it while drifting
    vl *= Math.exp(-(9.5 - 6.8 * c.drift) * def.grip * dt);
    fx = -Math.sin(c.h); fz = Math.cos(c.h); rx = Math.cos(c.h); rz = Math.sin(c.h);
    c.vx = fx * vf + rx * vl; c.vz = fz * vf + rz * vl;
    c.x += c.vx * dt; c.z += c.vz * dt;
    c.v = vf; c.lat = vl; c.braking = brake && !drifting && vf > 1; c.gasOn = gas;
  }
  // the two collision circles of a car
  circles(c, out) {
    const fx = -Math.sin(c.h), fz = Math.cos(c.h);
    out[0] = c.x + fx * c.co; out[1] = c.z + fz * c.co; out[2] = c.x - fx * c.co; out[3] = c.z - fz * c.co;
    return out;
  }
  collide(impulses) {
    const cars = this.cars, ca = this._ca || (this._ca = [0, 0, 0, 0]), cb = this._cb || (this._cb = [0, 0, 0, 0]);
    for (let i = 0; i < cars.length; i++) {
      const a = cars[i]; if (a.wreckT > 0) continue;
      for (let j = i + 1; j < cars.length; j++) {
        const b = cars[j]; if (b.wreckT > 0) continue;
        if (Math.abs(a.x - b.x) > 7 || Math.abs(a.z - b.z) > 7) continue;
        this.circles(a, ca); this.circles(b, cb);
        let best = 0, nx = 0, nz = 0, px = 0, pz = 0;
        const rr = a.cr + b.cr;
        for (let p = 0; p < 4; p += 2) for (let q = 0; q < 4; q += 2) {
          const dx = cb[q] - ca[p], dz = cb[q + 1] - ca[p + 1], d = Math.hypot(dx, dz), pen = rr - d;
          if (pen > best) { best = pen; nx = d > 1e-5 ? dx / d : 1; nz = d > 1e-5 ? dz / d : 0; px = ca[p] + nx * a.cr; pz = ca[p + 1] + nz * a.cr; }
        }
        if (best <= 0) continue;
        const ma = a.def.mass, mb = b.def.mass, tot = ma + mb;
        a.x -= nx * best * (mb / tot); a.z -= nz * best * (mb / tot); b.x += nx * best * (ma / tot); b.z += nz * best * (ma / tot);
        if (!impulses) continue;
        // closing speed along the contact normal
        const van = a.vx * nx + a.vz * nz, vbn = b.vx * nx + b.vz * nz, rv = vbn - van;
        if (rv >= 0) continue;
        const closing = -rv, e = 0.32, jimp = (1 + e) * closing / (1 / ma + 1 / mb);
        a.vx -= nx * jimp / ma; a.vz -= nz * jimp / ma; b.vx += nx * jimp / mb; b.vz += nz * jimp / mb;
        // off-centre hits spin the car round (2D cross of lever arm and impulse)
        const kick = 0.11;
        a.w += ((px - a.x) * -nz - (pz - a.z) * -nx) * jimp * kick / ma;
        b.w += ((px - b.x) * nz - (pz - b.z) * nx) * jimp * kick / mb;
        if (closing > 2) this.emit({ t: 'bump', a, b, x: px, z: pz, imp: closing });
        // who rammed whom: the car driving into the contact harder
        const att = van >= -vbn ? a : b, vic = att === a ? b : a;
        this.scoreHit(att, vic, closing, px, pz);
      }
    }
  }
  // a hit is contact at real closing speed. The rammer scores, times its combo (x1 up to x5).
  scoreHit(att, vic, closing, x, z) {
    if (this.over || !this.started || closing < 4) return;
    const key = att.id < vic.id ? att.id * 100 + vic.id : vic.id * 100 + att.id, last = this.pairT.get(key);
    if (last != null && this.time - last < 0.6) return;
    this.pairT.set(key, this.time);
    // a ram charge doubles the points, hits far harder, throws the victim away and costs the rammer nothing
    const ram = att.ramT > 0;
    const gain = this.award(att, vic, Math.round(closing * 14) * (ram ? 2 : 1));
    this.emit({ t: 'score', car: att, victim: vic, pts: gain, combo: att.combo, imp: closing, ram, x, z });
    const dmg = Math.max(0, closing - 8) * 1.9 * (ram ? 2.5 : 1) + (ram ? 12 : 0);
    if (ram) {
      const dx = vic.x - att.x, dz = vic.z - att.z, d = Math.hypot(dx, dz) || 1;
      vic.vx += dx / d * 16; vic.vz += dz / d * 16; vic.hopV = Math.max(vic.hopV, 6); vic.w += (this.rng() < 0.5 ? -1 : 1) * 4;
    }
    if (dmg > 0) { this.damage(vic, dmg); if (!ram) this.damage(att, dmg * 0.25); }
    if (closing > 16) vic.hopV = Math.max(vic.hopV, Math.min(7, closing * 0.3));
  }
  damage(c, dmg) {
    if (c.wreckT > 0 || c.invulnT > 0) return;
    c.health -= dmg;
    if (c.health <= 0) this.wreck(c);
  }
  wreck(c) {
    c.health = 0; c.wreckT = 2.4; c.wrecks++; c.comboN = 0; c.combo = 1; c.drift = 0;
    const by = c.lastHitBy && this.time - c.lastHitT < 4 ? c.lastHitBy : null;
    let pts = 0;
    if (by && by !== c && !this.over) { pts = 300 * by.combo; by.score += pts; by.kills++; }
    this.emit({ t: 'wreck', car: c, by, pts, x: c.x, z: c.z });
  }
  // back in play at the free spot furthest from everybody, facing the middle
  respawn(c) {
    const r = this.rng, A = ARENA_DEF; let bx = 0, bz = 0, bd = -1;
    for (let k = 0; k < 14; k++) {
      const x = (r() * 2 - 1) * (A.AX - 14), z = (r() * 2 - 1) * (A.AZ - 14);
      if (Math.hypot(x, z) < A.island + 12) continue;
      let md = 1e9; for (const o of this.cars) if (o !== c && o.wreckT <= 0) md = Math.min(md, Math.hypot(o.x - x, o.z - z));
      if (md > bd) { bd = md; bx = x; bz = z; }
    }
    c.x = bx; c.z = bz; c.h = Math.atan2(bx, -bz); c.vx = c.vz = c.w = 0; c.v = 0; c.steer = 0;
    c.health = c.maxHp; c.invulnT = 2.5; c.lastHitBy = null;
    this.emit({ t: 'respawn', car: c, x: c.x, z: c.z });
  }
  walls(c) {
    if (c.wreckT > 0) return;
    const A = ARENA_DEF, cc = this.circles(c, this._cw || (this._cw = [0, 0, 0, 0])), w = this._w || (this._w = { nx: 0, nz: 0 });
    for (let p = 0; p < 4; p += 2) {
      const x = cc[p], z = cc[p + 1];
      // outer wall
      const d = arenaWall(x, z, w);
      if (d < c.cr) this.bounce(c, w.nx, w.nz, c.cr - d, 'wall');
      // statue island
      const di = Math.hypot(x, z), lim = A.island + c.cr;
      if (di < lim) { const k = di > 1e-5 ? 1 / di : 0; this.bounce(c, -x * k, -z * k, lim - di, 'island'); }
    }
  }
  // push out along -n (n points into the obstacle) and reflect the speed going into it
  bounce(c, nx, nz, pen, kind) {
    c.x -= nx * pen; c.z -= nz * pen;
    const into = c.vx * nx + c.vz * nz;
    if (into <= 0) return;
    c.vx -= nx * into * 1.3; c.vz -= nz * into * 1.3;
    c.vx *= 0.94; c.vz *= 0.94;
    c.scrape = Math.max(c.scrape, Math.min(1, into / 14 + 0.25));
    if (into > 13) this.damage(c, (into - 13) * 1.2);
    if (into > 4) this.emit({ t: 'wall', car: c, imp: into, x: c.x + nx * 1.4, z: c.z + nz * 1.4 });
  }
  // points for att landing anything on vic, times att's combo (x1 up to x5, +1 every three hits within 4 s)
  award(att, vic, base) {
    if (this.time - att.comboT > 4) att.comboN = 0;
    att.comboN++; att.comboT = this.time; att.combo = Math.min(5, 1 + Math.floor(att.comboN / 3));
    const gain = base * att.combo;
    att.score += gain; att.hitsN++;
    vic.lastHitBy = att; vic.lastHitT = this.time;
    return gain;
  }
  // ---------------- power-ups: same eight as the races, re-thought for open ground ----------------
  updatePickups(dt) {
    for (const p of this.pickups) {
      if (!p.alive) { p.t -= dt; if (p.t <= 0) { p.alive = true; this.emit({ t: 'pickupBack', p }); } continue; }
      for (const c of this.cars) {
        if (c.slots.length >= 3 || c.wreckT > 0) continue;
        if (Math.hypot(c.x - p.x, c.z - p.z) < 2.9) {
          p.alive = false; p.t = 2; // back two seconds after somebody takes it
          c.slots.push({ type: p.type, ammo: PW[p.type].ammo || 1 });
          this.emit({ t: 'pickup', car: c, type: p.type, p });
          break;
        }
      }
    }
  }
  // the best target in front (or behind): close and well lined up
  aimAt(c, back, range, minDot) {
    const k = back ? -1 : 1, fx = -Math.sin(c.h) * k, fz = Math.cos(c.h) * k; let best = null, bs = -Infinity;
    for (const o of this.cars) {
      if (o === c || o.wreckT > 0) continue;
      const dx = o.x - c.x, dz = o.z - c.z, d = Math.hypot(dx, dz); if (d > range) continue;
      const dot = (dx * fx + dz * fz) / (d || 1); if (dot < (minDot == null ? 0.25 : minDot)) continue;
      const sc = dot * 2 - d / range; if (sc > bs) { bs = sc; best = o; }
    }
    return best;
  }
  useItem(c, back) {
    const it = c.slots[0];
    if (!it || c.wreckT > 0 || c.spinT > 0 || !this.started || this.over) return;
    const type = it.type, k = back ? -1 : 1, fx = -Math.sin(c.h), fz = Math.cos(c.h); let used = true;
    switch (type) {
      case 'eagle': {
        const tgt = this.aimAt(c, back, back ? 90 : 220, 0.1) || (back ? null : this.aimAt(c, false, 400, -1));
        const sp = Math.max(Math.abs(c.v) + 22, 42);
        this.projs.push({ id: this.nextId++, kind: 'eagle', owner: c, x: c.x + fx * 3.5 * k, z: c.z + fz * 3.5 * k, vx: fx * sp * k, vz: fz * sp * k, target: tgt, life: 6 });
        break;
      }
      case 'bolt': {
        const sp = Math.max(c.v, 0) * k + 80 * k;
        this.projs.push({ id: this.nextId++, kind: 'bolt', owner: c, x: c.x + fx * 3 * k, z: c.z + fz * 3 * k, vx: fx * sp, vz: fz * sp, target: null, life: 1.3 });
        it.ammo--; used = it.ammo <= 0;
        break;
      }
      case 'barge': { // shockwave: everybody close gets thrown away from you
        for (const o of this.cars) {
          if (o === c || o.wreckT > 0) continue;
          const dx = o.x - c.x, dz = o.z - c.z, d = Math.hypot(dx, dz) || 1;
          if (d < 15) { const f = 1 - d / 15, push = 12 + 14 * f; this.hit(o, c, 'barge', 12 + 12 * f, { slow: 0.9, px: dx / d * push, pz: dz / d * push }); }
        }
        this.emit({ t: 'barge', car: c, x: c.x, z: c.z });
        break;
      }
      case 'mine': {
        if (back) this.mines.push({ id: this.nextId++, owner: c, x: c.x - fx * 4, z: c.z - fz * 4, vx: 0, vz: 0, fly: 0, fly0: 0.6, life: 40, arm: 0.4, born: this.time });
        else { const sp = Math.max(c.v, 8) + 24; this.mines.push({ id: this.nextId++, owner: c, x: c.x + fx * 3, z: c.z + fz * 3, vx: fx * sp, vz: fz * sp, fly: 0.65, fly0: 0.65, life: 40, arm: 0.4, born: this.time }); }
        break;
      }
      case 'shock': { // three electric domes where the leader is heading
        const lead = this.order.find(o => o !== c && o.wreckT <= 0 && o.score >= c.score);
        if (!lead) { used = false; this.emit({ t: 'denied', car: c, why: 'first' }); break; }
        const bx = lead.x + lead.vx * 1.1, bz = lead.z + lead.vz * 1.1;
        for (let n = 0; n < 3; n++) {
          const a = this.rng() * Math.PI * 2, rr = n ? 6 + this.rng() * 5 : 0;
          let x = bx + Math.cos(a) * rr, z = bz + Math.sin(a) * rr; const w = { nx: 0, nz: 0 }, d = arenaWall(x, z, w);
          if (d < 5) { x -= w.nx * (5 - d); z -= w.nz * (5 - d); }
          this.domes.push({ id: this.nextId++, owner: c, x, z, r: 4.8, warn: 0.9, life: 7, hitSet: new Set() });
        }
        this.emit({ t: 'shock', car: c, target: lead });
        break;
      }
      case 'ram': c.ramT = 1.6; this.emit({ t: 'ram', car: c, x: c.x, z: c.z }); break;
      case 'cluster': { // five darts in a fan
        const sp = Math.max(c.v, 0) + 72;
        for (let i = -2; i <= 2; i++) {
          const a = c.h + i * 0.13, dx = -Math.sin(a), dz = Math.cos(a);
          this.projs.push({ id: this.nextId++, kind: 'bolt', wk: 'cluster', owner: c, x: c.x + dx * 3, z: c.z + dz * 3, vx: dx * sp, vz: dz * sp, target: null, life: 1.2 });
        }
        break;
      }
      case 'nitro': {
        if (back) { c.vx *= 0.4; c.vz *= 0.4; } else c.nitroT = 2.6;
        this.emit({ t: 'nitro', car: c, back });
        break;
      }
      case 'shield': c.shieldT = 8; this.emit({ t: 'shield', car: c }); break;
      case 'repair': {
        if (c.health >= c.maxHp * 0.97) { used = false; this.emit({ t: 'denied', car: c, why: 'full' }); }
        else { c.health = c.maxHp; this.emit({ t: 'repair', car: c, x: c.x, z: c.z }); }
        break;
      }
    }
    if (used || type === 'bolt') this.emit({ t: 'fire', car: c, type, back, x: c.x, z: c.z });
    if (used) c.slots.shift();
  }
  hit(o, by, kind, dmg, fx) {
    if (o.wreckT > 0) return false;
    if (o.shieldT > 0 || o.invulnT > 0) { this.emit({ t: 'blocked', car: o, by, kind, x: o.x, z: o.z }); return false; }
    if (fx.spin) { o.spinT = 1.0; o.w += (this.rng() < 0.5 ? -1 : 1) * 7; o.vx *= 0.35; o.vz *= 0.35; o.hopV = Math.max(o.hopV, 7); }
    if (fx.slow) { o.vx *= fx.slow; o.vz *= fx.slow; }
    if (fx.stun) o.stunT = Math.max(o.stunT, fx.stun);
    if (fx.hop) o.hopV = Math.max(o.hopV, fx.hop);
    if (fx.px) { o.vx += fx.px; o.vz += fx.pz; }
    const pts = by && by !== o && !this.over ? this.award(by, o, ARENA_WPTS[kind] || 100) : 0;
    this.emit({ t: 'hit', car: o, by, kind, dmg, pts, combo: by ? by.combo : 1, x: o.x, z: o.z });
    this.damage(o, dmg);
    return true;
  }
  updateProjs(dt) {
    const w = this._pw || (this._pw = { nx: 0, nz: 0 });
    for (let i = this.projs.length - 1; i >= 0; i--) {
      const p = this.projs[i]; let dead = false; p.life -= dt;
      const tg = p.target && p.target.wreckT <= 0 ? p.target : null;
      if (p.kind === 'eagle') { // homing: turns toward its target and keeps a little faster than it
        const cur = Math.atan2(p.vz, p.vx), sp = Math.hypot(p.vx, p.vz);
        const na = tg ? cur + clamp(wrapAng(Math.atan2(tg.z - p.z, tg.x - p.x) - cur), -3.4 * dt, 3.4 * dt) : cur;
        const nsp = Math.min(sp + 40 * dt, Math.max(50, tg ? Math.hypot(tg.vx, tg.vz) + 18 : 50));
        p.vx = Math.cos(na) * nsp; p.vz = Math.sin(na) * nsp;
      }
      p.x += p.vx * dt; p.z += p.vz * dt;
      for (const o of this.cars) {
        if (o === p.owner || o.wreckT > 0 || Math.hypot(o.x - p.x, o.z - p.z) > 2.5) continue;
        const sp = Math.hypot(p.vx, p.vz) || 1;
        if (p.kind === 'eagle') this.hit(o, p.owner, 'eagle', 34, { spin: true });
        else this.hit(o, p.owner, p.wk || 'bolt', p.wk ? 9 : 11, { slow: 0.86, px: p.vx / sp * 4, pz: p.vz / sp * 4 });
        this.emit({ t: 'boom', kind: p.kind, x: p.x, z: p.z, hitCar: o }); dead = true; break;
      }
      if (!dead && (arenaWall(p.x, p.z, w) < 0.4 || Math.hypot(p.x, p.z) < ARENA_DEF.island)) { this.emit({ t: 'boom', kind: p.kind, x: p.x, z: p.z }); dead = true; }
      if (!dead && p.life <= 0) { this.emit({ t: 'fizzle', kind: p.kind, x: p.x, z: p.z }); dead = true; }
      if (dead) this.projs.splice(i, 1);
    }
  }
  updateMines(dt) {
    const w = this._mw || (this._mw = { nx: 0, nz: 0 });
    for (let i = this.mines.length - 1; i >= 0; i--) {
      const m = this.mines[i];
      if (m.fly > 0) {
        m.fly -= dt; m.x += m.vx * dt; m.z += m.vz * dt;
        const d = arenaWall(m.x, m.z, w); if (d < 1.5) { m.x -= w.nx * (1.5 - d); m.z -= w.nz * (1.5 - d); m.fly = 0; }
        continue;
      }
      m.life -= dt; m.arm -= dt;
      if (m.life <= 0) { this.mines.splice(i, 1); continue; }
      if (m.arm > 0) continue;
      for (const o of this.cars) {
        if ((o === m.owner && this.time - m.born < 2.5) || o.wreckT > 0) continue;
        if (Math.hypot(o.x - m.x, o.z - m.z) < 2.3) {
          this.hit(o, m.owner, 'mine', 26, { hop: 7.5, slow: 0.5, stun: 1.0 });
          this.emit({ t: 'boom', kind: 'mine', x: m.x, z: m.z, hitCar: o });
          this.mines.splice(i, 1); break;
        }
      }
    }
    if (this.mines.length > 16) this.mines.shift();
  }
  updateDomes(dt) {
    for (let i = this.domes.length - 1; i >= 0; i--) {
      const dm = this.domes[i];
      if (dm.warn > 0) { dm.warn -= dt; continue; }
      dm.life -= dt; if (dm.life <= 0) { this.domes.splice(i, 1); continue; }
      for (const o of this.cars) {
        if (dm.hitSet.has(o.id) || o.wreckT > 0) continue;
        if (Math.hypot(o.x - dm.x, o.z - dm.z) < dm.r) { dm.hitSet.add(o.id); this.hit(o, dm.owner, 'shock', 20, { stun: 2.2, slow: 0.6 }); this.emit({ t: 'zap', dome: dm, car: o, x: o.x, z: o.z }); }
      }
    }
  }
  aiWeapons(c) {
    const it = c.slots[0]; if (!it || !this.started) return;
    const r = this.rng(), aim = this.diff.aim; let fire = false, back = false;
    switch (it.type) {
      case 'eagle': if (this.aimAt(c, false, 180, 0.3) && r < 0.8 * aim) fire = true; else if (this.aimAt(c, true, 40, 0.5) && r < 0.3) { fire = true; back = true; } break;
      case 'bolt': if (this.aimAt(c, false, 55, 0.93) && r < 0.9 * aim) fire = true; break;
      case 'barge': for (const o of this.cars) if (o !== c && o.wreckT <= 0 && Math.hypot(o.x - c.x, o.z - c.z) < 10) fire = true; break;
      case 'mine': if (this.aimAt(c, true, 30, 0.5) && r < 0.7) { fire = true; back = true; } else if (this.aimAt(c, false, 35, 0.8) && r < 0.4) fire = true; break;
      case 'shock': if (c.place > 1 && r < 0.5) fire = true; break;
      case 'nitro': { const t = c.ai.tgt; if (t && Math.hypot(t.x - c.x, t.z - c.z) > 22 && this.aimAt(c, false, 90, 0.9) === t && r < 0.8) fire = true; break; }
      case 'shield': {
        let threat = false; for (const p of this.projs) if (p.target === c || (p.owner !== c && Math.hypot(p.x - c.x, p.z - c.z) < 25)) threat = true;
        if (threat || (c.health < c.maxHp * 0.5 && r < 0.25) || r < 0.04) fire = true; break;
      }
      case 'repair': if (c.health < c.maxHp * 0.45) fire = true; break;
      case 'ram': { const t = c.ai.tgt; if (t && t === this.aimAt(c, false, 45, 0.85) && r < 0.9) fire = true; break; }
      case 'cluster': if (this.aimAt(c, false, 60, 0.75) && r < 0.85 * aim) fire = true; break;
    }
    if (fire) this.useItem(c, back);
    else if (c.slots.length >= 2 && r > 0.9) c.slots.push(c.slots.shift());
  }
  // ---------------- AI: pick a victim, lead it, ram it, back off, repeat ----------------
  aiDrive(c, dt) {
    const ai = c.ai, r = this.rng, A = ARENA_DEF;
    if (c.wreckT > 0) return;
    ai.retargetT -= dt;
    if (!ai.tgt || ai.tgt.wreckT > 0 || ai.retargetT <= 0) {
      let best = null, bs = Infinity;
      const fx = -Math.sin(c.h), fz = Math.cos(c.h);
      for (const o of this.cars) {
        if (o === c || o.wreckT > 0 || o.invulnT > 0.5) continue;
        const dx = o.x - c.x, dz = o.z - c.z, d = Math.hypot(dx, dz), front = (dx * fx + dz * fz) / (d || 1);
        // close and in front is best; the leader and the player are juicier
        const s = d * (1.6 - front * 0.6) * (0.8 + r() * 0.5) * (o === this.order[0] ? 0.85 : 1) * (o.isPlayer ? 0.9 : 1);
        if (s < bs) { bs = s; best = o; }
      }
      ai.tgt = best; ai.retargetT = (2.2 + r() * 2.8) * this.diff.react * ai.react;
    }
    if (ai.backT > 0) { ai.backT -= dt; c.ctrl.gas = false; c.ctrl.brake = true; c.ctrl.steer = ai.backSteer; return; }
    if (this.started && Math.abs(c.v) < 2.2) {
      ai.stuckT += dt;
      if (ai.stuckT > 0.7) { ai.stuckT = 0; ai.backT = 0.8 + r() * 0.4; ai.backSteer = r() < 0.5 ? -1 : 1; return; }
    } else ai.stuckT = 0;
    // aim where the target will be
    const t = ai.tgt; let px = 0, pz = 0;
    if (t) {
      const d = Math.hypot(t.x - c.x, t.z - c.z), lead = clamp(d / Math.max(10, Math.abs(c.v) + 6), 0, 1.1);
      px = t.x + t.vx * lead; pz = t.z + t.vz * lead;
    }
    // nothing in hand and a power-up close by: take it on the way
    if (c.slots.length < 2) {
      let bp = null, bd = c.slots.length ? 22 : 38;
      for (const p of this.pickups) { if (!p.alive) continue; const d = Math.hypot(p.x - c.x, p.z - c.z); if (d < bd) { bd = d; bp = p; } }
      if (bp && (!t || bd < Math.hypot(t.x - c.x, t.z - c.z) * 0.8)) { px = bp.x; pz = bp.z; }
    }
    // go round the statue island instead of into it
    const sx = px - c.x, sz = pz - c.z, L2 = sx * sx + sz * sz || 1, t0 = clamp(-(c.x * sx + c.z * sz) / L2, 0, 1);
    const qx = c.x + sx * t0, qz = c.z + sz * t0, qd = Math.hypot(qx, qz);
    if (t0 > 0.02 && t0 < 0.98 && qd < A.island + 5) {
      const k = (A.island + 10) / Math.max(qd, 0.5); px = qd > 0.5 ? qx * k : qx - sz * 0.3; pz = qd > 0.5 ? qz * k : qz + sx * 0.3;
    }
    // about to kiss the wall at speed: turn for the middle
    const w = this._aw || (this._aw = { nx: 0, nz: 0 }), ahead = 0.9;
    if (arenaWall(c.x + c.vx * ahead, c.z + c.vz * ahead, w) < 5 && Math.abs(c.v) > 10) { px = c.x - w.nx * 30; pz = c.z - w.nz * 30; }
    const want = Math.atan2(-(px - c.x), pz - c.z), dA = wrapAng(want - c.h);
    c.ctrl.steer = clamp(dA * 2.4, -1, 1);
    c.ctrl.gas = true;
    c.ctrl.brake = Math.abs(dA) > 1.9 && c.v > 12; // hard about-turn: brake into a drift
    ai.wT = (ai.wT || 0) - dt;
    if (ai.wT <= 0) { ai.wT = (0.35 + r() * 0.6) * this.diff.react * ai.react; this.aiWeapons(c); }
  }
}
