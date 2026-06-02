#!/bin/bash
# =============================================================================
# Deploy Nextcloud AIO using Docker (Docker must already be installed)
# =============================================================================

if [[ "$INSTALL_NC_AIO" != "yes" ]]; then
    log_info "Nextcloud AIO skipped (INSTALL_NC_AIO != yes)"
    exit 0
fi

log_info "Checking Docker availability..."
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed. Please install Docker first (e.g., via OMV extras or 'apt install docker.io docker-compose')."
    exit 1
fi

# Check for docker-compose (either standalone or plugin)
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    log_error "docker-compose not found. Please install docker-compose (e.g., via OMV extras or 'apt install docker-compose')."
    exit 1
fi

log_info "Docker is present. Proceeding with Nextcloud AIO setup."

mkdir -p "$DATA_ROOT/nextcloud_aio"

cat > "$DATA_ROOT/nextcloud_aio/docker-compose.yml" <<EOF
version: '3.8'
services:
  nextcloud-aio-mastercontainer:
    image: nextcloud/all-in-one:latest
    restart: always
    container_name: nextcloud-aio-mastercontainer
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - "$DATA_ROOT/nextcloud_aio:/var/lib/docker/volumes/nextcloud_aio/_data"
    environment:
      - APACHE_PORT=$NC_PORT
      - SKIP_DOMAIN_VALIDATION=true
      - TRUSTED_DOMAINS=$DOMAIN
      - OVERWRITEHOST=$DOMAIN
      - OVERWRITEPROTOCOL=https
      - NEXTCLOUD_ADMIN_USER=$ADMIN_USER
      - NEXTCLOUD_ADMIN_PASSWORD=$ADMIN_PASS
    ports:
      - "$NC_PORT:8080"
EOF

cd "$DATA_ROOT/nextcloud_aio"
docker compose up -d || docker-compose up -d

log_info "Nextcloud AIO started. Initialization may take a few minutes."
