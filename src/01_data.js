// ---------- game data: environments, cities, cars, power-ups, copy ----------
const ENV = {
  night:  { sky: ['#02030a', '#1d1538'], glow: '#6a2f78', fog: ['#120e22', 90, 860], sun: { dir: [0.35, 0.55, -0.45], col: '#8ea6ff', i: 0.6 }, hemi: ['#4b508c', '#120c10', 0.5], win: 1.0, lamps: true, stars: true, moon: true, exp: 1.1, bloom: 1.05, label: 'Natë', icon: '☾' },
  dusk:   { sky: ['#121842', '#e06c5a'], glow: '#ff7a50', fog: ['#4e3150', 100, 920], sun: { dir: [-0.75, 0.12, 0.4], col: '#ff9a6a', i: 1.5 }, hemi: ['#a8a0d8', '#2a1e22', 0.45], win: 0.85, lamps: true, stars: true, exp: 1.05, bloom: 0.9, label: 'Muzg', icon: '◐' },
  sunset: { sky: ['#22336e', '#ffaa62'], glow: '#ff9a50', fog: ['#c98a6a', 120, 1050], sun: { dir: [0.8, 0.14, -0.3], col: '#ffb26e', i: 2.4 }, hemi: ['#b8b0e0', '#3a2c26', 0.5], win: 0.5, lamps: true, exp: 1.0, bloom: 0.75, label: 'Perëndim', icon: '◒' },
  day:    { sky: ['#3e7fd8', '#c4e2f4'], fog: ['#c6def0', 170, 1200], sun: { dir: [0.4, 0.85, 0.3], col: '#fff4dc', i: 2.6 }, hemi: ['#d4eaff', '#6c6a52', 0.6], win: 0, exp: 0.95, bloom: 0.45, label: 'Ditë', icon: '☀' },
  golden: { sky: ['#3a78c8', '#f4d0a0'], glow: '#ffc890', fog: ['#dcc29a', 150, 1150], sun: { dir: [-0.6, 0.33, 0.5], col: '#ffd6a0', i: 2.8 }, hemi: ['#cfe0f5', '#5c5240', 0.55], win: 0.1, exp: 0.95, bloom: 0.5, label: 'Pasdite', icon: '☀' },
  rain:   { sky: ['#07090f', '#262e3c'], glow: '#38506e', fog: ['#181d27', 55, 560], sun: { dir: [0.3, 0.8, 0.2], col: '#9fb0c8', i: 0.55 }, hemi: ['#5a6a80', '#101214', 0.55], win: 1.0, lamps: true, rain: true, wet: true, exp: 1.15, bloom: 1.05, label: 'Shi natën', icon: '☂' },
  snow:   { sky: ['#161d33', '#5e6584'], glow: '#ffb070', fog: ['#3e445c', 60, 640], sun: { dir: [-0.5, 0.3, 0.6], col: '#ffd8b8', i: 0.9 }, hemi: ['#b8c4dc', '#4a4e5a', 0.6], win: 0.95, lamps: true, snow: true, exp: 1.1, bloom: 0.95, label: 'Borë', icon: '❄' },
};

const REGIONS = { al: 'Shqipëri', xk: 'Kosovë', mk: 'Maqedoni e Veriut' };

