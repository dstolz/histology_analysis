// Generates images/browser-layout.svg: a schematic of the HistologyImageBrowser
// window, laid out from buildUI.m and the build*Panel.m files. Labels are copied
// from the code; tile captions use sections from tests/make_test_dataset.m.
const fs = require('fs');
const out = [];
const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const W = 1240, H = 800;
const C = {
  bg: '#ffffff', win: '#f3f4f6', panel: '#ffffff', border: '#c9ced6', title: '#1f2937',
  text: '#1f2937', muted: '#6b7280', ctl: '#f9fafb', ctlb: '#9aa3af', btn: '#e5e7eb',
  accent: '#2563eb', callout: '#d9480f', tileBg: '#d1d5db', tile: '#1b1b1b'
};
const rect = (x, y, w, h, o = {}) => out.push(`<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${o.rx ?? 3}" fill="${o.fill ?? C.ctl}" stroke="${o.stroke ?? C.ctlb}" stroke-width="${o.sw ?? 1}"${o.dash ? ` stroke-dasharray="${o.dash}"` : ''}/>`);
const text = (x, y, s, o = {}) => out.push(`<text x="${x}" y="${y}" font-size="${o.size ?? 11}" fill="${o.fill ?? C.text}"${o.bold ? ' font-weight="600"' : ''}${o.anchor ? ` text-anchor="${o.anchor}"` : ''}${o.italic ? ' font-style="italic"' : ''}>${esc(s)}</text>`);
const btn = (x, y, w, s, o = {}) => { rect(x, y, w, 20, { fill: o.disabled ? '#f3f4f6' : C.btn, stroke: C.ctlb }); text(x + w / 2, y + 14, s, { anchor: 'middle', fill: o.disabled ? '#a0a6ae' : C.text, size: 10.5 }); };
const dd = (x, y, w, s) => { rect(x, y, w, 20, { fill: '#fff' }); text(x + 5, y + 14, s, { size: 10.5 }); out.push(`<path d="M${x + w - 12} ${y + 8} l4 5 l4 -5" fill="none" stroke="${C.muted}" stroke-width="1.3"/>`); };
const field = (x, y, w, s, o = {}) => { rect(x, y, w, 20, { fill: '#fff' }); text(o.right ? x + w - 5 : x + 5, y + 14, s, { size: 10.5, fill: o.ph ? C.muted : C.text, italic: o.ph, anchor: o.right ? 'end' : undefined }); };
const chk = (x, y, s, on) => { rect(x, y + 4, 12, 12, { fill: '#fff', rx: 2 }); if (on) out.push(`<path d="M${x + 2.5} ${y + 10} l3 3 l5 -6" fill="none" stroke="${C.accent}" stroke-width="1.8"/>`); text(x + 17, y + 14, s, { size: 10.5 }); };
const lbl = (x, y, s, o = {}) => text(x, y + 14, s, { size: 10.5, ...o });
const panel = (x, y, w, h, t) => { rect(x, y, w, h, { fill: C.panel, stroke: C.border, rx: 4 }); text(x + 8, y + 15, t, { bold: true, size: 11.5 }); };
const callout = (x, y, n) => { out.push(`<circle cx="${x}" cy="${y}" r="10" fill="${C.callout}"/>`); text(x, y + 4, n, { anchor: 'middle', fill: '#fff', bold: true, size: 11 }); };

