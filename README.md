# uber-haus-server
Script for quick home server setup

# Nextcloud AIO + Tailscale + nginx installer for Armbian / OMV

This repository provides a modular, non‑interactive installer that sets up:

- [Tailscale](https://tailscale.com/) – secure VPN & automatic HTTPS certificates
- [nginx](https://nginx.org/) – reverse proxy with HTTPS (using Tailscale certificates)
- [Nextcloud All‑in‑One](https://github.com/nextcloud/all-in-one) – the complete Nextcloud suite (including Files, Talk, etc.)
- (Optional) OMV web interface port reconfiguration (to free ports 80/443 for nginx)

All configuration is done via a single commented file – no command‑line arguments are needed.

---

## 📋 Requirements

- **Hardware:** PixelNAS, BananaNAS or SBC running Armbian 
- **Software:** Armbian with **OMV 7.x** (or 8.x) already installed.
- **Docker:** Docker and docker-compose must be installed beforehand. The easiest way is via the OMV‑Compose plugin (Services → Compose → Settings → Install Docker). The installer will verify their presence and exit if not found.
- **Disk:** A mounted data drive (e.g., NVMe/RAID) – the installer will automatically detect the first `/srv/dev-disk-by-uuid-*` directory.
- **Network:** A domain name (e.g., `banananas.ru`) that you intend to use with Tailscale (no public DNS needed – works inside your Tailnet).

---

## 🧩 Components – Before & After

### Before installation (system state)
- OMV web interface listens on ports **80** and **443**
- No Docker, no Tailscale, no nginx
- No Nextcloud

### After installation
| Component           | Description                                                                 |
|---------------------|-----------------------------------------------------------------------------|
| **Tailscale**       | Installed and running. Your device will appear in your Tailnet.            |
| **Tailscale certificate** | A Let's Encrypt certificate obtained for your domain (via `tailscale cert`) |
| **nginx**           | Installed, configured as a reverse proxy for Nextcloud AIO on port 443.     |
| **Docker**          | Installed (docker.io + docker-compose).                                    |
| **Nextcloud AIO**   | Running as a Docker container, listening locally on port 8080.             |
| **OMV ports**       | (If selected) Changed to `8081` (HTTP) and `8443` (HTTPS) to avoid conflicts. |
| **HTTPS access**    | Your Nextcloud will be available at `https://your-domain` (inside your Tailnet). |

---

## 🚀 Quick start (deployment on Armbian)

### 1. Prepare your system
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl
```
### 2. Clone the repository
```bash
git clone git@github.com:sdyspb/uber-haus-server.git
cd uber-haus-server.git
```
### 3. Make scripts executable
```bash
chmod +x setup.sh modules/*.sh
```
### 4. Edit the configuration file
```bash
sudo cp /opt/uber-haus-server/uber-haus-server.conf.example /etc/uber-haus-server.conf
sudo nano /etc/uber-haus-server.conf   # fill DOMAIN and ADMIN_PASS
```
### 5. Run the installer as root
```bash
cd /opt/uber-haus-server
sudo ./setup.sh
```
The installation is fully non‑interactive. It will:

- Validate your configuration
- Install each selected component in sequence
- Save logs to logs/setup.log

### 6. After installation

- Authenticate Tailscale – open the URL shown after tailscale up in your browser and log in.
- Access Nextcloud – open https://your-domain (you must be connected to your Tailnet).
- Complete Nextcloud AIO setup – the first run will guide you through the final steps (create admin account, configure database, etc.). The installer has already pre‑filled the admin user/password.

> ⚠️ Important: The domain will only be reachable from devices inside your Tailscale network (Tailnet). If you want public access, you need to use Tailscale Funnel or a different setup.

### 🛠️ Troubleshooting

- Logs: Check logs/setup.log for detailed error messages.
- Tailscale not connected: Run tailscale up manually and follow the link.
- Certificate not ready: Wait a few minutes after tailscale cert or run tailscale cert your-domain manually.
- Nextcloud AIO not starting: Use docker ps to see if the container is running. View logs with docker logs nextcloud-aio-mastercontainer.
- OMV web interface still on 80/443: The installer modifies the OMV nginx site. If you skipped that step, change ports manually in /etc/nginx/sites-enabled/openmediavault-webgui.
