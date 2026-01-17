# Orange Pi Print Server

A lightweight AirPrint-compatible print server with a real-time web UI,
designed for Orange Pi and other ARM boards.

No nginx. No CGI. Single Python daemon.

---

## Features

- Auto-discovered via mDNS (`printserver.local`)
- Real-time web UI (no refresh button)
- Live status:
  - WiFi connection
  - CUPS service
  - mDNS (Avahi)
  - Active print jobs
- Device uptime & last reboot
- Remote reboot from UI
- Systemd-managed daemon (auto-start on boot)

---

## Web Interface

Accessible from any device on the local network:

http://printserver.local:8080

The page automatically refreshes status every 5 seconds.

---

## Installation

Clone the repository and run:

```bash
chmod +x install_printserver.sh
sudo ./install_printserver.sh
```

Edit script for your printer:
- set your printer name, look for the following line:
    PRINTER_NAME="Brother_DCP7030"

- install your printer driver for debian, look for the following line:
    echo "[5/9] Installing Brother laser driver..."
    sudo apt install -y printer-driver-brlaser

- add your printer to cups along with selecting printer driver, make sure printer is plugged into orangepi
    https://printserver.local:631
    - add printer
    - use your orangepi credientials
    - select your printer, name and go through the printer setup UI (make sure you select share printer)

- access the printer from another device
    http://printserver.local:8080
    - print test page (printer is connected to orangepi)
    - reboot orangepi and check if all services start after reboot (headless and reboot recovery print server)

---

## Services Used

- Python 3 HTTP server
- CUPS (printing)
- Avahi (mDNS)
- systemd (daemon management)

---

## File Structure

<pre>
/opt/printserver
  ├── app.py
  ├── templates/
│     └── index.html
  ├── static/
  │   └── app.js
</pre>

---

## Notes:
- WiFi-only operation (no Ethernet required)
- Designed for headless devices
- Safe to power-cycle
- Automatically reconnects after reboot

| Feature                 | Status |
| ----------------------- | ------ |
| CUPS auto-starts        | ✅      |
| Brother printer added   | ✅      |
| Android / iOS discovery | ✅      |
| `printserver.local`     | ✅      |
| Web UI status page      | ✅      |
| Test print button       | ✅      |
| Survives power loss     | ✅      |
