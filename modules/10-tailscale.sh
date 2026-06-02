#!/bin/bash
# =============================================================================
# Install Tailscale and obtain a certificate for the domain
# =============================================================================

source "$(dirname "$0")/00-utils.sh"

if [[ "$INSTALL_TAILSCALE" != "yes" ]]; then
    log_info "Tailscale skipped (INSTALL_TAILSCALE != yes)"
    exit 0
fi

log_info "Installing Tailscale..."
if ! command -v tailscale &> /dev/null; then
    curl -fsSL https://tailscale.com/install.sh | sh
fi

log_info "Starting Tailscale (will require manual authentication)..."
tailscale up --advertise-exit-node --accept-routes || true

if [[ "$USE_TAILSCALE_CERT" == "yes" && -n "$DOMAIN" ]]; then
    log_info "Obtaining Tailscale certificate for $DOMAIN..."
    tailscale cert "$DOMAIN"
    mkdir -p /etc/ssl/tailscale
    cp "$DOMAIN".crt /etc/ssl/tailscale/fullchain.pem
    cp "$DOMAIN".key /etc/ssl/tailscale/privkey.pem
    log_info "Certificate installed to /etc/ssl/tailscale/"
fi

log_info "Tailscale setup completed."
