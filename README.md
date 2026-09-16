# AioNginx - Nginx Route & Proxy Web Manager

A modern, lightweight Nginx reverse proxy management tool featuring a Persian Web UI (Google Material Design 3) and a powerful CLI tool (`aionginx`).

---

## 🚀 Quick Install (One-Line Command)

Run this command as `root` on any fresh Ubuntu/Debian server:

```bash
curl -sSL https://raw.githubusercontent.com/monhacer/aionginx/main/install.sh | bash
```

---

## 🛠 Features

- **Automated Fresh Server Setup**: Runs `apt-get update && apt-get upgrade -y` and installs Nginx and Python automatically.
- **Custom Panel Port**: Interactive port selection during setup (Default: `9090`).
- **Material Design 3**: Clean, dark-themed UI styled with Google Material Design 3 guidelines and Vazirmatn typography.
- **Direct Nginx Sync**: Real-time Nginx reload and configuration validation (`nginx -t`).
- **Terminal CLI (`aionginx`)**:
  - View Panel URL & credentials
  - Change admin username & password
  - Change Web Panel port
  - Restart/test Nginx and Panel services
  - Check detailed status and active listening ports
  - Completely uninstall the panel

---

## 💻 CLI Management Tool

Access the terminal management menu anytime by running:

```bash
aionginx
```

```text
==================================================
               AIONGINX CLI MANAGER               
==================================================
1) View Panel URL & Credentials
2) Change Admin Username and Password
3) Change Web Panel Port
4) Restart Nginx Service
5) Restart Web Panel Service
6) Check Services Status (Detailed)
7) Test Nginx Syntax (nginx -t)
8) Uninstall Panel Completely
0) Exit
==================================================
```

---

## 🔐 Default Credentials

- **Username**: `admin`
- **Password**: `admin`

*(You can change credentials directly via the CLI menu or in the web panel.)*
