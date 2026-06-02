#!/bin/bash
# =============================================================================
# Install nginx, obtain SSL certificate via Let's Encrypt (DNS-01 with Cloudflare),
# and configure reverse proxy for Nextcloud AIO
# =============================================================================

source "$(dirname "$0")/00-utils.sh"

if [[ "$INSTALL_NGINX" != "yes" ]]; then
    log_info "nginx skipped (INSTALL_NGINX != yes)"
    exit 0
fi

log_info "Installing nginx and certbot..."
apt-get update
apt-get install -y nginx certbot python3-certbot-dns-cloudflare

# Prepare Cloudflare credentials
if [[ -z "$CLOUDFLARE_API_TOKEN" ]]; then
    log_error "CLOUDFLARE_API_TOKEN is not set in the configuration file."
    log_info "Please obtain a Cloudflare API token with DNS edit permissions and add it to $CONFIG_FILE"
    exit 1
fi

CLOUDFLARE_CREDS="/etc/letsencrypt/cloudflare.ini"
mkdir -p /etc/letsencrypt
cat > "$CLOUDFLARE_CREDS" <<EOF
dns_cloudflare_api_token = $CLOUDFLARE_API_TOKEN
EOF
chmod 600 "$CLOUDFLARE_CREDS"

# Set default email if not provided
if [[ -z "$CERTBOT_EMAIL" ]]; then
    CERTBOT_EMAIL="admin@$DOMAIN"
    log_info "CERTBOT_EMAIL not set, using default: $CERTBOT_EMAIL"
fi

# Obtain certificate (DNS-01 challenge)
log_info "Obtaining Let's Encrypt certificate for $DOMAIN..."
certbot certonly --dns-cloudflare --dns-cloudflare-credentials "$CLOUDFLARE_CREDS" \
    --non-interactive --agree-tos --email "$CERTBOT_EMAIL" \
    -d "$DOMAIN"

if [[ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
    log_error "Certificate retrieval failed. Check your domain and Cloudflare token."
    exit 1
fi

log_info "Certificate obtained successfully."

# Configure nginx site
cat > /etc/nginx/sites-available/nextcloud <<EOF
server {
    listen $NGINX_HTTPS_PORT ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

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
