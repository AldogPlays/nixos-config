# Waydroid Android inputs

I use `default.nix` to pin the official x86-64 LineageOS 20 VANILLA system
image, MAINLINE vendor image, and stable Aurora Store APK. Android image hashes
come from the official Waydroid OTA metadata; the APK comes from Aurora OSS's
release directory. Downloads are verified by Nix. APKs, Android images, app
accounts, and user data are not checked into Git.

The NixOS module exposes the images at `/etc/waydroid-extra/images`, an upstream
preinstalled-image location. First-use initialization selects these images
without downloading a moving release. Runtime overlays and Android user data
remain writable outside the store. Aurora is installed as a normal Android app,
without root, device-owner privileges, Google Play services, or a Google account
configured by the repository.

I update the URLs and hashes deliberately when changing Android or Aurora
versions. I update these read-only images through Nix rather than `waydroid
upgrade`. Existing Android data is preserved during routine system rebuilds;
image migrations need separate testing. See [Waydroid
usage](../../docs/waydroid.md).

## YV12 graphics layout

`graphics.nix` builds the small `yv12-layout.c` adapter for the pinned vendor
image's minigbm library. Upstream revision `e5a7769` allocates Android YV12 as
linear GR88 storage but describes it as a single plane. The adapter restores
the three Y/Cr/Cb plane descriptions, offsets and shared-buffer descriptors.
Other formats retain the original backend. Its private C++ objects and buffer
mapping/ownership stay with the original library; the adapter uses the matching
upstream C headers and verifies the original library's hash before packaging.

The original library is retained under a separate SONAME in the vendor image.
The adapter is about 8 KiB and introduces no service or software-rendering
fallback. Android NDK 27 is a build dependency only; it is not part of the
running system's closure. `yv12-probe.c` supplies an on-device allocation,
import, mapping and RGB regression check.
An on-device test copy can be staged at `/data/local/tmp/waydroid-yv12-probe`.
After testing, remove that copy and retain Android's standard temporary-directory
permissions with `sudo waydroid shell -- sh -c 'rm -f /data/local/tmp/waydroid-yv12-probe; chmod 0771 /data/local/tmp'`.

The image builder reserves 8 MiB because the official vendor filesystem has no
free blocks. It verifies the embedded libraries, runs a read-only filesystem
check and uses fixed filesystem timestamps. The system image stays unchanged.
Switching generations changes the vendor image through `/etc/waydroid-extra/images`;
no mutable Android overlay file is installed by this repair. Stop Android before
an image change and start it again afterward. This also allows a generation
rollback to remove the repair without restoring or deleting Android user data.

The triggering crash and upstream investigation are documented in
[Waydroid issue 2454](https://github.com/waydroid/waydroid/issues/2454).