// Track control points are metres in the x/z plane; the race runs in point order.
const CITIES = [
  {
    hero: { type: 'skanderbeg', height: 260 },
    id: 'tirane', name: 'Tiranë', region: 'al', env: 'night', laps: 3, neon: '#ff2d6f', road: 'asphalt',
    blurb: 'Bulevardi natën: pallate me ngjyra, neon dhe semaforë dekorativë.',
    styles: [['painted', 5], ['soviet', 3], ['modern', 2]], hRange: [14, 46], tall: 0.12, ground: 'urban', amp: 3, tscale: 420,
    trees: 'deciduous', bunkers: 2, mountains: { col: '#2b3550', snow: false, h: [260, 520] },
    ads: ['lavazh', 'byrek', 'apartament', 'kafe', 'sigurim', 'xhiro', 'diaspora'],
    landmarks: [
      { type: 'skanderbeg', at: 0.06, side: 1, off: 34 },
      { type: 'mosque', at: 0.025, side: -1, off: 36, dome: 6, minaret: 26 },
      { type: 'clocktower', at: 0.1, side: -1, off: 32, h: 34 },
      { type: 'pyramid', at: 0.2, side: 1, off: 46 },
      { type: 'flagpole', at: 0.14, side: 1, off: 26, h: 34 },
    ],
    pts: [[0, -120], [0, 150], [0, 330], [28, 440], [120, 492], [262, 488], [356, 430], [392, 330], [360, 228], [404, 120], [418, -10], [392, -150], [318, -268], [196, -330], [76, -338], [12, -260]],
  },
  {
    hero: { type: 'venetian', height: 200 },
    id: 'durres', name: 'Durrës', region: 'al', env: 'night', laps: 3, neon: '#ff8c3a', road: 'asphalt',
    blurb: 'Shëtitorja natën. Kujdes nga turistët dhe nga bunkerët në plazh.',
    styles: [['seaside', 6], ['soviet', 3]], hRange: [10, 34], tall: 0.08, ground: 'dry', amp: 3, tscale: 380,
    water: { type: 'sea', dir: [0, -1] }, trees: 'palm', bunkers: 14, umbrellas: true, mountains: { col: '#6f5a66', snow: false, h: [160, 320] },
    ads: ['lavazh', 'byrek', 'apartament', 'kafe', 'diaspora', 'sigurim'],
    landmarks: [
      { type: 'venetian', at: 0.62, out: true, off: 40 },
      { type: 'amphi', at: 0.74, out: true, off: 62 },
      { type: 'cranes', at: 0.16, side: -1, off: 58 },
      { type: 'flagpole', at: 0.03, side: -1, off: 24, h: 28 },
    ],
    pts: [[-300, -200], [0, -206], [300, -196], [460, -150], [520, -40], [470, 80], [350, 124], [262, 222], [120, 262], [-36, 206], [-160, 244], [-330, 232], [-462, 150], [-522, 20], [-482, -130]],
  },
  {
    hero: { type: 'indep', height: 240 },
    id: 'vlore', name: 'Vlorë', region: 'al', env: 'sunset', laps: 3, neon: '#ffd23a', road: 'asphalt',
    blurb: 'Këtu lindi shteti. Rrugën po e rregullojnë që atëherë.',
    styles: [['seaside', 5], ['modern', 3], ['soviet', 2]], hRange: [10, 40], tall: 0.1, ground: 'dry', amp: 5, tscale: 420,
    water: { type: 'sea', dir: [-1, 0] }, trees: 'palm', bunkers: 8, mountains: { col: '#5f6e6a', snow: false, h: [200, 420] }, island: true,
    ads: ['lavazh', 'byrek', 'kafe', 'diaspora', 'apartament', 'xhiro'],
    landmarks: [
      { type: 'indep', at: 0.5, side: 1, off: 40 },
      { type: 'flagpole', at: 0.47, side: -1, off: 30, h: 46, big: true },
      { type: 'mosque', at: 0.8, side: 1, off: 36, dome: 5, minaret: 22 },
    ],
    pts: [[-370, -120], [-382, 80], [-340, 260], [-220, 372], [-50, 362], [56, 262], [40, 128], [124, 26], [262, -18], [306, -150], [232, -280], [70, -332], [-110, -270], [-250, -330], [-344, -270]],
  },
  {
    hero: { type: 'castle', height: 150, r: 52 },
    id: 'shkoder', name: 'Shkodër', region: 'al', env: 'dusk', laps: 3, neon: '#4ee0ff', road: 'asphalt',
    blurb: 'Liqeni, Rozafa dhe një mijë biçikleta që s’të lënë rrugë.',
    styles: [['old', 5], ['soviet', 4], ['painted', 1]], hRange: [8, 26], tall: 0.04, ground: 'grass', amp: 4, tscale: 400,
    water: { type: 'lake', at: 0.66, side: -1, off: 300, r: 210 }, trees: 'deciduous', bunkers: 6,
    mountains: { col: '#55606e', snow: true, h: [380, 720] },
    ads: ['lavazh', 'byrek', 'kafe', 'xhiro', 'sigurim', 'apartament'],
    landmarks: [
      { type: 'castle', at: 0.06, out: true, off: 200, hill: { h: 48, r: 120 }, r: 52 },
      { type: 'mosque', at: 0.12, side: -1, off: 52, dome: 4.2, minaret: 22, domes: 5, lead: true },
      { type: 'flagpole', at: 0.94, side: 1, off: 26, h: 26 },
    ],
    pts: [[0, -352], [150, -330], [282, -250], [334, -100], [302, 60], [342, 222], [262, 352], [100, 382], [-60, 332], [-150, 222], [-160, 62], [-222, -80], [-202, -232], [-120, -330]],
  },
  {
    hero: { type: 'castle', height: 150, r: 40 },
    id: 'berat', scale: 1.2, name: 'Berat', region: 'al', env: 'dusk', laps: 3, neon: '#ffb347', road: 'cobble',
    blurb: 'Qyteti i një mbi një dritareve. Të gjitha të shohin kur humb.',
    styles: [['old', 7], ['soviet', 2]], hRange: [7, 15], tall: 0, ground: 'grass', amp: 9, tscale: 360,
    trees: 'cypress', bunkers: 3, mountains: { col: '#4e4660', snow: true, h: [420, 760] },
    ads: ['byrek', 'kafe', 'lavazh', 'xhiro', 'diaspora'],
    landmarks: [
      { type: 'mangalem', center: true, hill: { h: 46, r: 125 } },
      { type: 'castle', center: true, r: 34 },
      { type: 'mosque', at: 0.04, side: -1, off: 36, dome: 4.5, minaret: 20 },
      { type: 'bridge', at: 0.7, out: true, off: 44 },
    ],
    pts: [[0, -252], [102, -262], [182, -200], [202, -90], [150, 2], [202, 102], [182, 222], [80, 282], [-42, 252], [-82, 150], [-162, 110], [-222, 0], [-182, -112], [-100, -202]],
  },
  {
    hero: { type: 'castle', height: 150, r: 46, clock: true },
    id: 'gjirokaster', scale: 1.1, name: 'Gjirokastër', region: 'al', env: 'rain', laps: 3, neon: '#3d9dff', road: 'cobble',
    blurb: 'Gurë, shi dhe kthesa. Qyteti i gurtë nuk fal.',
    styles: [['stone', 8], ['soviet', 1]], hRange: [7, 16], tall: 0, ground: 'grass', amp: 16, tscale: 330,
    trees: 'cypress', bunkers: 4, mountains: { col: '#4c5258', snow: false, h: [420, 700] },
    ads: ['byrek', 'kafe', 'lavazh', 'sigurim'],
    landmarks: [
      { type: 'castle', at: 0.0, side: 1, off: 0, center: true, hill: { h: 42, r: 95 }, r: 46, clock: true },
      { type: 'mosque', at: 0.55, side: -1, off: 34, dome: 4, minaret: 18 },
    ],
    pts: [[0, -282], [140, -252], [236, -150], [214, -46], [256, 60], [222, 190], [110, 250], [20, 206], [-70, 252], [-182, 242], [-252, 120], [-214, 0], [-252, -120], [-182, -242], [-82, -302]],
  },
  {
    hero: { type: 'cathedral', height: 220 },
    id: 'korce', name: 'Korçë', region: 'al', env: 'snow', laps: 3, neon: '#ffe6a0', road: 'asphalt',
    blurb: 'Borë, serenata dhe asnjë zinxhir në gomat e tua.',
    styles: [['old', 5], ['soviet', 4]], hRange: [8, 22], tall: 0, ground: 'snow', amp: 5, tscale: 400,
    trees: 'pine', bunkers: 4, mountains: { col: '#7a8494', snow: true, h: [360, 640] },
    ads: ['byrek', 'kafe', 'lavazh', 'xhiro', 'sigurim'],
    landmarks: [
      { type: 'cathedral', at: 0.05, side: 1, off: 44 },
      { type: 'flagpole', at: 0.02, side: -1, off: 24, h: 26 },
      { type: 'mosque', at: 0.6, side: -1, off: 40, dome: 4, minaret: 18 },
    ],
    pts: [[0, -262], [200, -242], [322, -120], [302, 40], [362, 160], [282, 282], [120, 302], [0, 222], [-120, 302], [-282, 262], [-342, 120], [-302, -20], [-342, -150], [-222, -262]],
  },
  {
    hero: { type: 'library', height: 160 },
    id: 'prishtine', scale: 1.18, name: 'Prishtinë', region: 'xk', env: 'night', laps: 3, neon: '#2de2ff', road: 'asphalt',
    blurb: 'NEWBORN natën, makiato ditën, gara gjithmonë.',
    styles: [['modern', 4], ['soviet', 5], ['painted', 1]], hRange: [14, 44], tall: 0.1, ground: 'urban', amp: 5, tscale: 420,
    trees: 'deciduous', bunkers: 0, mountains: { col: '#2a3048', snow: false, h: [200, 380] },
    ads: ['makiato', 'flija', 'lavazh', 'apartament', 'sigurim', 'diaspora', 'xhiro'],
    landmarks: [
      { type: 'newborn', at: 0.07, side: 1, off: 26 },
      { type: 'library', at: 0.42, side: 1, off: 58 },
      { type: 'hotel', at: 0.2, side: -1, off: 42 },
      { type: 'flagpole', at: 0.03, side: -1, off: 24, h: 30 },
    ],
    pts: [[0, -252], [0, 52], [32, 202], [142, 262], [302, 252], [382, 162], [366, 42], [296, -36], [304, -152], [262, -272], [142, -322], [30, -310]],
  },
  {
    hero: { type: 'mosque', height: 260, dome: 7, minaret: 30 },
    id: 'prizren', scale: 1.22, name: 'Prizren', region: 'xk', env: 'sunset', laps: 3, neon: '#ff7a59', road: 'cobble',
    blurb: 'Kalaja sipër, Ura e Gurit poshtë, dhe ti në mes pa frena.',
    styles: [['old', 7], ['modern', 1]], hRange: [7, 16], tall: 0, ground: 'grass', amp: 7, tscale: 360,
    trees: 'deciduous', bunkers: 0, mountains: { col: '#5a4a5e', snow: true, h: [460, 820] },
    ads: ['makiato', 'flija', 'lavazh', 'diaspora', 'xhiro'],
    landmarks: [
      { type: 'castle', at: 0.62, out: true, off: 210, hill: { h: 56, r: 115 }, r: 50 },
      { type: 'mosque', at: 0.07, side: -1, off: 40, dome: 7, minaret: 30, big: true },
      { type: 'bridge', at: 0.16, side: 1, off: 36 },
      { type: 'flagpole', at: 0.02, side: 1, off: 22, h: 24 },
    ],
    pts: [[0, -202], [120, -232], [232, -172], [262, -62], [202, 42], [242, 152], [162, 252], [40, 242], [-42, 152], [-152, 172], [-242, 102], [-252, -22], [-172, -102], [-102, -202]],
  },
  {
    hero: { type: 'mosque', height: 260, dome: 5, minaret: 26 },
    id: 'peje', name: 'Pejë', region: 'xk', env: 'golden', laps: 2, neon: '#7dff9a', road: 'asphalt',
    blurb: 'Rugova, kthesa malore dhe shkëmbinj që s’lëvizin për ty.',
    styles: [['old', 5], ['soviet', 3]], hRange: [8, 20], tall: 0, ground: 'grass', amp: 14, tscale: 460,
    trees: 'pine', bunkers: 0, mountains: { col: '#4a5a52', snow: true, h: [520, 980], near: true }, canyon: [0.36, 0.56],
    ads: ['makiato', 'flija', 'lavazh', 'xhiro', 'sigurim'],
    landmarks: [
      { type: 'mosque', at: 0.04, side: -1, off: 36, dome: 4.5, minaret: 22 },
      { type: 'flagpole', at: 0.02, side: 1, off: 24, h: 26 },
    ],
    pts: [[0, -402], [200, -382], [382, -282], [462, -100], [422, 100], [482, 282], [402, 442], [200, 482], [40, 402], [-80, 262], [-200, 202], [-342, 122], [-382, -60], [-302, -222], [-180, -362]],
  },
  {
    hero: { type: 'paintedmosque', height: 220 },
    id: 'tetove', name: 'Tetovë', region: 'mk', env: 'night', laps: 3, neon: '#ff5fc8', road: 'asphalt',
    blurb: 'Xhamia e Larme, Sharri me borë dhe kthesa që s’mbarojnë.',
    styles: [['old', 4], ['soviet', 4], ['painted', 1]], hRange: [8, 26], tall: 0.03, ground: 'grass', amp: 6, tscale: 420,
    trees: 'deciduous', bunkers: 0, mountains: { col: '#55506a', snow: true, h: [600, 1050], near: true, side: [0, 1] },
    ads: ['makiato', 'flija', 'lavazh', 'byrek', 'diaspora', 'xhiro'],
    landmarks: [
      { type: 'paintedmosque', at: 0.06, side: 1, off: 40 },
      { type: 'flagpole', at: 0.02, side: -1, off: 24, h: 26 },
      { type: 'mosque', at: 0.52, side: 1, off: 38, dome: 4, minaret: 20 },
    ],
    pts: [[0, -282], [162, -282], [282, -202], [302, -60], [240, 46], [262, 182], [162, 302], [0, 302], [-122, 238], [-202, 284], [-322, 202], [-322, 40], [-242, -80], [-252, -196], [-196, -266], [-100, -296]],
  },
];