out.push(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" font-family="Segoe UI, Helvetica, Arial, sans-serif">`);
rect(0, 0, W, H, { fill: C.bg, stroke: 'none', rx: 0 });
// window chrome
rect(10, 10, W - 20, H - 44, { fill: C.win, stroke: '#9aa3af', rx: 6 });
out.push(`<rect x="10" y="10" width="${W - 20}" height="26" rx="6" fill="#e5e7eb"/>`);
text(22, 28, 'Histology Image Browser  -  D:/GM6001_HISTOLOGY/', { size: 12, bold: true });
// menu bar
out.push(`<rect x="11" y="36" width="${W - 22}" height="20" fill="#fafafa"/>`);
['Dataset', 'Display', 'View', 'Help'].forEach((m, i) => text(22 + i * 62, 50, m, { size: 11 }));

// ---------- Left column: Look Up / Sections / Review ----------
const LX = 18, LW = 400;
panel(LX, 62, LW, 262, 'Look Up');
text(LX + 10, 94, 'Tracker: published sheet set (gid 1084786865)', { fill: C.accent, size: 10.5 });
field(LX + 10, 100, LW - 20, 'Search subject, section, stain, notes...', { ph: true });
const colW = [(LW - 20 - 24) * 1.7 / 4.7, (LW - 20 - 24) * 0.9 / 4.7, (LW - 20 - 24) * 1.2 / 4.7, (LW - 20 - 24) * 0.9 / 4.7];
let cx = LX + 10; const colX = [];
colW.forEach(w => { colX.push(cx); cx += w + 8; });
['Subject', 'Hemisphere', 'Stain', 'Atlas plate'].forEach((s, i) => lbl(colX[i], 124, s, { bold: true }));
colX.forEach((x, i) => { rect(x, 144, colW[i], 118, { fill: '#fff' }); for (let r = 0; r < 5; r++) out.push(`<rect x="${x + 5}" y="${152 + r * 20}" width="${colW[i] * (0.45 + 0.1 * ((r + i) % 4))}" height="7" rx="2" fill="#e5e7eb"/>`); });
chk(colX[0], 268, 'Only with profiles', false);
lbl(colX[2] + colW[2] - 42, 268, 'Sort by');
dd(colX[3], 268, colW[3], 'Subject, s…');
lbl(colX[0], 294, 'No dataset loaded.', { fill: C.muted });
btn(colX[3], 294, colW[3], 'Reset');
callout(LX + LW - 6, 66, '1');

panel(LX, 330, LW, 330, 'Sections');
const heads = [['Subject', 56], ['Section', 48], ['Hemi', 36], ['Stain', 56], ['Plate', 36], ['Prof', 32], ['ROI', 60], ['Images', 40], ['Status', 20]];
let hx = LX + 8; rect(LX + 8, 350, LW - 16, 276, { fill: '#fff' });
out.push(`<rect x="${LX + 8.5}" y="350.5" width="${LW - 17}" height="20" fill="#eef0f3"/>`);
heads.forEach(([h, w]) => { text(hx + 4, 364, h, { size: 10, bold: true }); hx += w * (LW - 16) / 384; });
for (let r = 0; r < 12; r++) {
  const y = 376 + r * 20.5;
  if (r === 2 || r === 3) out.push(`<rect x="${LX + 9}" y="${y - 3}" width="${LW - 18}" height="20" fill="#dbeafe"/>`);
  let x = LX + 8;
  heads.forEach(([h, w], i) => { out.push(`<rect x="${x + 4}" y="${y + 4}" width="${Math.max(10, w * (LW - 16) / 384 * (0.35 + 0.1 * ((r * 3 + i) % 5)))}" height="7" rx="2" fill="${r === 2 || r === 3 ? '#93c5fd' : '#e5e7eb'}"/>`); x += w * (LW - 16) / 384; });
}
const sb = ['< Prev', 'Next >', 'Select All', 'Open Folder', 'Columns...'];
const bw = (LW - 16 - 16) / 5;
sb.forEach((s, i) => btn(LX + 8 + i * (bw + 4), 632, bw, s));
callout(LX + LW - 6, 334, '2');

panel(LX, 666, LW, 84, 'Review');
lbl(LX + 8, 686, 'Atlas plate'); field(LX + 70, 686, 50, ''); btn(LX + 124, 686, 50, 'Set');
btn(LX + 180, 686, 130, 'Mark Measured'); btn(LX + 316, 686, 76, 'Clear');
text(LX + 8, 726, '(summary of the selection, or why the buttons are off)', { size: 10, fill: C.muted, italic: true });
callout(LX + LW - 6, 670, '3');

// ---------- Right column: Display / Images / Profiles ----------
const RX = 426, RW = W - 18 - RX;
panel(RX, 62, RW, 196, 'Display');
let y = 82;
// row 1
lbl(RX + 8, y, 'Image'); dd(RX + 44, y, 84, 'Projection');
lbl(RX + 136, y, 'Channel'); dd(RX + 182, y, 84, 'Channel 1');
lbl(RX + 274, y, 'Colormap'); dd(RX + 328, y, 66, 'gray');
lbl(RX + 402, y, 'Contrast %'); field(RX + 464, y, 40, '0.5', { right: true }); field(RX + 508, y, 40, '99.7', { right: true });
lbl(RX + 556, y, 'Max tiles'); field(RX + 608, y, 34, '12', { right: true });
lbl(RX + 650, y, 'Background'); dd(RX + 716, y, RW - 724, 'Light gray');
// row 2
y += 28;
chk(RX + 8, y, 'Line ROI', true); chk(RX + 92, y, 'Sampling band', true); chk(RX + 204, y, 'Shade ROI by intensity', true);
lbl(RX + 362, y, 'Profiles'); dd(RX + 408, y, 104, 'Below images');
lbl(RX + 520, y, 'Size %'); field(RX + 562, y, 34, '33', { right: true });
btn(RX + RW - 200, y, 94, 'Open in Figure'); btn(RX + RW - 102, y, 94, 'Export View');
// row 3
y += 28;
lbl(RX + 8, y, 'ROI'); dd(RX + 46, y, 70, 'A');
btn(RX + 124, y, 90, 'Add ROI'); btn(RX + 220, y, 100, 'Name ROIs...');
text(RX + 330, y + 14, 'ROI names / list of this section\u2019s ROIs', { size: 10, fill: C.muted, italic: true });
// row 4
y += 28;
rect(RX + 8, y, 90, 20, { fill: C.btn }); text(RX + 53, y + 14, 'Edit ROI', { anchor: 'middle', size: 10.5 });
lbl(RX + 106, y, 'Width px'); field(RX + 158, y, 56, '994', { right: true });
btn(RX + 222, y, 90, 'Draw Line'); btn(RX + 318, y, 90, 'Save ROI', { disabled: true }); btn(RX + 414, y, 80, 'Revert', { disabled: true });
chk(RX + 504, y, 'Band grid', false);
text(RX + 600, y + 14, 'ROI hint: names the target section', { size: 10, fill: C.muted, italic: true });
// row 5
y += 28;
chk(RX + 8, y, 'Brain surface', true); btn(RX + 118, y, 80, 'Detect', { disabled: true }); btn(RX + 204, y, 100, 'Mark Surface', { disabled: true }); btn(RX + 310, y, 70, 'Clear', { disabled: true });
// row 6
y += 28;
lbl(RX + 8, y, 'Normalize'); dd(RX + 68, y, 120, 'Raw intensity');
lbl(RX + 196, y, 'over'); dd(RX + 226, y, 96, 'Each trace');
lbl(RX + 332, y, 'Distance'); dd(RX + 386, y, 116, 'As measured');
callout(RX + RW - 6, 66, '4');

// Images panel
const IY = 264, IH = 330;
panel(RX, IY, RW, IH, 'Images');
out.push(`<rect x="${RX + 1}" y="${IY + 22}" width="${RW - 2}" height="${IH - 23}" fill="${C.tileBg}"/>`);
const tiles = [
  ['1174 1A L WFA-PV | plate 28', '#0072bd', -62], ['1174 1A R WFA-PV | plate 28', '#e8883a', -118],
  ['1174 2B L NeuN-DAPI | plate 34', '#edc948', -48], ['2087 3A L WFA-PV | plate 40', '#a55fbf', -70],
  ['2087 3A R WFA-PV | plate 40', '#77ac30', -110], ['2087 4C L NeuN-DAPI | plate 46', '#4dbeee', -132]];
const tw = (RW - 24) / 3, th = (IH - 38) / 2;
tiles.forEach(([t, col, ang], i) => {
  const x = RX + 8 + (i % 3) * (tw + 4), yy = IY + 28 + Math.floor(i / 3) * (th + 4);
  rect(x, yy, tw, th, { fill: C.tile, stroke: col, sw: i === 0 ? 3 : 1.5, rx: 0 });
  // tissue blob
  out.push(`<ellipse cx="${x + tw * 0.55}" cy="${yy + th * 0.62}" rx="${tw * 0.36}" ry="${th * 0.34}" fill="#3a3a3a"/>`);
  out.push(`<ellipse cx="${x + tw * 0.55}" cy="${yy + th * 0.64}" rx="${tw * 0.30}" ry="${th * 0.27}" fill="#4a4a4a"/>`);
  // line ROI with band
  const a = ang * Math.PI / 180, L = th * 0.34;
  const x1 = x + tw * 0.55 + Math.cos(a) * L * 1.1, y1 = yy + th * 0.62 + Math.sin(a) * L * 1.1;
  const x2 = x + tw * 0.55 + Math.cos(a) * L * 0.1, y2 = yy + th * 0.62 + Math.sin(a) * L * 0.1;
  const nx = -Math.sin(a) * 9, ny = Math.cos(a) * 9;
  out.push(`<polygon points="${x1 + nx},${y1 + ny} ${x2 + nx},${y2 + ny} ${x2 - nx},${y2 - ny} ${x1 - nx},${y1 - ny}" fill="none" stroke="${col}" stroke-width="1"/>`);
  out.push(`<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${col}" stroke-width="1.5"/>`);
  out.push(`<circle cx="${x1}" cy="${y1}" r="3" fill="none" stroke="${col}" stroke-width="1.3"/>`);
  const label = i === 0 ? t + '  (ROI target)' : t;
  const lw = label.length * 5.3 + 8;
  out.push(`<rect x="${x + 3}" y="${yy + 3}" width="${lw}" height="15" fill="${i === 0 ? col : '#171717'}"/>`);
  text(x + 7, yy + 14, label, { size: 9.5, fill: i === 0 ? '#101010' : col, bold: i === 0 });
});
callout(RX + RW - 6, IY + 4, '5');

// Profiles panel
const PY = IY + IH + 6, PH = H - 44 - PY + 10 - 32;
panel(RX, PY, RW, PH, 'Profiles');
const ax = RX + 60, ay = PY + 26, aw = RW - 80, ah = PH - 62;
rect(ax, ay, aw, ah, { fill: '#fff', stroke: '#6b7280', rx: 0 });
for (let g = 1; g < 6; g++) out.push(`<line x1="${ax + aw * g / 6}" y1="${ay}" x2="${ax + aw * g / 6}" y2="${ay + ah}" stroke="#eceff3"/>`);
for (let g = 1; g < 4; g++) out.push(`<line x1="${ax}" y1="${ay + ah * g / 4}" x2="${ax + aw}" y2="${ay + ah * g / 4}" stroke="#eceff3"/>`);
tiles.forEach(([, col], i) => {
  const pts = [];
  for (let k = 0; k <= 60; k++) {
    const u = k / 60, edge = 0.12 + 0.02 * i;
    const v = u < edge ? 0.08 : 0.25 + 0.55 * Math.exp(-((u - (0.35 + 0.03 * i)) ** 2) / 0.05) + 0.1 * (1 - u) * (i % 3) / 2;
    pts.push(`${ax + u * aw},${ay + ah - v * ah * 0.95}`);
  }
  out.push(`<polyline points="${pts.join(' ')}" fill="none" stroke="${col}" stroke-width="1.4"/>`);
});
text(ax + aw / 2, ay + ah + 26, 'distance along line (\u00b5m)', { anchor: 'middle', size: 10.5 });
out.push(`<text transform="translate(${ax - 14},${ay + ah / 2}) rotate(-90)" font-size="10.5" text-anchor="middle" fill="${C.text}">intensity</text>`);
callout(RX + RW - 6, PY + 4, '6');

// status bar
const SY = H - 64;
rect(18, SY, W - 36, 20, { fill: '#fff', stroke: C.border, rx: 2 });
out.push(`<circle cx="30" cy="${SY + 10}" r="4" fill="#16a34a"/>`);
text(42, SY + 14, 'Idle. Choose Dataset > Root Folder, then Dataset > Load Dataset.', { size: 10.5 });
text(W - 26, SY + 14, '14:32:07', { size: 10.5, fill: C.muted, anchor: 'end' });
callout(W - 90, SY + 10, '7');

text(W / 2, H - 14, 'Schematic drawn from the layout code in @HistologyImageBrowser/build*.m \u2014 not a screenshot. Tile captions use sections from tests/make_test_dataset.m; image content and traces are illustrative.', { anchor: 'middle', size: 10.5, fill: C.muted, italic: true });
out.push('</svg>');
fs.writeFileSync(process.argv[2], out.join('\n'));
