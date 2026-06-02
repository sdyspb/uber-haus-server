#!/bin/bash
source "$(dirname "$0")/00-utils.sh"

if [[ "$RECONFIGURE_OMV" != "yes" ]]; then
    log_info "OMV reconfiguration skipped"
    exit 0
fi

OMV_CONFIG="/etc/nginx/sites-enabled/openmediavault-webgui"
if [[ ! -f "$OMV_CONFIG" ]]; then
    log_info "OMV nginx site not found."
    exit 0
fi

if [[ "$FORCE" != "yes" ]] && grep -q "listen $OMV_HTTP_PORT default_server;" "$OMV_CONFIG"; then
    log_info "OMV ports already changed. Skipping."
    exit 0
fi

log_info "Changing OMV ports to $OMV_HTTP_PORT / $OMV_HTTPS_PORT..."
sed -i "s/listen 80 default_server;/listen $OMV_HTTP_PORT default_server;/" "$OMV_CONFIG"
sed -i "s/listen 443 ssl default_server;/listen $OMV_HTTPS_PORT ssl default_server;/" "$OMV_CONFIG"
systemctl restart nginx
log_info "OMV ports changed."
