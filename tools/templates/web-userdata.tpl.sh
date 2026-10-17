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
@@FILE:webapp/web/index.html@@
LAB_EOF
cat > /usr/share/nginx/html/simulate.html <<'LAB_EOF'
@@FILE:webapp/web/simulate.html@@
LAB_EOF
cat > /usr/share/nginx/html/style.css <<'LAB_EOF'
@@FILE:webapp/web/style.css@@
LAB_EOF
cat > /usr/share/nginx/html/app.js <<'LAB_EOF'
@@FILE:webapp/web/app.js@@
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
