#!/bin/bash
# =============================================================================
# Install Tailscale and set up the Tailnet (idempotent)
# =============================================================================

source "$(dirname "$0")/00-utils.sh"

if [[ "$INSTALL_TAILSCALE" != "yes" ]]; then
    log_info "Tailscale skipped"
    exit 0
fi

if [[ "$FORCE" != "yes" ]] && command -v tailscale &> /dev/null && tailscale status 2>/dev/null | grep -q "Connected"; then
    log_info "Tailscale already running. Skipping."
    exit 0
fi

log_info "Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh

log_info "Starting Tailscale (requires manual authentication if not already authenticated)..."
tailscale up --advertise-exit-node --accept-routes || true

log_info "Tailscale setup completed. If a login URL appeared, open it in your browser to authenticate."
