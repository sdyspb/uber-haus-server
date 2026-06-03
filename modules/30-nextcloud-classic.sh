#!/bin/bash
# =============================================================================
# Module 30: Deploy classic Nextcloud stack (MariaDB, Redis, Nextcloud, optional Talk HPB)
# Version: 3.0
# Author: sdyspb
# =============================================================================

source "$(dirname "$0")/00-utils.sh"

if [[ "$INSTALL_NC_CLASSIC" != "yes" ]]; then
    log_info "Nextcloud classic skipped"
    exit 0
fi

if [[ "$FORCE" != "yes" ]] && docker ps --filter "name=nextcloud-app" --filter "status=running" | grep -q nextcloud-app; then
    log_info "Nextcloud stack already running. Skipping (use FORCE=yes to recreate)."
    exit 0
fi

[[ -z "$MYSQL_PASSWORD" ]] && MYSQL_PASSWORD="$NEXTCLOUD_ADMIN_PASSWORD"
[[ -z "$REDIS_PASSWORD" ]] && REDIS_PASSWORD="$NEXTCLOUD_ADMIN_PASSWORD"

log_info "Creating directories..."
mkdir -p "$DATA_ROOT/nextcloud"/{db,redis,nextcloud,config}
if [[ "$INSTALL_TALK_HPB" == "yes" ]]; then
    mkdir -p "$DATA_ROOT/nextcloud/talk-hpb"
fi
chown -R 33:33 "$DATA_ROOT/nextcloud"

if [[ "$INSTALL_TALK_HPB" == "yes" && -z "$TALK_SECRET" ]]; then
    TALK_SECRET=$(openssl rand -base64 32)
    log_info "Generated Talk secret: $TALK_SECRET (save this for Nextcloud settings)"
fi

log_info "Creating docker-compose.yml..."
cat > "$DATA_ROOT/nextcloud/docker-compose.yml" <<EOF
services:
  db:
    image: mariadb:11
    container_name: nextcloud-db
    restart: unless-stopped
    command: --transaction-isolation=READ-COMMITTED --log-bin=binlog --binlog-format=ROW
    volumes:
      - $DATA_ROOT/nextcloud/db:/var/lib/mysql
    environment:
      - MYSQL_ROOT_PASSWORD=$MYSQL_PASSWORD
      - MYSQL_PASSWORD=$MYSQL_PASSWORD
      - MYSQL_DATABASE=$MYSQL_DATABASE
      - MYSQL_USER=$MYSQL_USER

  redis:
    image: redis:alpine
    container_name: nextcloud-redis
    restart: unless-stopped
    command: redis-server --requirepass $REDIS_PASSWORD
    volumes:
      - $DATA_ROOT/nextcloud/redis:/data

  app:
    image: nextcloud:stable
    container_name: nextcloud-app
    restart: unless-stopped
    ports:
      - "$NC_PORT:80"
    volumes:
      - $DATA_ROOT/nextcloud/nextcloud:/var/www/html
      - $DATA_ROOT/nextcloud/config:/var/www/html/config
    environment:
      - MYSQL_HOST=$MYSQL_HOST
      - MYSQL_DATABASE=$MYSQL_DATABASE
      - MYSQL_USER=$MYSQL_USER
      - MYSQL_PASSWORD=$MYSQL_PASSWORD
      - REDIS_HOST=redis
      - REDIS_HOST_PASSWORD=$REDIS_PASSWORD
      - NEXTCLOUD_ADMIN_USER=$NEXTCLOUD_ADMIN_USER
      - NEXTCLOUD_ADMIN_PASSWORD=$NEXTCLOUD_ADMIN_PASSWORD
      - TRUSTED_DOMAINS=$NEXTCLOUD_DOMAIN
      - OVERWRITEHOST=$NEXTCLOUD_DOMAIN
      - OVERWRITEPROTOCOL=https
      - PUID=33
      - PGID=33
    depends_on:
      - db
      - redis
EOF

if [[ "$INSTALL_TALK_HPB" == "yes" ]]; then
    cat >> "$DATA_ROOT/nextcloud/docker-compose.yml" <<EOF

  talk-hpb:
    image: ghcr.io/nextcloud-releases/talk-high-performance-backend:latest
    container_name: nextcloud-talk-hpb
    restart: unless-stopped
    ports:
      - "127.0.0.1:8081:8080"
    volumes:
      - $DATA_ROOT/nextcloud/talk-hpb:/config
    environment:
      - NEXTCLOUD_URL=https://$NEXTCLOUD_DOMAIN
      - SECRET=$TALK_SECRET
    depends_on:
      - app
EOF
fi

echo "" >> "$DATA_ROOT/nextcloud/docker-compose.yml"

cd "$DATA_ROOT/nextcloud"
if [[ "$FORCE" == "yes" ]]; then
    docker compose down 2>/dev/null
fi
docker compose up -d

log_info "Nextcloud stack started with domain $NEXTCLOUD_DOMAIN."
if [[ "$INSTALL_TALK_HPB" == "yes" ]]; then
    log_info "Talk HPB running on port 8081. Secret: $TALK_SECRET"
fi