// Points mode: free driving in Skanderbeg Square (Tirana), walled in. The arena itself lives in 035_arena.js.
const ARENA = { id: 'arena', name: 'Sheshi Skënderbej', short: 'Sheshi', region: 'al', env: 'dusk', neon: '#ff2d6f', blurb: 'Sheshi më i madh i Tiranës, i mbyllur me barriera. Pa rrugë, pa xhiro: vetëm ti dhe katër shoferë.' };

const CARS = [
  { id: 'benxi', name: 'Benxi GT', style: 'gt', vmax: 58, acc: 17, grip: 1.0, hp: 100, mass: 1.0, color: '#e41e20', desc: 'Kapot i gjatë, motor V8, dhe gjithmonë i parkuar te kafeneja.' },
  { id: 'kali', name: 'Kali i Egër GT', style: 'muscle', vmax: 62, acc: 15.5, grip: 0.9, hp: 110, mass: 1.15, color: '#26262c', desc: 'Kalë amerikan. Shpejt në vijë të drejtë, kthesat janë opinion personal.' },
  { id: 'golfi', name: 'Golfi GTI', style: 'hatch', vmax: 55, acc: 19, grip: 1.16, hp: 90, mass: 0.85, color: '#f2c230', desc: 'Makina kombëtare. I vogël, i shkathët, dhe gjithmonë me xhamat poshtë.' },
  { id: 'uragani', name: 'Uragani V10', style: 'sleek', vmax: 60, acc: 18, grip: 1.03, hp: 85, mass: 0.9, color: '#f1eee8', desc: 'Pykë italiane. E bukur, e shpejtë, dhe kushton sa një pallat në Bllok.' },
  { id: 'gelendvagen', name: 'Gelendvagen G', style: 'jeep', vmax: 54, acc: 15, grip: 0.96, hp: 140, mass: 1.35, color: '#2a2a2e', desc: 'Kutia e zezë e çdo dasme. Gropat e tua s’i bëjnë gjë.' },
  { id: 'sprinteri', name: 'Sprinteri i Linjës', style: 'van', vmax: 51, acc: 13.5, grip: 0.88, hp: 175, mass: 1.7, color: '#f3f3ee', desc: 'Tiranë–Durrës, 24/7. Ndalon ku të duash, edhe ku s’do.' },
];
const PAINTS = ['#e41e20', '#26262c', '#f1eee8', '#f2c230', '#2a6fdb', '#3f6d3b', '#ff6a1a', '#8e44ad'];

