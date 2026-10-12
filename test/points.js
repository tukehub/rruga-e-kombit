// Points-mode check: the roundabout with six cars (player on autopilot), run for the full timer.
// Asserts: the timer ends the round, nothing goes NaN, bots and the player score, and no lap or pickup events leak in.
const fs = require('fs'), vm = require('vm'), path = require('path');
const ctx = { THREE: require('../node_modules/three'), console, Math, Date, Map, Set, Float32Array, Uint16Array, Array, Object, JSON, Infinity, isFinite };
vm.createContext(ctx);
const src = ['00_util.js', '01_data.js', '02_track.js', '03_sim.js'].map(f => fs.readFileSync(path.join(__dirname, '../src', f), 'utf8')).join('\n');
vm.runInContext(src + '\n;globalThis.E = { ARENA, CARS, Track, Race };', ctx);
const E = ctx.E;

let ok = true;
for (const minutes of [2, 3]) {
  const track = new E.Track(E.ARENA);
  const race = new E.Race(track, { playerDef: E.CARS[0], playerColor: '#e41e20', diff: 1, seed: 7 + minutes, mode: 'points', time: minutes * 60 });
  race.player.autopilot = true; race.started = true;
  let t = 0, nan = false, leaks = 0, timeupAt = -1;
  const kinds = {};
  while (t < minutes * 60 + 5) {
    race.step(1 / 60); t += 1 / 60;
    for (const e of race.events) {
      kinds[e.t] = (kinds[e.t] || 0) + 1;
      if (e.t === 'lap' || e.t === 'finish' || e.t === 'pickup') leaks++;
      if (e.t === 'timeup') timeupAt = race.time;
    }
    race.events.length = 0;
    for (const c of race.cars) if (!isFinite(c.progress) || !isFinite(c.v) || !isFinite(c.score)) nan = true;
  }
  const board = race.cars.slice().sort((a, b) => b.score - a.score);
  const scored = board.filter(c => c.score > 0).length;
  const roundOk = race.over && timeupAt > 0 && Math.abs(timeupAt - minutes * 60) < 0.05;
  const pass = roundOk && !nan && leaks === 0 && scored >= 3;
  if (!pass) ok = false;
  console.log(`${minutes} min: timer ended at ${timeupAt.toFixed(2)}s · scored ${scored}/${race.cars.length} · hits ${kinds.score || 0} · wrecks ${kinds.wreck || 0} · ${pass ? 'ok' : 'PROBLEM'}`);
  console.log('  ' + board.map(c => `${c.name}:${c.score}(${c.hitsN}h)`).join('  '));
}
console.log(ok ? 'POINTS MODE OK' : 'POINTS MODE PROBLEM');
