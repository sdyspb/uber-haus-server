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
