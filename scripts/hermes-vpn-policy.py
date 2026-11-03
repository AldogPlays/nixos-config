#!/usr/bin/env python3
"""Keep the Hermes VPN off on its home connection and on on other uplinks."""

import argparse
import fcntl
import os
from pathlib import Path
import subprocess
import sys


UPLINK_TYPES = {"802-11-wireless", "802-3-ethernet", "gsm", "cdma", "bluetooth", "pppoe"}
EVENTS = {"reconcile", "up", "down", "dhcp4-change", "dhcp6-change", "connectivity-change", "reapply"}
PAUSE_FILE = Path("/run/hermes-vpn-paused")


def desired_state(active, home_uuid):
    if any(uuid == home_uuid for uuid, _kind in active):
        return False
    return any(kind in UPLINK_TYPES for _uuid, kind in active)


def nmcli(*arguments):
    return subprocess.run(
        ["nmcli", *arguments], capture_output=True, text=True, timeout=5, check=False
    )


def reconcile(home_uuid, paused=False):
    # Only public metadata is queried; this helper never reads credentials.
    profile = nmcli("-g", "connection.uuid", "connection", "show", "id", "hermes-homelab")
    if profile.returncode:
        return 0  # Credentials have not been imported (or were deliberately removed).
    vpn_uuid = profile.stdout.strip()
    status = nmcli("-t", "-f", "UUID,TYPE", "connection", "show", "--active")
    if status.returncode:
        raise RuntimeError("Cannot inspect active connections")
    active = [tuple(line.split(":", 1)) for line in status.stdout.splitlines() if ":" in line]
    wanted = not paused and desired_state(active, home_uuid)
    current = any(uuid == vpn_uuid for uuid, _kind in active)
    if wanted != current:
        # Return immediately: waiting for activation inside a dispatcher can block
        # the very dispatcher events that complete the activation.
        result = nmcli("--wait", "0", "connection", "up" if wanted else "down", "uuid", vpn_uuid)
        if result.returncode:
            raise RuntimeError("Cannot apply VPN policy")
        print("Hermes VPN: " + ("activation requested away from home" if wanted else "deactivation requested"))
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--home-uuid", required=True)
    parser.add_argument("--pause", action="store_true", help="turn off and pause automatic activation until resume or reboot")
    parser.add_argument("--resume", action="store_true", help="resume automatic activation and apply the current network policy")
    parser.add_argument("interface", nargs="?", default="")
    parser.add_argument("action", nargs="?", default="reconcile")
    args = parser.parse_args()
    # Ignore the tunnel's own changes so manual toggles last until an uplink event.
    if args.action not in EVENTS or args.interface == "wg-hermes":
        return 0
    try:
        if os.geteuid() != 0 or (args.pause and args.resume):
            raise ValueError("Root access required; choose pause or resume")
        descriptor = os.open("/run/lock/hermes-vpn-policy.lock", os.O_CREAT | os.O_WRONLY | os.O_NOFOLLOW, 0o600)
        with os.fdopen(descriptor, "w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            if args.pause:
                PAUSE_FILE.touch(mode=0o600)
            elif args.resume:
                PAUSE_FILE.unlink(missing_ok=True)
            return reconcile(args.home_uuid, paused=PAUSE_FILE.exists())
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired):
        print("Hermes VPN policy could not be applied; credentials withheld.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
