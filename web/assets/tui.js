// Shared helpers for every ARS page: box frames, API calls, formatting,
// and the airport picker.

const esc = s => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const inr = n => n == null ? '—' : '₹' + Math.round(n).toLocaleString('en-IN');
const isoDay = d => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
const addDays = n => new Date(Date.now() + n * 864e5);

// 'YYYY-MM-DDTHH:MM:SS' (airport-local, no zone) -> parts, never shifted
const stamp = s => ({ day: s.slice(0, 10), time: s.slice(11, 16) });
const MONTHS = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
const shortDay = s => `${s.slice(8, 10)} ${MONTHS[+s.slice(5, 7) - 1]}`;
const longDay = s => {
  const d = new Date(+s.slice(0, 4), +s.slice(5, 7) - 1, +s.slice(8, 10));
  return d.toLocaleDateString('en-GB', { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric' }).toLowerCase();
};
const duration = m => `${Math.floor(m / 60)}h ${String(m % 60).padStart(2, '0')}m`;

async function api(path, options = {}) {
  const res = await fetch('/api' + path, {
    ...options,
    headers: { 'content-type': 'application/json', ...(options.headers || {}) },
    body: options.body ? JSON.stringify(options.body) : undefined,
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw Object.assign(new Error(data.error || 'Request failed.'), { status: res.status, code: data.code });
  return data;
}

// ═════════ box-character frames ═════════
// Each .tui gets a <pre> of ╭─╮│╰╯ sized to the panel, with data-title in the
// top edge and data-foot in the bottom edge.
const TUI = (() => {
  const probe = document.createElement('span');
  probe.textContent = 'M'.repeat(100);
  probe.style.cssText = 'position:fixed;left:-10000px;top:0;visibility:hidden;white-space:pre;font:inherit';
  let CW = 8.4, LH = 17.5;
  const metrics = () => { const r = probe.getBoundingClientRect(); if (r.width) { CW = r.width / 100; LH = r.height; } };

  function draw(el) {
    if (el.hidden || !el.isConnected) return;
    let edge = el.querySelector(':scope > .edge');
    if (!edge) { edge = document.createElement('pre'); edge.className = 'edge'; edge.setAttribute('aria-hidden', 'true'); el.prepend(edge); }
    edge.textContent = '';
    el.style.minHeight = '';
    const cols = Math.max(8, Math.floor(el.clientWidth / CW));
    const rows = Math.max(3, Math.ceil(el.scrollHeight / LH - 0.05));
    el.style.minHeight = rows * LH + 'px';
    const room = cols - 6;
    const t = (el.dataset.title || '').slice(0, room), f = (el.dataset.foot || '').slice(0, Math.max(0, room - t.length - 4));
    const title = t ? `─ <b>${esc(t)}</b> ` : '', tLen = t ? t.length + 3 : 0;
    const foot = f ? ` <i>${esc(f)}</i> ─` : '', fLen = f ? f.length + 3 : 0;
    const top = '╭' + title + '─'.repeat(Math.max(0, cols - 2 - tLen)) + '╮';
    const mid = '│' + ' '.repeat(cols - 2) + '│';
    const bot = '╰' + '─'.repeat(Math.max(0, cols - 2 - fLen)) + foot + '╯';
    edge.innerHTML = [top, ...Array(rows - 2).fill(mid), bot].join('\n');
  }

  let busy = false;
  const ro = new ResizeObserver(entries => {
    if (busy) return;
    busy = true;
    entries.forEach(e => draw(e.target));
    requestAnimationFrame(() => { busy = false; });
  });
  function watch(root = document) {
    root.querySelectorAll('.tui').forEach(el => { if (!el.dataset.framed) { el.dataset.framed = '1'; ro.observe(el); } draw(el); });
  }
  function start() {
    document.body.appendChild(probe);
    metrics();
    watch();
    document.fonts.ready.then(() => { metrics(); watch(); });
    addEventListener('resize', () => { metrics(); document.querySelectorAll('.tui').forEach(draw); });
  }
  return { draw, watch, start };
})();

// ═════════ section rules: ── 01 · title ─────── ═════════
function drawRules() {
  document.querySelectorAll('.rule[data-label]').forEach(r => {
    r.innerHTML = `── <b>${esc(r.dataset.label)}</b> ` + '─'.repeat(300);
  });
}

// ═════════ airport picker ═════════
// Turns <input> into a type-to-search airport field. The chosen IATA code is
// kept in input.dataset.code.
let AIRPORTS = [];
async function loadAirports() {
  if (!AIRPORTS.length) AIRPORTS = await api('/airports');
  return AIRPORTS;
}
const airportLabel = a => `${a.code}  ${a.city.toLowerCase()}`;

function airportPicker(input, onPick) {
  const box = document.createElement('div');
  box.className = 'picker tui hot';
  box.hidden = true;
  box.setAttribute('role', 'listbox');
  input.parentElement.appendChild(box);
  input.setAttribute('autocomplete', 'off');
  input.setAttribute('role', 'combobox');
  let matches = [], active = 0;

  const set = a => {
    input.dataset.code = a.code;
    input.value = airportLabel(a);
    box.hidden = true;
    onPick && onPick(a);
  };
  const score = (a, q) => {
    if (a.code.toLowerCase() === q) return 0;
    if (a.city.toLowerCase().startsWith(q)) return 1;
    if (a.code.toLowerCase().startsWith(q)) return 2;
    if (a.name.toLowerCase().includes(q) || a.country.toLowerCase().startsWith(q)) return 3;
    if (a.city.toLowerCase().includes(q)) return 4;
    return 9;
  };
  const render = () => {
    const q = input.value.trim().toLowerCase();
    matches = AIRPORTS.map(a => [score(a, q), a]).filter(([s]) => !q || s < 9)
      .sort((x, y) => x[0] - y[0] || x[1].city.localeCompare(y[1].city)).slice(0, 8).map(([, a]) => a);
    active = 0;
    box.dataset.title = q ? `${matches.length ? '' : 'no '}matches` : 'airports';
    box.innerHTML = matches.length
      ? matches.map((a, i) => `<div class="opt${i === active ? ' on' : ''}" role="option" data-i="${i}"><span>${a.code}</span><span>${esc(a.city)} · ${esc(a.name)} · ${esc(a.country)}</span></div>`).join('')
      : '<div class="none">try a city, a country or a 3-letter code</div>';
    box.hidden = false;
    TUI.draw(box);
  };
  const highlight = () => box.querySelectorAll('.opt').forEach((o, i) => o.classList.toggle('on', i === active));

  input.addEventListener('focus', () => { input.select(); render(); });
  input.addEventListener('input', () => { delete input.dataset.code; render(); });
  input.addEventListener('keydown', e => {
    if (box.hidden) return;
    if (e.key === 'ArrowDown') { active = Math.min(active + 1, matches.length - 1); highlight(); e.preventDefault(); }
    else if (e.key === 'ArrowUp') { active = Math.max(active - 1, 0); highlight(); e.preventDefault(); }
    else if (e.key === 'Enter' && matches[active]) { set(matches[active]); e.preventDefault(); }
    else if (e.key === 'Escape') box.hidden = true;
  });
  box.addEventListener('mousedown', e => {
    const o = e.target.closest('.opt');
    if (o) { set(matches[+o.dataset.i]); e.preventDefault(); }
  });
  input.addEventListener('blur', () => {
    if (!input.dataset.code && matches[0] && input.value.trim()) set(matches[0]);
    else if (input.dataset.code) input.value = airportLabel(AIRPORTS.find(a => a.code === input.dataset.code));
    box.hidden = true;
  });

  return {
    setCode(code) { const a = AIRPORTS.find(x => x.code === code); if (a) set(a); },
    get code() { return input.dataset.code; },
  };
}

// ═════════ nearest airport to the visitor ═════════
// Uses the browser's location (it asks once). Remembered for the session;
// resolves to null when location is refused or unavailable.
const km = (la1, lo1, la2, lo2) => {
  const r = Math.PI / 180;
  const a = Math.sin((la2 - la1) * r / 2) ** 2 + Math.cos(la1 * r) * Math.cos(la2 * r) * Math.sin((lo2 - lo1) * r / 2) ** 2;
  return 12742 * Math.asin(Math.sqrt(a));
};
function nearestAirport() {
  let cached = null;
  try { cached = sessionStorage.getItem('ars-nearest'); } catch { /* storage blocked */ }
  if (cached) return Promise.resolve(cached === '-' ? null : cached);
  const remember = v => { try { sessionStorage.setItem('ars-nearest', v || '-'); } catch { /* ignore */ } return v; };
  if (!navigator.geolocation) return Promise.resolve(null);
  return new Promise(resolve => {
    navigator.geolocation.getCurrentPosition(pos => {
      const { latitude, longitude } = pos.coords;
      let best = null, bestKm = Infinity;
      for (const a of AIRPORTS) {
        const d = km(latitude, longitude, a.latitude, a.longitude);
        if (d < bestKm) { bestKm = d; best = a; }
      }
      resolve(remember(best && best.code));
    }, () => resolve(remember(null)), { timeout: 8000, maximumAge: 36e5 });
  });
}

// ═════════ airline logos ═════════
// A pixel banner of the airline code in a colour close to its livery, with
// the same left-to-right glint as the other banners;
// airlines without one get a colour derived from their code.
const BRAND = {
  AI: '#e8352f', '6E': '#5b7cfa', SG: '#f0473c', QP: '#ff7a1a', IX: '#f26b38', '9I': '#e0566b', S5: '#3fa9f5',
  EK: '#e8352f', SQ: '#f5b335', LH: '#ffcc33', QR: '#c2457a', EY: '#c9a24a', TK: '#ef3340', BA: '#5b8fd9',
  AF: '#6f8fd6', KL: '#26b5ec', UA: '#4c8fe0', AA: '#b8c4cc', DL: '#ec4f63', NH: '#3d86d6', JL: '#ef3b3b',
  CX: '#3fb0a5', QF: '#e8352f', VS: '#e0315a', LX: '#ef3340', TG: '#a55fc9', MH: '#3d7fd6', ET: '#5fbf4a',
  FZ: '#3fa0e0', G9: '#e8352f', AK: '#ef3340', TR: '#ffd23f', UL: '#3d86d6', WY: '#c9a24a', SV: '#4caf7d',
};
const hex = (r, g, b) => '#' + [r, g, b].map(v => Math.round(v).toString(16).padStart(2, '0')).join('');
function brandColor(code) {
  if (BRAND[code]) return BRAND[code];
  let h = 0;
  for (const c of code) h = (h * 31 + c.charCodeAt(0)) % 360;
  const s = 0.65, l = 0.6, k = n => (n + h / 30) % 12, a = s * Math.min(l, 1 - l);
  const f = n => 255 * (l - a * Math.max(-1, Math.min(k(n) - 3, 9 - k(n), 1)));
  return hex(f(0), f(8), f(4));
}
const shade = c => hex(...[1, 3, 5].map(i => parseInt(c.slice(i, i + 2), 16) * 0.72));
const airlineLogo = code => {
  const c = brandColor(code);
  return `<ascii-banner text="${esc(code)}" color="${c},${shade(c)}" shadow="rounded" effect="glint" label="${esc(code)} logo"></ascii-banner>`;
};

// ═════════ tabs ═════════
// <nav class="tabs"> links point at #ids of <section data-tab>. The number
// keys 1-9 switch tabs when the focus is not in a text field.
function startTabs(onShow) {
  const tabs = [...document.querySelectorAll('.tabs a[href^="#"]')];
  const show = () => {
    const id = (location.hash || '#home').slice(1).split('?')[0];
    const target = document.querySelector(`section[data-tab="${id}"]`) ? id : 'home';
    document.querySelectorAll('section[data-tab]').forEach(s => { s.hidden = s.dataset.tab !== target; });
    tabs.forEach(a => a.classList.toggle('on', a.getAttribute('href') === '#' + target));
    TUI.watch(document.querySelector(`section[data-tab="${target}"]`));
    onShow && onShow(target);
  };
  addEventListener('hashchange', () => { show(); scrollTo(0, 0); });
  addEventListener('keydown', e => {
    if (e.ctrlKey || e.metaKey || e.altKey || /^(INPUT|SELECT|TEXTAREA)$/.test(document.activeElement.tagName)) return;
    const t = tabs[+e.key - 1];
    if (t) location.hash = t.getAttribute('href');
  });
  show();
}
const goTab = id => { if (location.hash !== '#' + id) location.hash = id; };

document.addEventListener('DOMContentLoaded', () => { drawRules(); TUI.start(); });
