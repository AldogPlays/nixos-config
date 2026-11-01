"""Choose a declarative desktop theme through Rofi and the normal NixOS rebuild."""

import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile


ACTIVE_THEME = Path("/run/current-system/etc/desktop-theme.json")


def command(*arguments, **kwargs):
    return subprocess.run(list(map(str, arguments)), check=True, **kwargs)


def active_preset(path=ACTIVE_THEME):
    try:
        data = json.loads(path.read_text())
        return data.get("preset") if isinstance(data, dict) else None
    except (OSError, ValueError):
        return None


def menu_entries(presets, active):
    return [
        (key, value["name"] + ("  — Active" if key == active else ""))
        for key, value in presets.items()
    ]


def updated_configuration(config, preset):
    directory = Path(config["configuration"]["directory"])
    kind = config["configuration"]["kind"]
    if not (directory / "flake.nix").is_file():
        raise ValueError(f"Configuration checkout not found: {directory}")
    if kind == "checkout":
        source = directory / "theme/selection.nix"
    elif kind == "portable":
        source = directory / "project-host.json"
    else:
        raise ValueError("Unrecognized configuration type")
    if source.is_symlink() or str(source.resolve()).startswith("/nix/store/"):
        raise ValueError(
            "Theme settings must be in an editable configuration, outside the Nix store"
        )
    original = source.read_bytes()
    if kind == "checkout":
        updated, count = re.subn(
            r'(?m)^(\s*preset\s*=\s*)"[^"\n]*"(\s*;)',
            lambda match: match[1] + json.dumps(preset) + match[2],
            original.decode(),
        )
        if count != 1:
            raise ValueError(
                "Expected one literal preset assignment in theme/selection.nix"
            )
        updated = updated.encode()
    else:
        data = json.loads(original)
        if data.get("bootstrapSchema") != 1:
            raise ValueError("This is not a project-generated host configuration")
        selection = dict(data.get("themeSelection", config["defaultSelection"]))
        selection["preset"] = preset
        data["themeSelection"] = selection
        updated = (json.dumps(data, indent=2) + "\n").encode()
    return source, original, updated, kind == "portable"


def replace_configuration(source, expected, content, privileged, run=command):
    if source.read_bytes() != expected:
        raise RuntimeError(
            "Theme settings changed during the operation; leaving them untouched"
        )
    mode = stat.S_IMODE(source.stat().st_mode)
    with tempfile.NamedTemporaryFile(
        prefix="desktop-theme-", delete=False
    ) as temporary:
        temporary.write(content)
        temporary_path = Path(temporary.name)
    staged = source.with_name("." + source.name + "." + temporary_path.name)
    try:
        if privileged:
            run(
                "/run/wrappers/bin/sudo",
                "install",
                "-m",
                f"{mode:o}",
                "--",
                temporary_path,
                staged,
            )
            # Recheck after any authentication prompt, before publishing the file.
            if source.read_bytes() != expected:
                raise RuntimeError("Theme settings changed; leaving them untouched")
            run("/run/wrappers/bin/sudo", "mv", "-fT", "--", staged, source)
        else:
            staged.write_bytes(content)
            staged.chmod(mode)
            if source.read_bytes() != expected:
                raise RuntimeError("Theme settings changed; leaving them untouched")
            staged.replace(source)
    finally:
        temporary_path.unlink(missing_ok=True)
        if staged.exists():
            if privileged:
                run("/run/wrappers/bin/sudo", "rm", "-f", "--", staged)
            else:
                staged.unlink()


def apply_theme(config, preset, run=command, active_path=ACTIVE_THEME):
    if preset not in config["presets"] or not re.fullmatch(r"[a-z0-9_-]+", preset):
        raise ValueError("Unknown theme preset")
    source, original, updated, privileged = updated_configuration(config, preset)
    reference = (
        str(source.parent.parent if not privileged else source.parent) + "#nixos"
    )
    print(f"Applying {config['presets'][preset]['name']}", flush=True)
    print(
        "The rebuild includes other saved configuration edits. No automatic reboot.",
        flush=True,
    )
    replace_configuration(source, original, updated, privileged, run)
    try:
        target = (
            reference.removesuffix("#nixos")
            + "#nixosConfigurations.nixos.config.system.build.toplevel"
        )
        run(
            "nix",
            "--extra-experimental-features",
            "nix-command flakes",
            "build",
            target,
            "--no-link",
        )
        if source.read_bytes() != updated:
            raise RuntimeError(
                "Theme settings changed during the build; activation cancelled"
            )
        run("/run/wrappers/bin/sudo", "nixos-rebuild", "switch", "--flake", reference)
        if active_preset(active_path) != preset:
            raise RuntimeError("Activation did not report the selected theme as active")
    except BaseException:
        if active_preset(active_path) != preset and source.read_bytes() == updated:
            replace_configuration(source, updated, original, privileged, run)
            print("Previous theme selection restored in the configuration.", flush=True)
        print(
            "If activation started, inspect its output before trying again.", flush=True
        )
        raise
    print(
        "Theme applied. Reopen apps that keep their old appearance; reboot when convenient.",
        flush=True,
    )


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--apply", metavar="PRESET")
    parser.add_argument(
        "--list",
        action="store_true",
        help="Print choices and active state without opening a menu",
    )
    args = parser.parse_args(argv)
    config = json.loads(args.config.read_text())
    active = active_preset()
    entries = menu_entries(config["presets"], active)
    if args.list:
        print("\n".join(label for _, label in entries))
        return 0
    if args.apply:
        try:
            if os.geteuid() == 0:
                raise ValueError(
                    "Run the menu as the desktop account; it requests sudo when needed"
                )
            lock_path = (
                Path(os.environ["XDG_RUNTIME_DIR"]) / "desktop-theme-switch.lock"
            )
            with lock_path.open("a") as lock:
                try:
                    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                except BlockingIOError:
                    raise RuntimeError(
                        "Another theme switch is already running"
                    ) from None
                apply_theme(config, args.apply)
            result = 0
        except (
            OSError,
            ValueError,
            RuntimeError,
            subprocess.CalledProcessError,
            KeyboardInterrupt,
        ) as error:
            print(f"Theme switch failed: {error}", file=sys.stderr)
            result = 1
        if sys.stdin.isatty():
            try:
                input("Press Enter to close.")
            except (EOFError, KeyboardInterrupt):
                pass
        return result
    options = [
        "rofi",
        "-dmenu",
        "-i",
        "-no-custom",
        "-format",
        "i",
        "-l",
        str(len(entries)),
        "-p",
        "Theme",
        "-mesg",
        "Choose a theme to apply. A terminal will show progress and request your password.",
    ]
    for index, (key, _) in enumerate(entries):
        if key == active:
            # Keep the launcher's normal selection colors; the label marks Active.
            options += ["-selected-row", str(index)]
    choice = subprocess.run(
        options,
        input="\n".join(label for _, label in entries) + "\n",
        text=True,
        capture_output=True,
    )
    if choice.returncode != 0:
        if choice.returncode != 1:
            raise RuntimeError(choice.stderr.strip() or "Unable to open the theme menu")
        return 0
    index = int(choice.stdout.strip())
    if index < 0 or index >= len(entries):
        raise ValueError("Invalid menu selection")
    preset = entries[index][0]
    if preset == active:
        return 0
    command(
        "alacritty",
        "--class",
        "theme-switch",
        "--title",
        "Apply theme",
        "-e",
        sys.executable,
        Path(__file__).resolve(),
        "--config",
        args.config,
        "--apply",
        preset,
    )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"Theme menu: {error}", file=sys.stderr)
        sys.exit(1)
