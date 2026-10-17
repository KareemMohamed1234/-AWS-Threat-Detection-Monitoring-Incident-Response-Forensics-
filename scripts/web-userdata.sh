#!/bin/bash
# ===== Web server user data (Amazon Linux 2023): nginx + SecureCart Lab site =====
# Paste this whole script into: Launch instance > Advanced details > User data.
# Edit the ONE value below first. Logs: /var/log/cloud-init-output.log
APP_SERVER_IP="10.0.2.X"        # <-- private IP of App-Server-EC2

set -euxo pipefail
dnf install -y nginx

# --- site files -------------------------------------------------------------
mkdir -p /usr/share/nginx/html
cat > /usr/share/nginx/html/index.html <<'LAB_EOF'
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>SecureCart Lab</title><link rel="stylesheet" href="/style.css"></head>
<body>
<header><div class="bar"><span class="logo">SecureCart Lab</span>
<nav><a class="on" href="/">Home</a><a href="/simulate.html">Simulation</a></nav>
<span class="badge" id="server-badge">Served by ...</span></div></header>
<main>
  <h1>Customer portal</h1>
  <p class="lead">A small three-tier app used as the target for the incident response lab: ALB → web servers → app server → RDS, EBS and S3.</p>
  <div class="grid">
    <section class="card">
      <h2>Register a customer</h2>
      <form id="customer-form">
        <label for="name">Name</label><input id="name" name="name" required maxlength="80" autocomplete="off">
        <label for="email">Email</label><input id="email" name="email" type="email" required maxlength="120" autocomplete="off">
        <label for="message">Note (optional)</label><textarea id="message" name="message" maxlength="500"></textarea>
        <button type="submit">Save customer</button>
        <div id="form-msg" class="msg"></div>
      </form>
    </section>
    <section class="card">
      <h2>Latest customers</h2>
      <table><thead><tr><th>Name</th><th>Email</th><th>Created (UTC)</th></tr></thead><tbody id="customers"><tr><td colspan="3">Loading...</td></tr></tbody></table>
    </section>
  </div>
</main>
<footer>Lab environment - use fake data only.</footer>
<script src="/app.js"></script>
</body></html>
LAB_EOF
cat > /usr/share/nginx/html/simulate.html <<'LAB_EOF'
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>SecureCart Lab - Simulation</title><link rel="stylesheet" href="/style.css"></head>
<body>
<header><div class="bar"><span class="logo">SecureCart Lab</span>
<nav><a href="/">Home</a><a class="on" href="/simulate.html">Simulation</a></nav>
<span class="badge" id="server-badge">Served by ...</span></div></header>
<main>
  <h1>Traffic simulation</h1>
  <p class="lead">Generate traffic against <b>this lab's own load balancer</b> so the logging pipeline has something to collect.</p>
  <div class="note">Requests are sent only to this site (relative URLs) from your browser. Use it only in your own lab account.</div>
  <section class="card">
    <h2>Scenarios</h2>
    <div class="row">
      <button id="btn-normal" data-sim>Normal browsing (30 req)</button>
      <button id="btn-scan" class="secondary" data-sim>Scanner-style probing (24 req)</button>
      <button id="btn-burst" class="secondary" data-sim>Burst (200 req)</button>
      <button id="btn-clear" class="secondary">Clear</button>
    </div>
    <p class="lead" style="margin-top:14px">Refresh the page a few times: the badge in the top-right shows which web server answered, so you can see the ALB alternating between Web-Server-1 and Web-Server-2.</p>
    <pre id="log">Ready.
</pre>
  </section>
