// Shared helpers: show which web server answered (proves the ALB is balancing).
async function loadServerBadge() {
  const el = document.getElementById('server-badge');
  if (!el) return;
  try {
    const r = await fetch('/instance.json', {cache: 'no-store'});
    const j = await r.json();
    el.textContent = `Served by ${j.name} · ${j.az}`;
  } catch (e) { el.textContent = 'Served by unknown server'; }
}

function esc(s) {
  return String(s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
}

async function loadCustomers() {
  const body = document.getElementById('customers');
  if (!body) return;
  try {
    const r = await fetch('/api/customers', {cache: 'no-store'});
    if (!r.ok) throw new Error('HTTP ' + r.status);
    const rows = await r.json();
    body.innerHTML = rows.length
      ? rows.map(c => `<tr><td>${esc(c.name)}</td><td>${esc(c.email)}</td><td>${esc(c.created_at)}</td></tr>`).join('')
      : '<tr><td colspan="3">No customers yet. Add the first one!</td></tr>';
  } catch (e) {
    body.innerHTML = `<tr><td colspan="3" class="err">Could not load customers (${esc(e.message)})</td></tr>`;
  }
}

function initForm() {
  const form = document.getElementById('customer-form');
  if (!form) return;
  form.addEventListener('submit', async ev => {
    ev.preventDefault();
    const btn = form.querySelector('button'); const msg = document.getElementById('form-msg');
    btn.disabled = true; msg.textContent = 'Saving...'; msg.className = 'msg';
    const payload = Object.fromEntries(new FormData(form).entries());
    try {
      const r = await fetch('/api/customers', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(payload)});
      const j = await r.json();
      if (!r.ok) throw new Error(j.error || ('HTTP ' + r.status));
      msg.textContent = `Saved! Record ${j.id} stored in RDS, the EBS volume and S3.`; msg.className = 'msg ok';
      form.reset(); loadCustomers();
    } catch (e) { msg.textContent = 'Error: ' + e.message; msg.className = 'msg err'; }
    btn.disabled = false;
  });
}

// ---- Simulation page ----
const logEl = () => document.getElementById('log');
function log(line) { const l = logEl(); l.textContent += line + '\n'; l.scrollTop = l.scrollHeight; }

async function hit(path, opts) {
  try {
    const r = await fetch(path, Object.assign({cache: 'no-store'}, opts || {}));
    return r.status;
  } catch (e) { return 0; }
}

async function whoAnswered() {
  try { const j = await (await fetch('/instance.json', {cache: 'no-store'})).json(); return j.name; } catch (e) { return '?'; }
}

async function runBatch(label, paths, delayMs) {
  const buttons = document.querySelectorAll('button[data-sim]'); buttons.forEach(b => b.disabled = true);
  log(`--- ${label}: ${paths.length} requests ---`);
  const codes = {}; const servers = {};
  for (const p of paths) {
    const code = await hit(p);
    codes[code] = (codes[code] || 0) + 1;
    if (paths.length <= 60 || Math.random() < 0.1) { const s = await whoAnswered(); servers[s] = (servers[s] || 0) + 1; }
    if (delayMs) await new Promise(r => setTimeout(r, delayMs));
  }
  log('status codes: ' + JSON.stringify(codes));
  log('servers seen: ' + JSON.stringify(servers));
  log('Done. Check ALB access logs / VPC Flow Logs in a few minutes.\n');
  buttons.forEach(b => b.disabled = false);
}

const SCAN_PATHS = ['/admin', '/admin/login', '/.env', '/.git/config', '/wp-login.php', '/phpmyadmin/', '/backup.zip', '/server-status', '/api/users', '/api/admin', '/config.json', '/debug'];

function initSim() {
  const q = id => document.getElementById(id);
  if (!q('btn-normal')) return;
  q('btn-normal').onclick = () => runBatch('Normal browsing', Array.from({length: 30}, (_, i) => i % 3 ? '/' : '/api/customers'), 150);
  q('btn-scan').onclick = () => runBatch('Scanner-style probing (404s expected)', SCAN_PATHS.concat(SCAN_PATHS), 100);
  q('btn-burst').onclick = () => runBatch('Request burst', Array.from({length: 200}, () => '/health'), 0);
  q('btn-clear').onclick = () => { logEl().textContent = ''; };
}

loadServerBadge(); initForm(); loadCustomers(); initSim();
