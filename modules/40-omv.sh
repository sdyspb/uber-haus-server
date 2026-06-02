#!/bin/bash
# =============================================================================
# Reconfigure OMV web interface ports to avoid conflict with nginx
# =============================================================================

source "$(dirname "$0")/00-utils.sh"

if [[ "$RECONFIGURE_OMV" != "yes" ]]; then
    log_info "OMV reconfiguration skipped (RECONFIGURE_OMV != yes)"
    exit 0
fi

OMV_CONFIG="/etc/nginx/sites-enabled/openmediavault-webgui"
if [[ ! -f "$OMV_CONFIG" ]]; then
    log_info "OMV nginx site not found – OMV may not be installed or its config is elsewhere."
    exit 0
fi

# Check if already reconfigured
is_omv_reconfigured() {
    if grep -q "listen $OMV_HTTP_PORT default_server;" "$OMV_CONFIG" && \
       grep -q "listen $OMV_HTTPS_PORT ssl default_server;" "$OMV_CONFIG"; then
        return 0
    fi
    return 1
}

if [[ "$FORCE" != "yes" ]] && is_omv_reconfigured; then
    log_info "OMV ports already changed to $OMV_HTTP_PORT / $OMV_HTTPS_PORT. Skipping (use FORCE=yes to reapply)."
    exit 0
fi

log_info "Changing OMV web interface ports from 80/443 to $OMV_HTTP_PORT / $OMV_HTTPS_PORT..."

sed -i "s/listen 80 default_server;/listen $OMV_HTTP_PORT default_server;/" "$OMV_CONFIG"
sed -i "s/listen 443 ssl default_server;/listen $OMV_HTTPS_PORT ssl default_server;/" "$OMV_CONFIG"

systemctl restart nginx
log_info "OMV ports changed. OMV web interface is now accessible on ports $OMV_HTTP_PORT (HTTP) and $OMV_HTTPS_PORT (HTTPS)."
