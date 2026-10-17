#!/bin/bash
# ===== App server user data (Amazon Linux 2023, private subnet) =====
# Paste into: Launch instance > Advanced details > User data.
# Edit ALL values below first. Logs: /var/log/cloud-init-output.log
DB_HOST="customer-db.XXXXXXXX.eu-north-1.rds.amazonaws.com"
DB_USER="admin"
DB_PASS="CHANGE_ME"                              # letters/digits only (no spaces, quotes, # $ \)
DB_NAME="customerdb"
DATA_BUCKET="target-data-bucket-ir-lab"            # your unique name
AWS_ACCESS_KEY_ID="AKIA_CHANGE_ME"                 # keys of IAM user app-storage-user
AWS_SECRET_ACCESS_KEY="CHANGE_ME"
AWS_REGION="eu-north-1"

set -euxo pipefail
dnf install -y mariadb105 xfsprogs      # mysql client + XFS tools (repos reachable through the S3 gateway endpoint)

# --- EBS data volume (2nd disk) mounted on /data -------------------------------
DEV=""
for i in $(seq 1 30); do
  for d in /dev/nvme1n1 /dev/xvdf /dev/sdf; do [ -b "$d" ] && DEV="$d" && break; done
  [ -n "$DEV" ] && break; sleep 2
done
if [ -n "$DEV" ]; then
  blkid "$DEV" || mkfs -t xfs "$DEV"
  mkdir -p /data
  echo "UUID=$(blkid -s UUID -o value "$DEV") /data xfs defaults,nofail 0 2" >> /etc/fstab
  mount -a
fi
mkdir -p /data/lab

# --- app user, code and config ----------------------------------------------
useradd -r -m -d /opt/lab-app -s /sbin/nologin labapp || true
chown -R labapp:labapp /data/lab
cat > /opt/lab-app/server.py <<'LAB_EOF'
#!/usr/bin/env python3
"""Lab app server (tier 2). Standard library only, so it runs on a private
subnet with no internet access.

  POST /api/customers  -> RDS (mysql CLI) + EBS (/data/lab) + S3 (aws CLI)
  GET  /api/customers  -> last 10 customers from RDS
  GET  /api/health     -> liveness
"""
import json, os, re, subprocess, sys, time, uuid
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

DB_HOST = os.environ.get("DB_HOST", "")
DB_USER = os.environ.get("DB_USER", "admin")
DB_PASS = os.environ.get("DB_PASS", "")
DB_NAME = os.environ.get("DB_NAME", "customerdb")
BUCKET = os.environ.get("DATA_BUCKET", "")
DATA_DIR = os.environ.get("DATA_DIR", "/data/lab")
PORT = int(os.environ.get("PORT", "8080"))
MYSQL_BIN = os.environ.get("MYSQL_BIN", "mysql")
AWS_BIN = os.environ.get("AWS_BIN", "aws")
EMAIL_RE = re.compile(r"^[^@\s]{1,64}@[^@\s]{1,255}\.[^@\s]{2,}$")
CTRL_RE = re.compile(r"[\x00-\x1f\x7f]")


def log(msg):
    print(f"{datetime.now(timezone.utc).isoformat()} {msg}", flush=True)


def mysql(sql):
    """Run one SQL statement through the mysql CLI and return stdout."""
    env = dict(os.environ, MYSQL_PWD=DB_PASS)
    cmd = [MYSQL_BIN, "-h", DB_HOST, "-u", DB_USER, "-D", DB_NAME, "--batch", "--skip-column-names", "-e", sql]
    out = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=20)
    if out.returncode != 0:
        raise RuntimeError(out.stderr.strip() or "mysql failed")
    return out.stdout


def hexlit(value):
    """Encode a string as a SQL hex literal: no quoting, so no SQL injection."""
    return "CONVERT(UNHEX('%s') USING utf8mb4)" % value.encode("utf-8").hex()


def init_db():
    for attempt in range(30):
        try:
            mysql("CREATE TABLE IF NOT EXISTS customers ("
                  "id CHAR(36) PRIMARY KEY, name VARCHAR(80) NOT NULL, email VARCHAR(120) NOT NULL,"
                  "message VARCHAR(500), created_at DATETIME NOT NULL) CHARACTER SET utf8mb4")
            log("database ready")
            return
        except Exception as e:  # RDS may still be starting
            log(f"database not ready ({e}); retry {attempt + 1}/30")
            time.sleep(10)
    log("giving up on database init; API will return errors until RDS is reachable")


