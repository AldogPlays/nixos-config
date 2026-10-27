"""Select firmware-managed battery protection; never implement a software cutoff."""

import argparse
import os
from pathlib import Path
import sys


POWER_SUPPLIES = Path("/sys/class/power_supply")
MODES = {"protect": "Long_Life", "full": "Standard"}


def batteries(root):
    result = []
    for device in sorted(root.glob("*")):
        try:
            if (device / "type").read_text().strip() == "Battery":
                result.append(device)
        except FileNotFoundError:
            # A removable supply can disappear during discovery.
            continue
    return result


def read_modes(path):
    tokens = path.read_text().split()
    selected = [token[1:-1] for token in tokens if token.startswith("[") and token.endswith("]")]
    if len(selected) != 1:
        raise ValueError(f"{path}: expected one selected charging mode")
    return {token.strip("[]") for token in tokens}, selected[0]


def select_mode(path, desired):
    available, current = read_modes(path)
    if not set(MODES.values()).issubset(available):
        return None
    if current != desired:
        path.write_text(desired + "\n")
        _, current = read_modes(path)
        if current != desired:
            raise RuntimeError(f"{path}: requested {desired}, but firmware reports {current}")
    return current


def main(argv=None, root=POWER_SUPPLIES):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["status", *MODES])
    args = parser.parse_args(argv)
    if args.action != "status" and os.geteuid() != 0:
        print(f"Changing charging mode requires sudo: sudo battery-charge {args.action}", file=sys.stderr)
        return 1

    supported = 0
    failed = False
    devices = batteries(root)
    for device in devices:
        path = device / "charge_types"
        try:
            if args.action == "status":
                available, current = read_modes(path)
                print(f"{device.name}: {current} (available: {', '.join(sorted(available))})")
                continue
            selected = select_mode(path, MODES[args.action])
            if selected is None:
                print(f"{device.name}: Long_Life/Standard controls unavailable; unchanged")
                continue
            supported += 1
            detail = "firmware conservation limit" if args.action == "protect" else "normal full charging allowed"
            print(f"{device.name}: {selected} — {detail}")
        except FileNotFoundError:
            print(f"{device.name}: charging-mode control unavailable; unchanged")
        except (OSError, ValueError, RuntimeError) as error:
            print(f"{device.name}: {error}", file=sys.stderr)
            failed = True

    if not devices:
        print("No batteries detected; nothing changed.")
    elif args.action != "status" and supported == 0 and not failed:
        print("No supported charging-mode controls found; nothing changed.")
    return 1 if failed else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except OSError as error:
        print(f"Unable to inspect battery controls: {error}", file=sys.stderr)
        sys.exit(1)
