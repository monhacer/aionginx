import os
import json
import subprocess
from flask import Flask, request, jsonify, render_template_string

app = Flask(__name__)

DATA_FILE = "/opt/nginx-manager/routes.json"
AUTH_FILE = "/opt/nginx-manager/auth.json"
NGINX_CONF_PATH = "/etc/nginx/sites-available/default"

DEFAULT_ROUTES = [
    {"id": 1, "listenPort": 80, "path": "/dk", "targetPort": 110, "desc": "سرویس دانمارک"},
    {"id": 2, "listenPort": 80, "path": "/sg", "targetPort": 995, "desc": "سرویس سنگاپور"},
    {"id": 3, "listenPort": 80, "path": "/nl", "targetPort": 993, "desc": "سرویس هلند"},
    {"id": 4, "listenPort": 80, "path": "/pro", "targetPort": 446, "desc": "پروکسی پرو"},
    {"id": 5, "listenPort": 80, "path": "/combapi", "targetPort": 445, "desc": "API ترکیبی"},
    {"id": 6, "listenPort": 80, "path": "/", "targetPort": 2053, "desc": "مسیر روت پیش‌فرض"}
]

def load_auth():
    if os.path.exists(AUTH_FILE):
        try:
            with open(AUTH_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {"username": "admin", "password": "admin"}

def load_routes():
    if os.path.exists(DATA_FILE):
        try:
            with open(DATA_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return DEFAULT_ROUTES

def save_routes_to_disk(routes):
    with open(DATA_FILE, "w", encoding="utf-8") as f:
        json.dump(routes, f, ensure_ascii=False, indent=2)

def generate_nginx_conf(routes):
    ports = sorted(list(set(r["listenPort"] for r in routes)))
    full_conf = ""

    for port in ports:
        port_routes = [r for r in routes if r["listenPort"] == port]
        sorted_routes = sorted(port_routes, key=lambda x: (x["path"] == "/", x["path"]))

        locations = ""
        for r in sorted_routes:
            comment = f"    # {r['desc']}\n" if r.get("desc") else ""
            loc_directive = "location /" if r["path"] == "/" else f"location ^~ {r['path']}"
            locations += f"""{comment}    {loc_directive} {{
        proxy_pass http://127.0.0.1:{r['targetPort']};
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
        proxy_connect_timeout 10s;
        proxy_buffering off;
    }}\n\n"""

        full_conf += f"""server {{
    listen {port};
    listen [::]:{port};
    server_name _;
    client_max_body_size 0;
    proxy_intercept_errors off;

{locations}}}

"""
    return full_conf.strip()

def apply_nginx_config(content):
    with open(NGINX_CONF_PATH, "w", encoding="utf-8") as f:
        f.write(content)

    test = subprocess.run(["nginx", "-t"], capture_output=True, text=True)
    if test.returncode != 0:
        raise Exception(f"Nginx syntax validation failed:\n{test.stderr}")

    subprocess.run(["systemctl", "reload", "nginx"], check=True)

def init_system():
    routes = load_routes()
    if not os.path.exists(DATA_FILE):
        save_routes_to_disk(routes)
    try:
        conf_content = generate_nginx_conf(routes)
        apply_nginx_config(conf_content)
    except Exception as e:
        print(f"Warning on initial sync: {e}")

@app.route("/")
def index():
    html_path = "/opt/nginx-manager/index.html"
    if not os.path.exists(html_path):
        html_path = "index.html"
    with open(html_path, "r", encoding="utf-8") as f:
        return render_template_string(f.read())

@app.route("/api/login", methods=["POST"])
def api_login():
    data = request.json or {}
    username = data.get("username", "")
    password = data.get("password", "")
    creds = load_auth()

    if username == creds.get("username") and password == creds.get("password"):
        return jsonify({"status": "success", "message": "Authentication successful."})
    return jsonify({"status": "error", "message": "Invalid username or password."}), 401

@app.route("/api/routes", methods=["GET"])
def get_routes():
    return jsonify(load_routes())

@app.route("/api/routes", methods=["POST"])
def update_routes():
    try:
        new_routes = request.json
        conf_content = generate_nginx_conf(new_routes)
        apply_nginx_config(conf_content)
        save_routes_to_disk(new_routes)
        return jsonify({"status": "success", "message": "Routes updated and Nginx reloaded."})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 400

@app.route("/api/nginx/raw", methods=["GET"])
def get_raw_conf():
    if os.path.exists(NGINX_CONF_PATH):
        with open(NGINX_CONF_PATH, "r", encoding="utf-8") as f:
            return jsonify({"config": f.read()})
    return jsonify({"config": ""})

@app.route("/api/nginx/raw", methods=["POST"])
def save_raw_conf():
    try:
        data = request.json
        raw_conf = data.get("config", "")
        apply_nginx_config(raw_conf)
        return jsonify({"status": "success", "message": "Raw configuration applied successfully."})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 400

@app.route("/api/nginx/action", methods=["POST"])
def nginx_control():
    action = request.json.get("action")
    try:
        if action == "test":
            res = subprocess.run(["nginx", "-t"], capture_output=True, text=True)
            if res.returncode == 0:
                return jsonify({"status": "success", "message": "Nginx configuration syntax is OK."})
            return jsonify({"status": "error", "message": res.stderr}), 400
        elif action in ["reload", "restart", "stop"]:
            subprocess.run(["systemctl", action, "nginx"], check=True)
            return jsonify({"status": "success", "message": f"Nginx {action} executed successfully."})
        return jsonify({"status": "error", "message": "Invalid action specified."}), 400
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

if __name__ == "__main__":
    init_system()
    panel_port = int(os.environ.get("PANEL_PORT", 9090))
    app.run(host="0.0.0.0", port=panel_port)
