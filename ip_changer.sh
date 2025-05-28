#!/bin/bash

# Exit on errors and unset variables
set -euo pipefail

# Logging functions
info() {
    echo "[INFO] $1"
}

warn() {
    echo "[WARN] $1"
}

error() {
    echo "[ERROR] $1"
    exit 1
}

# Validate configuration file
validate_config() {
    local config_file="/usr/share/kali-whoami/assets/sources/config"
    if [[ ! -f "$config_file" ]]; then
        error "Configuration file not found: $config_file"
    fi
    source "$config_file"
}

# Backup configurations
backup_configs() {
    info "Backing up configurations..."
    mkdir -p "$BACKUPDIR"
    cp "$TORRC" "$BACKUPDIR/torrc.bak" || error "Failed to backup torrc"
    cp "/etc/resolv.conf" "$BACKUPDIR/resolv.conf.bak" || error "Failed to backup resolv.conf"
    iptables-save > "$BACKUPDIR/iptables.rules.bak" || error "Failed to backup iptables rules"
}

# Configure iptables for Tor
configure_iptables() {
    info "Configuring iptables..."
    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X
    iptables -t nat -A OUTPUT -d 10.192.0.0/10 -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -j REDIRECT --to-ports 9040
    iptables -t nat -A OUTPUT -d 127.0.0.1/32 -p udp -m udp --dport 53 -j REDIRECT --to-ports 5353
    iptables -t nat -A OUTPUT -m owner --uid-owner "$tor_uid" -j RETURN
    iptables -t nat -A OUTPUT -o lo -j RETURN

    for lan in 127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16; do
        iptables -t nat -A OUTPUT -d "$lan" -j RETURN
    done

    iptables -t nat -A OUTPUT -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -j REDIRECT --to-ports 9040
    iptables -A INPUT -m state --state ESTABLISHED -j ACCEPT
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A INPUT -j DROP
    iptables -A FORWARD -j DROP
    iptables -A OUTPUT -m conntrack --ctstate INVALID -j DROP
    iptables -A OUTPUT -m state --state INVALID -j DROP
    iptables -A OUTPUT -m state --state ESTABLISHED -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner "$tor_uid" -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -m state --state NEW -j ACCEPT
    iptables -A OUTPUT -d 127.0.0.1/32 -o lo -j ACCEPT
    iptables -A OUTPUT -d 127.0.0.1/32 -p tcp -m tcp --dport 9040 --tcp-flags FIN,SYN,RST,ACK SYN -j ACCEPT
    iptables -A OUTPUT -j DROP
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT DROP
}

# Configure Tor
configure_tor() {
    info "Configuring Tor..."
    cat > "$TORRC" <<EOF
VirtualAddrNetworkIPv4 10.192.0.0/10
AutomapHostsOnResolve 1
TransPort 9040 IsolateClientAddr IsolateClientProtocol IsolateDestAddr IsolateDestPort
SocksPort 9050
DNSPort 5353
EOF

    cat > "/etc/resolv.conf" <<EOF
# This file was edited by kali-whoami. Do not change manually!
nameserver 127.0.0.1
EOF
}

# Start Tor service
start_tor() {
    info "Starting Tor service..."
    systemctl --system daemon-reload
    if systemctl is-active tor.service >/dev/null 2>&1; then
        systemctl stop tor.service
    fi
    sysctl -w net.ipv6.conf.all.disable_ipv6=1 &> /dev/null
    sysctl -w net.ipv6.conf.default.disable_ipv6=1 &> /dev/null
    systemctl start tor.service &>/dev/null || error "Failed to start Tor service"
}

# Validate changes
validate_changes() {
    info "Validating changes..."
    if ! systemctl is-active tor.service >/dev/null 2>&1; then
        error "Tor service is not running"
    fi
    info "Validation successful"
}

# Cleanup on interruption
cleanup() {
    warn "Script interrupted. Cleaning up..."
    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    systemctl stop tor.service || true
    sysctl -w net.ipv6.conf.all.disable_ipv6=0 &> /dev/null
    sysctl -w net.ipv6.conf.default.disable_ipv6=0 &> /dev/null
    if [[ -f "$BACKUPDIR/iptables.rules.bak" ]]; then
        iptables-restore < "$BACKUPDIR/iptables.rules.bak" || true
    fi
    if [[ -f "$BACKUPDIR/torrc.bak" ]]; then
        cp "$BACKUPDIR/torrc.bak" "$TORRC" || true
    fi
    if [[ -f "$BACKUPDIR/resolv.conf.bak" ]]; then
        cp "$BACKUPDIR/resolv.conf.bak" "/etc/resolv.conf" || true
    fi
    rm -fr "$BACKUPDIR/resolv.conf.bak" "$BACKUPDIR/torrc.bak" "$BACKUPDIR/iptables.rules.bak"
    info "Cleanup complete"
}

# Main function
main() {
    trap cleanup EXIT INT TERM

    validate_config

    if [[ "$dns_changer_status" == "Disable" ]]; then
        if [[ "$ip_changer_status" == "Disable" ]]; then
            read -p "Are you sure you want to enable IP changer? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                backup_configs
                configure_iptables
                configure_tor
                start_tor
                sed -i 's/ip_changer_status="Disable"/ip_changer_status="Enable"/g' "$SRCDIR/sources/config"
                validate_changes
                info "IP changer successfully enabled"
            else
                warn "Operation cancelled by user"
            fi
        else
            warn "IP changer is already running"
        fi
    else
        warn "The IP changer is not available. (DNS changer enabled)"
    fi
}

# Execute main function
main