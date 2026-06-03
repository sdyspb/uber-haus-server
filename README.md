# uber-haus-server

This repository provides a modular installer that sets up:

- [Tailscale](https://tailscale.com/) – secure VPN & automatic HTTPS certificates
- [nginx](https://nginx.org/) – reverse proxy with HTTPS (using Let's Encrypt certificates via DNS‑01 challenge)
- [Nextcloud](https://nextcloud.com/) – Classic Nextcloud (MariaDB, Redis, optional Talk High‑Performance Backend)
- [OpenMediaVault](https://www.openmediavault.org/) – web interface port reconfiguration (to free ports 80/443 for nginx)

All configuration is done via a single commented file – no command‑line arguments are needed.

---

## 📋 Requirements

- **Hardware:** PixelNAS, BananaNAS or any SBC running Armbian
- **Software:** Armbian with **OMV 7.x** (or 8.x) already installed.
- **Docker:** Docker and docker-compose must be installed beforehand. The easiest way is via the OMV‑Compose plugin (Services → Compose → Settings → Install Docker). The installer will verify their presence and exit if not found.
- **Disk:** A mounted data drive (e.g., NVMe/RAID) – the installer will automatically detect the first `/srv/dev-disk-by-uuid-*` directory, or you can set it manually (recommended).
- **Network:** A domain name (e.g., `banananas.ru`) that you intend to use with Tailscale (no public DNS needed – works inside your Tailnet).

---

## 🧭 DNS and SSL certificate

This installer assumes you own a domain (e.g., `banananas.ru`) and have delegated its DNS management to **Cloudflare**.  
You must create an **A record** pointing to your server's Tailscale IP address (e.g., `100.xxx.xxx.xxx`) with **proxy disabled** (DNS only).  

The SSL certificate is obtained automatically using **Let's Encrypt DNS‑01 challenge** via Cloudflare API.  
To enable this, you need a Cloudflare API token with **DNS:Edit** permission.  
Add the token to the configuration file (`uber-haus-server.conf`) as `CLOUDFLARE_API_TOKEN`.

After installation, your Nextcloud will be accessible at `https://your-domain` (only from devices connected to your Tailnet, because the A record points to a Tailscale IP).  
If you configure `OMV_SUBDOMAIN` (e.g., `omv.banananas.ru`), OMV will be accessible at `https://omv.banananas.ru` without specifying a port.

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
| **Let's Encrypt certificate** | Obtained for your domain via Cloudflare DNS‑01 challenge.               |
| **nginx**           | Installed, configured as a reverse proxy for Nextcloud on port 443.       |
| **Nextcloud**       | Classic stack (MariaDB, Redis, Nextcloud app) running in Docker containers, listening locally on port 8080. |
| **Talk HPB**        | (Optional) High‑Performance Backend for Nextcloud Talk, running on port 8081. |
| **OMV ports**       | (If selected) Changed to `8081` (HTTP) and `8443` (HTTPS) to avoid conflicts. |
| **OMV subdomain**   | (If configured) OMV becomes available at `https://omv.your-domain` (no port). |
| **HTTPS access**    | Your Nextcloud is available at `https://your-domain` (inside your Tailnet). |

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
cd uber-haus-server
```
### 3. Make scripts executable
```bash
chmod +x setup.sh modules/*.sh
```
### 4. Edit the configuration file
```bash
sudo cp /opt/uber-haus-server/uber-haus-server.conf.example /etc/uber-haus-server.conf
sudo nano /etc/uber-haus-server.conf   # fill DOMAIN, NEXTCLOUD_ADMIN_PASSWORD, CLOUDFLARE_API_TOKEN, etc.
```
### 5. Run the installer as root
```bash
cd /opt/uber-haus-server
sudo ./setup.sh
```
The installation will:

- Validate your configuration
- Install each selected component according to checklist
- Save logs to logs/setup.log

### 6. Interface

* Whiptail menu: run selected modules, run all, edit config:

<img width="589" height="325" alt="image" src="https://github.com/user-attachments/assets/473c74da-249f-4f37-83b9-7df4ceac0fac" />

* Each step checks if already done; skip unless Force reinstall is enabled:

<img width="585" height="353" alt="image" src="https://github.com/user-attachments/assets/127023e9-8158-4d19-abe8-bcb3098aaa9b" />

---

### Module status checks

| Module                    | Check                                                                 |
|---------------------------|-----------------------------------------------------------------------|
| Tailscale                 | `tailscale status` shows "Connected"                                  |
| nginx + certificate       | nginx site exists and certificate file present                        |
| Classic Nextcloud         | Docker containers `nextcloud-app`, `nextcloud-db`, `nextcloud-redis` running |
| Talk HPB (optional)       | Docker container `nextcloud-talk-hpb` running on port 8081            |
| OMV ports                 | `/etc/nginx/sites-available/openmediavault-webgui` uses custom ports  |
| OMV subdomain (if set)    | nginx site for `OMV_SUBDOMAIN` created and active                     |

### 7. After installation

- **Authenticate Tailscale** – open the URL shown after `tailscale up` in your browser and log in.
- **Access Nextcloud** – open `https://your-domain` (you must be connected to your Tailnet).
- **Complete Nextcloud setup** – the first run will guide you through the final steps (create admin account – already pre‑filled with `NEXTCLOUD_ADMIN_USER`/`NEXTCLOUD_ADMIN_PASSWORD`).
- **If Talk HPB was enabled**, after logging into Nextcloud go to **Settings → Talk** and set:
  - HPB server URL: `https://your-domain/standalone-signaling/`
  - HPB secret: the generated secret printed in the installer log (or set in config).

> ⚠️ **Important:** The domain will only be reachable from devices inside your Tailscale network (Tailnet). For public access, use Tailscale Funnel or a different setup.

### 🛠️ Troubleshooting

- **Logs:** Check `logs/setup.log` for detailed error messages.
- **Tailscale not connected:** Run `tailscale up` manually and follow the link.
- **Certificate not ready:** Wait a few minutes or run `certbot renew --force-renewal` manually.
- **Nextcloud not starting:** Use `docker ps` to see if containers are running. View logs with `docker logs nextcloud-app`.
- **Talk HPB not working:** Ensure the secret matches and the nginx location `/standalone-signaling/` is proxied correctly.
- **OMV web interface still on 80/443:** The installer modifies the OMV nginx site. If you skipped that step, change ports manually in `/etc/nginx/sites-enabled/openmediavault-webgui` or re‑run module 40 with `Force = Yes`.
- **OMV subdomain not responding:** Verify that `OMV_SUBDOMAIN` is set in the config and that the A record for the subdomain points to your Tailscale IP (DNS only). Then re‑run module 20 with `Force = Yes`.

### 📜 Acknowledgements & Licenses

This project builds upon and includes components from the following Open Source projects. Thank their authors and respect their licenses.

- **[Tailscale](https://tailscale.com/)** – BSD 3‑Clause License  
  Used for secure VPN networking and automatic HTTPS certificates (DNS‑01 challenge).
- **[nginx](https://nginx.org/)** – BSD 2‑Clause License  
  Used as a reverse proxy and HTTPS terminator.
- **[Nextcloud](https://nextcloud.com/)** – GNU AGPLv3  
  The core cloud storage and collaboration platform.
- **[MariaDB](https://mariadb.org/)** – GNU GPLv2  
  Database backend for Nextcloud.
- **[Redis](https://redis.io/)** – BSD 3‑Clause License  
  Cache and session storage for Nextcloud.
- **[Talk HPB](https://github.com/nextcloud-releases/talk-high-performance-backend)** – GNU AGPLv3  
  High‑Performance Backend for Nextcloud Talk.
- **[Certbot](https://certbot.eff.org/)** – Apache License 2.0  
  Let's Encrypt client used to obtain SSL certificates via DNS‑01.
- **[Cloudflare API](https://api.cloudflare.com/)** – Used under Cloudflare’s terms of service.
- **[Docker](https://www.docker.com/)** – Apache License 2.0  
  Container runtime for Nextcloud and related services.
- **[OpenMediaVault](https://www.openmediavault.org/)** – GNU GPLv3  
  NAS management platform whose web interface ports are reconfigured.
- **[Armbian](https://www.armbian.com/)** – GNU GPLv2  
  The base operating system on which this installer runs.
- **[whiptail](https://manpages.debian.org/testing/newt/whiptail.1.en.html)** – GNU LGPLv2  
  Used for the interactive menu.

Full license texts of each project can be found on their respective websites.
