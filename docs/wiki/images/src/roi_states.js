// images/roi-states.svg: the four ROI save states as styled by
// @HistologyImageBrowser/roiStateStyle.m, plus the brain surface tick from drawRoiOverlay.m.
const fs = require('fs');
const out = [];
const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const rgb = a => `rgb(${a.map(v => Math.round(v * 255)).join(',')})`;
const W = 1000, H = 330;
out.push(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" font-family="Segoe UI, Helvetica, Arial, sans-serif">`);
out.push(`<rect width="${W}" height="${H}" fill="#ffffff"/>`);
const tileCol = [0, 0.447, 0.741]; // first tile color, lines(1) lifted; illustrative
const states = [
  { key: 'file', title: 'On disk', sub: 'read from the .roi file', color: [0.30, 0.62, 0.95], lw: 1.25, dash: '', badge: '', btext: '', surf: 'surface (auto)' },
  { key: 'clean', title: 'Editing, unchanged', sub: 'Edit ROI pressed, nothing moved', color: [1, 0.85, 0.10], lw: 1.75, dash: '', badge: 'ROI FROM FILE', btext: [0.1, 0.1, 0.1], surf: 'surface' },
  { key: 'dirty', title: 'Unsaved', sub: 'dragged, drawn, or surface moved', color: [1, 0.35, 0.10], lw: 3, dash: '8 5', badge: 'UNSAVED EDITS', badge2: 'UNSAVED - NEW ROI', btext: [1, 1, 1], surf: 'surface' },
  { key: 'saved', title: 'Saved', sub: 'Save ROI wrote .roi, values.csv, surface', color: [0.10, 0.70, 0.35], lw: 2.25, dash: '', badge: 'SAVED TO DISK', btext: [1, 1, 1], surf: 'surface' }];
const tw = 220, th = 190, gap = 24, x0 = (W - (4 * tw + 3 * gap)) / 2;
states.forEach((st, i) => {
  const x = x0 + i * (tw + gap), y = 44;
  out.push(`<text x="${x + tw / 2}" y="24" text-anchor="middle" font-size="14" font-weight="600" fill="#1f2937">${esc(st.title)}</text>`);
  out.push(`<text x="${x + tw / 2}" y="38" text-anchor="middle" font-size="10.5" fill="#6b7280">${esc(st.sub)}</text>`);
  out.push(`<rect x="${x}" y="${y}" width="${tw}" height="${th}" fill="#141414" stroke="${rgb(st.color)}" stroke-width="1.5"/>`);
  out.push(`<path d="M${x} ${y + th} L${x} ${y + 70} Q${x + tw * 0.5} ${y + 30} ${x + tw} ${y + 80} L${x + tw} ${y + th} Z" fill="#474747"/>`);
  const c = rgb(st.color);
  // line from background (top) down into tissue
  const x1 = x + tw * 0.46, y1 = y + 18, x2 = x + tw * 0.56, y2 = y + th - 16;
  const dx = x2 - x1, dy = y2 - y1, L = Math.hypot(dx, dy), nx = -dy / L * 16, ny = dx / L * 16;
  out.push(`<polygon points="${x1 + nx},${y1 + ny} ${x2 + nx},${y2 + ny} ${x2 - nx},${y2 - ny} ${x1 - nx},${y1 - ny}" fill="none" stroke="${c}" stroke-width="${Math.max(1, st.lw - 0.5)}"${st.dash ? ` stroke-dasharray="${st.dash}"` : ''}/>`);
  out.push(`<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${c}" stroke-width="${st.lw}"${st.dash ? ` stroke-dasharray="${st.dash}"` : ''}/>`);
  if (st.key === 'dirty') out.push(`<rect x="${x1 - 4}" y="${y1 - 4}" width="8" height="8" fill="none" stroke="${c}" stroke-width="1.5"/>`);
  else out.push(`<circle cx="${x1}" cy="${y1}" r="3.5" fill="none" stroke="${c}" stroke-width="1.5"/>`);
  // surface tick at where the line enters tissue
  const t = 0.25, sx = x1 + dx * t, sy = y1 + dy * t;
  out.push(`<line x1="${sx - nx}" y1="${sy - ny}" x2="${sx + nx}" y2="${sy + ny}" stroke="${c}" stroke-width="${st.lw + 1}"/>`);
  const lw = st.surf.length * 5 + 8;
  out.push(`<rect x="${sx - nx - lw / 2}" y="${sy - ny + 2}" width="${lw}" height="13" fill="${c}"/>`);
  out.push(`<text x="${sx - nx}" y="${sy - ny + 12}" text-anchor="middle" font-size="9" fill="${st.btext ? rgb(st.btext) : '#101010'}">${esc(st.surf)}</text>`);
  // badge chip below tile
  const by = y + th + 12;
  if (st.badge) {
    const bw = st.badge.length * 7 + 14;
    out.push(`<rect x="${x + tw / 2 - bw / 2}" y="${by}" width="${bw}" height="18" fill="${c}"/>`);
    out.push(`<text x="${x + tw / 2}" y="${by + 13}" text-anchor="middle" font-size="10.5" font-weight="700" fill="${rgb(st.btext)}">${esc(st.badge)}</text>`);
    if (st.badge2) {
      const bw2 = st.badge2.length * 7 + 14;
      out.push(`<text x="${x + tw / 2}" y="${by + 32}" text-anchor="middle" font-size="10" fill="#6b7280">or, for a line that has no file yet:</text>`);
      out.push(`<rect x="${x + tw / 2 - bw2 / 2}" y="${by + 38}" width="${bw2}" height="18" fill="${c}"/>`);
      out.push(`<text x="${x + tw / 2}" y="${by + 51}" text-anchor="middle" font-size="10.5" font-weight="700" fill="#ffffff">${esc(st.badge2)}</text>`);
    }
  } else {
    out.push(`<text x="${x + tw / 2}" y="${by + 13}" text-anchor="middle" font-size="10.5" fill="#6b7280">no badge; drawn in the tile's own color</text>`);
  }
});
out.push(`<text x="${W / 2}" y="${H - 10}" text-anchor="middle" font-size="10.5" font-style="italic" fill="#6b7280">Schematic of the styles in roiStateStyle.m and drawRoiOverlay.m (colors, weights, dashes, badge text) — not a screenshot.</text>`);
out.push('</svg>');
fs.writeFileSync(process.argv[2], out.join('\n'));
