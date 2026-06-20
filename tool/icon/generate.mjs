// Renders logo.png to all Android launcher densities (legacy square + adaptive
// foreground) and writes a matched adaptive background color, using the
// Playwright/Chromium vendored under submission/intro/.render.
//   node tool/icon/generate.mjs
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';
import { mkdirSync, existsSync, writeFileSync, readFileSync } from 'node:fs';

const require = createRequire(import.meta.url);
const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');
const { chromium } = require(join(ROOT, 'submission', 'intro', '.render', 'node_modules', 'playwright'));

const RES = join(ROOT, 'android', 'app', 'src', 'main', 'res');
// Inline the logo as a same-origin data URL so the page can both render and
// sample it (a file:// image taints the canvas and blocks getImageData).
const DATA_URL =
  'data:image/png;base64,' + readFileSync(join(ROOT, 'logo.png')).toString('base64');

// density -> legacy launcher px / adaptive foreground px (108dp canvas)
const D = {
  'mdpi':    { legacy: 48,  fg: 108 },
  'hdpi':    { legacy: 72,  fg: 162 },
  'xhdpi':   { legacy: 96,  fg: 216 },
  'xxhdpi':  { legacy: 144, fg: 324 },
  'xxxhdpi': { legacy: 192, fg: 432 },
};

const browser = await chromium.launch();
const page = await browser.newPage({ deviceScaleFactor: 1 });

async function render(size) {
  await page.setViewportSize({ width: size, height: size });
  await page.setContent(
    `<style>*{margin:0;padding:0}body{background:transparent}` +
    `#logo{display:block;width:${size}px;height:${size}px;object-fit:cover}</style>` +
    `<img id="logo" src="${DATA_URL}">`,
  );
  await page.waitForFunction(() => {
    const i = document.getElementById('logo');
    return i && i.complete && i.naturalWidth > 0;
  });
}

async function shot(size, out) {
  await render(size);
  const el = await page.$('#logo');
  await el.screenshot({ path: out });
  console.log('  ✓', out.replace(ROOT + '\\', '').replace(ROOT + '/', ''));
}

for (const [den, px] of Object.entries(D)) {
  const dir = join(RES, `mipmap-${den}`);
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
  await shot(px.legacy, join(dir, 'ic_launcher.png'));
  await shot(px.legacy, join(dir, 'ic_launcher_round.png'));
  await shot(px.fg, join(dir, 'ic_launcher_foreground.png'));
}

// Sample the logo's corner so the adaptive-icon background blends seamlessly.
await render(256);
const bg = await page.evaluate(() => {
  const img = document.getElementById('logo');
  const c = document.createElement('canvas');
  c.width = img.naturalWidth; c.height = img.naturalHeight;
  const ctx = c.getContext('2d');
  ctx.drawImage(img, 0, 0);
  const p = ctx.getImageData(3, 3, 1, 1).data;
  const hex = (v) => v.toString(16).padStart(2, '0');
  return '#' + hex(p[0]) + hex(p[1]) + hex(p[2]);
});

const valuesDir = join(RES, 'values');
if (!existsSync(valuesDir)) mkdirSync(valuesDir, { recursive: true });
writeFileSync(
  join(valuesDir, 'ic_launcher_background.xml'),
  `<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <!-- Sampled from logo.png so the adaptive icon blends seamlessly. -->\n    <color name="ic_launcher_background">${bg.toUpperCase()}</color>\n</resources>\n`,
);
console.log('  ✓ values/ic_launcher_background.xml ->', bg.toUpperCase());

await browser.close();
console.log('done.');
