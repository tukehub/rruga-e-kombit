// Pure simulation check: every city, three difficulties, player on autopilot.
const fs = require('fs'), vm = require('vm'), path = require('path');
const ctx = { THREE: require('../node_modules/three'), console, Math, Date, Map, Set, Float32Array, Uint16Array, Array, Object, JSON, Infinity, isFinite };
vm.createContext(ctx);
let src = ['00_util.js', '01_data.js', '02_track.js', '03_sim.js'].map(f => fs.readFileSync(path.join(__dirname, '../src', f), 'utf8')).join('\n');
vm.runInContext(src + '\n;globalThis.E = { CITIES, CARS, Track, Race };', ctx);
const E = ctx.E; let ok = true; const places = [[], [], []];
for (const city of E.CITIES) {
  const tr = new E.Track(city); const row = [];
  for (const diff of [0, 1, 2]) {
    const race = new E.Race(tr, { playerDef: E.CARS[0], playerColor: '#e41e20', diff, seed: 3 + diff, laps: city.laps });
    race.player.autopilot = true; race.started = true;
    let t = 0, nan = false;
    while (t < 420 && !race.cars.every(c => c.finished)) { race.step(1 / 60); t += 1 / 60; race.events.length = 0; for (const c of race.cars) if (!isFinite(c.progress)) nan = true; }
    if (nan || !race.cars.every(c => c.finished)) ok = false;
    places[diff].push(race.player.place);
    row.push(`d${diff}:P${race.player.place} ${t.toFixed(0)}s [${race.order.map(c => c.name).join(' ')}]`);
  }
  console.log(city.id.padEnd(12), row.join(' | '));
}
console.log('avg autopilot place by difficulty:', places.map(p => (p.reduce((a, b) => a + b, 0) / p.length).toFixed(1)).join(' / '));
console.log(ok ? 'ALL RACES FINISHED' : 'PROBLEM');
