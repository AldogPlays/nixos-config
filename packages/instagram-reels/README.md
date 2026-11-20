# Instagram navigation and messaging patches

I use this on-demand tool to patch local original APKs for my Waydroid
installation. It adds no desktop service or Android root manager.
`supported.json` records the tested x86-64 version, version code and original
split hashes. Unknown inputs are rejected before patching.

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

The messaging header also omits the Blend button and its add/invite variant.
The local Blend hook changes four boolean results only in the native thread-header
builder: the existing-Blend entrypoint, two creation checks, and the per-thread
add-icon preference. It follows method references from semantic fingerprints;
shared Blend utilities, conversations, sending, calls and other header controls
are not patched. This does not block Blend links or remove existing Blend data.

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

I preserve the original APK splits outside Git, under
`~/.local/state/instagram-reels/original/`. I build from the checkout:

```bash
nix run .#instagram-reels-patch -- ~/.local/state/instagram-reels/original
```

The signed result is `~/.local/state/instagram-reels/instagram-reels.apk` by
default; `--output /path/to/file.apk` overrides it. Builds stage in a private
directory beside the output. Only a successful report containing exactly the four
selected patches and successful patch/rebuild/sign steps can replace the output.
The previous output is retained as `instagram-reels.previous.apk` (or
`<custom-output-stem>.previous.apk`). Failed builds preserve the existing output
and successful report. `last-build.json` records the final APK hash, original
input hashes, patcher/bundle hashes and selected patches. The report's
`packageName` describes the original input; `clonePackage` identifies the output.
This command builds only; it does not install or launch Android.
Nix builds the small patch bundle from checked-in source. Proprietary APKs and
signing keys are neither flake inputs nor copied into the Nix store.

The private signing key is
`~/.local/state/instagram-reels/morphe/morphe.keystore`, mode 0600. Preserve it
with private backups: the same signing identity permits later updates without
uninstalling the clone. Do not commit it. NixOS rollback does not restore app data
or this key. New installations also need matching original APKs; Google Play may
stop serving an older release.
If a previous build exists but the key is missing, the wrapper refuses to create
a replacement identity; restore the private key backup first.

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

An already-running Waydroid session also supports a headless update through its
native install bridge, without opening the app or requesting ADB authorization:

```bash
waydroid app install ~/.local/state/instagram-reels/instagram-reels.apk
```

That bridge completes installation asynchronously; its command exit status alone
does not establish success. On my host, I compare the built APK's SHA-256 with
the single installed clone under
`~/.local/share/waydroid/data/app/*/com.instagram.android.piko-*/base.apk` after
installation completes. An in-place update retains Android data and existing
permissions. Use ADB or the Android settings UI separately when changing appops.
If the container was frozen, the bridge may restore that state before Android's
asynchronous installation finishes. Wake only the container in the background,
verify the installed hash, then restore its previous frozen state:

```bash
busctl --system call id.waydro.Container /ContainerManager id.waydro.ContainerManager Unfreeze
# Compare hashes after installation completes, without launching Instagram.
busctl --system call id.waydro.Container /ContainerManager id.waydro.ContainerManager Freeze
```

I freeze the container only when I'm not using the Android session.

To use the patched app as my only Instagram launcher, I preserve the original
app but disable it for the Android user, then apply my desktop launcher policy:

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

### Patch maintenance contract

I keep the working app version, signing identity, package name, and current
behavior when making a small UI change. A newer patcher, Piko bundle or Android
image is a separate upgrade. No broad Piko features, root manager or additional
service is required for these local hooks. Original APKs and private keys must
remain outside Git and the Nix store.

