#!/bin/bash
# =============================================================================
# Install Tailscale and set up the Tailnet (idempotent)
# =============================================================================

source "$(dirname "$0")/00-utils.sh"

# Check if already installed and authenticated
is_tailscale_ready() {
    if command -v tailscale &> /dev/null && tailscale status 2>/dev/null | grep -q "Connected"; then
        return 0
    fi
    return 1
}

if [[ "$FORCE" != "yes" ]] && is_tailscale_ready; then
    log_info "Tailscale already installed and authenticated. Skipping (use FORCE=yes to reinstall)."
    exit 0
fi

log_info "Installing Tailscale..."
if ! command -v tailscale &> /dev/null; then
    curl -fsSL https://tailscale.com/install.sh | sh
fi

log_info "Starting Tailscale (requires manual authentication)..."
tailscale up --advertise-exit-node --accept-routes || true

log_info "Tailscale setup completed."
