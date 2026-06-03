#!/bin/bash
# =============================================================================
# Reconfigure OMV web interface ports to avoid conflict with nginx.
# Ensures OMV listens on $OMV_HTTP_PORT (HTTP) and $OMV_HTTPS_PORT (HTTPS).
# =============================================================================

source "$(dirname "$0")/00-utils.sh"

if [[ "$RECONFIGURE_OMV" != "yes" ]]; then
    log_info "OMV reconfiguration skipped"
    exit 0
fi

OMV_CONFIG="/etc/nginx/sites-available/openmediavault-webgui"
if [[ ! -f "$OMV_CONFIG" ]]; then
    log_info "OMV nginx site not found – OMV may not be installed."
    exit 0
fi

# Check if already reconfigured
if [[ "$FORCE" != "yes" ]] && grep -q "listen $OMV_HTTP_PORT default_server;" "$OMV_CONFIG"; then
    log_info "OMV ports already changed to $OMV_HTTP_PORT / $OMV_HTTPS_PORT. Skipping."
    exit 0
fi

log_info "Changing OMV web interface ports to $OMV_HTTP_PORT (HTTP) and $OMV_HTTPS_PORT (HTTPS)..."

# Replace listen directives
sudo sed -i "s/listen 80 default_server;/listen $OMV_HTTP_PORT default_server;/" "$OMV_CONFIG"
sudo sed -i "s/listen \[::\]:80 default_server;/listen \[::\]:$OMV_HTTP_PORT default_server;/" "$OMV_CONFIG"
sudo sed -i "s/listen 443 ssl default_server;/listen $OMV_HTTPS_PORT ssl default_server;/" "$OMV_CONFIG"
sudo sed -i "s/listen \[::\]:443 ssl default_server;/listen \[::\]:$OMV_HTTPS_PORT ssl default_server;/" "$OMV_CONFIG"

# Ensure IPv4 listen for HTTPS port (if missing, add it)
if ! grep -q "listen 0.0.0.0:$OMV_HTTPS_PORT" "$OMV_CONFIG"; then
    sudo sed -i "/listen \[::\]:$OMV_HTTPS_PORT ssl default_server;/i\    listen 0.0.0.0:$OMV_HTTPS_PORT ssl default_server;" "$OMV_CONFIG"
fi

# Regenerate OMV nginx config via salt (to keep consistency)
sudo omv-salt deploy run nginx

sudo systemctl restart nginx
log_info "OMV ports changed and nginx reloaded."