</main>
<footer>Lab environment - use fake data only.</footer>
<script src="/app.js"></script>
</body></html>
LAB_EOF
cat > /usr/share/nginx/html/style.css <<'LAB_EOF'
:root{--bg:#f6f8fb;--card:#fff;--ink:#16202e;--muted:#5b6778;--line:#dfe5ee;--brand:#1f6feb;--ok:#1a7f4b;--warn:#b54708}
*{box-sizing:border-box}
body{margin:0;font:16px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;background:var(--bg);color:var(--ink)}
header{background:#0f1b2d;color:#fff}
.bar{max-width:960px;margin:0 auto;padding:14px 20px;display:flex;align-items:center;gap:24px;flex-wrap:wrap}
.logo{font-weight:700;font-size:18px;letter-spacing:.3px}
nav a{color:#c9d6ea;text-decoration:none;margin-right:16px}
nav a:hover,nav a.on{color:#fff}
.badge{margin-left:auto;font-size:13px;background:#16263f;border:1px solid #2a3d5c;border-radius:999px;padding:4px 12px;color:#bcd0ee}
main{max-width:960px;margin:0 auto;padding:24px 20px 48px}
h1{margin:8px 0 4px;font-size:28px}
.lead{color:var(--muted);margin:0 0 24px}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:20px}
@media(max-width:760px){.grid{grid-template-columns:1fr}}
.card{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:20px}
.card h2{margin:0 0 12px;font-size:18px}
label{display:block;font-size:14px;color:var(--muted);margin:12px 0 4px}
input,textarea{width:100%;padding:10px 12px;border:1px solid var(--line);border-radius:8px;font:inherit}
textarea{min-height:84px;resize:vertical}
button{margin-top:14px;background:var(--brand);color:#fff;border:0;border-radius:8px;padding:10px 16px;font:inherit;font-weight:600;cursor:pointer}
button.secondary{background:#fff;color:var(--brand);border:1px solid var(--brand)}
button:disabled{opacity:.6;cursor:wait}
.msg{margin-top:12px;font-size:14px}.ok{color:var(--ok)}.err{color:#b42318}
table{width:100%;border-collapse:collapse;font-size:14px}
th,td{text-align:left;padding:8px 6px;border-bottom:1px solid var(--line);vertical-align:top}
th{color:var(--muted);font-weight:600}
.note{background:#fff7e6;border:1px solid #ffd591;color:var(--warn);border-radius:10px;padding:12px 14px;font-size:14px;margin-bottom:20px}
pre{background:#0f1b2d;color:#d6e4ff;border-radius:10px;padding:14px;max-height:340px;overflow:auto;font-size:13px;margin:12px 0 0;white-space:pre-wrap}
.row{display:flex;gap:10px;flex-wrap:wrap}
.stat{display:inline-block;margin-right:16px;font-size:14px;color:var(--muted)}
.stat b{color:var(--ink)}
footer{text-align:center;color:var(--muted);font-size:13px;padding:24px}
LAB_EOF
cat > /usr/share/nginx/html/app.js <<'LAB_EOF'
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
LAB_EOF

# --- who am I? (shown in the page badge; proves the ALB is balancing) --------
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
IMD() { curl -s -H "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/$1"; }
echo "{\"name\":\"$(IMD instance-id)\",\"az\":\"$(IMD placement/availability-zone)\"}" > /usr/share/nginx/html/instance.json

# --- nginx: static site + reverse proxy to the app tier ----------------------
cat > /etc/nginx/nginx.conf <<'LAB_EOF'
user nginx;
worker_processes auto;
pid /run/nginx.pid;
events { worker_connections 1024; }
http {
  include /etc/nginx/mime.types;
  default_type application/octet-stream;
  log_format lab '$http_x_forwarded_for - [$time_local] "$request" $status $body_bytes_sent "$http_user_agent"';
  access_log /var/log/nginx/access.log lab;
  server {
    listen 80 default_server;
    root /usr/share/nginx/html;
    index index.html;
    location = /health { access_log off; default_type text/plain; return 200 "ok\n"; }
    location = /instance.json { add_header Cache-Control "no-store"; }
    location /api/ {
      proxy_pass http://APP_SERVER_IP_PLACEHOLDER:8080;
      proxy_set_header X-Forwarded-For $http_x_forwarded_for;
      proxy_connect_timeout 5s;
      proxy_read_timeout 30s;
    }
    location / { try_files $uri =404; }
  }
}
LAB_EOF
sed -i "s/APP_SERVER_IP_PLACEHOLDER/${APP_SERVER_IP}/" /etc/nginx/nginx.conf
nginx -t
systemctl enable --now nginx