const PW = {
  eagle:  { name: 'Shqiponja', col: '#ff2b2b', w: 15, desc: 'Lëshon një shqiponjë që ndjek makinën para teje. Prapa: atë pas teje.' },
  bolt:   { name: 'Rrufeja', col: '#3aa8ff', w: 16, ammo: 3, desc: 'Tre rrufe të shpejta. Pak dëm, shumë inat.' },
  barge:  { name: 'Tërmeti', col: '#b45cff', w: 12, desc: 'Shtyn me forcë këdo që të rri afër.' },
  mine:   { name: 'Gropa', col: '#ff8c1a', w: 14, desc: 'Lë një gropë pas vetes, si bashkia. Përpara: e hedh.' },
  shock:  { name: 'Stuhia', col: '#ffe03a', w: 7, desc: 'Tre kupola elektrike para atij që është i pari.' },
  nitro:  { name: 'Nitro', col: '#38ff6a', w: 17, desc: 'Shpejtësi e çmendur. Prapa: frenim i menjëhershëm.' },
  shield: { name: 'Mburoja', col: '#dfe9ff', w: 10, desc: 'Të mbron nga çdo sulm për 8 sekonda.' },
  repair: { name: 'Usta', col: '#ff5fc8', w: 9, desc: 'Usta Ramizi ta rregullon makinën. Pa faturë.' },
};
const PW_KEYS = Object.keys(PW);

