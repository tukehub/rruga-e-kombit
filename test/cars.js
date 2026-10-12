const { chromium } = require('/opt/npm-tools/node_modules/playwright');
const path = require('path');
(async () => {
  const b = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const page = await (await b.newContext({ viewport: { width: 640, height: 360 } })).newPage();
  const errs = []; page.on('pageerror', e => errs.push(e.message));
  await page.addInitScript(() => { window.__noAdapt = true; });
  await page.goto('file://' + path.join(__dirname, '../www/index.html')); await page.waitForTimeout(2000);
  await page.evaluate(() => { document.getElementById('scr-title').hidden = true; });
  const paints = ['#e41e20', '#2a6fdb', '#f2c230', '#f1eee8', '#3f6d3b', '#26262c'];
  for (let i = 0; i < 6; i++) {
    for (const [ang, tag] of [[0.9, 'f'], [3.6, 'r']]) {
      await page.evaluate(([i, p, ang]) => { const R = __rk; R.SET.car = i; R.SET.paint = p; R.G.garage.t = ang / 0.32; }, [i, paints[i], ang]);
      await page.evaluate(() => { window.__gc && 0; });
      await page.evaluate(() => { const g = __rk.G.garage; }); 
      await page.evaluate(() => window.__garageCar && window.__garageCar());
      await page.waitForTimeout(700);
      await page.screenshot({ path: `${__dirname}/shots/car${i}${tag}.png` });
    }
  }
  console.log(errs.length ? errs : 'no errors'); await b.close();
})();
