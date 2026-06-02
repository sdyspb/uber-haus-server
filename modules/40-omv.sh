#!/bin/bash
# =============================================================================
# Reconfigure OMV web interface ports (HTTP: 8081, HTTPS: 8443) and ensure the site is enabled
# =============================================================================

source "$(dirname "$0")/00-utils.sh"

if [[ "$RECONFIGURE_OMV" != "yes" ]]; then
    log_info "OMV reconfiguration skipped"
    exit 0
fi

OMV_SITE_AVAIL="/etc/nginx/sites-available/openmediavault-webgui"
if [[ ! -f "$OMV_SITE_AVAIL" ]]; then
    log_error "OMV nginx config not found. Is OMV installed?"
    exit 1
fi

# Check if already reconfigured (IPv4 HTTP port 8081)
if [[ "$FORCE" != "yes" ]] && grep -q "listen 0.0.0.0:8081" "$OMV_SITE_AVAIL"; then
    log_info "OMV ports already changed. Skipping (use FORCE=yes to reapply)."
    exit 0
fi

log_info "Reconfiguring OMV web interface ports: HTTP $OMV_HTTP_PORT, HTTPS $OMV_HTTPS_PORT"

# Backup original
cp "$OMV_SITE_AVAIL" "${OMV_SITE_AVAIL}.backup"

# Change HTTP port for IPv4 and IPv6
sed -i 's/listen 0.0.0.0:80 default_server;/listen 0.0.0.0:8081 default_server;/' "$OMV_SITE_AVAIL"
sed -i 's/listen \[::\]:80 default_server;/listen \[::\]:8081 default_server;/' "$OMV_SITE_AVAIL"

# If HTTPS section exists (with ssl), change its port; if not, add a simple HTTPS block using existing certs
if grep -q "listen 443 ssl" "$OMV_SITE_AVAIL"; then
    sed -i 's/listen 443 ssl default_server;/listen 8443 ssl default_server;/' "$OMV_SITE_AVAIL"
    sed -i 's/listen \[::\]:443 ssl default_server;/listen \[::\]:8443 ssl default_server;/' "$OMV_SITE_AVAIL"
else
    # Insert an HTTPS server block after the HTTP server block (simplified)
    # This is a fallback; normally OMV already has HTTPS enabled
    log_info "Adding HTTPS server block for OMV using Nextcloud certificate"
    sed -i "/listen \[::\]:8081 default_server;/a\\\n    listen 8443 ssl default_server;\n    listen \[::\]:8443 ssl default_server;\n    ssl_certificate /etc/nginx/ssl/banananas.ru.crt;\n    ssl_certificate_key /etc/nginx/ssl/banananas.ru.key;\n" "$OMV_SITE_AVAIL"
fi

# Ensure the site is enabled
ln -sf "$OMV_SITE_AVAIL" /etc/nginx/sites-enabled/

# Test and reload nginx
nginx -t
systemctl restart nginx

log_info "OMV ports changed. Web interface is now accessible on ports $OMV_HTTP_PORT (HTTP) and $OMV_HTTPS_PORT (HTTPS)."
