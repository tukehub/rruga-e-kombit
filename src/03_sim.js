// ---------- Race simulation (pure logic, no rendering) ----------
const FANS = { eagle: 100, bolt: 35, barge: 50, mine: 60, shock: 70, wreck: 150, place: 15 };
const BOT_ASSIST = 1.4;

class Car {
  constructor(id, def, name, isPlayer, color) {
    this.id = id; this.def = def; this.name = name; this.isPlayer = isPlayer; this.color = color;
    this.progress = 0; this.s = 0; this.d = 0; this.v = 0; this.yaw = 0; this.latV = 0; this.steer = 0;
    this.ctrl = { steer: 0, gas: false, brake: false, fire: false, back: false, cycle: false };
    this.maxHp = def.hp; this.health = def.hp; this.slots = [];
    this.wreckT = 0; this.spinT = 0; this.spinDir = 1; this.hop = 0; this.hopV = 0;
    this.stunT = 0; this.nitroT = 0; this.shieldT = 0; this.invulnT = 0; this.hbrakeT = 0;
    this.finished = false; this.finishTime = 0; this.place = 0; this.lap = -1; this.lapStart = 0; this.bestLap = Infinity; this.lapTimes = [];
    this.fans = 0; this.drift = 0; this.driftT = 0; this.scrape = 0; this.wrecks = 0; this.hits = 0; this.vmaxMul = 1;
    this.ai = null; this.braking = false; this.gasOn = false; this.est = 0;
  }
}

