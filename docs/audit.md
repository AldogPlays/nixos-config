# System audit — 2026-10-16

## Hardware

- Lenovo IdeaPad 5 2-in-1 14AKP10 (`83KT`), firmware `R4CN15WW`.
- AMD Ryzen AI 7 350: 8 cores / 16 threads with AMD-V.
- Integrated Radeon 860M using the `amdgpu` driver.
- AMD XDNA NPU using the `amdxdna` driver.
- 13 GiB usable RAM and an 8.8 GiB encrypted swap partition.
- 476.9 GiB Samsung PM9C1a NVMe SSD.
- MediaTek MT7925 Wi-Fi 7 using the `mt7925e` driver.
- 1920x1200 internal touch display at 1.5x scale, Wacom pen/touch, and tablet-mode switch.
- Integrated camera and AMD audio are visible through PipeWire/WirePlumber.

## Storage

- EFI system partition at `/boot` (`FC38-9259`).
- LUKS2-encrypted Btrfs root (`37a5048c-12ef-4a44-bad4-0236bbb301e2`).
- Separate Btrfs subvolumes for `/home` and `/nix`.
- Separate LUKS2 encrypted swap (`0c3d5683-051d-4417-9909-736d7d45680f`).
- Swap is smaller than RAM and no resume device is configured, so hibernation is not enabled.
- No snapshot policy or Btrfs compression was present; both are left unchanged for this bootstrap.

## Software before migration

- NixOS 26.05 with Linux 7.2.10.
- Hyprland 0.55.4 under Wayland/UWSM, using the generated example Lua configuration.
- PipeWire 1.6.6 with working speakers, microphones, and camera nodes.
- No failed system or user units were reported.
- Configuration consisted of `/etc/nixos/configuration.nix` plus generated hardware configuration.
- Flakes and Home Manager were not configured.
- The Git repository had no commits or remote.
- GitHub CLI was installed but not authenticated.
- Codex was 0.146.0 from the system profile; it was upgraded first to 0.162.1 through a pinned `nixos-unstable` user profile.

## Findings addressed by this repository

- Split host, core OS, AMD hardware, Hyprland, home, program, and package concerns into modules.
- Added a lockable flake and integrated Home Manager as a NixOS module.
- Declared every command referenced by the Hyprland configuration.
- Added explicit PipeWire, graphics, Bluetooth, firmware-update, power-management, portal, and PolicyKit configuration.
- Added a minimal Waybar, notification daemon, NetworkManager applet, PolicyKit agent, terminal, shell, and Git configuration.
- Kept disk UUIDs and `system.stateVersion = "26.05"` unchanged.

## Follow-up observations

- The current boot log repeats an early `i2c_hid_acpi` report-length warning for the Wacom device. Pen and touch are nevertheless detected by Hyprland; investigate only if input is unreliable.
- NixOS 26.05 reports support through 2026-12-31. Plan a normal input upgrade to 26.11 after it is released and Home Manager has a matching branch. Do not change `system.stateVersion` during that upgrade.
- The original Btrfs layout mounts the top-level root rather than a dedicated root subvolume. Snapshot/rollback tooling should be designed deliberately instead of enabled as an incidental bootstrap change.
