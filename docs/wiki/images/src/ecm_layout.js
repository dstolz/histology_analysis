// images/ecm-browser-layout.svg: schematic of the ECMBrowser window from
// ECM_Analysis/@ECMBrowser/buildUI.m and buildToolbar.m. Curves are illustrative.
const fs = require('fs');
const out = [];
const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const W = 1200, H = 760;
const T = (x, y, s, o = {}) => out.push(`<text x="${x}" y="${y}" font-size="${o.size ?? 11}" fill="${o.fill ?? '#1f2937'}"${o.bold ? ' font-weight="600"' : ''}${o.anchor ? ` text-anchor="${o.anchor}"` : ''}${o.italic ? ' font-style="italic"' : ''}>${esc(s)}</text>`);
const R = (x, y, w, h, o = {}) => out.push(`<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${o.rx ?? 3}" fill="${o.fill ?? '#fff'}" stroke="${o.stroke ?? '#9aa3af'}" stroke-width="${o.sw ?? 1}"/>`);
const dd = (x, y, w, s) => { R(x, y, w, 19); T(x + 5, y + 13.5, s, { size: 10.5 }); out.push(`<path d="M${x + w - 12} ${y + 7.5} l4 5 l4 -5" fill="none" stroke="#6b7280" stroke-width="1.3"/>`); };
const fld = (x, y, w, s) => { R(x, y, w, 19); T(x + w - 5, y + 13.5, s, { size: 10.5, anchor: 'end' }); };
const btn = (x, y, w, s) => { R(x, y, w, 20, { fill: '#e5e7eb' }); T(x + w / 2, y + 14, s, { size: 10.5, anchor: 'middle' }); };
const chk = (x, y, s, on) => { R(x, y + 3, 12, 12, { rx: 2 }); if (on) out.push(`<path d="M${x + 2.5} ${y + 9} l3 3 l5 -6" fill="none" stroke="#2563eb" stroke-width="1.8"/>`); T(x + 17, y + 13.5, s, { size: 10.5 }); };
const co = (x, y, n) => { out.push(`<circle cx="${x}" cy="${y}" r="10" fill="#d9480f"/>`); T(x, y + 4, n, { anchor: 'middle', fill: '#fff', bold: true }); };
out.push(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" font-family="Segoe UI, Helvetica, Arial, sans-serif">`);
out.push(`<rect width="${W}" height="${H}" fill="#ffffff"/>`);
R(10, 10, W - 20, H - 44, { fill: '#f3f4f6', rx: 6 });
out.push(`<rect x="10" y="10" width="${W - 20}" height="26" rx="6" fill="#e5e7eb"/>`);
T(22, 28, 'ECM Browser', { size: 12, bold: true });
out.push(`<rect x="11" y="36" width="${W - 22}" height="20" fill="#fafafa"/>`);
['Plot', 'Data', 'Export options'].forEach((m, i) => T(22 + [0, 50, 100][i], 50, m));
// control column
const CX = 18, CW = 290; let y = 62;
R(CX, y, CW, H - 44 - 62 - 44, { rx: 4 });
const head = (t, open) => { out.push(`<rect x="${CX + 4}" y="${y}" width="${CW - 8}" height="22" fill="#eef0f3"/>`); T(CX + 10, y + 15, (open ? '▾ ' : '▸ ') + t, { bold: true, size: 11.5 }); y += 26; };
y += 6;
head('Signal & scale', true);
const row = (l, fn) => { T(CX + 12, y + 13.5, l, { size: 10.5 }); fn(CX + 96, y, CW - 110); y += 24; };
row('Signal', (x, yy, w) => dd(x, yy, w, 'smoothed'));
row('Normalize', (x, yy, w) => dd(x, yy, w, 'none'));
row('Scope', (x, yy, w) => dd(x, yy, w, 'per section'));
row('Ref. min', (x, yy, w) => fld(x, yy, w, ''));
row('Ref. max', (x, yy, w) => fld(x, yy, w, ''));
head('Compare', false);
head('Plot', true);
row('Show', (x, yy, w) => dd(x, yy, w, 'group mean'));
row('Metric', (x, yy, w) => dd(x, yy, w, 'mean'));
row('Error band', (x, yy, w) => dd(x, yy, w, 'sem'));
chk(CX + 12, y, 'Sections behind the mean', true); y += 24;
row('Color by', (x, yy, w) => dd(x, yy, w, 'Treatment'));
row('Depth min', (x, yy, w) => fld(x, yy, w, ''));
row('Depth max', (x, yy, w) => fld(x, yy, w, ''));
head('Split', true);
T(CX + 12, y + 13.5, 'Tile by', { size: 10.5 }); R(CX + 96, y, CW - 110, 110);
['(none)', 'AtlasPlate', 'SubjectID', 'Treatment'].forEach((s, i) => { if (s === 'AtlasPlate') out.push(`<rect x="${CX + 97}" y="${y + 3 + i * 18}" width="${CW - 112}" height="17" fill="#dbeafe"/>`); T(CX + 102, y + 15 + i * 18, s, { size: 10.5 }); });
y += 118;
head('Filter', false); head('Layout', false); head('Configurations', false);
co(CX + CW - 6, 66, '1');
// toolbar
const PX = 318, PW = W - 18 - PX;
let tx = PX;
[['Copy plot', 70], ['Copy vector', 82], ['Save plot...', 80], null, ['Copy data', 72], ['Copy summary', 98], ['Copy code', 74], ['To workspace', 92], null, ['Pop out', 62], ['Reset', 52]].forEach(b => {
  if (!b) { out.push(`<line x1="${tx + 4}" y1="64" x2="${tx + 4}" y2="84" stroke="#9aa3af"/>`); tx += 10; return; }
  btn(tx, 63, b[1], b[0]); tx += b[1] + 4;
});
co(W - 28, 73, '2');
// plot area
const AY = 92, AH = H - 44 - AY - 44;
R(PX, AY, PW, AH, { rx: 2 });
T(PX + PW / 2, AY + 20, 'colored by Treatment', { anchor: 'middle', size: 12.5, bold: true });
T(PX + PW / 2, AY + 36, 'tiled by AtlasPlate', { anchor: 'middle', size: 11, fill: '#4b5563' });
const plates = [28, 29, 30, 31, 32, 34];
const cols = 3, gw = (PW - 80) / cols, gh = (AH - 110) / 2;
const grp = [['Vehicle', '#0072bd', 0], ['GM6001', '#d95319', 1]];
plates.forEach((p, i) => {
  const x = PX + 60 + (i % cols) * gw, yy = AY + 52 + Math.floor(i / cols) * gh;
  const ax = x + 6, ay = yy + 18, aw = gw - 22, ah = gh - 42;
  T(ax + aw / 2, yy + 12, `AtlasPlate ${p}`, { anchor: 'middle', size: 11, bold: true });
  R(ax, ay, aw, ah, { rx: 0, stroke: '#6b7280' });
  grp.forEach(([g, c, k]) => {
    const top = [], bot = [], mid = [], secs = [[], [], []];
    for (let s = 0; s <= 50; s++) {
      const u = s / 50;
      const v = 0.25 + (0.5 - 0.12 * k) * Math.exp(-((u - 0.22 - 0.02 * (i % 3)) ** 2) / 0.02) + 0.12 * Math.exp(-((u - 0.7) ** 2) / 0.01) - 0.1 * u;
      const e = 0.05 + 0.02 * k;
      const X = ax + u * aw, Y = v => ay + ah - v * ah * 0.95;
      mid.push(`${X},${Y(v)}`); top.push(`${X},${Y(v + e)}`); bot.unshift(`${X},${Y(v - e)}`);
      secs.forEach((arr, j) => arr.push(`${X},${Y(v + (j - 1) * 0.07 * Math.sin(u * 9 + j + k))}`));
    }
    secs.forEach(a => out.push(`<polyline points="${a.join(' ')}" fill="none" stroke="${c}" stroke-opacity="0.25" stroke-width="1"/>`));
    out.push(`<polygon points="${top.concat(bot).join(' ')}" fill="${c}" fill-opacity="0.2"/>`);
    out.push(`<polyline points="${mid.join(' ')}" fill="none" stroke="${c}" stroke-width="2"/>`);
  });
  // per-tile legend
  grp.forEach(([g, c], k) => { out.push(`<line x1="${ax + aw - 86}" y1="${ay + 10 + k * 13}" x2="${ax + aw - 70}" y2="${ay + 10 + k * 13}" stroke="${c}" stroke-width="2"/>`); T(ax + aw - 66, ay + 14 + k * 13, `${g} (n=…)`, { size: 9 }); });
});
T(PX + PW / 2, AY + AH - 12, 'depth from cortical surface (µm)', { anchor: 'middle', size: 11 });
out.push(`<text transform="translate(${PX + 22},${AY + AH / 2}) rotate(-90)" font-size="11" text-anchor="middle" fill="#1f2937">smoothed intensity</text>`);
co(W - 28, AY + 12, '3');
// status line
const SY = H - 44 - 36;
R(18, SY, W - 36, 24, { rx: 2 });
T(26, SY + 16, 'N of M sections | n tile(s) | G group(s)', { size: 10.5 });
co(W - 40, SY + 12, '4');
T(W / 2, H - 14, 'Schematic drawn from the layout code in ECM_Analysis/@ECMBrowser/buildUI.m and buildToolbar.m — not a screenshot. Plate numbers and curves are illustrative.', { anchor: 'middle', size: 10.5, fill: '#6b7280', italic: true });
out.push('</svg>');
fs.writeFileSync(process.argv[2], out.join('\n'));