class Race {
  constructor(track, opt) {
    this.track = track; this.L = track.L; this.hw = track.halfW; this.opt = opt;
    this.laps = opt.laps || track.city.laps || 3;
    this.diff = DIFFS[opt.diff == null ? 1 : opt.diff];
    this.rng = mulberry32(opt.seed || 1234);
    this.wet = !!opt.wet;
    this.assist = opt.assist === false ? 0.9 : 1.6;
    this.time = 0; this.events = []; this.nextId = 1;
    this.cars = []; this.pickups = []; this.projs = []; this.mines = []; this.domes = [];
    this.order = []; this.started = false;
    const r = this.rng;
    const pi = opt.noPlayer ? -1 : (opt.driver | 0), rivals = rivalsOf(pi, r);
    const n = opt.noPlayer ? rivals.length : rivals.length + 1, pslot = opt.playerSlot == null ? n - 2 : opt.playerSlot;
    let bi = 0;
    for (let i = 0; i < n; i++) {
      const row = Math.floor(i / 2), col = i % 2;
      let c;
      if (i === pslot && !opt.noPlayer) {
        const d = DRIVERS[pi] || DRIVERS[0];
        c = new Car(i, opt.playerDef || CARS[0], d.name, true, d.col);
        this.player = c;
      } else {
        const d = rivals[bi++];
        c = new Car(i, CARS[Math.floor(r() * (CARS.length - 1))], d.name, false, d.col);
      }
      c.progress = -9 - row * 9 - col * 3.5; c.s = this.mod(c.progress); c.d = col ? 4 : -4;
      c.ai = { t: 1 + r(), planT: 0, vT: 0, dT: c.d, laneBias: (r() - 0.5) * 4, lineAmt: 0.6 + r() * 0.35, skill: 0.975 + r() * 0.05, react: 0.8 + r() * 0.5 };
      this.cars.push(c);
    }
    if (!this.player) this.player = null;
    // pick-up stations
    const nSt = clamp(Math.round(this.L / 300), 5, 10);
    const wsum = PW_RACE.reduce((a, k) => a + PW[k].w, 0);
    const pickType = () => { let x = r() * wsum; for (const k of PW_RACE) { x -= PW[k].w; if (x <= 0) return k; } return 'nitro'; };
    for (let k = 0; k < nSt; k++) {
      const s = (k + 0.55) * this.L / nSt + (r() - 0.5) * 30;
      const lanes = [-6.5, 0, 6.5];
      for (let j = 0; j < 3; j++) this.pickups.push({ id: this.nextId++, s: this.mod(s), d: lanes[j], type: pickType(), alive: true, t: 0 });
    }
    this.computeOrder();
  }
  mod(p) { const L = this.L; p = p % L; return p < 0 ? p + L : p; }
  emit(e) { this.events.push(e); }
  computeOrder() {
    this.order = this.cars.slice().sort((a, b) => {
      if (a.finished && b.finished) return a.finishTime - b.finishTime;
      if (a.finished) return -1; if (b.finished) return 1;
      return b.progress - a.progress;
    });
    for (let i = 0; i < this.order.length; i++) {
      const c = this.order[i], np = i + 1;
      if (this.started && c.place && np < c.place && !c.finished) { c.fans += FANS.place * (c.place - np); }
      c.place = np;
    }
  }
  carAhead(c, range) {
    let best = null, bd = Infinity;
    for (const o of this.cars) {
      if (o === c || o.finished) continue;
      const g = o.progress - c.progress; if (g > 0 && g < range && g < bd) { bd = g; best = o; }
    }
    return best;
  }
  carBehind(c, range) {
    let best = null, bd = Infinity;
    for (const o of this.cars) {
      if (o === c || o.finished) continue;
      const g = c.progress - o.progress; if (g > 0 && g < range && g < bd) { bd = g; best = o; }
    }
    return best;
  }
  step(dt) {
    this.time += dt;
    const cars = this.cars;
    for (const c of cars) if (!c.isPlayer || c.finished || c.autopilot) this.aiDrive(c, dt);
    for (const c of cars) this.physics(c, dt);
    this.collisions();
    for (const c of cars) {
      if (c.ctrl.cycle) { c.ctrl.cycle = false; if (c.slots.length > 1) { c.slots.push(c.slots.shift()); this.emit({ t: 'cycle', car: c }); } }
      if (c.ctrl.select) { const k = c.ctrl.select; c.ctrl.select = 0; if (k < c.slots.length) { c.slots.unshift(c.slots.splice(k, 1)[0]); this.emit({ t: 'cycle', car: c }); } }
      if (c.ctrl.fire) { c.ctrl.fire = false; this.useItem(c, false); }
      if (c.ctrl.back) { c.ctrl.back = false; this.useItem(c, true); }
    }
    this.updatePickups(dt);
    this.updateProjs(dt);
    this.updateMines(dt);
    this.updateDomes(dt);
    // laps
    for (const c of cars) {
      const li = Math.floor(c.progress / this.L);
      if (li > c.lap) {
        c.lap = li;
        if (li >= 1 && !c.finished) {
          const lt = this.time - c.lapStart; c.lapTimes.push(lt); c.bestLap = Math.min(c.bestLap, lt); c.lapStart = this.time;
          if (li >= this.laps) { c.finished = true; c.finishTime = this.time; c.fans += (9 - c.place) * 60; this.emit({ t: 'finish', car: c }); }
          else this.emit({ t: 'lap', car: c, lap: li + 1 });
        }
      }
    }
    this.computeOrder();
    // rubber band + difficulty (bots only)
    const ref = this.player && !this.player.finished ? this.player.progress : null;
    for (const c of cars) {
      if (c.isPlayer) { c.vmaxMul = 1; continue; }
      let mul = this.diff.speed * c.ai.skill;
      if (ref != null) mul *= 1 + clamp(-(c.progress - ref) / 520, -0.05, 0.075);
      c.vmaxMul = mul;
    }
  }
  physics(c, dt) {
    const T = this.track, def = c.def;
    c.invulnT = Math.max(0, c.invulnT - dt); c.shieldT = Math.max(0, c.shieldT - dt); c.nitroT = Math.max(0, c.nitroT - dt);
    c.stunT = Math.max(0, c.stunT - dt); c.hbrakeT = Math.max(0, c.hbrakeT - dt); c.scrape = Math.max(0, c.scrape - dt * 3);
    if (c.hop > 0 || c.hopV > 0) { c.hopV -= 30 * dt; c.hop += c.hopV * dt; if (c.hop <= 0) { c.hop = 0; c.hopV = 0; } }
    if (c.wreckT > 0) {
      c.wreckT -= dt; c.v *= Math.exp(-3 * dt);
      c.progress += c.v * dt; c.s = this.mod(c.progress);
      if (c.wreckT <= 0) {
        c.health = c.maxHp; c.yaw = 0; c.latV = 0; c.v = 20; c.invulnT = 2.5; c.spinT = 0; c.stunT = 0;
        c.d = clamp(c.d, -5, 5); this.emit({ t: 'respawn', car: c });
      }
      return;
    }
    let steerIn = c.ctrl.steer, gas = c.ctrl.gas, brake = c.ctrl.brake;
    if (!this.started) { gas = false; brake = true; steerIn = 0; }
    if (c.spinT > 0) { c.spinT -= dt; steerIn = 0; gas = false; brake = false; c.v *= Math.exp(-1.3 * dt); }
    let vmax = def.vmax * c.vmaxMul;
    if (c.nitroT > 0) vmax *= 1.3;
    if (c.stunT > 0) vmax *= 0.55;
    if (c.health < c.maxHp * 0.25) vmax *= 0.95;
    const acc = def.acc * (c.nitroT > 0 ? 2.1 : 1);
    const drifting = brake && Math.abs(c.steer) > 0.35 && c.v > 18;
    c.drift = drifting ? Math.min(1, c.drift + dt * 4) : Math.max(0, c.drift - dt * 3);
    c.braking = brake && !drifting && c.v > 1; c.gasOn = gas;
    if (gas && !(brake && !drifting)) {
      if (c.v < vmax) c.v = Math.min(vmax, c.v + acc * (1 - 0.8 * (c.v / vmax) * (c.v / vmax)) * dt);
      else c.v = Math.max(vmax, c.v - 10 * dt);
    } else if (!brake) {
      if (c.v > 0) c.v = Math.max(0, c.v - (1.5 + c.v * 0.025) * dt); else c.v = Math.min(0, c.v + 3 * dt);
    }
    if (brake) {
      if (drifting) c.v -= 4.5 * dt;
      else if (c.v > 0.5) c.v = Math.max(0, c.v - 28 * dt);
      else if (this.started) c.v = Math.max(-9, c.v - 10 * dt);
    }
    if (c.v > vmax * 1.02 && c.nitroT <= 0) c.v -= (c.v - vmax) * 1.5 * dt;
    // steering
    const rate = c.isPlayer && !c.autopilot ? 5.5 : 8;
    c.steer += clamp(steerIn - c.steer, -rate * dt, rate * dt);
    const v = c.v, av = Math.max(Math.abs(v), 1);
    const aLat = def.grip * 22 * (1 + c.drift * 0.5) * (c.hbrakeT > 0 ? 1.8 : 1) * (this.wet ? 0.93 : 1);
    const cMax = Math.min(0.12, aLat / (av * av));
    const cc = c.steer * cMax;
    const k = T.curv(c.s);
    const dsdt = v * Math.cos(c.yaw) / Math.max(0.35, 1 - k * c.d);
    const assist = (c.isPlayer && !c.autopilot) ? this.assist * (Math.abs(c.steer) < 0.05 ? 1.5 : 1) : BOT_ASSIST;
    c.yaw += (cc * v - k * dsdt - assist * c.yaw * Math.min(1, av / 10)) * dt;
    c.yaw = clamp(c.yaw, -1.25, 1.25);
    c.d += (v * Math.sin(c.yaw) + c.latV) * dt; c.latV *= Math.exp(-4 * dt);
    c.progress += dsdt * dt; c.s = this.mod(c.progress);
    // walls
    const lim = this.hw - 1.1;
    if (c.d > lim || c.d < -lim) {
      const sd = c.d > 0 ? 1 : -1; c.d = sd * lim;
      const into = (v * Math.sin(c.yaw) + c.latV) * sd;
      if (into > 0) {
        c.v -= Math.sign(c.v) * (into * 0.5 + Math.abs(c.v) * 0.02);
        if (c.yaw * sd > 0) c.yaw *= -0.25;
        c.latV = -sd * Math.min(into * 0.25, 4);
        if (into > 9) this.damage(c, (into - 9) * 0.9, null, 'wall');
        c.scrape = Math.max(c.scrape, Math.min(1, into / 14 + 0.25));
        if (into > 5) this.emit({ t: 'wall', car: c, imp: into, side: sd });
      }
    }
    // drift fans
    if (c.drift > 0.6 && c.v > 25 && this.started) { c.driftT += dt; if (c.driftT > 0.5) { c.driftT -= 0.5; c.fans += 5; } }
  }
  collisions() {
    const cars = this.cars, T = this.track;
    for (let i = 0; i < cars.length; i++) {
      const a = cars[i]; if (a.finished || a.wreckT > 0) continue;
      for (let j = i + 1; j < cars.length; j++) {
        const b = cars[j]; if (b.finished || b.wreckT > 0) continue;
        const ds = T.wrapS(b.s - a.s); if (Math.abs(ds) > 4.5) continue;
        const dd = b.d - a.d; if (Math.abs(dd) > 2.05) continue;
        const penS = 4.5 - Math.abs(ds), penD = 2.05 - Math.abs(dd);
        const ma = a.def.mass, mb = b.def.mass, tot = ma + mb;
        if (penD < penS * 0.75) {
          const sg = dd >= 0 ? 1 : -1;
          a.d -= sg * penD * (mb / tot); b.d += sg * penD * (ma / tot);
          a.latV = -sg * 6 * (mb / tot); b.latV = sg * 6 * (ma / tot);
          a.yaw *= 0.75; b.yaw *= 0.75;
          this.emit({ t: 'bump', a, b, side: true });
        } else {
          const front = ds > 0 ? b : a, rear = ds > 0 ? a : b;
          rear.progress -= penS * (front.def.mass / tot); front.progress += penS * (rear.def.mass / tot);
          rear.s = this.mod(rear.progress); front.s = this.mod(front.progress);
          const dv = rear.v - front.v;
          if (dv > 0) {
            rear.v -= dv * (0.55 * front.def.mass / tot + 0.2); front.v += dv * 0.45 * rear.def.mass / tot;
            if (dv > 14) { this.damage(rear, (dv - 14) * 0.6, front, 'bump'); this.damage(front, (dv - 14) * 0.4, rear, 'bump'); }
            if (dv > 3) this.emit({ t: 'bump', a: rear, b: front, dv });
          }
        }
      }
    }
  }
  damage(c, dmg, by, kind) {
    if (c.wreckT > 0 || c.finished || c.invulnT > 0) return;
    c.health -= dmg;
    if (c.health <= 0) this.wreck(c, by, kind);
  }
  wreck(c, by, kind) {
    c.health = 0; c.wreckT = 2.4; c.spinT = 0; c.wrecks++; c.nitroT = 0; c.shieldT = 0;
    if (by && by !== c) { by.fans += FANS.wreck; }
    this.emit({ t: 'wreck', car: c, by, kind });
  }
  hit(o, by, kind, dmg, fx) {
    if (o.finished || o.wreckT > 0) return false;
    if (o.shieldT > 0 || o.invulnT > 0) { this.emit({ t: 'blocked', car: o, by, kind }); return false; }
    o.health -= dmg;
    if (fx.spin) { o.spinT = 1.15; o.spinDir = this.rng() < 0.5 ? -1 : 1; o.v *= 0.35; o.hopV = Math.max(o.hopV, 7); }
    if (fx.slow) o.v *= fx.slow;
    if (fx.stun) o.stunT = Math.max(o.stunT, fx.stun);
    if (fx.hop) o.hopV = Math.max(o.hopV, fx.hop);
    if (fx.push) o.latV += fx.push;
    if (by && by !== o) { by.fans += FANS[kind] || 0; by.hits++; }
    this.emit({ t: 'hit', car: o, by, kind, dmg });
    if (o.health <= 0) this.wreck(o, by, kind);
    return true;
  }
  useItem(c, back) {
    const it = c.slots[0];
    if (!it || c.wreckT > 0 || c.spinT > 0 || !this.started) return;
    const T = this.track, type = it.type; let used = true;
    switch (type) {
      case 'eagle': {
        const tgt = back ? this.carBehind(c, 160) : this.carAhead(c, 420);
        this.projs.push({ id: this.nextId++, kind: 'eagle', owner: c, s: this.mod(c.s + (back ? -5 : 4)), d: c.d, dir: back ? -1 : 1, speed: back ? 32 : Math.max(c.v + 25, 55), target: tgt, life: back ? 3.2 : 7, born: this.time });
        break;
      }
      case 'bolt': {
        this.projs.push({ id: this.nextId++, kind: 'bolt', owner: c, s: this.mod(c.s + (back ? -4 : 4)), d: c.d, dir: back ? -1 : 1, speed: back ? 75 : Math.max(c.v, 0) + 85, target: null, life: 1.5, born: this.time });
        it.ammo--; used = it.ammo <= 0;
        break;
      }
      case 'barge': {
        for (const o of this.cars) {
          if (o === c || o.finished || o.wreckT > 0) continue;
          const ds = T.wrapS(o.s - c.s), dd = o.d - c.d, dist = Math.hypot(ds, dd);
          if (dist < 15) { const f = 1 - dist / 15; this.hit(o, c, 'barge', 12 + 12 * f, { slow: 0.85 - 0.2 * f, push: (dd >= 0 ? 1 : -1) * (9 + 9 * f) }); }
        }
        this.emit({ t: 'barge', car: c });
        break;
      }
      case 'mine': {
        if (back) this.mines.push({ id: this.nextId++, owner: c, s: this.mod(c.s - 6), d: c.d, fly: 0, vs: 0, life: 45, arm: 0.4, born: this.time });
        else this.mines.push({ id: this.nextId++, owner: c, s: this.mod(c.s + 4), d: c.d, fly: 0.7, fly0: 0.7, vs: Math.max(c.v, 10) + 40, life: 45, arm: 0.4, born: this.time });
        break;
      }
      case 'shock': {
        const leader = this.order.find(o => !o.finished);
        if (!leader || leader === c) { used = false; this.emit({ t: 'denied', car: c, why: 'first' }); break; }
        const lanes = [-7, 0, 7]; for (let i = 2; i > 0; i--) { const j = Math.floor(this.rng() * (i + 1)); const t = lanes[i]; lanes[i] = lanes[j]; lanes[j] = t; }
        for (let k = 0; k < 3; k++) this.domes.push({ id: this.nextId++, owner: c, s: this.mod(leader.s + 110 + k * 45), d: lanes[k] + (this.rng() - 0.5) * 2, r: 4.8, warn: 1.0, life: 9, hitSet: new Set() });
        this.emit({ t: 'shock', car: c, target: leader });
        break;
      }
      case 'nitro': {
        if (back) { c.v *= 0.5; c.hbrakeT = 0.8; } else c.nitroT = 2.6;
        this.emit({ t: 'nitro', car: c, back });
        break;
      }
      case 'shield': c.shieldT = 8; this.emit({ t: 'shield', car: c }); break;
      case 'repair': {
        if (c.health >= c.maxHp * 0.97) { used = false; this.emit({ t: 'denied', car: c, why: 'full' }); }
        else { c.health = c.maxHp; this.emit({ t: 'repair', car: c }); }
        break;
      }
    }
    if (used || (type === 'bolt')) this.emit({ t: 'fire', car: c, type, back });
    if (used) c.slots.shift();
  }
  updatePickups(dt) {
    const T = this.track;
    for (const p of this.pickups) {
      if (!p.alive) { p.t -= dt; if (p.t <= 0) { p.alive = true; this.emit({ t: 'pickupBack', p }); } continue; }
      for (const c of this.cars) {
        if (c.slots.length >= 3 || c.wreckT > 0 || c.finished) continue;
        if (Math.abs(T.wrapS(c.s - p.s)) < 3.2 && Math.abs(c.d - p.d) < 2.6) {
          p.alive = false; p.t = 2; // back two seconds after somebody takes it
          c.slots.push({ type: p.type, ammo: PW[p.type].ammo || 1 });
          this.emit({ t: 'pickup', car: c, type: p.type, p });
          break;
        }
      }
    }
  }
  updateProjs(dt) {
    const T = this.track, hw = this.hw;
    for (let i = this.projs.length - 1; i >= 0; i--) {
      const p = this.projs[i]; let dead = false;
      p.life -= dt;
      const tgt = p.target && !p.target.finished && p.target.wreckT <= 0 ? p.target : null;
      if (p.kind === 'eagle') {
        if (p.dir > 0) { const want = tgt ? tgt.v + 45 : p.speed; p.speed += clamp(want - p.speed, -40 * dt, 70 * dt); p.speed = Math.max(p.speed, 45); }
        p.s = this.mod(p.s + p.dir * p.speed * dt);
        if (tgt) { const ds = T.wrapS(tgt.s - p.s); const rate = Math.abs(ds) < 70 ? 24 : 7; p.d += clamp(tgt.d - p.d, -rate * dt, rate * dt); }
      } else {
        p.s = this.mod(p.s + p.dir * p.speed * dt);
        // light homing on the nearest car in the firing direction
        let best = null, bd = 45;
        for (const o of this.cars) {
          if (o === p.owner || o.finished || o.wreckT > 0) continue;
          const ds = T.wrapS(o.s - p.s) * p.dir; if (ds > 0 && ds < bd && Math.abs(o.d - p.d) < 6) { bd = ds; best = o; }
        }
        if (best) p.d += clamp(best.d - p.d, -5 * dt, 5 * dt);
      }
      p.d = clamp(p.d, -hw + 1, hw - 1);
      for (const o of this.cars) {
        if (o === p.owner || o.finished || o.wreckT > 0) continue;
        if (Math.abs(T.wrapS(o.s - p.s)) < 3.2 && Math.abs(o.d - p.d) < 2.3) {
          if (p.kind === 'eagle') this.hit(o, p.owner, 'eagle', 34, { spin: true });
          else this.hit(o, p.owner, 'bolt', 11, { slow: 0.86, push: (o.d - p.d >= 0 ? 1 : -1) * 3 });
          this.emit({ t: 'boom', kind: p.kind, s: p.s, d: p.d, hitCar: o });
          dead = true; break;
        }
      }
      if (!dead) for (let j = this.mines.length - 1; j >= 0; j--) {
        const m = this.mines[j]; if (m.fly > 0) continue;
        if (Math.abs(T.wrapS(m.s - p.s)) < 2.6 && Math.abs(m.d - p.d) < 2.6) {
          this.mines.splice(j, 1); this.emit({ t: 'boom', kind: 'mine', s: m.s, d: m.d }); this.emit({ t: 'boom', kind: p.kind, s: p.s, d: p.d });
          dead = true; break;
        }
      }
      if (!dead) for (let j = this.projs.length - 1; j >= 0; j--) {
        const q = this.projs[j]; if (q === p || q.dir === p.dir) continue;
        if (Math.abs(T.wrapS(q.s - p.s)) < 3.5 && Math.abs(q.d - p.d) < 2.6) {
          this.emit({ t: 'boom', kind: q.kind, s: q.s, d: q.d }); this.emit({ t: 'boom', kind: p.kind, s: p.s, d: p.d });
          this.projs.splice(j, 1); if (j < i) i--; dead = true; break;
        }
      }
      if (!dead && p.life <= 0) { dead = true; this.emit({ t: 'fizzle', kind: p.kind, s: p.s, d: p.d }); }
      if (dead) { const k = this.projs.indexOf(p); if (k >= 0) this.projs.splice(k, 1); }
    }
  }
  updateMines(dt) {
    const T = this.track;
    for (let i = this.mines.length - 1; i >= 0; i--) {
      const m = this.mines[i];
      if (m.fly > 0) { m.fly -= dt; m.s = this.mod(m.s + m.vs * dt); continue; }
      m.life -= dt; m.arm -= dt;
      if (m.life <= 0) { this.mines.splice(i, 1); continue; }
      if (m.arm > 0) continue;
      for (const o of this.cars) {
        if ((o === m.owner && this.time - m.born < 2.5) || o.finished || o.wreckT > 0) continue;
        if (Math.abs(T.wrapS(o.s - m.s)) < 2.5 && Math.abs(o.d - m.d) < 2.1) {
          this.hit(o, m.owner, 'mine', 26, { hop: 7.5, slow: 0.5, stun: 1.0 });
          this.emit({ t: 'boom', kind: 'mine', s: m.s, d: m.d, hitCar: o });
          this.mines.splice(i, 1); break;
        }
      }
    }
    if (this.mines.length > 24) this.mines.shift();
  }
  updateDomes(dt) {
    const T = this.track;
    for (let i = this.domes.length - 1; i >= 0; i--) {
      const dm = this.domes[i];
      if (dm.warn > 0) { dm.warn -= dt; continue; }
      dm.life -= dt; if (dm.life <= 0) { this.domes.splice(i, 1); continue; }
      for (const o of this.cars) {
        if (dm.hitSet.has(o.id) || o.finished || o.wreckT > 0) continue;
        const ds = T.wrapS(o.s - dm.s), dd = o.d - dm.d;
        if (ds * ds + dd * dd < dm.r * dm.r) {
          dm.hitSet.add(o.id);
          this.hit(o, dm.owner, 'shock', 20, { stun: 2.2, slow: 0.6 });
          this.emit({ t: 'zap', dome: dm, car: o });
        }
      }
    }
  }
  // ---------------- AI ----------------
  aiDrive(c, dt) {
    const ai = c.ai, T = this.track, hw = this.hw;
    ai.planT -= dt; ai.t -= dt;
    if (ai.planT <= 0) {
      ai.planT = 0.1;
      const aLat = c.def.grip * 22 * 0.93 * (this.wet ? 0.93 : 1);
      let vT = c.def.vmax * c.vmaxMul * (c.nitroT > 0 ? 1.3 : 1) * (c.stunT > 0 ? 0.55 : 1);
      for (let x = 0; x <= 240; x += 6) {
        const k = Math.abs(T.curv(c.s + x)); if (k < 1e-4) continue;
        const vc = Math.sqrt(aLat / k), allow = Math.sqrt(vc * vc + 2 * 19 * x);
        if (allow < vT) vT = allow;
      }
      ai.vT = vT;
      let ka = 0; for (let x = 15; x <= 55; x += 10) ka += T.curv(c.s + x); ka /= 5;
      let dT = clamp(ka * 900, -1, 1) * (hw - 3.5) * ai.lineAmt + ai.laneBias;
      if (c.slots.length < 3) {
        let bp = null, bd = 80;
        for (const p of this.pickups) { if (!p.alive) continue; const ds = T.wrapS(p.s - c.s); if (ds > 8 && ds < bd) { bd = ds; bp = p; } }
        if (bp) dT = bp.d;
      }
      const hz = (hs, hd, rad) => { const ds = T.wrapS(hs - c.s); if (ds > 0 && ds < 70 && Math.abs(hd - dT) < rad) dT = hd + (hd > 0 ? -rad - 1 : rad + 1); };
      for (const m of this.mines) if (m.fly <= 0) hz(m.s, m.d, 3);
      for (const dm of this.domes) hz(dm.s, dm.d, dm.r + 0.5);
      for (const o of this.cars) {
        if (o === c || o.wreckT > 0) continue;
        const ds = T.wrapS(o.s - c.s);
        if (ds > 0 && ds < 24 && Math.abs(o.d - c.d) < 2.6 && c.v > o.v + 0.5) dT = o.d + (o.d > 0 ? -3.6 : 3.6);
      }
      ai.dT = clamp(dT, -hw + 1.7, hw - 1.7);
    }
    c.ctrl.gas = c.v < ai.vT - 0.5;
    c.ctrl.brake = c.v > ai.vT + 3;
    const v = Math.max(c.v, 3), k = T.curv(c.s);
    const Lk = Math.max(10, v * 0.6);
    const yawDes = Math.atan2(ai.dT - c.d, Lk);
    const dsdt = c.v * Math.cos(c.yaw) / Math.max(0.35, 1 - k * c.d);
    const cMax = Math.min(0.12, c.def.grip * 22 * (this.wet ? 0.93 : 1) / (v * v));
    const cNeed = ((yawDes - c.yaw) / 0.3 + k * dsdt + BOT_ASSIST * c.yaw * Math.min(1, v / 10)) / v;
    c.ctrl.steer = clamp(cNeed / cMax, -1, 1);
    if (ai.t <= 0) { ai.t = (0.35 + this.rng() * 0.6) * this.diff.react * ai.react; if (!c.finished) this.aiWeapons(c); }
  }
  aiWeapons(c) {
    const it = c.slots[0]; if (!it || !this.started) return;
    const T = this.track, r = this.rng(), aim = this.diff.aim;
    const ahead = this.carAhead(c, 260), behind = this.carBehind(c, 80);
    let fire = false, back = false;
    switch (it.type) {
      case 'eagle':
        if (ahead && r < 0.75 * aim) fire = true;
        else if (behind && c.progress - behind.progress < 45 && r < 0.3) { fire = true; back = true; }
        break;
      case 'bolt': {
        if (ahead && ahead.progress - c.progress < 60 && Math.abs(ahead.d - c.d) < 3.2 && r < 0.9 * aim) fire = true;
        else if (behind && c.progress - behind.progress < 35 && Math.abs(behind.d - c.d) < 3 && r < 0.4) { fire = true; back = true; }
        break;
      }
      case 'barge': {
        let n = 0; for (const o of this.cars) { if (o === c || o.finished) continue; if (Math.hypot(T.wrapS(o.s - c.s), o.d - c.d) < 11) n++; }
        if (n > 0 && r < 0.9) fire = true; break;
      }
      case 'mine':
        if (behind && c.progress - behind.progress < 45 && r < 0.7) { fire = true; back = true; }
        else if (r < 0.06) { fire = true; back = true; }
        break;
      case 'shock': {
        const lead = this.order.find(o => !o.finished);
        if (lead && lead !== c && lead.progress - c.progress > 40 && r < 0.6) fire = true; break;
      }
      case 'nitro': {
        let straight = true; for (let x = 0; x <= 140; x += 10) if (Math.abs(T.curv(c.s + x)) > 1 / 160) { straight = false; break; }
        if (straight && c.v > c.def.vmax * 0.55 && r < 0.8) fire = true; break;
      }
      case 'shield': {
        let threat = false;
        for (const p of this.projs) if (p.target === c || (p.owner !== c && Math.abs(T.wrapS(p.s - c.s)) < 30)) threat = true;
        if (threat || (c.health < c.maxHp * 0.5 && r < 0.25) || r < 0.04) fire = true; break;
      }
      case 'repair': if (c.health < c.maxHp * 0.45) fire = true; break;
    }
    if (fire) this.useItem(c, back);
    else if (c.slots.length >= 2 && r > 0.9) c.slots.push(c.slots.shift());
  }
  // estimated finishing times for cars still racing when results are shown
  estimate() {
    for (const c of this.cars) {
      if (c.finished) { c.est = c.finishTime; continue; }
      const remain = this.laps * this.L - c.progress;
      const avg = Math.max(18, c.progress / Math.max(1, this.time));
      c.est = this.time + remain / avg;
    }
  }
}