def validate(data):
    name = str(data.get("name", "")).strip()
    email = str(data.get("email", "")).strip()
    message = str(data.get("message", "")).strip()
    if not (1 <= len(name) <= 80) or CTRL_RE.search(name):
        raise ValueError("name must be 1-80 characters")
    if len(email) > 120 or not EMAIL_RE.match(email) or CTRL_RE.search(email):
        raise ValueError("invalid email")
    if len(message) > 500 or re.sub(r"[\n\r\t]", "", message) != CTRL_RE.sub("", message):
        raise ValueError("note must be at most 500 characters")
    return name, email, message


def save_customer(name, email, message):
    rec_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
    mysql("INSERT INTO customers (id,name,email,message,created_at) VALUES ('%s',%s,%s,%s,'%s')"
          % (rec_id, hexlit(name), hexlit(email), hexlit(message), now))
    record = {"id": rec_id, "name": name, "email": email, "message": message, "created_at": now}
    line = json.dumps(record, ensure_ascii=False)
    os.makedirs(DATA_DIR, exist_ok=True)               # EBS volume
    with open(os.path.join(DATA_DIR, "customers.log"), "a", encoding="utf-8") as f:
        f.write(line + "\n")
    if BUCKET:                                          # S3, using the IAM user's access keys
        up = subprocess.run([AWS_BIN, "s3", "cp", "-", f"s3://{BUCKET}/customers/{rec_id}.json"],
                            input=line, capture_output=True, text=True, timeout=30)
        if up.returncode != 0:
            raise RuntimeError("S3 upload failed: " + up.stderr.strip())
    return record


def list_customers():
    out = mysql("SELECT name,email,DATE_FORMAT(created_at,'%Y-%m-%d %H:%i:%s') FROM customers ORDER BY created_at DESC LIMIT 10")
    rows = []
    for line in out.splitlines():
        parts = line.split("\t")
        if len(parts) == 3:
            rows.append({"name": parts[0], "email": parts[1], "created_at": parts[2]})
    return rows


class Handler(BaseHTTPRequestHandler):
    server_version = "LabApp/1.0"

    def _send(self, code, payload):
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        log("%s %s" % (self.headers.get("X-Forwarded-For", self.client_address[0]), fmt % args))

    def do_GET(self):
        path = self.path.split("?")[0]
        if path == "/api/health":
            return self._send(200, {"status": "ok"})
        if path == "/api/customers":
            try:
                return self._send(200, list_customers())
            except Exception as e:
                log(f"list error: {e}")
                return self._send(503, {"error": "database unavailable"})
        self._send(404, {"error": "not found"})

    def do_POST(self):
        if self.path.split("?")[0] != "/api/customers":
            return self._send(404, {"error": "not found"})
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length <= 0 or length > 4096:
                return self._send(413, {"error": "bad body size"})
            data = json.loads(self.rfile.read(length))
            if not isinstance(data, dict):
                raise ValueError("body must be a JSON object")
            name, email, message = validate(data)
        except (ValueError, json.JSONDecodeError) as e:
            return self._send(400, {"error": str(e)})
        try:
            self._send(201, save_customer(name, email, message))
        except Exception as e:
            log(f"save error: {e}")
            self._send(503, {"error": "could not save the customer"})


if __name__ == "__main__":
    if "--no-db-init" not in sys.argv:
        init_db()
    log(f"listening on 0.0.0.0:{PORT}")
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
LAB_EOF
chown labapp:labapp /opt/lab-app/server.py

cat > /etc/lab-app.env <<LAB_EOF
DB_HOST=${DB_HOST}
DB_USER=${DB_USER}
DB_PASS=${DB_PASS}
DB_NAME=${DB_NAME}
DATA_BUCKET=${DATA_BUCKET}
DATA_DIR=/data/lab
AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
AWS_DEFAULT_REGION=${AWS_REGION}
HOME=/opt/lab-app
LAB_EOF
chmod 600 /etc/lab-app.env      # (the keys sitting on disk are the "exposed keys" scenario in Phase 4)

cat > /etc/systemd/system/lab-app.service <<'LAB_EOF'
[Unit]
Description=Lab app server
After=network-online.target
Wants=network-online.target
[Service]
User=labapp
EnvironmentFile=/etc/lab-app.env
ExecStart=/usr/bin/python3 /opt/lab-app/server.py
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
LAB_EOF
systemctl daemon-reload
systemctl enable --now lab-app

