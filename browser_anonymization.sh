#!/bin/bash

# Configuration paths (can be overridden via environment variables)
CONFIG_FILE="${CONFIG_FILE:-/usr/share/nullGPT/assets/sources/config}"
WHOAMI_JS="${WHOAMI_JS:-$SRCDIR/sources/whoami.js}"

# Help and usage information
usage() {
    echo "Usage: $0 [--enable|--disable|--dry-run|--help]"
    echo "Options:"
    echo "  --enable    Enable browser anonymization"
    echo "  --disable   Disable browser anonymization"
    echo "  --dry-run   Simulate changes without applying them"
    echo "  --help      Show this help message"
    exit 1
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Validate dependencies
validate_dependencies() {
    if ! command_exists "firefox-esr"; then
        echo "Error: Firefox ESR is not installed. This script requires Firefox ESR."
        exit 1
    fi

    if [ ! -d "/etc/firefox-esr" ]; then
        echo "Error: /etc/firefox-esr directory not found."
        exit 1
    fi

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: Config file not found at $CONFIG_FILE."
        exit 1
    fi
}

# Source the config file safely
source_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: Config file not found at $CONFIG_FILE."
        exit 1
    fi
    source "$CONFIG_FILE" || {
        echo "Error: Failed to source config file."
        exit 1
    }
}

# Enable browser anonymization
enable_anonymization() {
    local dry_run="$1"
    if [[ "$browser_anonymization_status" == "Disable" ]]; then
        if [ "$dry_run" = false ]; then
            cp "$WHOAMI_JS" "/etc/firefox-esr/" || {
                echo "Error: Failed to copy whoami.js."
                exit 1
            }
            sed -i 's/browser_anonymization_status="Disable"/browser_anonymization_status="Enable"/g' "$CONFIG_FILE" || {
                echo "Error: Failed to update config file."
                exit 1
            }
            echo "Browser anonymization successfully enabled."
        else
            echo "[Dry Run] Would copy $WHOAMI_JS to /etc/firefox-esr/ and update config."
        fi
    else
        echo "Browser anonymization is already enabled."
    fi
}

# Disable browser anonymization
disable_anonymization() {
    local dry_run="$1"
    if [[ "$browser_anonymization_status" == "Enable" ]]; then
        if [ "$dry_run" = false ]; then
            rm -f "/etc/firefox-esr/null.js" || {
                echo "Error: Failed to remove null.js."
                exit 1
            }
            sed -i 's/browser_anonymization_status="Enable"/browser_anonymization_status="Disable"/g' "$CONFIG_FILE" || {
                echo "Error: Failed to update config file."
                exit 1
            }
            echo "Browser anonymization successfully disabled."
        else
            echo "[Dry Run] Would remove /etc/firefox-esr/null.js and update config."
        fi
    else
        echo "Browser anonymization is already disabled."
    fi
}

# Main script logic
main() {
    local action=""
    local dry_run=false

    # Parse command-line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --enable)
                action="enable"
                shift
                ;;
            --disable)
                action="disable"
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --help)
                usage
                ;;
            *)
                echo "Error: Invalid argument '$1'."
                usage
                ;;
        esac
    done

    if [ -z "$action" ]; then
        echo "Error: No action specified."
        usage
    fi

    validate_dependencies
    source_config

    case "$action" in
        enable)
            enable_anonymization "$dry_run"
            ;;
        disable)
            disable_anonymization "$dry_run"
            ;;
    esac
}

# Run the script
main "$@"
