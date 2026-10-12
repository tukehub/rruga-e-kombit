// ---------- Points mode: free driving in an open, walled square. 2D arcade physics, no track. ----------
// World axes: x/z metres, heading h with forward = (-sin h, cos h) and right = (cos h, sin h), same convention as the race view.
// The square is a rounded rectangle (half extents AX/AZ, corner radius R) with a round statue island in the middle.
const ARENA_DEF = { AX: 88, AZ: 62, R: 20, island: 9.5 };
const CAR_HALF_L = { gt: 2.27, muscle: 2.4, hatch: 2.14, sleek: 2.26, jeep: 2.41, van: 2.8 };
const ARENA_SPEED = 0.68; // top speeds are scaled down: the square is big, but not 200 km/h big

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
    this.lastHitBy = null; this.lastHitT = -99; this.vmaxMul = 1; this.ai = null; this.autopilot = false; this.est = 0;
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
    this.pickups = []; this.projs = []; this.mines = []; this.domes = []; this.laps = 1;
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
    this.computeOrder();
  }
  physics(c, dt) {
    c.invulnT = Math.max(0, c.invulnT - dt); c.scrape = Math.max(0, c.scrape - dt * 3);
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
    const vmax = def.vmax * ARENA_SPEED * c.vmaxMul, acc = def.acc * 1.15;
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
    if (this.time - att.comboT > 4) att.comboN = 0;
    att.comboN++; att.comboT = this.time; att.combo = Math.min(5, 1 + Math.floor(att.comboN / 3));
    const gain = Math.round(closing * 14) * att.combo;
    att.score += gain; att.hitsN++;
    vic.lastHitBy = att; vic.lastHitT = this.time;
    this.emit({ t: 'score', car: att, victim: vic, pts: gain, combo: att.combo, imp: closing, x, z });
    const dmg = Math.max(0, closing - 8) * 1.9;
    if (dmg > 0) { this.damage(vic, dmg); this.damage(att, dmg * 0.25); }
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
  }
}
