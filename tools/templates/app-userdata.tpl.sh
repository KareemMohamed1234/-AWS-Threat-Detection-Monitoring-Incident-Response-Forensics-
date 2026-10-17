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
@@FILE:webapp/app/server.py@@
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
