#!/usr/bin/env bash
set -e

echo "=== Orange Pi Print Server Installer ==="

# -------------------------------
# Variables
# -------------------------------
HOSTNAME="printserver"
PRINTER_NAME="Brother_DCP7030"
APP_DIR="/opt/printserver"
SERVICE_NAME="printserver-web"

# -------------------------------
# 1. System prep
# -------------------------------
echo "[1/9] Updating system..."
sudo apt update
sudo apt -y upgrade

echo "[2/9] Installing required packages..."
sudo apt install -y \
  cups \
  cups-client \
  avahi-daemon \
  python3 \
  python3-flask \
  python3-psutil \
  git \
  usbutils

# -------------------------------
# 2. Hostname & Avahi
# -------------------------------
echo "[3/9] Setting hostname..."
sudo hostnamectl set-hostname "$HOSTNAME"

sudo systemctl enable avahi-daemon
sudo systemctl restart avahi-daemon

# -------------------------------
# 3. Fix CUPS runtime directory
# -------------------------------
echo "[4/9] Fixing CUPS runtime directories..."
sudo mkdir -p /run/cups
sudo chown root:lp /run/cups
sudo chmod 755 /run/cups

# -------------------------------
# 4. Install Brother driver (brlaser)
# -------------------------------
echo "[5/9] Installing Brother laser driver..."
sudo apt install -y printer-driver-brlaser

# -------------------------------
# 5. Replace CUPS config (KNOWN GOOD)
# -------------------------------
echo "[6/9] Installing stable CUPS configuration..."

sudo tee /etc/cups/cupsd.conf >/dev/null <<'EOF'
LogLevel warn
MaxLogSize 0

Listen 0.0.0.0:631
Listen /run/cups/cups.sock

Browsing Yes
BrowseLocalProtocols dnssd

DefaultAuthType Basic
WebInterface Yes

<Location />
  Order allow,deny
  Allow all
</Location>

<Location /admin>
  Order allow,deny
  Allow all
</Location>

<Location /admin/conf>
  AuthType Basic
  Require user @SYSTEM
  Order allow,deny
  Allow all
</Location>

<Policy default>
  <Limit All>
    Order allow,deny
    Allow all
  </Limit>
</Policy>
EOF

sudo systemctl enable cups.socket cups.path cups.service
sudo systemctl restart cups.socket cups.path cups.service

# -------------------------------
# 6. Auto-add Brother printer (USB)
# -------------------------------
echo "[7/9] Waiting for USB printer..."
sleep 5

USB_URI=$(lpinfo -v 2>/dev/null | grep -i brother | head -n1 | awk '{print $2}')

if [ -n "$USB_URI" ]; then
  echo "Found printer at $USB_URI"
  sudo lpadmin \
    -p "$PRINTER_NAME" \
    -E \
    -v "$USB_URI" \
    -m drv:///brlaser.drv/br7030.ppd

  sudo lpoptions -d "$PRINTER_NAME"
else
  echo "WARNING: Brother printer not detected yet."
  echo "You can add it later via https://printserver.local:631"
fi

# -------------------------------
# 7. Install Web UI
# -------------------------------
echo "[8/9] Installing web UI..."

sudo mkdir -p "$APP_DIR"

sudo tee "$APP_DIR/app.py" >/dev/null <<'EOF'
from flask import Flask, jsonify, redirect
import subprocess
import psutil
import time
import os

app = Flask(__name__)

def cmd(c):
    try:
        return subprocess.check_output(c, shell=True).decode().strip()
    except:
        return ""

@app.route("/status")
def status():
    return jsonify({
        "wifi": "CONNECTED" if cmd("iw dev wlan0 link") else "DISCONNECTED",
        "cups": "RUNNING" if "running" in cmd("lpstat -r") else "STOPPED",
        "mdns": "RUNNING" if cmd("systemctl is-active avahi-daemon") == "active" else "STOPPED",
        "jobs": cmd("lpstat -o | wc -l"),
        "uptime": time.strftime("%H:%M:%S", time.gmtime(time.time() - psutil.boot_time())),
        "last_reboot": time.ctime(psutil.boot_time())
    })

@app.route("/test-print")
def test_print():
    subprocess.call("echo 'Test Page from Orange Pi' | lp", shell=True)
    return redirect("/")

@app.route("/reboot")
def reboot():
    subprocess.call("reboot", shell=True)
    return "Rebooting..."

@app.route("/")
def index():
    return """
<!DOCTYPE html>
<html>
<head>
<title>Orange Pi Print Server</title>
<script>
function refresh() {
  fetch('/status').then(r=>r.json()).then(d=>{
    for (let k in d) document.getElementById(k).innerText = d[k];
  });
}
setInterval(refresh, 10000);
window.onload = refresh;
</script>
</head>
<body>
<h1>Orange Pi Print Server</h1>
WiFi: <span id="wifi"></span><br>
CUPS: <span id="cups"></span><br>
mDNS: <span id="mdns"></span><br>
Active Print Jobs: <span id="jobs"></span><br>
Uptime: <span id="uptime"></span><br>
Last Reboot: <span id="last_reboot"></span><br><br>

<a href="/test-print">Test Print</a><br>
<a href="/reboot">Reboot Device</a>
</body>
</html>
"""

app.run(host="0.0.0.0", port=8080)
EOF

# -------------------------------
# 8. systemd service for Web UI
# -------------------------------
sudo tee /etc/systemd/system/$SERVICE_NAME.service >/dev/null <<EOF
[Unit]
Description=Print Server Web UI
After=network.target cups.service

[Service]
ExecStart=/usr/bin/python3 $APP_DIR/app.py
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME
sudo systemctl start $SERVICE_NAME

# -------------------------------
# DONE
# -------------------------------
echo "======================================"
echo " Installation complete!"
echo " Web UI:  http://printserver.local:8080"
echo " CUPS:    https://printserver.local:631"
echo "======================================"
