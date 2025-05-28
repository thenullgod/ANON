#!/usr/bin/env python

import argparse
import logging
import platform
import subprocess
from scapy.all import Ether, ARP, srp, sniff, conf

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Whitelist of trusted MAC addresses
TRUSTED_MACS = set()

def get_mac(ip):
    """
    Retrieve the MAC address for a given IP address.
    :param ip: Target IP address
    :return: MAC address or None if not found
    """
    try:
        p = Ether(dst='ff:ff:ff:ff:ff:ff') / ARP(pdst=ip)
        result = srp(p, timeout=3, verbose=False)[0]
        return result[0][1].hwsrc
    except Exception as e:
        logger.error(f"Failed to get MAC for {ip}: {e}")
        return None

def block_mac(mac):
    """
    Block a MAC address (cross-platform).
    :param mac: MAC address to block
    """
    try:
        if platform.system() == "Linux":
            subprocess.run(["iptables", "-A", "INPUT", "-m", "mac", "--mac-source", mac, "-j", "DROP"], check=True)
        elif platform.system() == "Windows":
            # Example: Use netsh (adjust as needed)
            subprocess.run(["netsh", "advfirewall", "firewall", "add", "rule", "name=\"Block MAC\"", "dir=in", "action=block", "remoteip=any", f"remoteMAC={mac}"], check=True)
        else:
            logger.warning(f"Unsupported platform for blocking MAC: {platform.system()}")
    except subprocess.CalledProcessError as e:
        logger.error(f"Failed to block MAC {mac}: {e}")

def process(packet):
    """
    Process ARP packets to detect spoofing.
    :param packet: Scapy packet
    """
    if packet.haslayer(ARP) and packet[ARP].op == 2:
        src_ip = packet[ARP].psrc
        response_mac = packet[ARP].hwsrc

        if response_mac in TRUSTED_MACS:
            logger.debug(f"Ignoring trusted MAC: {response_mac}")
            return

        real_mac = get_mac(src_ip)
        if real_mac and real_mac != response_mac:
            logger.warning(f"ARP spoofing detected! IP: {src_ip}, Real MAC: {real_mac}, Spoofed MAC: {response_mac}")
            block_mac(response_mac)

def main():
    """
    Main function to parse arguments and start sniffing.
    """
    parser = argparse.ArgumentParser(description="ARP Spoofing Detector")
    parser.add_argument("-i", "--interface", help="Network interface to sniff on", default=conf.iface)
    parser.add_argument("-v", "--verbose", help="Enable verbose logging", action="store_true")
    args = parser.parse_args()

    if args.verbose:
        logger.setLevel(logging.DEBUG)

    logger.info(f"Starting ARP spoofing detector on interface {args.interface}")
    sniff(iface=args.interface, store=False, prn=process, filter="arp")

if __name__ == "__main__":
    main()