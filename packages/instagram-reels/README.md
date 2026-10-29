# Instagram Home and Reels patch

This on-demand tool patches local original APKs for the reference Waydroid
installation. It adds no desktop service or Android root manager. `supported.json`
records the tested x86-64 version, version code and original split hashes.
Unknown inputs are rejected before patching.

## Behavior and sources

The local GPL-3.0 patches in `Reels.kt` adapt fingerprints and the scrolling hook
from [ReVanced's Instagram patches](https://gitlab.com/ReVanced/revanced-patches/-/tree/015fe10a23ea5b919a3fda6e7da2c176517ae75d/patches/src/main/kotlin/app/revanced/patches/instagram).
They hide the Home (`fragment_feed`) and Reels (`fragment_clips`) navigation items
and disable the Reels pager's swipe and pull-to-refresh handlers.
Navigation is filtered through a mutable copy of the returned list, matching the
fragment ID rather than an obfuscated field
name. Other navigation items, including Direct, Search, Profile and Create, are
retained. Direct is placed first and the native startup intent selects it when
no destination is specified or Home/Reels is requested. Explicit other startup
destinations are preserved. Native tab-selection and tab-history requests for
Home/Reels are redirected to Direct, including Android Back from the inbox.
Individual Reel links and videos elsewhere in
Instagram are not globally blocked; this is a navigation restriction, not a
network content filter.

`default.nix` pins and verifies Morphe Desktop 1.19.1 and Piko 3.10.0. Only Piko's
generic **Clone** patch is enabled; its settings, ads, analytics and other feature
patches are excluded. The local hooks do not depend on Piko's incompatible settings
UI. Exact method matches are required; a failed patch aborts the build.
The generic Clone patch's older compatibility metadata requires `--force`, but
the local hooks independently check the version and version code, and the wrapper
checks the original APK hashes. This is not support for arbitrary app versions.

The result is **Instagram**, package `com.instagram.android.piko`.
It installs alongside the original app. Their Android data and account sessions
are separate; the clone may need a new sign-in. No account database is copied.
Native x86-64 libraries and the existing Waydroid YV12 repair are retained.
Updating the earlier **Instagram (no Reels)** or **Instagram (no feed)** clone uses the same package and
signing key, preserving its Android data without another installation alongside it.

## Build and install

Preserve the original APK splits outside Git. On the reference laptop they are
under `~/.local/state/instagram-reels/original/`. Run from the checkout:

```bash
nix run .#instagram-reels-patch -- ~/.local/state/instagram-reels/original
```

The signed result is `~/.local/state/instagram-reels/instagram-reels.apk` by
default; `--output /path/to/file.apk` overrides it. `last-build.json` records the
build result. This command builds only; it does not install or launch Android.
Nix builds the small patch bundle from checked-in source. Proprietary APKs and
signing keys are neither flake inputs nor copied into the Nix store.

The private signing key is
`~/.local/state/instagram-reels/morphe/morphe.keystore`, mode 0600. Preserve it
with private backups: the same signing identity permits later updates without
uninstalling the clone. Do not commit it. NixOS rollback does not restore app data
or this key. New installations also need matching original APKs; Google Play may
stop serving an older release.

For an explicit install using normal, unprivileged ADB, start Waydroid and obtain
its address from `waydroid status`. Enter a temporary pinned tool shell:

```bash
nix shell --inputs-from . nixpkgs#android-tools
adb connect ANDROID_IP:5555
adb install --no-streaming -r ~/.local/state/instagram-reels/instagram-reels.apk
adb shell appops set com.instagram.android.piko REQUEST_INSTALL_PACKAGES deny
adb shell appops get com.instagram.android.piko REQUEST_INSTALL_PACKAGES
adb disconnect ANDROID_IP:5555
```

Approve any debugging authorization locally in Android. ADB root and disabling
APK signature checks are not needed. Installation must report **Success**;
verify the package with `waydroid app list` before opening its launcher.

To use the patched app as the only Instagram launcher, preserve the original app
but disable it for the Android user, then apply the desktop launcher policy:

```bash
adb shell pm disable-user --user 0 com.instagram.android
adb shell cmd uimode night no
nix shell --inputs-from . nixpkgs#python3 --command python3 \
  scripts/waydroid-launcher-policy.py ~/.local/share/applications
```

Run the last command from the repository. Home Manager also reapplies that
`NoDisplay` policy on activation when the original desktop entry exists.
Waydroid preserves the flag while refreshing its writable desktop files.
The theme and enabled-package state are saved Android preferences, separate from
the APK patch and Nix generation. No account data is removed.

## Updates and recovery

The clone has a separate package name and signing identity, so normal Play/Aurora
Instagram updates do not target it. Its APK-install request operation is denied.
The original Instagram is separately excluded through Aurora's **Blacklist
manager**. These are Android user-state choices, not a global system update policy.
Other apps and the NixOS input-update workflow retain their existing behavior.
Pinning the APK does not pin Instagram's server-side layouts or prevent the
service from eventually requiring a newer version.

To update manually, preserve the signing key, obtain original APKs, review the
new app/patch source, update the supported input pins, and rerun fingerprint,
build, install and signed-in behavior checks. Keep the working APK and original
splits until the replacement is verified. Do not replace a failed patch with
`--continue-on-error` or simply remove the input guards.

The original app is disabled and hidden on the reference laptop. For recovery,
temporarily enable it through an authorized ADB connection, then launch it:

```bash
adb shell pm enable --user 0 com.instagram.android
waydroid app launch com.instagram.android
```

Removing the clone through Android app settings removes its own account and local
data, without removing the original app. System-generation rollback alone does
not uninstall Android apps or undo Aurora preferences.
Disable the original again after recovery to restore the single active app.

## Validation boundary

On 2026-10-29, the original reference-laptop x86-64 splits were preserved, the
local hooks matched uniquely, and the pinned Nix workflow built the signed clone.
Installation, native ABI selection and startup were verified. Aurora's original
Instagram exclusion and the clone's denied APK-install operation were verified
separately. The owner confirmed that the initial signed-in Reels-only clone opens
and Reels controls are absent. The Home-removal update was installed with the
same signing key and retained the sign-in. A cold start selected Direct, showed
its inbox, omitted Home/Reels navigation and had no Home feed UI markers. Search,
Activity, Create and Profile controls remained present. After adding the native
tab-history redirect, two consecutive Android Back presses from the inbox kept
Direct selected without reopening Home or Reels. Sending messages, Back within
a conversation, Reel gestures, alternate feed entry points and the complete
photo-upload flow still require interactive verification.

The plain-name APK update retained the patched package's sign-in and update
restriction. Android light mode was saved and Instagram's light interface was
visually verified. The original package was verified disabled with no resolvable
launcher activity; only the patched desktop entry remained visible. The launcher
policy was applied live from the repository helper and included in a successful
system build; it will run automatically on subsequent Home Manager activations.
