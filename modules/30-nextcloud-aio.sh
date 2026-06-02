#!/bin/bash
# =============================================================================
# Deploy Nextcloud AIO using Docker (idempotent)
# =============================================================================

source "$(dirname "$0")/00-utils.sh"

# Check if already running
is_nextcloud_running() {
    if docker ps --filter "name=nextcloud-aio-mastercontainer" --filter "status=running" | grep -q nextcloud-aio-mastercontainer; then
        return 0
    fi
    return 1
}

if [[ "$FORCE" != "yes" ]] && is_nextcloud_running; then
    log_info "Nextcloud AIO container is already running. Skipping (use FORCE=yes to recreate)."
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
if [[ "$FORCE" == "yes" ]]; then
    docker compose down || docker-compose down
fi
docker compose up -d || docker-compose up -d

log_info "Nextcloud AIO started. Initialization may take a few minutes."
