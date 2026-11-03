#!/usr/bin/env python3
"""Import a Hermes router export without putting credentials in Nix or argv."""

import argparse
import base64
import configparser
import ipaddress
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import uuid


def key(value):
    if len(base64.b64decode(value, validate=True)) != 32:
        raise ValueError("Invalid WireGuard key")
    return value


def profile(source):
    config = configparser.ConfigParser(interpolation=None)
    config.read_string(source)
    if config.defaults() or set(config.sections()) != {"Interface", "Peer"}:
        raise ValueError("Expected one interface and one peer")
    interface, peer = config["Interface"], config["Peer"]
    # Reject hooks and unsupported options rather than silently executing or losing them.
    if set(interface) - {"privatekey", "address", "dns", "mtu", "listenport"}:
        raise ValueError("Unsupported interface option")
    if set(peer) - {"publickey", "presharedkey", "allowedips", "endpoint", "persistentkeepalive"}:
        raise ValueError("Unsupported peer option")
    addresses = [ipaddress.ip_interface(item.strip()) for item in interface["Address"].split(",")]
    if len(addresses) != 1 or addresses[0].version != 4:
        raise ValueError("Expected one IPv4 tunnel address")
    endpoint = peer["Endpoint"]
    if not re.fullmatch(r"[A-Za-z0-9.-]+:[0-9]{1,5}", endpoint):
        raise ValueError("Expected an IPv4 or hostname endpoint")
    if not 1 <= int(endpoint.rsplit(":", 1)[1]) <= 65535:
        raise ValueError("Invalid endpoint port")
    keepalive = int(peer.get("PersistentKeepalive", "25"))
    if not 0 <= keepalive <= 65535:
        raise ValueError("Invalid keepalive")
    result = configparser.ConfigParser(interpolation=None)
    result["connection"] = {
        "id": "hermes-homelab",
        "uuid": str(uuid.uuid4()),
        "type": "wireguard",
        "interface-name": "wg-hermes",
        "autoconnect": "false",
    }
    result["wireguard"] = {
        "private-key": key(interface["PrivateKey"]),
        "private-key-flags": "0",
        "peer-routes": "true",
        "ip4-auto-default-route": "0",
        "ip6-auto-default-route": "0",
    }
    for option, maximum in (("MTU", 65535), ("ListenPort", 65535)):
        if option in interface:
            value = int(interface[option])
            if not 0 <= value <= maximum:
                raise ValueError("Invalid interface setting")
            result["wireguard"]["mtu" if option == "MTU" else "listen-port"] = str(value)
    peer_section = {
        "endpoint": endpoint,
        "allowed-ips": "10.10.10.0/24;10.10.40.0/24;",
        "persistent-keepalive": str(keepalive),
    }
    if "PresharedKey" in peer:
        peer_section["preshared-key"] = key(peer["PresharedKey"])
        peer_section["preshared-key-flags"] = "0"
    result["wireguard-peer." + key(peer["PublicKey"])] = peer_section
    result["ipv4"] = {
        "method": "manual",
        "address1": str(addresses[0]),
        "never-default": "true",
        "ignore-auto-dns": "true",
        "dns": "10.10.10.1;",
        "dns-search": "~home.arpa;",
        "dns-priority": "50",
        "route-metric": "50",
    }
    result["ipv6"] = {"method": "disabled", "never-default": "true"}
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("configuration", type=Path)
    parser.add_argument("--check", action="store_true", help="validate without writing or printing credentials")
    args = parser.parse_args()
    try:
        result = profile(args.configuration.read_text())
        if args.check:
            print("Valid Hermes export; split routing, home.arpa DNS and manual activation will be enforced.")
            return 0
        if os.geteuid() != 0:
            raise ValueError("Run the import with sudo")
        destination = Path("/etc/NetworkManager/system-connections/hermes-homelab.nmconnection")
        destination.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        # Root-only temporary file; link atomically without overwriting an existing profile.
        with tempfile.NamedTemporaryFile(mode="w", dir=destination.parent, prefix=".hermes-") as temporary:
            result.write(temporary, space_around_delimiters=False)
            temporary.flush()
            os.fsync(temporary.fileno())
            os.link(temporary.name, destination)
        loaded = subprocess.run(
            ["nmcli", "connection", "load", str(destination)], capture_output=True, check=False
        )
        if loaded.returncode:
            destination.unlink()
            raise ValueError("NetworkManager rejected the profile")
        print("Imported hermes-homelab, OFF with autoconnect disabled; credentials are root-only.")
        return 0
    except (OSError, ValueError, KeyError, configparser.Error):
        # Parser and NM errors can contain input data. Never print their raw messages.
        print("Import failed. Check the export, root access and that no Hermes profile already exists; credentials withheld.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
