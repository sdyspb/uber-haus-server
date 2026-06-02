#!/bin/bash
# =============================================================================
# Install nginx, obtain SSL certificate via Let's Encrypt (DNS-01 with Cloudflare),
# and configure reverse proxy for Nextcloud (with optional Talk HPB location)
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
    log_error "CLOUDFLARE_API_TOKEN is not set in the configuration file."
    exit 1
fi

# Optionally verify token using user-provided command
if [[ -n "$CLOUDFLARE_VERIFY_CMD" ]]; then
    log_info "Verifying Cloudflare API token using provided command..."
    if ! eval "$CLOUDFLARE_VERIFY_CMD" | grep -q '"status":"active"'; then
        log_error "Cloudflare API token verification failed. Check your token and command."
        exit 1
    fi
    log_info "Cloudflare API token is valid."
else
    log_info "CLOUDFLARE_VERIFY_CMD not set; skipping token verification."
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

log_info "Obtaining Let's Encrypt certificate for $DOMAIN (if not already present)..."
certbot certonly --dns-cloudflare --dns-cloudflare-credentials "$CLOUDFLARE_CREDS" \
    --non-interactive --agree-tos --email "$CERTBOT_EMAIL" -d "$DOMAIN" 2>&1 | tee -a "$LOG_DIR/setup.log"

if [[ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
    log_error "Certificate retrieval failed. Check your domain and Cloudflare token."
    exit 1
fi

# Copy certificates to nginx ssl directory
mkdir -p /etc/nginx/ssl
cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" /etc/nginx/ssl/banananas.ru.crt
cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" /etc/nginx/ssl/banananas.ru.key
chmod 644 /etc/nginx/ssl/banananas.ru.crt
chmod 600 /etc/nginx/ssl/banananas.ru.key

log_info "SSL certificates copied to /etc/nginx/ssl/"

# Build nginx config
cat > /etc/nginx/sites-available/nextcloud <<EOF
server {
    listen $NGINX_HTTPS_PORT ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/nginx/ssl/banananas.ru.crt;
    ssl_certificate_key /etc/nginx/ssl/banananas.ru.key;

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

cat >> /etc/nginx/sites-available/nextcloud <<EOF
}
EOF

ln -sf /etc/nginx/sites-available/nextcloud /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

systemctl restart nginx
log_info "nginx configured and listening on port $NGINX_HTTPS_PORT"
