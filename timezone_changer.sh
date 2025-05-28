#!/bin/bash

# =============================================
# Browser Anonymization Script
# Description: Enables/disables browser anonymization for Firefox ESR.
# Usage: ./timezone_changer.sh [--dry-run]
# Dependencies: sed, cp, rm, Firefox ESR
# =============================================

# Configurable paths (can be overridden via environment variables)
SRCDIR="${SRCDIR:-/usr/share/kali-whoami/assets/sources}"
CONFIG_FILE="${CONFIG_FILE:-$SRCDIR/config}"
FIREFOX_DIR="${FIREFOX_DIR:-/etc/firefox-esr}"
WHOAMI_JS="${WHOAMI_JS:-$SRCDIR/whoami.js}"

# Logging functions
log_info() {
    echo "[INFO] $1"
}

log_warn() {
    echo "[WARN] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

# Load and validate config file
load_and_validate_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "Config file not found: $CONFIG_FILE"
        exit 1
    fi

    if ! source "$CONFIG_FILE"; then
        log_error "Failed to source config file"
        exit 1
    fi

    if [[ "$browser_anonymization_status" != "Enable" && "$browser_anonymization_status" != "Disable" ]]; then
        log_error "Invalid browser_anonymization_status in config: $browser_anonymization_status"
        exit 1
    fi
}

# Update config file status
update_config_status() {
    local status="$1"
    if ! sed -i "s/browser_anonymization_status=\".*\"/browser_anonymization_status=\"$status\"/g" "$CONFIG_FILE"; then
        log_error "Failed to update config file"
        exit 1
    fi
}

start_browser_anonymization() {
    load_and_validate_config

    if [[ "$browser_anonymization_status" == "Disable" ]]; then
        if [ ! -d "$FIREFOX_DIR" ]; then
            log_warn "Browser anonymization only supports Firefox and Firefox not found on your system"
            exit 1
        fi

        if [ ! -f "$WHOAMI_JS" ]; then
            log_error "whoami.js not found: $WHOAMI_JS"
            exit 1
        fi

        if [[ "$1" == "--dry-run" ]]; then
            log_info "Dry run: Would copy $WHOAMI_JS to $FIREFOX_DIR/"
            log_info "Dry run: Would enable browser anonymization"
            return 0
        fi

        if ! cp "$WHOAMI_JS" "$FIREFOX_DIR/"; then
            log_error "Failed to copy whoami.js"
            exit 1
        fi

        update_config_status "Enable"
        log_info "Browser anonymization enabled"
    else
        log_warn "Browser anonymization is already enabled"
    fi
}

stop_browser_anonymization() {
    load_and_validate_config

    if [[ "$browser_anonymization_status" == "Enable" ]]; then
        if [[ "$1" == "--dry-run" ]]; then
            log_info "Dry run: Would remove $FIREFOX_DIR/whoami.js"
            log_info "Dry run: Would disable browser anonymization"
            return 0
        fi

        if [ -f "$FIREFOX_DIR/whoami.js" ]; then
            if ! rm -f "$FIREFOX_DIR/whoami.js"; then
                log_error "Failed to remove whoami.js"
                exit 1
            fi
        fi

        update_config_status "Disable"
        log_info "Browser anonymization disabled"
    else
        log_warn "Browser anonymization is already disabled"
    fi
}

# Main execution
case "$1" in
    "--dry-run")
        log_info "Dry run mode: Testing start functionality"
        start_browser_anonymization --dry-run
        log_info "Dry run mode: Testing stop functionality"
        stop_browser_anonymization --dry-run
        ;;
    *)
        start_browser_anonymization
        ;;
esac
