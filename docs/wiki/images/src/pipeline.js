const fs = require('fs');
const out = [];
const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const W = 1100, H = 560;
out.push(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" font-family="Segoe UI, Helvetica, Arial, sans-serif">`);
out.push(`<defs><marker id="a" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M0 0 L10 5 L0 10 z" fill="#4b5563"/></marker></defs>`);
out.push(`<rect width="${W}" height="${H}" fill="#ffffff"/>`);
const pal = { fiji: ['#fff4e6', '#e8590c'], browser: ['#e7f5ff', '#1c7ed6'], ecm: ['#ebfbee', '#2f9e44'], data: ['#f8f9fa', '#868e96'], r: ['#f3f0ff', '#7048e8'] };
const box = (x, y, w, h, kind, title, lines) => {
  const [f, s] = pal[kind];
  out.push(`<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="8" fill="${f}" stroke="${s}" stroke-width="1.6"${kind === 'data' ? ' stroke-dasharray="5 3"' : ''}/>`);
  out.push(`<text x="${x + w / 2}" y="${y + 20}" text-anchor="middle" font-size="12.5" font-weight="600" fill="#1f2937">${esc(title)}</text>`);
  lines.forEach((l, i) => out.push(`<text x="${x + w / 2}" y="${y + 38 + i * 15}" text-anchor="middle" font-size="10.5" fill="#374151"${l.startsWith('`') ? ' font-family="Consolas, Menlo, monospace"' : ''}>${esc(l.replace(/`/g, ''))}</text>`));
};
const arrow = (x1, y1, x2, y2, label, o = {}) => {
  out.push(`<path d="M${x1} ${y1} L${x2} ${y2}" stroke="#4b5563" stroke-width="1.5" fill="none" marker-end="url(#a)"${o.dash ? ' stroke-dasharray="5 4"' : ''}/>`);
  if (label) out.push(`<text x="${(x1 + x2) / 2 + (o.dx ?? 0)}" y="${(y1 + y2) / 2 + (o.dy ?? -5)}" text-anchor="middle" font-size="10" fill="#4b5563" font-style="italic">${esc(label)}</text>`);
};
// Row 1
box(20, 30, 190, 80, 'data', 'Zeiss acquisition', ['`.czi`', '+ exported `_proj` `_mid` `_composite`']);
box(270, 30, 230, 80, 'fiji', 'Fiji line measure', ['`MACRO_Batch_LineMeasure.ijm`', 'draw one line per section']);
box(560, 30, 230, 80, 'data', 'Sidecars beside each image', ['`<stem>_proj_roi.roi`', '`<stem>_proj_values.csv`']);
box(850, 30, 230, 80, 'data', 'Section tracker', ['Google Sheet (API or published)', 'or a CSV export']);
arrow(210, 70, 268, 70); arrow(500, 70, 558, 70);
// Row 2 browser
box(290, 170, 520, 120, 'browser', 'HistologyImageBrowser', ['catalog • filter • view tiles and profiles', 'edit / draw / add line ROIs • mark brain surface', 'review: atlas plate + Measured (Sheets API only)', '`launch_histology_browser(root, ...)`']);
arrow(675, 110, 600, 168, 'read', { dx: 22 });
arrow(965, 110, 760, 168, 'join by filename stem', { dx: 60 });
arrow(120, 110, 360, 168, 'catalog', { dx: -40 });
// write-backs
arrow(560, 168, 640, 112, '', { dash: true });
out.push(`<text x="535" y="148" font-size="10" fill="#1c7ed6" font-style="italic" text-anchor="end">Save ROI rewrites .roi + values.csv,</text>`);
out.push(`<text x="535" y="161" font-size="10" fill="#1c7ed6" font-style="italic" text-anchor="end">writes _roi_surface.json</text>`);
arrow(800, 190, 930, 112, '', { dash: true });
out.push(`<text x="880" y="165" font-size="10" fill="#1c7ed6" font-style="italic">writes Atlas plate / Measured</text>`);
// Row 3
box(290, 340, 520, 70, 'data', 'Table in the base workspace (one row per ROI)', ['Dataset > Export Selection to Workspace (Ctrl+Shift+E)', 'tokens, tracker columns, ROI geometry, surface, Profile {Distance, Intensity}']);
arrow(550, 290, 550, 338);
// Row 4
box(40, 460, 300, 80, 'ecm', 'Prepare + browse', ['`A = ecm_prepare_analysis_data(T, ...)`', '`B = launch_ecm_browser(A)`', 'align to surface, smooth, grid, compare']);
box(400, 460, 300, 80, 'data', 'Join experiment metadata (optional)', ['e.g. treatment per hemisphere', '(see `S_ECManalysis.m`)', 'save to .mat']);
box(760, 460, 320, 80, 'r', 'Statistics in R', ['`ecm_export_for_r(matFile, outDir)`', '→ profiles.csv + sections.csv', '→ `ecm_analysis.R` (lme4 models, HTML report)']);
arrow(550, 410, 550, 458); arrow(400, 500, 342, 500); arrow(700, 500, 758, 500);
out.push(`<text x="${W / 2}" y="${H - 4}" text-anchor="middle" font-size="10" fill="#6b7280" font-style="italic">Dashed arrows: files written back by the browser.</text>`);
out.push('</svg>');
fs.writeFileSync(process.argv[2], out.join('\n'));
