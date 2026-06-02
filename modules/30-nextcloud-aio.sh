#!/bin/bash
# =============================================================================
# Deploy Nextcloud AIO using Docker (idempotent) - corrected for official AIO
# =============================================================================

source "$(dirname "$0")/00-utils.sh"

if [[ "$INSTALL_NC_AIO" != "yes" ]]; then
    log_info "Nextcloud AIO skipped (INSTALL_NC_AIO != yes)"
    exit 0
fi

log_info "Checking Docker availability..."
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed. Please install Docker first (e.g., via OMV extras)."
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    log_error "docker-compose not found. Please install docker-compose."
    exit 1
fi

log_info "Docker is present. Proceeding with Nextcloud AIO setup."

# Stop and remove existing container and volume if force
if [[ "$FORCE" == "yes" ]]; then
    cd "$DATA_ROOT/nextcloud_aio" 2>/dev/null && docker compose down 2>/dev/null || true
    docker rm -f nextcloud-aio-mastercontainer 2>/dev/null || true
    docker volume rm -f nextcloud_aio_mastercontainer 2>/dev/null || true
fi

mkdir -p "$DATA_ROOT/nextcloud_aio"

# Create the required docker volume for AIO master container
docker volume create nextcloud_aio_mastercontainer

# Write correct docker-compose.yml according to official AIO documentation
cat > "$DATA_ROOT/nextcloud_aio/docker-compose.yml" <<EOF
services:
  nextcloud-aio-mastercontainer:
    image: nextcloud/all-in-one:latest
    restart: always
    container_name: nextcloud-aio-mastercontainer
    volumes:
      - nextcloud_aio_mastercontainer:/mnt/docker-aio-config
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

volumes:
  nextcloud_aio_mastercontainer:
    external: true
EOF

cd "$DATA_ROOT/nextcloud_aio"
docker compose up -d || docker-compose up -d

log_info "Nextcloud AIO started. Initialization may take a few minutes."
