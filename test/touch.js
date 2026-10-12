// Phone layout: tilt steering via synthetic devicemotion, gas/brake zones, centre fire button.
const { chromium } = require('/opt/npm-tools/node_modules/playwright');
const path = require('path');
(async () => {
  const b = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const ctx = await b.newContext({ viewport: { width: 800, height: 370 }, hasTouch: true, isMobile: true, deviceScaleFactor: 1 });
  const page = await ctx.newPage(); const errs = []; page.on('pageerror', e => errs.push(e.message));
  await page.addInitScript(() => { window.__noAdapt = true; try { Object.defineProperty(screen.orientation, 'angle', { get: () => 90, configurable: true }); } catch (e) { } });
  await page.goto('file://' + path.join(__dirname, '../www/index.html')); await page.waitForTimeout(2000);
  await page.screenshot({ path: __dirname + '/shots/t_title.png' });
  await page.evaluate(() => { __rk.SET.city = 7; __rk.startRace(); });
  await page.waitForFunction(() => __rk.G.state === 'intro', null, { timeout: 90000 });
  await page.evaluate(() => { __rk.G.introT = 9; }); await page.waitForFunction(() => __rk.G.state === 'countdown');
  await page.evaluate(() => { __rk.G.cdT = 0.01; }); await page.waitForFunction(() => __rk.G.state === 'race');
  const motion = (x, y, z) => page.evaluate(([x, y, z]) => window.dispatchEvent(new DeviceMotionEvent('devicemotion', { accelerationIncludingGravity: { x, y, z } })), [x, y, z]);
  const res = {};
  res.frame0 = await page.evaluate(() => __rk.G.t);
  await page.waitForTimeout(2000);
  res.frame1 = await page.evaluate(() => [__rk.G.t, __rk.G.state]);
  res.tiltClass = await page.evaluate(() => document.getElementById('app').classList.contains('tilt'));
  for (const [name, y] of [['right', 3.2], ['left', -3.2], ['level', 0.1]]) {
    for (let k = 0; k < 6; k++) { await motion(9.0, y, 2.0); await page.waitForTimeout(400); }
    res['steer_' + name] = await page.evaluate(() => +__rk.G.player.ctrl.steer.toFixed(2));
  }
  // gas zone hold
  const gz = await page.locator('#z-gas').boundingBox(), bz = await page.locator('#z-brake').boundingBox();
  await page.dispatchEvent('#z-gas', 'pointerdown', { pointerId: 11, pointerType: 'touch', clientX: gz.x + gz.width * 0.6, clientY: gz.y + gz.height * 0.5, isPrimary: true });
  await page.waitForTimeout(1500);
  res.gas = await page.evaluate(() => [__rk.IN.gasT, __rk.G.player.ctrl.gas]);
  await page.dispatchEvent('#z-gas', 'pointerup', { pointerId: 11, pointerType: 'touch' });
  await page.dispatchEvent('#z-brake', 'pointerdown', { pointerId: 12, pointerType: 'touch', clientX: bz.x + 40, clientY: bz.y + 60, isPrimary: true });
  await page.waitForTimeout(1500);
  res.brake = await page.evaluate(() => __rk.G.player.ctrl.brake);
  await page.dispatchEvent('#z-brake', 'pointerup', { pointerId: 12, pointerType: 'touch' });
  await page.waitForTimeout(1500);
  res.gasAfter = await page.evaluate(() => __rk.IN.gasT);
  // fire
  await page.evaluate(() => { const P = __rk.G.player; P.slots.push({ type: 'nitro', ammo: 1 }, { type: 'eagle', ammo: 1 }, { type: 'mine', ammo: 1 }); });
  await page.waitForTimeout(300);
  await page.screenshot({ path: __dirname + '/shots/t_race.png' });
  const fb = await page.locator('#t-fire').boundingBox();
  await page.touchscreen.tap(fb.x + fb.width / 2, fb.y + fb.height / 2); await page.waitForTimeout(2500);
  res.afterFire = await page.evaluate(() => ({ slots: __rk.G.player.slots.map(s => s.type), nitro: __rk.G.player.nitroT > 0 }));
  res.fireCenter = Math.round(fb.x + fb.width / 2) + '/' + 800;
  console.log(JSON.stringify(res), errs.length ? errs : 'no errors');
  await b.close();
})();
