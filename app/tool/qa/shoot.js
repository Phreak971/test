// Visual QA harness: serves build/web and screenshots app states.
// Usage: node tool/qa/shoot.js <outDir> [scenario...]
// Scenarios are defined in scenarios.js. Requires `flutter build web` first.
const { chromium } = require('playwright');
const http = require('http');
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '../../build/web');
const types = { '.html': 'text/html', '.js': 'application/javascript', '.mjs': 'application/javascript', '.json': 'application/json', '.png': 'image/png', '.wasm': 'application/wasm', '.ttf': 'font/ttf', '.otf': 'font/otf', '.css': 'text/css', '.svg': 'image/svg+xml' };

function serve() {
  return new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      let p = decodeURIComponent(req.url.split('?')[0]);
      if (p === '/') p = '/index.html';
      const f = path.join(root, p);
      if (!f.startsWith(root) || !fs.existsSync(f) || fs.statSync(f).isDirectory()) { res.writeHead(404); return res.end(); }
      res.writeHead(200, { 'Content-Type': types[path.extname(f)] || 'application/octet-stream' });
      fs.createReadStream(f).pipe(res);
    });
    server.listen(0, () => resolve(server));
  });
}

/** Opens the app with persisted settings/places and a fake GPS position. */
async function openApp(browser, base, { settings, places, geo = { latitude: 40.758, longitude: -73.9855 }, viewport = { width: 390, height: 844 }, locale = 'en-US' } = {}) {
  const ctx = await browser.newContext({ viewport, deviceScaleFactor: 2, geolocation: geo, permissions: ['geolocation'], locale, isMobile: true, hasTouch: true });
  await ctx.addInitScript(({ settings, places }) => {
    const put = (k, v) => localStorage.setItem('flutter.' + k, JSON.stringify(v));
    if (settings) put('settings.v1', JSON.stringify(settings));
    if (places) put('saved_places.v1', JSON.stringify(places));
  }, { settings, places });
  const page = await ctx.newPage();
  page.on('pageerror', (e) => console.log('PAGEERROR', e.message));
  page.on('console', (m) => { if (m.type() === 'error') console.log('CONSOLE', m.text().slice(0, 300)); });
  await page.goto(base);
  return { ctx, page };
}

const wait = (ms) => new Promise((r) => setTimeout(r, ms));

module.exports = { serve, openApp, wait };

if (require.main === module) {
  (async () => {
    const out = process.argv[2] || 'qa-out';
    fs.mkdirSync(out, { recursive: true });
    const server = await serve();
    const base = `http://127.0.0.1:${server.address().port}/`;
    const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
    const scenarios = require('./scenarios.js');
    const names = process.argv.slice(3);
    for (const s of scenarios.filter((s) => !names.length || names.includes(s.name))) {
      const { ctx, page } = await openApp(browser, base, s.open || {});
      try {
        await s.run(page, { wait, out, shot: (n) => page.screenshot({ path: path.join(out, `${s.name}${n ? '-' + n : ''}.png`) }) });
        console.log('OK', s.name);
      } catch (e) {
        console.log('FAIL', s.name, e.message);
        await page.screenshot({ path: path.join(out, `${s.name}-FAIL.png`) }).catch(() => {});
      }
      await ctx.close();
    }
    await browser.close();
    server.close();
  })();
}
