#!/bin/bash
# =============================================================================
# Module 20: Install nginx, obtain SSL certificate (SAN for all domains),
#            configure reverse proxy for Nextcloud, OMV, and landing page.
# Version: 3.1
# Author: sdyspb
# =============================================================================

source "$(dirname "$0")/00-utils.sh"

if [[ "$INSTALL_NGINX" != "yes" ]]; then
    log_info "nginx skipped"
    exit 0
fi

if [[ "$FORCE" != "yes" ]] && [[ -f "/etc/nginx/sites-enabled/nextcloud" ]]; then
    log_info "nginx site already configured. Skipping (use FORCE=yes to recreate)."
    exit 0
fi

log_info "Installing nginx and certbot..."
apt-get update
apt-get install -y nginx certbot python3-certbot-dns-cloudflare

if [[ -z "$CLOUDFLARE_API_TOKEN" ]]; then
    log_error "CLOUDFLARE_API_TOKEN not set."
    exit 1
fi

CLOUDFLARE_CREDS="/etc/letsencrypt/cloudflare.ini"
mkdir -p /etc/letsencrypt
cat > "$CLOUDFLARE_CREDS" <<EOF
dns_cloudflare_api_token = $CLOUDFLARE_API_TOKEN
EOF
chmod 600 "$CLOUDFLARE_CREDS"

if [[ -z "$CERTBOT_EMAIL" ]]; then
    CERTBOT_EMAIL="admin@$DOMAIN"
    log_info "Using default email: $CERTBOT_EMAIL"
fi

log_info "Obtaining Let's Encrypt certificate for $DOMAIN, $NEXTCLOUD_DOMAIN, $OMV_DOMAIN..."
certbot certonly --dns-cloudflare --dns-cloudflare-credentials "$CLOUDFLARE_CREDS" \
    --non-interactive --agree-tos --email "$CERTBOT_EMAIL" \
    -d "$DOMAIN" -d "$NEXTCLOUD_DOMAIN" -d "$OMV_DOMAIN"

if [[ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
    log_error "Certificate retrieval failed."
    exit 1
fi

# --------------------------------------------------------------------------
# Create landing page (static placeholder or user-provided)
# --------------------------------------------------------------------------
mkdir -p /var/www/landing

if [[ -f "$SCRIPT_DIR/landing.html" ]]; then
    log_info "Copying user-provided landing page from $SCRIPT_DIR/landing.html"
    cp "$SCRIPT_DIR/landing.html" /var/www/landing/index.html
else
    log_info "Creating default landing page"
    cat > /var/www/landing/index.html <<EOF
<!DOCTYPE html>
<html>
<head><title>$DOMAIN</title></head>
<body>
<h1>Welcome to $DOMAIN</h1>
<p>Services:</p>
<ul>
    <li><a href="https://$NEXTCLOUD_DOMAIN">Nextcloud</a></li>
    <li><a href="https://$OMV_DOMAIN">OMV</a></li>
</ul>
</body>
</html>
EOF
fi

chown -R www-data:www-data /var/www/landing

# --------------------------------------------------------------------------
# Configure nginx sites
# --------------------------------------------------------------------------
# Landing page
cat > /etc/nginx/sites-available/landing <<EOF
server {
    listen $NGINX_HTTPS_PORT ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    root /var/www/landing;
    index index.html;
}
EOF

# Nextcloud reverse proxy
cat > /etc/nginx/sites-available/nextcloud <<EOF
server {
    listen $NGINX_HTTPS_PORT ssl;
    server_name $NEXTCLOUD_DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    client_max_body_size 10G;

    location / {
        proxy_pass http://127.0.0.1:$NC_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Port \$server_port;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
EOF

if [[ "$INSTALL_TALK_HPB" == "yes" ]]; then
    cat >> /etc/nginx/sites-available/nextcloud <<EOF

    location /standalone-signaling/ {
        proxy_pass http://127.0.0.1:8081/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
EOF
fi

echo "}" >> /etc/nginx/sites-available/nextcloud

# OMV reverse proxy (HTTP backend, because OMV listens on 8081)
cat > /etc/nginx/sites-available/omv <<EOF
server {
    listen $NGINX_HTTPS_PORT ssl;
    server_name $OMV_DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:$OMV_HTTP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Enable sites
ln -sf /etc/nginx/sites-available/landing /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/nextcloud /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/omv /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test and reload nginx
nginx -t && systemctl restart nginx
log_info "nginx configured for $DOMAIN, $NEXTCLOUD_DOMAIN, $OMV_DOMAIN."
