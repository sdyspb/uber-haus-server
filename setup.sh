#!/bin/bash
# =============================================================================
# Main orchestrator for Nextcloud AIO + Tailscale + nginx installer
# Provides interactive menu with checkboxes and force reinstall option.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"
CONFIG_FILE="/etc/uber-haus-server.conf"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

# Load utility module
source "$MODULES_DIR/00-utils.sh"

# Must be root
check_root

# Configuration file must exist
if [[ ! -f "$CONFIG_FILE" ]]; then
    log_error "Configuration file not found: $CONFIG_FILE"
    log_info "Copy uber-haus-server.conf.example to $CONFIG_FILE and edit it."
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

# Export all variables needed by modules
export DOMAIN ADMIN_PASS DATA_ROOT NC_PORT NGINX_HTTPS_PORT OMV_HTTP_PORT OMV_HTTPS_PORT
export ADMIN_USER INSTALL_TAILSCALE INSTALL_NGINX INSTALL_NC_AIO RECONFIGURE_OMV
export CLOUDFLARE_API_TOKEN CLOUDFLARE_VERIFY_CMD CERTBOT_EMAIL
export LOG_DIR

# Module list (order matters)
MODULES=(
    "10-tailscale.sh"
    "20-nginx.sh"
    "30-nextcloud-aio.sh"
    "40-omv.sh"
)

MODULE_NAMES=(
    "Tailscale installation"
    "nginx + SSL certificate"
    "Nextcloud AIO"
    "Reconfigure OMV ports"
)

# -------------------------------------------------------------------------
# Helper: run a module (with optional force flag)
# -------------------------------------------------------------------------
run_module_with_force() {
    local module="$1"
    local force="$2"
    local module_path="$MODULES_DIR/$module"

    if [[ ! -x "$module_path" ]]; then
        log_error "Module $module_path not found or not executable"
        return 1
    fi

    log_info "Running module $module (force=$force)"
    FORCE="$force" "$module_path"
}

# -------------------------------------------------------------------------
# Main menu loop
# -------------------------------------------------------------------------
while true; do
    CHOICE=$(whiptail --title "Nextcloud AIO Installer" \
        --menu "Choose an action" 18 70 10 \
        "1" "Run selected modules (checklist)" \
        "2" "Run all modules (quick install)" \
        "3" "Edit configuration file" \
        "4" "Exit" \
        3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]]; then
        break
    fi

    case "$CHOICE" in
        1)
            # Build checklist
            CHECKLIST=()
            for i in "${!MODULES[@]}"; do
                CHECKLIST+=("$i" "${MODULE_NAMES[$i]}" ON)
            done
            SELECTED_INDICES=$(whiptail --title "Select modules to run" \
                --checklist "Choose which steps to execute" 20 70 8 \
                "${CHECKLIST[@]}" 3>&1 1>&2 2>&3)

            if [[ $? -eq 0 && -n "$SELECTED_INDICES" ]]; then
                # Ask for force reinstall
                whiptail --title "Force reinstall?" \
                    --yesno "Run modules even if already installed/configured? (Yes = force, No = skip if done)" 10 60
                FORCE=$([ $? -eq 0 ] && echo "yes" || echo "no")

                # Convert SELECTED_INDICES (string like "0 1 2") into array
                # whiptail returns indices separated by spaces, possibly quoted? We'll handle both.
                # Remove quotes and split
                SELECTED_INDICES=$(echo "$SELECTED_INDICES" | tr -d '"')
                for idx in $SELECTED_INDICES; do
                    # Ensure idx is a number
                    if [[ "$idx" =~ ^[0-9]+$ ]]; then
                        run_module_with_force "${MODULES[$idx]}" "$FORCE"
                    else
                        log_error "Invalid index: $idx"
                    fi
                done
                whiptail --msgbox "Selected modules completed." 8 40
            else
                log_info "No modules selected or cancelled."
            fi
            ;;
        2)
            # Run all modules (quick install)
            whiptail --title "Force reinstall?" \
                --yesno "Run modules even if already installed/configured? (Yes = force, No = skip if done)" 10 60
            FORCE=$([ $? -eq 0 ] && echo "yes" || echo "no")
            for module in "${MODULES[@]}"; do
                run_module_with_force "$module" "$FORCE"
            done
            whiptail --msgbox "All modules completed." 8 40
            ;;
        3)
            nano "$CONFIG_FILE"
            # Reload configuration after editing
            source "$CONFIG_FILE"
            # Re-export variables
            export DOMAIN ADMIN_PASS DATA_ROOT NC_PORT NGINX_HTTPS_PORT OMV_HTTP_PORT OMV_HTTPS_PORT
            export ADMIN_USER INSTALL_TAILSCALE INSTALL_NGINX INSTALL_NC_AIO RECONFIGURE_OMV
            export CLOUDFLARE_API_TOKEN CLOUDFLARE_VERIFY_CMD CERTBOT_EMAIL
            whiptail --msgbox "Configuration updated. Please verify parameters." 8 50
            ;;
        4)
            break
            ;;
    esac
done

log_info "Exited installer."
