#!/bin/bash
# =============================================================================
# Install nginx and configure it as a reverse proxy for Nextcloud AIO
# =============================================================================

if [[ "$INSTALL_NGINX" != "yes" ]]; then
    log_info "nginx skipped (INSTALL_NGINX != yes)"
    exit 0
fi

log_info "Installing nginx..."
apt-get update
apt-get install -y nginx

# Create nginx site configuration
cat > /etc/nginx/sites-available/nextcloud <<EOF
server {
    listen $NGINX_HTTPS_PORT ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/ssl/tailscale/fullchain.pem;
    ssl_certificate_key /etc/ssl/tailscale/privkey.pem;

    location / {
        proxy_pass http://localhost:$NC_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

ln -sf /etc/nginx/sites-available/nextcloud /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

systemctl restart nginx
log_info "nginx configured and listening on port $NGINX_HTTPS_PORT"
