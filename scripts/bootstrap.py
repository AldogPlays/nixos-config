"""Adopt a fresh NixOS installation without repartitioning or copying Lenovo IDs."""

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import platform
import pwd
import re
import shutil
import subprocess
import sys
import tempfile


FEATURES = ["--extra-experimental-features", "nix-command flakes"]
FILES = (
    "project-hardware.nix",
    "project-host.nix",
    "project-host.json",
    "flake.lock",
    "flake.nix",  # Publish the entry point last.
)


def run(arguments, **kwargs):
    return subprocess.run(arguments, check=True, **kwargs)


def nix(*arguments, **kwargs):
    return run(["nix", *FEATURES, *map(str, arguments)], **kwargs)


def validate_release(release):
    if not re.fullmatch(r"\d{2}\.\d{2}", release):
        raise ValueError("Cannot determine the installed NixOS release.")
    if tuple(map(int, release.split("."))) > (26, 5):
        raise ValueError(
            "This project's pinned NixOS 26.05 cannot adopt a newer installation."
        )


def validate_host(host):
    if host.get("unsupportedGraphics"):
        raise ValueError(
            "Custom graphics packages need an explicit host module; standard VA-API extras and NVIDIA branches are supported."
        )
    if host.get("unsupportedBoot"):
        raise ValueError(
            "Custom Secure Boot or mirrored GRUB needs an explicit host module."
        )
    loader = host["bootLoader"]
    if loader["systemd-boot"]["enable"] == loader["grub"]["enable"]:
        raise ValueError("Expected an existing systemd-boot or GRUB installation.")
    if not host["mutableUsers"]:
        raise ValueError(
            "Immutable user accounts need a separate secret/account migration."
        )
    if not host["userIsNormal"]:
        raise ValueError(
            "The selected account must be an existing declared normal user."
        )
    if not re.fullmatch(r"[a-z_][a-z0-9_-]*", host["username"]):
        raise ValueError("Unsupported login name.")
    if not Path(host["homeDirectory"]).is_absolute():
        raise ValueError("The existing user's home directory must be absolute.")
    validate_release(host["stateVersion"])


def write_configuration(stage, project, hardware, host):
    templates = project / "bootstrap"
    url = json.dumps("path:" + str(project)).replace("${", r"\${")
    flake = (templates / "flake.nix.in").read_text().replace("@PROJECT_URL@", url)
    (stage / "flake.nix").write_text(flake)
    (stage / "project-host.nix").write_bytes((templates / "host.nix").read_bytes())
    (stage / "project-host.json").write_text(json.dumps(host, indent=2) + "\n")
    (stage / "project-hardware.nix").write_bytes(hardware.read_bytes())


def check_destination(destination):
    if destination.is_symlink():
        raise ValueError("Refusing to replace a symlinked configuration directory.")
    if (destination / "flake.nix").exists():
        marker = destination / "project-host.json"
        try:
            owned = json.loads(marker.read_text()).get("bootstrapSchema") == 1
        except (OSError, ValueError, AttributeError):
            owned = False
        if not owned:
            raise ValueError(
                "An existing unrelated flake is present; it needs an explicit migration."
            )


def privileged(*arguments):
    prefix = [] if os.geteuid() == 0 else ["/run/wrappers/bin/sudo", "--"]
    run([*prefix, *map(str, arguments)])


def install(stage, destination, host):
    # Recheck after building: a different installation must not be overwritten.
    check_destination(destination)
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
    backup = destination.with_name(destination.name + ".pre-project-" + timestamp)
    privileged(shutil.which("cp"), "-a", "--", destination, backup)
    print(f"Original configuration backup: {backup}", flush=True)
    for name in FILES:
        privileged(
            shutil.which("install"),
            "-m",
            "0644",
            "--",
            stage / name,
            destination / name,
        )
    try:
        privileged(
            shutil.which("nixos-rebuild"),
            "switch",
            "--flake",
            str(destination) + "#nixos",
        )
        if (
            host["bootLoader"]["systemd-boot"]["enable"]
            and host["bootLoader"]["efi"]["canTouchEfiVariables"]
        ):
            privileged(shutil.which("bootctl"), "set-timeout", "")
    except subprocess.CalledProcessError:
        print(
            f"Activation failed. Configuration backup: {backup}. No automatic reboot was attempted.",
            file=sys.stderr,
        )
        raise


