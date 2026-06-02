#!/bin/bash
# =============================================================================
# Main orchestrator for Nextcloud AIO + Tailscale + nginx installer
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"
CONFIG_FILE="$SCRIPT_DIR/uber-haus-server.conf"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

# Load utility module
source "$MODULES_DIR/00-utils.sh"

# Must be root
check_root

# Configuration file must exist
if [[ ! -f "$CONFIG_FILE" ]]; then
    log_error "Configuration file not found: $CONFIG_FILE"
    log_info "Copy uber-haus-server.conf.example to uber-haus-server.conf and edit it."
    exit 1
fi

# Load configuration
source "$CONFIG_FILE"

# Check required parameters
if [[ -z "$DOMAIN" || -z "$ADMIN_PASS" ]]; then
    log_error "Missing required parameters: DOMAIN and/or ADMIN_PASS in $CONFIG_FILE"
    exit 1
fi

# Auto‑detect DATA_ROOT if not set
if [[ -z "$DATA_ROOT" ]]; then
    detect_data_root
fi

# Export variables for all modules
export DOMAIN ADMIN_PASS DATA_ROOT NC_PORT NGINX_HTTPS_PORT OMV_HTTP_PORT OMV_HTTPS_PORT
export ADMIN_USER INSTALL_TAILSCALE INSTALL_NGINX INSTALL_NC_AIO RECONFIGURE_OMV USE_TAILSCALE_CERT
export LOG_DIR

log_info "Starting installation. Domain: $DOMAIN, DATA_ROOT: $DATA_ROOT"

run_module "10-tailscale.sh"
run_module "20-nginx.sh"
run_module "30-nextcloud-aio.sh"
run_module "40-omv.sh"

print_summary
