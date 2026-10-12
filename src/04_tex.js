// ---------- procedural canvas textures ----------
const FONT_D = '"Big Shoulders Display", "Arial Narrow", Impact, sans-serif';
const FONT_U = '"Chakra Petch", "Trebuchet MS", Arial, sans-serif';
const TEX = {};
function mkCanvas(w, h) { const c = document.createElement('canvas'); c.width = w; c.height = h; return c; }
function canvasTex(w, h, draw, o) {
  o = o || {};
  const c = mkCanvas(w, h), g = c.getContext('2d'); draw(g, w, h);
  const t = new THREE.CanvasTexture(c); t.encoding = THREE.sRGBEncoding;
  if (o.repeat) { t.wrapS = t.wrapT = THREE.RepeatWrapping; }
  t.anisotropy = o.aniso || 4;
  if (o.nearest) { t.magFilter = THREE.NearestFilter; }
  t.needsUpdate = true; t.userData = { canvas: c };
  return t;
}
function noiseFill(g, w, h, base, amt, n, r) {
  g.fillStyle = base; g.fillRect(0, 0, w, h);
  for (let i = 0; i < n; i++) {
    const v = (r() - 0.5) * amt; g.fillStyle = v > 0 ? `rgba(255,255,255,${v})` : `rgba(0,0,0,${-v})`;
    const s = 1 + r() * 2.5; g.fillRect(r() * w, r() * h, s, s);
  }
}
// double-headed eagle silhouette in a 100x100 box
const EAGLE_L = [[50, 30], [47, 24], [45, 18], [43, 14], [40, 11], [36, 10], [32, 11], [28, 13], [24, 15], [28, 16], [31, 16], [33, 18], [36, 21], [39, 25], [41, 30], [36, 27], [30, 23], [24, 19], [17, 15], [10, 12], [3, 11], [7, 15], [2, 18], [8, 21], [3, 25], [10, 27], [5, 31], [12, 33], [8, 37], [15, 39], [12, 43], [19, 44], [17, 48], [25, 48], [24, 53], [31, 51], [36, 55], [38, 60], [37, 65], [33, 67], [28, 70], [31, 72], [35, 71], [38, 70], [40, 74], [36, 80], [41, 79], [40, 86], [45, 83], [46, 91], [50, 87]];
function drawEagle(g, cx, cy, size, color) {
  const pts = EAGLE_L.concat(EAGLE_L.slice(1, -1).reverse().map(p => [100 - p[0], p[1]]));
  g.save(); g.translate(cx - size / 2, cy - size / 2); g.scale(size / 100, size / 100);
  g.fillStyle = color; g.beginPath();
  pts.forEach((p, i) => (i ? g.lineTo(p[0], p[1]) : g.moveTo(p[0], p[1])));
  g.closePath(); g.fill(); g.restore();
}
function flagTex() {
  return canvasTex(140, 100, (g, w, h) => { g.fillStyle = '#e41e20'; g.fillRect(0, 0, w, h); drawEagle(g, w / 2, h / 2 + 2, 86, '#111'); });
}
function roadTex(kind, wet) {
  const r = mulberry32(77);
  return canvasTex(256, 512, (g, w, h) => {
    if (kind === 'cobble') {
      g.fillStyle = wet ? '#2c2a29' : '#4a4642'; g.fillRect(0, 0, w, h);
      const rows = 32, rh = h / rows;
      for (let y = 0; y < rows; y++) {
        let x = (y % 2) * 6 - 6;
        while (x < w) {
          const sw = 10 + r() * 8, v = 70 + r() * 50;
          g.fillStyle = wet ? `rgb(${v * 0.55},${v * 0.55},${v * 0.6})` : `rgb(${v + 10},${v + 4},${v - 4})`;
          g.beginPath(); g.roundRect ? g.roundRect(x + 1, y * rh + 1, sw - 2, rh - 2, 4) : g.rect(x + 1, y * rh + 1, sw - 2, rh - 2); g.fill();
          x += sw;
        }
      }
      g.fillStyle = 'rgba(230,220,200,0.55)'; g.fillRect(4, 0, 5, h); g.fillRect(w - 9, 0, 5, h);
    } else {
      noiseFill(g, w, h, wet ? '#1f2124' : (kind === 'snow' ? '#34363a' : '#2e3034'), 0.22, 9000, r);
      for (let i = 0; i < 26; i++) { g.fillStyle = `rgba(0,0,0,${0.08 + r() * 0.1})`; g.fillRect(r() * w, r() * h, 8 + r() * 60, 3 + r() * 10); }
      g.fillStyle = 'rgba(0,0,0,0.12)'; g.fillRect(w * 0.12, 0, w * 0.12, h); g.fillRect(w * 0.45, 0, w * 0.1, h); g.fillRect(w * 0.76, 0, w * 0.12, h);
      g.fillStyle = '#e9e6dc'; g.fillRect(8, 0, 6, h); g.fillRect(w - 14, 0, 6, h);
      g.fillStyle = '#e9e6dc';
      for (const u of [1 / 3, 2 / 3]) for (let y = 0; y < h; y += 128) g.fillRect(u * w - 3, y + 20, 6, 70);
      if (kind === 'snow') {
        for (let i = 0; i < 1600; i++) {
          const side = r() < 0.5, x = side ? r() * r() * 34 : w - r() * r() * 34;
          g.fillStyle = `rgba(245,248,255,${0.5 + r() * 0.5})`; g.fillRect(x, r() * h, 2 + r() * 5, 2 + r() * 5);
        }
      }
      if (wet) for (let i = 0; i < 40; i++) { g.fillStyle = `rgba(160,180,210,${0.05 + r() * 0.06})`; g.fillRect(r() * w, r() * h, 2 + r() * 4, 20 + r() * 80); }
    }
  }, { repeat: true, aniso: 8 });
}
function sidewalkTex() {
  const r = mulberry32(5);
  return canvasTex(128, 128, (g, w, h) => {
    noiseFill(g, w, h, '#8b8884', 0.15, 1200, r);
    g.strokeStyle = 'rgba(40,36,32,0.45)'; g.lineWidth = 2;
    for (let i = 0; i <= 4; i++) { g.beginPath(); g.moveTo(i * 32, 0); g.lineTo(i * 32, h); g.stroke(); g.beginPath(); g.moveTo(0, i * 32); g.lineTo(w, i * 32); g.stroke(); }
  }, { repeat: true });
}
function barrierTex(neon) {
  return canvasTex(512, 64, (g, w, h) => {
    // plain carbon-dark barrier, no lettering: thin red pinstripes only
    g.fillStyle = '#121015'; g.fillRect(0, 0, w, h);
    for (let x = -h; x < w; x += 6) { g.strokeStyle = (x / 6) % 2 ? 'rgba(255,255,255,0.025)' : 'rgba(0,0,0,0.25)'; g.lineWidth = 3; g.beginPath(); g.moveTo(x, h); g.lineTo(x + h, 0); g.stroke(); }
    g.fillStyle = '#b0141a'; g.fillRect(0, 10, w, 3); g.fillRect(0, h - 13, w, 3);
  }, { repeat: true });
}
// facade styles: map (light wall + dark windows, tinted by vertex colour) and emissive window map
const STYLE_INFO = {
  painted: { cols: ['#e94f37', '#f6c445', '#3fa7d6', '#59cd90', '#ee6352', '#a26ec1', '#ff8c42', '#2ec4b6'], winX: 3.4, floorH: 3.1, roof: 'flat' },
  soviet: { cols: ['#b9b2a6', '#c9c0b0', '#a7a29a', '#cdb79e', '#9fa6ad'], winX: 3.2, floorH: 2.9, roof: 'flat' },
  modern: { cols: ['#8fb3c9', '#7d9cb3', '#a8bccb', '#6f8696'], winX: 2.6, floorH: 3.6, roof: 'flat' },
  old: { cols: ['#f1ebe0', '#eee3cf', '#f6f1e6', '#e8dcc6'], winX: 2.6, floorH: 3.0, roof: 'tile' },
  stone: { cols: ['#cfc8bd', '#bfb7aa', '#d8d0c4'], winX: 2.8, floorH: 3.2, roof: 'slate' },
  seaside: { cols: ['#f4f1ea', '#f7e6c8', '#e2f0f2', '#f6d9cf', '#fdf4d6'], winX: 3.2, floorH: 3.0, roof: 'flat' },
};
function facadeTex(style, seed) {
  const r = mulberry32(seed || 3), N = 8, S = 256, cs = S / N;
  const map = canvasTex(S, S, (g) => {
    g.fillStyle = '#ffffff'; g.fillRect(0, 0, S, S);
    if (style === 'stone') { for (let i = 0; i < 260; i++) { const v = 200 + r() * 55; g.fillStyle = `rgb(${v},${v - 6},${v - 14})`; g.fillRect(r() * S, r() * S, 10 + r() * 18, 6 + r() * 6); } g.strokeStyle = 'rgba(80,70,60,0.25)'; for (let y = 0; y < S; y += 8) { g.beginPath(); g.moveTo(0, y); g.lineTo(S, y); g.stroke(); } }
    if (style === 'soviet') { g.strokeStyle = 'rgba(60,60,60,0.35)'; g.lineWidth = 2; for (let i = 0; i <= N; i++) { g.beginPath(); g.moveTo(0, i * cs); g.lineTo(S, i * cs); g.stroke(); } }
    if (style === 'painted') { for (let i = 0; i < 6; i++) { g.fillStyle = `rgba(255,255,255,${0.25 + r() * 0.3})`; g.fillRect(0, r() * S, S, 6 + r() * 14); } g.fillStyle = 'rgba(0,0,0,0.08)'; for (let i = 0; i < 4; i++) g.fillRect(r() * S, 0, 10 + r() * 20, S); }
    for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
      const px = x * cs, py = y * cs;
      if (style === 'modern') {
        const v = 40 + r() * 40; g.fillStyle = `rgb(${v * 0.7},${v * 0.9},${v * 1.2})`; g.fillRect(px + 1, py + 2, cs - 2, cs - 4);
        g.fillStyle = 'rgba(255,255,255,0.14)'; g.fillRect(px + 1, py + 2, cs - 2, 5);
      } else {
        const ww = style === 'old' || style === 'stone' ? cs * 0.42 : cs * 0.56, wh = cs * (style === 'old' ? 0.56 : 0.6);
        const ox = px + (cs - ww) / 2, oy = py + cs * 0.18;
        g.fillStyle = style === 'seaside' ? '#3b6f86' : '#2a2c33'; g.fillRect(ox, oy, ww, wh);
        g.fillStyle = 'rgba(255,255,255,0.12)'; g.fillRect(ox, oy, ww, wh * 0.25);
        if (style === 'old' || style === 'stone') { g.fillStyle = style === 'old' ? '#6b4a2e' : '#3b3530'; g.fillRect(ox - 5, oy, 4, wh); g.fillRect(ox + ww + 1, oy, 4, wh); }
        if (style === 'soviet' || style === 'seaside') { g.fillStyle = style === 'seaside' ? 'rgba(255,255,255,0.9)' : 'rgba(90,86,80,0.9)'; g.fillRect(px + 2, oy + wh + 2, cs - 4, 4); }
        if (style === 'painted') { g.strokeStyle = 'rgba(0,0,0,0.3)'; g.lineWidth = 2; g.strokeRect(ox, oy, ww, wh); }
      }
    }
    g.fillStyle = '#ffffff'; g.fillRect(0, 0, 10, 10); // plain patch used by roofs
  }, { repeat: true });
  const em = canvasTex(S, S, (g) => {
    g.fillStyle = '#000'; g.fillRect(0, 0, S, S);
    const warm = ['#ffc56a', '#ffd08c', '#f7d9a8', '#ffb050', '#9fc6f0', '#f2d9b0'];
    for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
      if (r() < (style === 'modern' ? 0.58 : 0.5)) continue;
      const px = x * cs, py = y * cs;
      g.fillStyle = style === 'modern' ? (r() < 0.6 ? '#8fb6e6' : '#f0cf96') : warm[Math.floor(r() * warm.length)];
      g.globalAlpha = 0.45 + r() * 0.45;
      if (style === 'modern') g.fillRect(px + 1, py + 2, cs - 2, cs - 4);
      else { const ww = style === 'old' || style === 'stone' ? cs * 0.42 : cs * 0.56, wh = cs * (style === 'old' ? 0.56 : 0.6); g.fillRect(px + (cs - ww) / 2, py + cs * 0.18, ww, wh); }
      g.globalAlpha = 1;
    }
    g.fillStyle = '#000'; g.fillRect(0, 0, 10, 10);
  }, { repeat: true });
  return { map, em };
}
function adAtlasTex(keys) {
  return canvasTex(1024, 512, (g) => {
    keys.slice(0, 16).forEach((k, i) => {
      const a = ADS[k], x = (i % 4) * 256, y = Math.floor(i / 4) * 128;
      g.fillStyle = a.bg; g.fillRect(x, y, 256, 128);
      g.fillStyle = a.fg; g.textAlign = 'center'; g.textBaseline = 'middle';
      let fs = 46; g.font = `900 ${fs}px ${FONT_D}`;
      while (g.measureText(a.t).width > 236 && fs > 20) { fs -= 2; g.font = `900 ${fs}px ${FONT_D}`; }
      g.fillText(a.t, x + 128, y + 50);
      g.font = `600 17px ${FONT_U}`; let ss = 17;
      while (g.measureText(a.s).width > 236 && ss > 10) { ss--; g.font = `600 ${ss}px ${FONT_U}`; }
      g.globalAlpha = 0.85; g.fillText(a.s, x + 128, y + 94); g.globalAlpha = 1;
      g.fillStyle = 'rgba(0,0,0,0.25)'; g.fillRect(x, y + 120, 256, 8);
    });
  });
}
function neonAtlasTex() {
  const cols = ['#ff3d7f', '#3de2ff', '#ffd23d', '#7dff9a', '#ff7a3d', '#c77dff', '#ff3d3d', '#3dff6e'];
  return canvasTex(512, 512, (g) => {
    g.fillStyle = '#000'; g.fillRect(0, 0, 512, 512);
    NEON_WORDS.forEach((wd, i) => {
      const x = (i % 2) * 256, y = Math.floor(i / 2) * 128, c = cols[i % cols.length];
      g.textAlign = 'center'; g.textBaseline = 'middle';
      let fs = 70; g.font = `800 ${fs}px ${FONT_D}`;
      while (g.measureText(wd).width > 220 && fs > 24) { fs -= 2; g.font = `800 ${fs}px ${FONT_D}`; }
      g.shadowColor = c; g.shadowBlur = 18; g.fillStyle = c; g.fillText(wd, x + 128, y + 64);
      g.shadowBlur = 0; g.fillStyle = '#fff'; g.globalAlpha = 0.7; g.fillText(wd, x + 128, y + 64); g.globalAlpha = 1;
    });
  });
}
function glowTex() {
  return canvasTex(64, 64, (g, w) => {
    const gr = g.createRadialGradient(32, 32, 0, 32, 32, 32);
    gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(0.25, 'rgba(255,255,255,0.6)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = gr; g.fillRect(0, 0, 64, 64);
  });
}
function signTex(text, sub, bg, fg) {
  return canvasTex(1024, 160, (g, w, h) => {
    g.fillStyle = bg; g.fillRect(0, 0, w, h);
    g.fillStyle = '#d0161b'; g.fillRect(0, 0, 150, h); drawEagle(g, 75, h / 2, 120, '#111');
    g.fillStyle = fg; g.textBaseline = 'middle'; g.textAlign = 'left';
    g.font = `900 92px ${FONT_D}`; g.fillText(text, 180, h * 0.42);
    g.font = `600 30px ${FONT_U}`; g.globalAlpha = 0.8; g.fillText(sub, 184, h * 0.82); g.globalAlpha = 1;
  });
}
function clockTex() {
  return canvasTex(128, 128, (g) => {
    g.fillStyle = '#3a2f26'; g.fillRect(0, 0, 128, 128);
    g.fillStyle = '#f4ecd8'; g.beginPath(); g.arc(64, 64, 52, 0, 7); g.fill();
    g.strokeStyle = '#222'; g.lineWidth = 4;
    for (let i = 0; i < 12; i++) { const a = i / 12 * Math.PI * 2; g.beginPath(); g.moveTo(64 + Math.cos(a) * 42, 64 + Math.sin(a) * 42); g.lineTo(64 + Math.cos(a) * 50, 64 + Math.sin(a) * 50); g.stroke(); }
    g.lineWidth = 5; g.beginPath(); g.moveTo(64, 64); g.lineTo(64, 30); g.stroke(); g.beginPath(); g.moveTo(64, 64); g.lineTo(88, 72); g.stroke();
  });
}
function paintedFacadeTex() {
  const r = mulberry32(42);
  return canvasTex(256, 256, (g) => {
    g.fillStyle = '#efe2c4'; g.fillRect(0, 0, 256, 256);
    const pal = ['#2f6fb3', '#3a9a5b', '#c0392b', '#e08b2c', '#7b4fa0', '#1f8f8a', '#d4a72c'];
    for (let y = 0; y < 3; y++) for (let x = 0; x < 4; x++) {
      const px = x * 64 + 6, py = y * 84 + 8, w = 52, h = 70;
      g.fillStyle = pal[(x + y * 2) % pal.length]; g.beginPath(); g.moveTo(px, py + h); g.lineTo(px, py + 22); g.quadraticCurveTo(px + w / 2, py - 8, px + w, py + 22); g.lineTo(px + w, py + h); g.closePath(); g.fill();
      g.fillStyle = pal[(x + y * 2 + 3) % pal.length]; g.beginPath(); g.moveTo(px + w / 2, py + 18); g.lineTo(px + w - 10, py + 42); g.lineTo(px + w / 2, py + 66); g.lineTo(px + 10, py + 42); g.closePath(); g.fill();
      for (let k = 0; k < 6; k++) { g.fillStyle = pal[Math.floor(r() * pal.length)]; g.beginPath(); g.arc(px + 8 + r() * (w - 16), py + 26 + r() * (h - 32), 3 + r() * 3, 0, 7); g.fill(); }
      g.strokeStyle = '#f7efd9'; g.lineWidth = 2; g.strokeRect(px, py + 16, w, h - 16);
    }
  });
}
function latticeTex() {
  return canvasTex(256, 256, (g) => {
    g.fillStyle = '#2b2f36'; g.fillRect(0, 0, 256, 256);
    g.fillStyle = 'rgba(160,200,230,0.25)'; for (let y = 8; y < 256; y += 32) g.fillRect(0, y, 256, 16);
    g.strokeStyle = '#c9ccd0'; g.lineWidth = 3;
    for (let i = -256; i < 512; i += 22) { g.beginPath(); g.moveTo(i, 0); g.lineTo(i + 256, 256); g.stroke(); g.beginPath(); g.moveTo(i + 256, 0); g.lineTo(i, 256); g.stroke(); }
  }, { repeat: true });
}
function statueTex() {
  return canvasTex(256, 256, (g) => {
    g.fillStyle = '#2d2b27';
    const poly = (p) => { g.beginPath(); p.forEach((q, i) => (i ? g.lineTo(q[0], q[1]) : g.moveTo(q[0], q[1]))); g.closePath(); g.fill(); };
    g.beginPath(); g.ellipse(140, 132, 58, 26, 0, 0, 7); g.fill();
    poly([[92, 128], [78, 96], [70, 74], [82, 62], [98, 70], [110, 108], [118, 128]]);
    poly([[70, 74], [56, 84], [46, 96], [52, 102], [64, 96], [80, 82], [86, 64], [80, 60]]);
    poly([[80, 62], [76, 50], [87, 60]]);
    poly([[93, 140], [101, 140], [104, 206], [96, 206]]);
    poly([[106, 140], [92, 164], [80, 170], [78, 163], [89, 158], [99, 138]]);
    poly([[166, 146], [175, 146], [180, 206], [171, 206]]);
    poly([[182, 140], [191, 140], [194, 206], [186, 206]]);
    poly([[193, 118], [212, 150], [206, 180], [198, 152], [188, 128]]);
    poly([[128, 110], [124, 70], [132, 58], [146, 62], [149, 106]]);
    g.beginPath(); g.arc(136, 47, 10, 0, 7); g.fill();
    poly([[138, 40], [152, 28], [162, 32], [151, 38], [143, 46]]);
    poly([[128, 74], [106, 94], [102, 89], [122, 69]]);
    poly([[146, 62], [172, 98], [161, 113], [148, 104]]);
    poly([[130, 104], [121, 130], [131, 133], [141, 108]]);
  });
}
function letterTex(ch, col) {
  return canvasTex(128, 160, (g, w, h) => {
    g.font = `900 176px ${FONT_D}`; g.textAlign = 'center'; g.textBaseline = 'alphabetic';
    g.fillStyle = col; g.fillText(ch, w / 2, h - 6);
    g.strokeStyle = 'rgba(0,0,0,0.35)'; g.lineWidth = 3; g.strokeText(ch, w / 2, h - 6);
  });
}
// power-up icon canvases (shared by HUD and 3D sprites)
function iconCanvas(type, size) {
  size = size || 128; const c = mkCanvas(size, size), g = c.getContext('2d'), s = size / 128;
  const col = PW[type].col;
  g.scale(s, s);
  const hex = (r) => { g.beginPath(); for (let i = 0; i < 6; i++) { const a = Math.PI / 6 + i * Math.PI / 3; g[i ? 'lineTo' : 'moveTo'](64 + Math.cos(a) * r, 64 + Math.sin(a) * r); } g.closePath(); };
  // outer glow, metal rim in the power-up colour, smoked-glass face, inner light, glossy highlight
  g.shadowColor = col; g.shadowBlur = 14; hex(58); g.fillStyle = col; g.fill(); g.shadowBlur = 0;
  const rim = g.createLinearGradient(0, 6, 0, 122); rim.addColorStop(0, '#ffffff'); rim.addColorStop(0.35, col); rim.addColorStop(1, '#0c0a12');
  hex(58); g.fillStyle = rim; g.fill();
  const face = g.createRadialGradient(64, 58, 4, 64, 64, 54); face.addColorStop(0, col); face.addColorStop(0.55, '#1a1424'); face.addColorStop(1, '#07060b');
  hex(51); g.fillStyle = face; g.fill();
  g.globalAlpha = 0.85; const inner = g.createRadialGradient(64, 66, 2, 64, 66, 40); inner.addColorStop(0, col); inner.addColorStop(1, 'rgba(0,0,0,0)'); hex(51); g.fillStyle = inner; g.fill(); g.globalAlpha = 1;
  g.save(); hex(51); g.clip(); const gl = g.createLinearGradient(0, 12, 0, 64); gl.addColorStop(0, 'rgba(255,255,255,0.35)'); gl.addColorStop(1, 'rgba(255,255,255,0)'); g.fillStyle = gl; g.beginPath(); g.ellipse(64, 20, 62, 40, 0, 0, 7); g.fill(); g.restore();
  g.lineWidth = 2; g.strokeStyle = 'rgba(255,255,255,0.55)'; hex(51); g.stroke();
  g.translate(64, 64); g.scale(0.82, 0.82); g.translate(-64, -64);
  g.shadowColor = col; g.shadowBlur = 10;
  g.fillStyle = '#fff'; g.strokeStyle = '#fff'; g.lineCap = 'round'; g.lineJoin = 'round';
  const poly = (p) => { g.beginPath(); p.forEach((q, i) => (i ? g.lineTo(q[0], q[1]) : g.moveTo(q[0], q[1]))); g.closePath(); g.fill(); };
  switch (type) {
    case 'eagle': drawEagle(g, 64, 66, 70, '#fff'); break;
    case 'bolt': poly([[70, 26], [44, 68], [62, 68], [54, 102], [84, 56], [66, 56], [76, 26]]); break;
    case 'barge': g.lineWidth = 6; for (const rr of [12, 24, 36]) { g.beginPath(); g.arc(64, 64, rr, 0, 7); g.stroke(); } break;
    case 'mine': g.fillStyle = '#1a120a'; g.beginPath(); g.ellipse(64, 66, 32, 22, 0, 0, 7); g.fill(); g.lineWidth = 4; g.beginPath(); g.ellipse(64, 66, 32, 22, 0, 0, 7); g.stroke(); g.lineWidth = 3; for (let i = 0; i < 6; i++) { const a = i * 1.05 + 0.3; g.beginPath(); g.moveTo(64 + Math.cos(a) * 30, 66 + Math.sin(a) * 20); g.lineTo(64 + Math.cos(a) * 44, 66 + Math.sin(a) * 30); g.stroke(); } break;
    case 'shock': g.lineWidth = 5; for (const x of [40, 64, 88]) { g.beginPath(); g.arc(x, 82, 12, Math.PI, 0); g.stroke(); } poly([[66, 24], [52, 52], [62, 52], [56, 70], [76, 44], [66, 44], [72, 24]]); break;
    case 'nitro': poly([[34, 40], [58, 64], [34, 88], [46, 88], [70, 64], [46, 40]]); poly([[62, 40], [86, 64], [62, 88], [74, 88], [98, 64], [74, 40]]); break;
    case 'shield': poly([[64, 26], [96, 38], [92, 74], [64, 102], [36, 74], [32, 38]]); g.fillStyle = PW.shield.col === '#dfe9ff' ? '#9db4e0' : '#000'; poly([[64, 36], [86, 45], [83, 72], [64, 92]]); break;
    case 'repair': g.lineWidth = 12; g.beginPath(); g.moveTo(44, 86); g.lineTo(76, 54); g.stroke(); g.beginPath(); g.arc(82, 46, 16, 0, 7); g.fill(); g.fillStyle = 'rgba(0,0,0,0.9)'; g.beginPath(); g.arc(90, 38, 8, 0, 7); g.fill(); break;
  }
  return c;
}
function nameTagCanvas() { return mkCanvas(256, 64); }
function drawNameTag(c, name, hp, color) {
  const g = c.getContext('2d'); g.clearRect(0, 0, 256, 64);
  g.font = `700 26px ${FONT_U}`; g.textAlign = 'center'; g.textBaseline = 'middle';
  g.fillStyle = 'rgba(0,0,0,0.55)'; g.fillRect(28, 6, 200, 34);
  g.fillStyle = '#fff'; g.fillText(name, 128, 24);
  g.fillStyle = 'rgba(0,0,0,0.6)'; g.fillRect(28, 44, 200, 12);
  g.fillStyle = hp > 0.5 ? '#38ff6a' : hp > 0.25 ? '#ffd23a' : '#ff3b3b'; g.fillRect(30, 46, 196 * clamp(hp, 0, 1), 8);
  g.fillStyle = color; g.fillRect(28, 6, 6, 34);
}
function vGradTex() {
  return canvasTex(4, 128, (g, w, h) => { const gr = g.createLinearGradient(0, h, 0, 0); gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(0.25, 'rgba(160,160,160,1)'); gr.addColorStop(1, 'rgba(0,0,0,1)'); g.fillStyle = gr; g.fillRect(0, 0, w, h); });
}
