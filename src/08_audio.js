// ---------- synthesized audio: engine, effects, 7/8 Balkan groove ----------
const AUD = {
  ctx: null, on: true, musicOn: true, started: false,
  init() {
    if (this.ctx) { if (this.ctx.state === 'suspended') this.ctx.resume(); return; }
    const AC = window.AudioContext || window.webkitAudioContext; if (!AC) return;
    try { this.ctx = new AC(); } catch (e) { return; }
    const c = this.ctx;
    this.master = c.createGain(); this.master.gain.value = this.on ? 0.9 : 0; this.master.connect(c.destination);
    this.sfx = c.createGain(); this.sfx.gain.value = 0.7; this.sfx.connect(this.master);
    this.mus = c.createGain(); this.mus.gain.value = this.musicOn ? 0.24 : 0; this.mus.connect(this.master);
    const len = c.sampleRate; this.noise = c.createBuffer(1, len, c.sampleRate); const d = this.noise.getChannelData(0); for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
    // engine: a V12-style supercar. Four detuned oscillators on the firing note and its sub-octaves,
    // a tanh shaper for growl, a body boost, a lowpass that opens with the revs, intake roar and a turbo whistle.
    this.eMix = c.createGain(); this.eMix.gain.value = 0.5;
    this.eShape = c.createWaveShaper(); this.eShape.curve = this.shapeCurve(2.4); this.eShape.oversample = '2x';
    this.eBody = c.createBiquadFilter(); this.eBody.type = 'peaking'; this.eBody.frequency.value = 160; this.eBody.Q.value = 0.9; this.eBody.gain.value = 7;
    this.eFilt = c.createBiquadFilter(); this.eFilt.type = 'lowpass'; this.eFilt.frequency.value = 600; this.eFilt.Q.value = 1.3;
    this.eGain = c.createGain(); this.eGain.gain.value = 0;
    this.eOsc = [['sawtooth', 1, 0.5], ['sawtooth', 0.5, 0.5], ['square', 1.5, 0.14], ['sine', 0.25, 0.6]].map(([type, mul, g0]) => {
      const o = c.createOscillator(), g = c.createGain(); o.type = type; o.detune.value = (Math.random() - 0.5) * 10; g.gain.value = g0;
      o.connect(g); g.connect(this.eMix); o.start(); return { o, mul };
    });
    this.eMix.connect(this.eShape); this.eShape.connect(this.eBody); this.eBody.connect(this.eFilt); this.eFilt.connect(this.eGain); this.eGain.connect(this.sfx);
    const ins = c.createBufferSource(); ins.buffer = this.noise; ins.loop = true;
    this.iFilt = c.createBiquadFilter(); this.iFilt.type = 'bandpass'; this.iFilt.Q.value = 0.8; this.iGain = c.createGain(); this.iGain.gain.value = 0;
    ins.connect(this.iFilt); this.iFilt.connect(this.iGain); this.iGain.connect(this.sfx); ins.start();
    this.turbo = c.createOscillator(); this.turbo.type = 'sine'; this.tGain = c.createGain(); this.tGain.gain.value = 0;
    this.turbo.connect(this.tGain); this.tGain.connect(this.sfx); this.turbo.start();
    this.eSt = { gear: 0, gas: false, shiftT: 0, popT: 0 };
    // wall scrape
    this.scrGain = c.createGain(); this.scrGain.gain.value = 0; const sf = c.createBiquadFilter(); sf.type = 'bandpass'; sf.frequency.value = 1800; sf.Q.value = 1.2;
    const sn = c.createBufferSource(); sn.buffer = this.noise; sn.loop = true; sn.connect(sf); sf.connect(this.scrGain); this.scrGain.connect(this.sfx); sn.start();
  },
  setOn(v) { this.on = v; if (this.master) this.master.gain.setTargetAtTime(v ? 0.9 : 0, this.ctx.currentTime, 0.05); },
  setMusic(v) { this.musicOn = v; if (this.mus) this.mus.gain.setTargetAtTime(v ? 0.24 : 0, this.ctx.currentTime, 0.1); },
  shapeCurve(k) { const n = 1024, cv = new Float32Array(n), d = Math.tanh(k); for (let i = 0; i < n; i++) { const x = i / (n - 1) * 2 - 1; cv[i] = Math.tanh(k * x) / d; } return cv; },
  // revs climb through six gears; upshifts dip the note and let the turbo blow off, lifting at high revs crackles the exhaust
  engine(speed01, gas, active, scrape) {
    if (!this.ctx) return; const t = this.ctx.currentTime, st = this.eSt;
    const sp = clamp(speed01, 0, 1.4), gears = 6, gf = Math.min(gears - 1, Math.floor(sp * gears)), frac = clamp(sp * gears - gf, 0, 1);
    const rpm = 1150 + frac * 5600 + (gas ? 450 : 0) - gf * 110, f = rpm / 60 * 3;
    for (const x of this.eOsc) x.o.frequency.setTargetAtTime(f * x.mul, t, 0.045);
    this.eFilt.frequency.setTargetAtTime(320 + rpm * 0.42 + (gas ? 900 : 0), t, 0.05);
    this.eMix.gain.setTargetAtTime(gas ? 0.95 : 0.45, t, 0.08);
    if (active && gas && gf > st.gear && t > st.shiftT) { st.shiftT = t + 0.14; this.hiss(0.3, 3200, 900, 0.1, 'bandpass', 0, 1.2); }
    if (active && st.gas && !gas && frac > 0.35 && sp > 0.25 && t > st.popT) { st.popT = t + 0.8; this.crackle(); }
    st.gear = gf; st.gas = gas;
    const shifting = t < st.shiftT;
    this.eGain.gain.setTargetAtTime(active ? (shifting ? 0.03 : 0.065 + (gas ? 0.05 : 0) + frac * 0.02) : 0, t, shifting ? 0.02 : 0.08);
    this.iFilt.frequency.setTargetAtTime(600 + rpm * 0.35, t, 0.05);
    this.iGain.gain.setTargetAtTime(active ? (gas ? 0.02 + frac * 0.03 : 0.006) : 0, t, 0.08);
    this.turbo.frequency.setTargetAtTime(1700 + rpm * 0.55, t, 0.1);
    this.tGain.gain.setTargetAtTime(active && gas ? frac * 0.011 : 0, t, 0.15);
    this.scrGain.gain.setTargetAtTime(active ? scrape * 0.18 : 0, t, 0.03);
  },
  // exhaust crackle on lift-off: a few sharp, uneven pops
  crackle() {
    const n = 4 + ((Math.random() * 4) | 0);
    for (let i = 0; i < n; i++) { const d = 0.04 + i * (0.06 + Math.random() * 0.07); this.hiss(0.05, 1500, 450, 0.22 + Math.random() * 0.12, 'lowpass', d); this.tone('square', 95, 48, 0.045, 0.07, d); }
  },
  tone(type, f0, f1, dur, vol, delay, dest) {
    const c = this.ctx; if (!c) return; const t = c.currentTime + (delay || 0);
    const o = c.createOscillator(), g = c.createGain(); o.type = type; o.frequency.setValueAtTime(f0, t);
    if (f1 !== f0) o.frequency.exponentialRampToValueAtTime(Math.max(20, f1), t + dur);
    g.gain.setValueAtTime(vol, t); g.gain.exponentialRampToValueAtTime(0.0008, t + dur);
    o.connect(g); g.connect(dest || this.sfx); o.start(t); o.stop(t + dur + 0.02);
  },
  hiss(dur, f0, f1, vol, type, delay, q) {
    const c = this.ctx; if (!c) return; const t = c.currentTime + (delay || 0);
    const s = c.createBufferSource(); s.buffer = this.noise; const fl = c.createBiquadFilter(); fl.type = type || 'bandpass'; fl.Q.value = q || 1;
    fl.frequency.setValueAtTime(f0, t); if (f1 !== f0) fl.frequency.exponentialRampToValueAtTime(f1, t + dur);
    const g = c.createGain(); g.gain.setValueAtTime(vol, t); g.gain.exponentialRampToValueAtTime(0.0008, t + dur);
    s.connect(fl); fl.connect(g); g.connect(this.sfx); s.start(t, Math.random() * 0.5); s.stop(t + dur + 0.02);
  },
  play(name, vol) {
    if (!this.ctx || !this.on) return; const v = vol == null ? 1 : vol;
    switch (name) {
      case 'pickup': this.tone('sine', 880, 880, 0.08, 0.25 * v); this.tone('sine', 1320, 1320, 0.12, 0.22 * v, 0.07); break;
      case 'eagle': this.hiss(0.7, 600, 3200, 0.35 * v, 'bandpass', 0, 2); this.tone('sawtooth', 1400, 500, 0.5, 0.08 * v); break;
      case 'bolt': this.tone('square', 1600, 180, 0.22, 0.12 * v); this.hiss(0.15, 4000, 2000, 0.15 * v, 'highpass'); break;
      case 'barge': this.tone('sine', 110, 38, 0.6, 0.6 * v); this.hiss(0.5, 400, 120, 0.4 * v, 'lowpass'); break;
      case 'mine': this.tone('sine', 220, 70, 0.2, 0.4 * v); this.hiss(0.08, 2000, 800, 0.2 * v); break;
      case 'shock': for (let i = 0; i < 6; i++) this.hiss(0.06, 5000, 3000, 0.25 * v, 'highpass', i * 0.07); this.tone('sawtooth', 90, 60, 0.5, 0.15 * v); break;
      case 'nitro': this.hiss(0.9, 300, 3500, 0.35 * v, 'bandpass', 0, 1.5); break;
      case 'brake': this.hiss(0.5, 2600, 1800, 0.3 * v, 'bandpass', 0, 4); break;
      case 'shield': this.tone('sine', 660, 990, 0.5, 0.15 * v); this.tone('sine', 990, 1480, 0.6, 0.1 * v, 0.05); break;
      case 'repair': for (let i = 0; i < 5; i++) this.hiss(0.03, 3000, 3000, 0.25 * v, 'bandpass', i * 0.07, 6); this.tone('sine', 1047, 1047, 0.3, 0.16 * v, 0.38); this.tone('sine', 1568, 1568, 0.4, 0.14 * v, 0.48); break;
      case 'hit': this.hiss(0.35, 1200, 200, 0.55 * v, 'lowpass'); this.tone('sine', 140, 50, 0.3, 0.45 * v); break;
      case 'boom': this.hiss(1.2, 900, 60, 0.7 * v, 'lowpass'); this.tone('sine', 90, 30, 0.9, 0.6 * v); break;
      case 'bump': this.tone('sine', 120, 60, 0.12, 0.35 * v); this.hiss(0.1, 900, 300, 0.2 * v, 'lowpass'); break;
      case 'wall': this.hiss(0.18, 2200, 900, 0.25 * v, 'bandpass', 0, 2); break;
      case 'beep': this.tone('square', 660, 660, 0.16, 0.12 * v); break;
      case 'go': this.tone('square', 990, 990, 0.45, 0.14 * v); this.tone('square', 1485, 1485, 0.45, 0.06 * v); break;
      case 'lap': this.tone('triangle', 784, 784, 0.15, 0.2 * v); this.tone('triangle', 1175, 1175, 0.3, 0.2 * v, 0.12); break;
      case 'finish': [523, 659, 784, 1047, 784, 1047].forEach((f, i) => this.tone('square', f, f, i === 5 ? 0.6 : 0.14, 0.09 * v, i * 0.13)); break;
      case 'denied': this.tone('square', 150, 120, 0.25, 0.12 * v); break;
      case 'ui': this.tone('triangle', 880, 660, 0.06, 0.12 * v); break;
      case 'cycle': this.tone('triangle', 520, 780, 0.07, 0.12 * v); break;
    }
  },
  // 7/8 (3+2+2) groove in D hijaz, played by a reedy lead over tapan
  startMusic() {
    if (this.musTimer) return;
    const c = this.ctx, step = 0.135; this.mStep = 0; this.mNext = c.currentTime + 0.1;
    const mtof = (m) => 440 * Math.pow(2, (m - 69) / 12);
    const mel = [
      69, -1, -1, 67, -1, 66, -1, 67, 69, 70, 69, -1, 67, -1, 66, -1, -1, 63, -1, 62, -1, 63, 66, 67, 66, -1, 63, -1,
      74, -1, 72, 70, -1, 69, -1, 70, 72, 70, 69, -1, 67, -1, 66, 67, 69, 67, -1, 66, -1, 63, 62, -1, -1, -1, -1, -1,
    ];
    const bass = [50, 0, 0, 57, 0, 50, 0];
    const kick = [1, 0, 0, 1, 0, 1, 0], tek = [0, 1, 1, 0, 1, 0, 1];
    const lead = (f, t, d) => {
      const o = c.createOscillator(), o2 = c.createOscillator(), fl = c.createBiquadFilter(), g = c.createGain(), lfo = c.createOscillator(), lg = c.createGain();
      o.type = 'square'; o2.type = 'sawtooth'; o.frequency.value = f; o2.frequency.value = f * 1.003;
      lfo.frequency.value = 6.2; lg.gain.value = f * 0.012; lfo.connect(lg); lg.connect(o.frequency); lg.connect(o2.frequency);
      fl.type = 'lowpass'; fl.frequency.value = 2400; fl.Q.value = 2;
      g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.11, t + 0.02); g.gain.setValueAtTime(0.1, t + d * 0.7); g.gain.exponentialRampToValueAtTime(0.0008, t + d);
      o.connect(fl); o2.connect(fl); fl.connect(g); g.connect(this.mus);
      o.start(t); o2.start(t); lfo.start(t); o.stop(t + d + 0.05); o2.stop(t + d + 0.05); lfo.stop(t + d + 0.05);
    };
    const tick = () => {
      if (!this.ctx) return;
      while (this.mNext < c.currentTime + 0.25) {
        const t = this.mNext, i = this.mStep, b = i % 7;
        if (kick[b]) { const o = c.createOscillator(), g = c.createGain(); o.type = 'sine'; o.frequency.setValueAtTime(130, t); o.frequency.exponentialRampToValueAtTime(42, t + 0.16); g.gain.setValueAtTime(0.55, t); g.gain.exponentialRampToValueAtTime(0.001, t + 0.2); o.connect(g); g.connect(this.mus); o.start(t); o.stop(t + 0.22); }
        if (tek[b]) { const s = c.createBufferSource(); s.buffer = this.noise; const fl = c.createBiquadFilter(); fl.type = 'bandpass'; fl.frequency.value = 2600; fl.Q.value = 2.5; const g = c.createGain(); g.gain.setValueAtTime(b === 1 || b === 4 ? 0.22 : 0.14, t); g.gain.exponentialRampToValueAtTime(0.001, t + 0.05); s.connect(fl); fl.connect(g); g.connect(this.mus); s.start(t, Math.random() * 0.5); s.stop(t + 0.06); }
        if (bass[b]) { const o = c.createOscillator(), g = c.createGain(); o.type = 'triangle'; o.frequency.value = mtof(bass[b] - 12 + (Math.floor(i / 28) % 2 && b === 3 ? 2 : 0)); g.gain.setValueAtTime(0.28, t); g.gain.exponentialRampToValueAtTime(0.001, t + step * 1.8); o.connect(g); g.connect(this.mus); o.start(t); o.stop(t + step * 2); }
        const m = mel[i % mel.length];
        if (m > 0 && Math.floor(i / mel.length) % 3 !== 2) { let d = 1; while (mel[(i + d) % mel.length] === -1 && d < 4) d++; lead(mtof(m), t, step * d * 0.95); }
        this.mStep++; this.mNext += step;
      }
    };
    this.musTimer = setInterval(tick, 60);
  },
};
