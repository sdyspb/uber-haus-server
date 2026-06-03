#!/bin/bash
# =============================================================================
# Module 10: Install and configure Tailscale VPN
# Version: 2.0
# Author: sdyspb
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
tailscale up --advertise-exit-node --accept-routes || true
log_info "Tailscale setup completed. Authenticate via the displayed URL if needed."