| Hook | Identification and required result |
| --- | --- |
| Navigation list | `UserSession, boolean → List` and opcode fingerprint; filter a mutable copy by semantic fragment IDs and place Direct first |
| Startup | `MainActivityAccountHelper.STARTUP_TAB`; preserve explicit non-feed destinations |
| Tab selection/history | `feed_viewpager_empty_tabs`, `NavigationController.pushTabFragment`; redirect Home/Reels to Direct |
| Reels pager | `ClipsViewPagerImpl_getViewAtIndex`; exactly one `ViewPager2` field |
| Reels refresh | `ClipsSwipeRefreshLayout.onInterceptTouchEvent(MotionEvent)`; return false |
| Messaging Blend | `show_blends_add_icon_for_thread` plus Context/UserSession/Capabilities parameter prefix; resolve the Blend utility through `android_purge_26_q2_BlendUtil_shouldBadge`, then follow native calls and require exactly four UI-result substitutions |

Unknown or ambiguous matches must fail. For a new Instagram release, inspect the
original bytecode and native call graph before updating the input pins; string
anchors and server-controlled layouts can change. Do not carry obfuscated names
or register numbers from one release into another.

`nix flake check --show-trace` includes `instagram-patch`, which checks rejection
of unknown APK inputs, missing signing keys and incomplete patch reports, plus
failed-build preservation and successful backup/provenance handling. These tests
use synthetic inputs and never install Android apps or access account data.
They do not prove APK-hook correctness: also build with the preserved real splits,
verify the signature matches the installed clone, and compare changed methods
against the previous working APK. For a Blend-only change, the thread-header
builder should be the only method whose instructions change.

For interactive verification, I check a cold start into Direct, absent
Home/Reels tabs, Back from the inbox, opening and backing out of a conversation,
a sent message, absent Blend controls in eligible chats, calls and photo
selection/upload. I keep message sending and content uploads as manual checks. I
build, verify, and install headlessly while I'm using the desktop, then check
the interface separately when I'm ready to open Android.

I keep the original app disabled and hidden on my laptop. For recovery, I
temporarily enable it through an authorized ADB connection, then launch it:

```bash
adb shell pm enable --user 0 com.instagram.android
waydroid app launch com.instagram.android
```

Removing the clone through Android app settings removes its own account and local
data, without removing the original app. System-generation rollback alone does
not uninstall Android apps or undo Aurora preferences.
Disable the original again after recovery to restore the single active app.

To undo the latest APK update, reinstall the preserved previous clone with the
same signing identity:

```bash
waydroid app install ~/.local/state/instagram-reels/instagram-reels.previous.apk
```

This replaces app code while retaining its data. Verify the installed hash as
above. Keep that known-working copy until the new UI has
been confirmed; another successful build rotates the single previous-output copy.

## Validation boundary

On 2026-10-29, my original laptop x86-64 splits were preserved, the local hooks
matched uniquely, and the pinned Nix workflow built the signed clone.
Installation, native ABI selection and startup were verified. Aurora's original
Instagram exclusion and the clone's denied APK-install operation were verified
separately. I checked that the initial signed-in Reels-only clone opens with its
Reels controls absent. The Home-removal update was installed with the same
signing key and retained the sign-in. A cold start selected Direct, showed its
inbox, omitted Home/Reels navigation and had no Home feed UI markers. Search,
Activity, Create and Profile controls remained present. After adding the native
tab-history redirect, two consecutive Android Back presses from the inbox kept
Direct selected without reopening Home or Reels. Sending messages, Back within a
conversation, Reel gestures, alternate feed entry points and the complete
photo-upload flow still require interactive verification.

The plain-name APK update retained the patched package's sign-in and update
restriction. Android light mode was saved and Instagram's light interface was
visually verified. The original package was verified disabled with no resolvable
launcher activity; only the patched desktop entry remained visible. The launcher
policy was applied live from the repository helper and included in a successful
system build; it will run automatically on subsequent Home Manager activations.

On 2026-11-01, I was satisfied with the existing Home/Reels behavior. The
Blend-only update passed the pinned real-APK build and all flake checks. Both
APK signatures verified for Android 13 with the same certificate. A comparison
of 882,361 method bodies across 217,945 classes found only the native
messaging-header builder changed. The update was installed headlessly and its
installed APK hash matched the verified build; the previous working APK remains
available for recovery. I have not recorded a visual check of Blend's absence.
