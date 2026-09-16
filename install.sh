#!/usr/bin/env bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script as root (sudo ./install.sh)"
  exit 1
fi

echo "=================================================="
echo "      Nginx Route Manager Installation Script     "
echo "=================================================="

read -r -p "Enter web panel port [Default: 9090]: " INPUT_PORT
PANEL_PORT=${INPUT_PORT:-9090}

if ! [[ "$PANEL_PORT" =~ ^[0-9]+$ ]] || [ "$PANEL_PORT" -lt 1 ] || [ "$PANEL_PORT" -gt 65535 ]; then
  echo "Error: Invalid port number! Port must be between 1 and 65535."
  exit 1
fi

echo "--> Panel port set to: $PANEL_PORT"

echo "[1/5] Updating and upgrading system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

echo "[2/5] Installing Nginx, Python3, and dependencies..."
apt-get install -y nginx python3 python3-pip python3-flask curl ufw

echo "[3/5] Setting up project directory and defaults..."
mkdir -p /opt/nginx-manager

# Download or copy local files
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$BASE_DIR/index.html" ]; then
  cp "$BASE_DIR/index.html" /opt/nginx-manager/index.html
fi

if [ -f "$BASE_DIR/app.py" ]; then
  cp "$BASE_DIR/app.py" /opt/nginx-manager/app.py
fi

if [ ! -f /opt/nginx-manager/auth.json ]; then
  cat << 'EOF' > /opt/nginx-manager/auth.json
{
  "username": "admin",
  "password": "admin"
}
EOF
fi

if [ -f "$BASE_DIR/aionginx" ]; then
  cp "$BASE_DIR/aionginx" /usr/local/bin/aionginx
  chmod +x /usr/local/bin/aionginx
fi

if command -v ufw >/dev/null 2>&1; then
  if ufw status | grep -q "Status: active"; then
    echo "Configuring UFW: Allowing port $PANEL_PORT/tcp..."
    ufw allow "$PANEL_PORT"/tcp
  fi
fi

echo "[4/5] Creating systemd service unit..."
cat << EOF > /etc/systemd/system/nginx-manager.service
[Unit]
Description=Nginx Web Manager Service
After=network.target nginx.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/nginx-manager
Environment="PANEL_PORT=$PANEL_PORT"
ExecStart=/usr/bin/python3 /opt/nginx-manager/app.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

echo "[5/5] Reloading daemon and starting services..."
systemctl daemon-reload
systemctl enable nginx
systemctl enable nginx-manager.service
systemctl restart nginx
systemctl restart nginx-manager.service

SERVER_IP=$(curl -s https://api.ipify.org || hostname -I | awk '{print $1}')

echo "=================================================="
echo "          Installation Completed Successfully!    "
echo "=================================================="
echo "Web Panel : http://${SERVER_IP}:${PANEL_PORT}"
echo "CLI Tool  : Type 'aionginx' in terminal"
echo "Username  : admin"
echo "Password  : admin"
echo "=================================================="