// The five drivers. The player is one of them; the other four are the rivals. Each has a colour nobody else uses.
const DRIVERS = [
  { name: 'Artur', col: '#ff2a3d', tag: 'Gjithmonë me gaz' },
  { name: 'Ritvan', col: '#1fb6ff', tag: 'Ftohtë si Valbona' },
  { name: 'Desantin', col: '#ffc21a', tag: 'Fren? Ç’është ajo?' },
  { name: 'Eno', col: '#2bff88', tag: 'Drift në çdo kthesë' },
  { name: 'Erlin', col: '#c46bff', tag: 'Godet i pari, pyet më vonë' },
];
// the rivals of driver pi (all five when pi < 0), shuffled
function rivalsOf(pi, r) {
  const b = DRIVERS.filter((_, i) => i !== pi);
  for (let i = b.length - 1; i > 0; i--) { const j = Math.floor(r() * (i + 1)); const t = b[i]; b[i] = b[j]; b[j] = t; }
  return b;
}
function placeMsg(place, n) { return place >= n ? PLACE_MSG[PLACE_MSG.length - 1] : PLACE_MSG[place - 1]; }

const ADS = {
  lavazh:     { t: 'LAVAZH 24/7', s: 'Lajmë edhe gropat', bg: '#1f6fd1', fg: '#ffffff' },
  byrek:      { t: 'BYREK 60 LEKË', s: 'I ngrohtë që nga viti 1991', bg: '#f2c230', fg: '#2a1a0a' },
  apartament: { t: 'SHITET APARTAMENT', s: 'Pamje nga kantieri', bg: '#e41e20', fg: '#ffffff' },
  kafe:       { t: 'KAFE 100 LEKË', s: 'Pije ngadalë. Ke kohë.', bg: '#3b2416', fg: '#f6e2c8' },
  sigurim:    { t: 'SIGURIM MAKINE', s: 'Do të të duhet. Besomë.', bg: '#121418', fg: '#38ff6a' },
  xhiro:      { t: 'XHIRO E MBRËMJES', s: 'Çdo ditë, ora 19:00', bg: '#7a3aa0', fg: '#ffffff' },
  diaspora:   { t: 'MIRË SE ERDHËT', s: 'Diaspora parkon ku të dojë', bg: '#ffffff', fg: '#d0161b' },
  makiato:    { t: 'MAKIATO 50 CENT', s: 'Më i miri në Ballkan (sipas nesh)', bg: '#5a3a26', fg: '#ffe9c9' },
  flija:      { t: 'FLIJA E GJYSHES', s: 'Piqet 5 orë, hahet 5 minuta', bg: '#d9822b', fg: '#ffffff' },
};
const AD_KEYS = Object.keys(ADS);
const NEON_WORDS = ['KAFE', 'BAR', 'LAVAZH', 'HOTEL', 'BYREK', 'QEBAPTORE', 'FARMACI', 'MARKET'];

