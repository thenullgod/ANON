#!/bin/bash

# Configuration file path
CONFIG_FILE="/usr/share/kali-whoami/assets/sources/config"

# Backup directory for MAC addresses
BACKUP_DIR="$BACKUPDIR/mac_addresses"

# Function to generate a random MAC address
generate_random_mac() {
    local mac=""
    for i in {1..6}; do
        if [ "$i" -lt 6 ]; then
            mac+=$(printf "%02x:" "$((RANDOM % 256))")
        else
            mac+=$(printf "%02x" "$((RANDOM % 256))")
        fi
    done
    echo "$mac"
}

# Function to change MAC address for a given interface
change_mac_address() {
    local iface="$1"
    local new_mac
    while :; do
        new_mac=$(generate_random_mac)
        ip link set "$iface" down || { warn "Failed to bring down interface $iface"; return 1; }
        if ip link set "$iface" address "$new_mac"; then
            ip link set "$iface" up || { warn "Failed to bring up interface $iface"; return 1; }
            break
        fi
    done
}

# Function to start MAC changer
start_mac_changer() {
    source "$CONFIG_FILE" || { error "Failed to load config file"; return 1; }

    if [[ "$mac_changer_status" == "Disable" ]]; then
        # Create backup directory if it doesn't exist
        mkdir -p "$BACKUP_DIR" || { error "Failed to create backup directory"; return 1; }

        # Backup current MAC addresses
        local interfaces
        interfaces=$(ip -o link show | awk -F': ' '{print $2}')
        for iface in $interfaces; do
            if [ "$iface" != "lo" ]; then
                cat "/sys/class/net/$iface/address" > "$BACKUP_DIR/$iface" || { warn "Failed to backup MAC for $iface"; }
            fi
        done

        # Check if running in a virtual machine
        local is_vm=false
        if dmidecode -s system-manufacturer | grep -qE "innotek GmbH|VMware, Inc."; then
            is_vm=true
        fi

        # Change MAC addresses
        for iface in $interfaces; do
            if [ "$iface" != "lo" ]; then
                if [ "$is_vm" = true ] && [ "$iface" = "eth0" ]; then
                    continue
                fi
                change_mac_address "$iface" || { warn "Failed to change MAC for $iface"; }
            fi
        done

        # Update config file
        sed -i 's/mac_changer_status="Disable"/mac_changer_status="Enable"/g' "$CONFIG_FILE" || { error "Failed to update config file"; return 1; }
        info "MAC changer successfully enabled"
    else
        warn "MAC changer is already running"
    fi
}

# Function to stop MAC changer
stop_mac_changer() {
    source "$CONFIG_FILE" || { error "Failed to load config file"; return 1; }

    if [ -d "$BACKUP_DIR" ]; then
        for device in "$BACKUP_DIR"/*; do
            local iface=$(basename "$device")
            ip link set "$iface" down || { warn "Failed to bring down interface $iface"; continue; }
            ip link set "$iface" address "$(cat "$device")" || { warn "Failed to restore MAC for $iface"; }
            ip link set "$iface" up || { warn "Failed to bring up interface $iface"; }
        done
        rm -rf "$BACKUP_DIR" || { error "Failed to remove backup directory"; return 1; }
    fi

    sed -i 's/mac_changer_status="Enable"/mac_changer_status="Disable"/g' "$CONFIG_FILE" || { error "Failed to update config file"; return 1; }
    info "MAC changer successfully disabled"
}

# Helper functions for logging
info() { echo "[INFO] $1"; }
warn() { echo "[WARN] $1"; }
error() { echo "[ERROR] $1"; exit 1; }

# Main script logic
case "$1" in
    start)
        start_mac_changer
        ;;
    stop)
        stop_mac_changer
        ;;
    *)
        echo "Usage: $0 {start|stop}"
        exit 1
        ;;
esac