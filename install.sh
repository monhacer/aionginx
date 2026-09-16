#!/usr/bin/env bash
set -e

# Check root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script as root (sudo ./install.sh)"
  exit 1
fi

echo "=================================================="
echo "      Nginx Route Manager Installation Script     "
echo "=================================================="

# Read interactively even when executed via curl | bash
if [ -c /dev/tty ]; then
  read -r -p "Enter web panel port [Default: 9090]: " INPUT_PORT < /dev/tty || INPUT_PORT=""
else
  read -r -p "Enter web panel port [Default: 9090]: " INPUT_PORT || INPUT_PORT=""
fi

INPUT_PORT=$(echo "$INPUT_PORT" | tr -d '\r\n ')
PANEL_PORT=${INPUT_PORT:-9090}

# Validate port number
if ! [[ "$PANEL_PORT" =~ ^[0-9]+$ ]] || [ "$PANEL_PORT" -lt 1 ] || [ "$PANEL_PORT" -gt 65535 ]; then
  echo "Error: Invalid port number! Port must be between 1 and 65535."
  exit 1
fi

echo "--> Panel port set to: $PANEL_PORT"

# 1. Update and upgrade fresh server
echo "[1/5] Updating and upgrading system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

# 2. Install required packages
echo "[2/5] Installing Nginx, Python3, and dependencies..."
apt-get install -y nginx python3 python3-pip python3-flask curl ufw

# 3. Setup project directory and deploy files
echo "[3/5] Setting up project directory..."
mkdir -p /opt/nginx-manager

GITHUB_RAW="https://raw.githubusercontent.com/monhacer/aionginx/main"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"

# Deploy index.html
if [ -n "$BASE_DIR" ] && [ -f "$BASE_DIR/index.html" ]; then
  cp "$BASE_DIR/index.html" /opt/nginx-manager/index.html
else
  curl -sSL "$GITHUB_RAW/index.html" -o /opt/nginx-manager/index.html
fi

# Deploy app.py
if [ -n "$BASE_DIR" ] && [ -f "$BASE_DIR/app.py" ]; then
  cp "$BASE_DIR/app.py" /opt/nginx-manager/app.py
else
  curl -sSL "$GITHUB_RAW/app.py" -o /opt/nginx-manager/app.py
fi

# Deploy aionginx CLI tool
if [ -n "$BASE_DIR" ] && [ -f "$BASE_DIR/aionginx" ]; then
  cp "$BASE_DIR/aionginx" /usr/local/bin/aionginx
else
  curl -sSL "$GITHUB_RAW/aionginx" -o /usr/local/bin/aionginx
fi
chmod +x /usr/local/bin/aionginx

# Default credentials if not already created
if [ ! -f /opt/nginx-manager/auth.json ]; then
  cat << 'EOF' > /opt/nginx-manager/auth.json
{
  "username": "admin",
  "password": "admin"
}
EOF
fi

# Default single route (2053)
if [ ! -f /opt/nginx-manager/routes.json ]; then
  cat << 'EOF' > /opt/nginx-manager/routes.json
[
  {
    "id": 1,
    "listenPort": 80,
    "path": "/",
    "targetPort": 2053,
    "desc": "مسیر روت پیش‌فرض"
  }
]
EOF
fi

# 4. Open firewall port if UFW is active
if command -v ufw >/dev/null 2>&1; then
  if ufw status | grep -q "Status: active"; then
    echo "Configuring UFW: Allowing port $PANEL_PORT/tcp..."
    ufw allow "$PANEL_PORT"/tcp
  fi
fi

# 5. Create and start systemd service
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

# Fetch public server IP
SERVER_IP=$(curl -s https://api.ipify.org || hostname -I | awk '{print $1}')

echo "=================================================="
echo "          Installation Completed Successfully!    "
echo "=================================================="
echo "Web Panel : http://${SERVER_IP}:${PANEL_PORT}"
echo "CLI Tool  : Type 'aionginx' in terminal"
echo "Username  : admin"
echo "Password  : admin"
echo "=================================================="
