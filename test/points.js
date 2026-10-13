// Points-mode check: the open square with five cars (player on autopilot), run for the full timer on every difficulty.
// Asserts: the timer ends the round, nothing goes NaN, cars stay inside the walls and off the island, they don't sit
// inside each other, hits and wrecks happen, power-ups are taken, fired and land, they come back after 2 s,
// and every driver name is used exactly once.
const fs = require('fs'), vm = require('vm'), path = require('path');
const ctx = { THREE: require('../node_modules/three'), console, Math, Date, Map, Set, Float32Array, Uint16Array, Array, Object, JSON, Infinity, isFinite };
vm.createContext(ctx);
const src = ['00_util.js', '01_data.js', '035_arena.js'].map(f => fs.readFileSync(path.join(__dirname, '../src', f), 'utf8')).join('\n');
vm.runInContext(src + '\n;globalThis.E = { CARS, DRIVERS, ArenaSim, ARENA_DEF, arenaWall, PW_ARENA };', ctx);
const E = ctx.E, A = E.ARENA_DEF;

let ok = true;
for (const [minutes, diff, driver] of [[2, 0, 0], [2, 1, 3], [3, 2, 1]]) {
  const race = new E.ArenaSim({ playerDef: E.CARS[driver], driver, diff, seed: 11 + diff, time: minutes * 60 });
  race.player.autopilot = true; race.started = true;
  let badType = 0, nan = false, outside = 0, overlap = 0, timeupAt = -1, hits = 0, wrecks = 0, frames = 0, picks = 0, fires = 0, wHits = 0, wPts = 0, back = [];
  const takenAt = new Map();
  const w = { nx: 0, nz: 0 };
  while (race.time < minutes * 60 + 3) {
    race.step(1 / 60); frames++;
    for (const e of race.events) {
      if (e.t === 'timeup') timeupAt = race.time; if (e.t === 'score') hits++; if (e.t === 'wreck') wrecks++;
      if (e.t === 'pickup') { picks++; takenAt.set(e.p.id, race.time); if (!E.PW_ARENA.includes(e.type)) badType++; } if (e.t === 'pickupBack') back.push(race.time - takenAt.get(e.p.id)); if (e.t === 'fire') fires++;
      if (e.t === 'hit' && e.by) { wHits++; wPts += e.pts; }
    }
    race.events.length = 0;
    for (const c of race.cars) {
      if (![c.x, c.z, c.vx, c.vz, c.h, c.score].every(isFinite)) nan = true;
      if (c.wreckT > 0) continue;
      if (E.arenaWall(c.x, c.z, w) < 0 || Math.hypot(c.x, c.z) < A.island) outside++;
    }
    for (let i = 0; i < race.cars.length; i++) for (let j = i + 1; j < race.cars.length; j++) {
      const a = race.cars[i], b = race.cars[j];
      if (a.wreckT <= 0 && b.wreckT <= 0 && Math.hypot(a.x - b.x, a.z - b.z) < 1.2) overlap++;
    }
  }
  const names = race.cars.map(c => c.name).sort().join(), all = E.DRIVERS.map(d => d.name).sort().join();
  const board = race.cars.slice().sort((a, b) => b.score - a.score);
  const pass = race.over && Math.abs(timeupAt - minutes * 60) < 0.05 && !nan && outside === 0 && overlap < frames * 0.01 && hits >= 20 && names === all && race.player.name === E.DRIVERS[driver].name && picks > 20 && fires > 10 && wHits > 3 && back.every(d => Math.abs(d - 2) < 0.05) && badType === 0;
  if (!pass) ok = false;
  console.log(`${minutes} min, diff ${diff}, player ${race.player.name}: timer ${timeupAt.toFixed(2)}s · hits ${hits} · wrecks ${wrecks} · outside ${outside} · overlap ${overlap} · power-ups taken ${picks}, fired ${fires}, landed ${wHits} (+${wPts}), respawn ${back.length ? Math.min(...back).toFixed(2) + '-' + Math.max(...back).toFixed(2) : '-'}s · non-attack pickups ${badType} · ${pass ? 'ok' : 'PROBLEM'}`);
  console.log('  ' + board.map(c => `${c.name}:${c.score}(${c.hitsN}h ${c.kills}k)`).join('  '));
}
console.log(ok ? 'POINTS MODE OK' : 'POINTS MODE PROBLEM');
