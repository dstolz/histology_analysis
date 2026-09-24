// Render an SVG from this folder's generators to a 2x PNG.
//   node browser_layout.js ../browser-layout.svg && node shot.js ../browser-layout.svg ../browser-layout.png
// Needs the playwright package and a Chromium it can launch.
const { chromium } = require('playwright');
const fs = require('fs');
(async () => {
  const b = await chromium.launch();
  const svg = fs.readFileSync(process.argv[2], 'utf8');
  const m = svg.match(/viewBox="0 0 (\d+) (\d+)"/);
  const p = await b.newPage({ viewport: { width: +m[1], height: +m[2] }, deviceScaleFactor: 2 });
  await p.setContent(`<html><body style="margin:0">${svg}</body></html>`);
  await p.screenshot({ path: process.argv[3], timeout: 60000 });
  await b.close();
})();
