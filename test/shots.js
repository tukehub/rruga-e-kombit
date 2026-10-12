// Headless visual check: menus + every (or selected) city mid-race. Usage: node test/shots.js [city,city] [quality]
const { chromium } = require('/opt/npm-tools/node_modules/playwright');
const path = require('path');
const only = process.argv[2] && process.argv[2] !== 'all' ? process.argv[2].split(',') : null;
const quality = process.argv[3] == null ? 2 : +process.argv[3];
const W = +(process.env.W || 844), H = +(process.env.H || 390);
(async () => {
  const b = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required'] });
  const page = await (await b.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 1 })).newPage();
  const errs = [];
  page.on('pageerror', e => errs.push('PAGEERROR ' + e.message + '\n' + (e.stack || '').split('\n').slice(0, 5).join('\n')));
  page.on('console', m => { if (m.type() === 'error' || m.type() === 'warning') errs.push(m.type() + ': ' + m.text().slice(0, 300)); });
  await page.addInitScript((q) => { window.__noAdapt = true; try { localStorage.setItem('kafshimAsfalti.v1', JSON.stringify({ quality: q })); } catch (e) { } }, quality);
  await page.goto('file://' + path.join(__dirname, '../www/index.html'));
  await page.waitForTimeout(2500);
  if (!only) {
    await page.screenshot({ path: __dirname + '/shots/00_title.png' });
    await page.click('#b-play'); await page.waitForTimeout(400); await page.click('#b-city-next'); await page.waitForTimeout(1200);
    await page.screenshot({ path: __dirname + '/shots/02_car.png' });
  }
  const cities = await page.evaluate(() => __rk.CITIES.map(c => c.id));
  for (let i = 0; i < cities.length; i++) {
    if (only && !only.includes(cities[i])) continue;
    const t0 = Date.now();
    await page.evaluate((i) => { __rk.SET.city = i; __rk.startRace(); }, i);
    await page.waitForFunction(() => __rk.G.state === 'intro', null, { timeout: 90000 });
    const build = Date.now() - t0;
    await page.evaluate(() => { __rk.G.introT = 9; });
    await page.waitForFunction(() => __rk.G.state === 'countdown', null, { timeout: 30000 });
    await page.evaluate(() => { __rk.G.cdT = 0.01; });
    await page.waitForFunction(() => __rk.G.state === 'race', null, { timeout: 30000 });
    const ff = (sec) => page.evaluate((sec) => { const G = __rk.G; G.player.autopilot = true; for (let k = 0; k < sec * 60; k++) { G.race.step(1 / 60); if (G.race.events.length > 400) G.race.events.length = 0; } G.snapCam = true; }, sec);
    await ff(8); await page.waitForTimeout(1500);
    await page.screenshot({ path: `${__dirname}/shots/${10 + i}_${cities[i]}_a.png` });
    await ff(22); await page.waitForTimeout(1500);
    await page.screenshot({ path: `${__dirname}/shots/${10 + i}_${cities[i]}_b.png` });
    const info = await page.evaluate(() => { const r = __rk.G.renderer || null; return { calls: window.__ren ? __ren.info.render.calls : -1, tris: window.__ren ? __ren.info.render.triangles : -1, place: __rk.G.player.place }; });
    console.log(cities[i].padEnd(12), 'build', build + 'ms', JSON.stringify(info));
  }
  console.log('ERRORS:', errs.length ? '\n' + [...new Set(errs)].join('\n') : 'none');
  await b.close();
})().catch(e => { console.error('FAIL', e); process.exit(1); });
