// Garage close-ups of every car (front 3/4 and rear 3/4)
const { chromium } = require('/opt/npm-tools/node_modules/playwright');
const path = require('path');
(async () => {
  const b = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const page = await (await b.newContext({ viewport: { width: 640, height: 360 } })).newPage();
  const errs = []; page.on('pageerror', e => errs.push(e.message)); page.on('console', m => { if (m.type() === 'error') errs.push(m.text()); });
  await page.addInitScript(() => { window.__noAdapt = true; });
  await page.goto('file://' + path.join(__dirname, '../www/index.html')); await page.waitForTimeout(2500);
  await page.evaluate(() => { document.getElementById('scr-title').hidden = true; });
  const paints = ['#e41e20', '#26262c', '#f2c230', '#f1eee8', '#2a2a2e', '#f3f3ee'];
  for (let i = 0; i < 6; i++) {
    for (const [ang, tag] of [[0.75, 'f'], [3.75, 'r']]) {
      await page.evaluate(([i, p, ang]) => { const R = __rk; R.SET.car = i; R.SET.paint = p; window.__garageCar(); R.G.garage.t = ang / 0.32; }, [i, paints[i], ang]);
      await page.waitForTimeout(900);
      await page.screenshot({ path: `${__dirname}/shots/car${i}${tag}.png` });
    }
  }
  console.log(errs.length ? errs : 'no errors'); await b.close();
})();
