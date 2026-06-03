#!/bin/bash
# =============================================================================
# Utility functions for logging, detection, and summary
# Version: 3.0
# Author: sdyspb
# =============================================================================

log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $*" | tee -a "$LOG_DIR/setup.log"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*" | tee -a "$LOG_DIR/setup.log" >&2
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (sudo)."
        exit 1
    fi
}

detect_data_root() {
    local disk_path
    disk_path=$(find /srv -maxdepth 1 -type d -name "dev-disk-by-uuid-*" | head -1)
    if [[ -n "$disk_path" ]]; then
        DATA_ROOT="${disk_path}/appdata"
        log_info "Auto‑detected DATA_ROOT: $DATA_ROOT"
    else
        log_error "Could not auto‑detect DATA_ROOT. Please set it manually in $CONFIG_FILE."
        exit 1
    fi
}

print_summary() {
    cat <<EOF

=============================================================================
✅ Installation completed successfully!

Nextcloud access:
    https://$NEXTCLOUD_DOMAIN

Admin credentials:
    Login: $NEXTCLOUD_ADMIN_USER
    Password: $NEXTCLOUD_ADMIN_PASSWORD

OMV web interface:
    https://$OMV_DOMAIN

Landing page (static placeholder):
    https://$DOMAIN

Configuration file: $CONFIG_FILE
Logs: $LOG_DIR/setup.log

Check container status: docker ps
=============================================================================
EOF
}