def parse_arguments(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-source", type=Path, required=True)
    parser.add_argument("--nixpkgs-source", type=Path, required=True)
    parser.add_argument(
        "--configuration", type=Path, default=Path("/etc/nixos/configuration.nix")
    )
    parser.add_argument(
        "--hardware",
        type=Path,
        help="Defaults to hardware-configuration.nix beside --configuration",
    )
    parser.add_argument(
        "--user",
        default=os.environ.get("SUDO_USER") or pwd.getpwuid(os.getuid()).pw_name,
    )
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--apply",
        action="store_true",
        help="Build, back up /etc/nixos and activate; may replace the login manager",
    )
    mode.add_argument("--plan", action="store_true", help="Preview only (the default)")
    parser.add_argument(
        "--output",
        type=Path,
        help="Save the preview's generated host files for inspection",
    )
    return parser.parse_args(argv)


def running_nixos():
    return Path("/etc/NIXOS").exists()


def installed_release():
    return platform.freedesktop_os_release().get("VERSION_ID", "")


def main(argv=None):
    args = parse_arguments(argv)
    if platform.system() != "Linux" or platform.machine() != "x86_64":
        raise ValueError("This bootstrap targets installed x86-64 NixOS systems.")
    if not running_nixos():
        raise ValueError("Run this on an installed NixOS system.")
    # stateVersion is a compatibility baseline, not the installed OS release.
    validate_release(installed_release())
    account = pwd.getpwnam(args.user)
    if account.pw_uid == 0:
        raise ValueError("Run as the existing desktop user, or pass --user LOGIN.")
    project = args.project_source.resolve()
    configuration = args.configuration.resolve(strict=True)
    hardware = (
        args.hardware or configuration.with_name("hardware-configuration.nix")
    ).resolve(strict=True)
    if args.apply:
        if args.output:
            raise ValueError("--output is a preview option; use --apply without it.")
        check_destination(Path("/etc/nixos"))
    result = nix(
        "eval",
        "--impure",
        "--json",
        "--file",
        project / "scripts/read-host.nix",
        "--apply",
        'reader: reader { nixpkgs = builtins.getEnv "NIXOS_BOOTSTRAP_NIXPKGS"; configuration = builtins.getEnv "NIXOS_BOOTSTRAP_CONFIGURATION"; username = builtins.getEnv "NIXOS_BOOTSTRAP_USER"; }',
        env=dict(
            os.environ,
            NIXOS_BOOTSTRAP_NIXPKGS=str(args.nixpkgs_source),
            NIXOS_BOOTSTRAP_CONFIGURATION=str(configuration),
            NIXOS_BOOTSTRAP_USER=args.user,
        ),
        capture_output=True,
        text=True,
    )
    host = json.loads(result.stdout)
    host.update(
        bootstrapSchema=1,
        username=args.user,
        homeDirectory=account.pw_dir,
        homeStateVersion="26.05",
    )
    validate_host(host)
    print(f"Target: {host['hostName']} / {host['username']} / {host['homeDirectory']}")
    print(
        f"Preserving system.stateVersion={host['stateVersion']}, existing disks/encryption and bootloader."
    )
    print(
        f"Graphics drivers: {', '.join(host['videoDrivers'])}; shared Hyprland desktop and cache included."
    )
    with tempfile.TemporaryDirectory(prefix="nixos-config-bootstrap-") as temporary:
        stage = Path(temporary)
        write_configuration(stage, project, hardware, host)
        # Explicit path references avoid inheriting an unrelated parent Git repo.
        stage_reference = "path:" + str(stage)
        nix("flake", "lock", stage_reference)
        target = (
            stage_reference + "#nixosConfigurations.nixos.config.system.build.toplevel"
        )
        nix("build", target, "--no-link", *([] if args.apply else ["--dry-run"]))
        if args.apply:
            install(stage, Path("/etc/nixos"), host)
            print(
                "Applied. Use rebuild for updates and log into the Hyprland session. No reboot was requested."
            )
        elif args.output:
            output = args.output.expanduser().resolve()
            if output.exists() and any(output.iterdir()):
                raise ValueError("--output must be absent or an empty directory.")
            output.mkdir(parents=True, exist_ok=True)
            for name in FILES:
                shutil.copyfile(stage / name, output / name)
            print(f"Preview saved to {output}; no system configuration changed.")
        else:
            print(
                "Preview passed; no system configuration changed. Add --apply to build and activate."
            )


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as error:
        print(f"Bootstrap stopped: {error}", file=sys.stderr)
        if isinstance(error, subprocess.CalledProcessError) and error.stderr:
            print(error.stderr, file=sys.stderr)
        sys.exit(1)
