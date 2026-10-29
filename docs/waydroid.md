# Waydroid and photo uploads

Waydroid runs Android applications inside an LXC container on the Wayland desktop.
The system module is `modules/nixos/waydroid.nix`; desktop launchers, the on-demand
user session and Dolphin integration live in `home/jeffreyc/waydroid.nix`.
The shared desktop includes them on bootstrap-generated hosts as well.

## First use

After applying the NixOS configuration, open **Set Up Aurora Store** from the app
launcher, or run:

```bash
waydroid-setup
```

An initialization oneshot prepares the pinned VANILLA Android images during
activation or boot if Waydroid has not already been initialized, without starting
Android. The setup command starts the user
session, waits for Android, installs the pinned Aurora APK if absent, and opens
Aurora. Existing installations are preserved. App downloads, permissions and
account sign-ins remain Android user data outside the repository and Nix store.

Complete Aurora's onboarding and use its normal Session installer. Instagram is
installed from Aurora's Google Play catalog; sign in to Instagram inside Android.
Some Android apps only ship ARM binaries and require translation on this x86-64
host. Compatibility must be checked against the actual downloaded app.

## Photos

**Waydroid** in Dolphin's Places sidebar opens `~/Waydroid`, a view of Android's
shared storage. Navigate into **Pictures** or **DCIM** and paste photos there.
This is the actual Android storage, so edits and deletions also affect Android.
It does not expose app-private data or share the Linux home folder with Android.
In Instagram, grant photo access and select the photos through its Android picker.
When Android is running, a systemd path watcher refreshes its media index after
pastes directly into Pictures, DCIM or Download. Changes inside existing nested
folders are not watched recursively. To refresh those after copying, run:

```bash
sudo systemctl start waydroid-media-scan
```

The sidebar helper adds a bookmark without replacing existing Places. Before its
first edit it backs up `user-places.xbel` to `user-places.xbel.before-waydroid`.
The file remains user-managed, rather than a Home Manager symlink.

## Start and stop

Open **Waydroid** to show Android. Android does not start automatically at login.
The root D-Bus controller starts on demand; the main launcher uses a user systemd
service for the Android session. Native exported app launchers can also start
Waydroid's session directly. Both use its D-Bus single-session mechanism.
The storage shortcut automounts on access and uses a small bindfs process to map
Android ownership to the desktop user. New files retain Android media ownership
underneath. A preparation oneshot creates missing directories; no file-sync daemon
copies the photos or starts Android automatically.
The photo-index path watcher uses systemd's filesystem notifications; its scan
oneshot runs only after folder changes and skips scanning when Android is stopped.

To release Android's memory when finished:

```bash
waydroid session stop
```

The Waydroid desktop entry also offers **Stop Android**. Closing the Android
window alone can leave its session running. Android needs additional RAM while
active; stopping it is useful on this laptop.

## Diagnostics and updates

```bash
waydroid status
waydroid app list
journalctl --user -u waydroid-session
sudo journalctl -u waydroid-container -u waydroid-initialize -u waydroid-storage-prepare
```

On 2026-10-29, Aurora installation, the Dolphin bookmark, shared-storage writes
and automatic indexing of photos pasted directly into Pictures were verified on
the Lenovo. Instagram installed native x86-64 libraries but crashed on its
RenderThread in `libhwui.so`, at `DeferredLayerUpdater::apply()`. Two Android
tombstone reports captured this failure; one followed a launch by two seconds.
The host kernel showed no corresponding out-of-memory kill. This matches the
failure described in [Waydroid issue 2454](https://github.com/waydroid/waydroid/issues/2454).
The vendor image now includes a small adapter correcting minigbm's single-plane
description of YV12 buffers. It preserves GPU acceleration and adds no background
service or ARM translation layer. The on-device regression check passed YV12
allocation, three-plane layout, import and mapping at five widths, plus ordinary
RGB allocation. The same Instagram process remained running for more than two
minutes after launch and its feed rendered. The owner confirmed normal feed-video
and Reels playback. The complete photo-upload flow still needs verification. See the
[package guide](../packages/waydroid/README.md#yv12-graphics-layout) for the build,
image packaging and rollback design.

The upstream report notes that software rendering avoids its crash but fails to
display video, so software rendering is not enabled here.

The NixOS module supplies Binder/LXC integration and trusts only the `waydroid0`
container interface in the host firewall. The selected package uses nftables for
its container network; the host firewall and Tailscale DNS selection stay intact.
No camera, location-forwarding, root-management or Google services stack is added.
The images and Aurora APK are pinned in `packages/waydroid/default.nix`; update
those pins rather than writing to the Nix-managed images with `waydroid upgrade`.
