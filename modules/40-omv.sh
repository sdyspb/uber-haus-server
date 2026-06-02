#!/bin/bash
# =============================================================================
# Reconfigure OMV web interface ports to avoid conflict with nginx
# =============================================================================

if [[ "$RECONFIGURE_OMV" != "yes" ]]; then
    log_info "OMV reconfiguration skipped (RECONFIGURE_OMV != yes)"
    exit 0
fi

if [[ ! -f /etc/nginx/sites-enabled/openmediavault-webgui ]]; then
    log_info "OMV nginx site not found – OMV may not be installed or its config is elsewhere."
    exit 0
fi

log_info "Changing OMV web interface ports from 80/443 to $OMV_HTTP_PORT / $OMV_HTTPS_PORT..."

sed -i "s/listen 80 default_server;/listen $OMV_HTTP_PORT default_server;/" /etc/nginx/sites-enabled/openmediavault-webgui
sed -i "s/listen 443 ssl default_server;/listen $OMV_HTTPS_PORT ssl default_server;/" /etc/nginx/sites-enabled/openmediavault-webgui

systemctl restart nginx
log_info "OMV ports changed. OMV web interface is now accessible on ports $OMV_HTTP_PORT (HTTP) and $OMV_HTTPS_PORT (HTTPS)."