const TIPS = [
  'Në Tiranë, drita e verdhë do të thotë: shtype më fort.',
  'Gropat janë falas. Amortizatorët jo.',
  'Furgoni ndalon kudo. Edhe aty ku nuk ka vend.',
  'Bori është mjeti kombëtar i komunikimit.',
  'Nëse dikush të ndez dritat, ose është polic, ose kushëriri.',
  'Kafeja zgjat tre orë. Gara zgjat tre minuta. Zgjidh me kujdes.',
  'Në Shkodër biçikleta ka gjithmonë përparësi. Edhe kur nuk ka.',
  'Shqipëria ka mbi 170 mijë bunkerë. Asnjë s’të mbron nga Shqiponja.',
  'Rrethrrotullimi është vendi ku ligjet e fizikës dalin me pushime.',
  'Usta Ramizi pranon vetëm kesh. Dhe raki.',
  'Mburoja zgjat 8 sekonda. Si premtimet para zgjedhjeve.',
  'Një gropë e vendosur mirë është art. Bashkia e di.',
  'Diaspora vjen në gusht. Ti erdhe i fundit.',
  'Mbaje frenën për të rrëshqitur në kthesë. Tifozët e duan dramën.',
  'Stuhia godet gjithmonë të parin. Mos u bëj i pari shumë herët.',
  'Rrufeja ka tre të shtëna. Gjuaji kur makina është drejt para teje.',
];
const PLACE_MSG = [
  'Kampion! Shqiponja dykrenore ngriti të dyja kokat për ty.',
  'I dyti. Si gjithmonë: afër, por jo aq afër.',
  'Podium! Mjafton për një foto profili.',
  'I katërti. Vendi më i dhimbshëm në sport.',
  'I parafundit. Të paktën dikush ishte më keq.',
  'I fundit. Edhe furgoni i linjës të kaloi, dhe ndaloi dy herë për pasagjerë.',
];
const ORD = ['I PARI', 'I DYTI', 'I TRETI', 'I KATËRTI', 'I PESTI', 'I GJASHTI', 'I SHTATI', 'I TETI'];
const DIFFS = [
  { id: 0, name: 'E lehtë', speed: 0.87, react: 1.3, aim: 0.55 },
  { id: 1, name: 'Normale', speed: 0.935, react: 0.9, aim: 0.8 },
  { id: 2, name: 'E vështirë', speed: 1.035, react: 0.55, aim: 1.0 },
];
