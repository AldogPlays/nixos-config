# Workspace wallpapers

hyprmosaic draws wallpapers inside Hyprland. Normal slides follow the workspace's
live animated position; interrupted slides resume from the last rendered image
positions as a joined strip, without exposing the fallback between images.
There is no separate background fade, animation clock, timing compensation,
wallpaper daemon, or polling controller.

## Behavior

- Images come recursively from `~/Pictures/Wallpapers`; regular workspaces
  remember a random choice even after an empty workspace is destroyed.
- Assignments refresh at :00, :15, :30 and :45. Distinct images are used when
  enough are available, avoiding immediate repeats when possible. Workspaces
  1–10 are prepared up front; additional positive IDs are added as encountered.
- Each output receives display-sized, cover-cropped images. Special workspaces
  retain the underlying regular backdrop. Originals are never modified.
- Existing numbered bindings, native horizontal swipes, and workspace scrolling
  stay unchanged. No grid navigation, parallax, blurred margins, or desktop
  windows are added. The workspace easing is chosen for motion, not fade timing.
- The selected desktop theme and opaque lock screen remain independent of image
  assignments. The theme's wallpaper mode selects color or grayscale prepared
  copies, with an override in `theme/selection.nix`. The shared
  background color is the fallback when an image is unavailable.

PNG, JPEG and WebP originals are considered, preserving the existing collection
contract. New files enter on refresh; missing/corrupt/unsafe-sized images are
replaced on reconciliation. Missing/empty collections leave resident images
alone; a fresh plugin without valid images uses the fallback. No placeholder
images are installed.

## Components and startup

`packages/hyprmosaic/default.nix` fetches upstream revision
`7597c5ef1fc7ce7265a0117089cf88da7cd7e08f` with a fixed hash and builds with the
pinned nixpkgs Hyprland plugin toolchain. The upstream license is installed with
the library. `wallpaper.cpp` is a deliberately wallpaper-only adaptation, not an
unmodified upstream release. It retains upstream's workspace-offset rendering
model, uses 0.55.4 APIs, and omits the optional grid gesture implementation.
It adds per-output prepared manifests, retains empty workspaces through their
outgoing animation, and exposes a read-only diagnostic command.
Horizontal workspace changes snapshot the visible tiles in output-width units.
Returning to a visible tile reuses its current position; a new tile is appended
at the appropriate edge. All tiles then move by the same displacement, derived
from the incoming workspace's already-stepped native offset. Normal slides stay
aligned with windows; during interruptions wallpaper movement intentionally stays
continuous rather than copying Hyprland's independent position resets. Window
animations themselves are never modified. Off-screen tiles are discarded at the
next change and pixel-rounded shared edges prevent fractional-pixel cracks.
Interactive swipe positioning outside these committed slides remains native.
The adapter reads the helper's uncompressed 24-bit BMPs directly, validating
their header and complete payload before allocation. Whole-row reads replace
the pinned hyprgraphics decoder's stream read for every color byte. Conversion
preserves bottom-up orientation, row padding and RGB channels in Cairo-owned,
opaque pixels; destroying the temporary surface releases its pixel allocation.

`home/jeffreyc/desktop.nix` supplies the plugin and Python/Hyprland paths.
The generated `hyprland.lua` loads the plugin through `hl.plugin.load`.
The plugin refuses a mismatched compositor ABI; do not bypass that check.
Review compatibility when changing the Hyprland input. Plugins run in the
compositor process, so a plugin defect can still disrupt the entire session.

`dotfiles/hypr/hyprland.lua` schedules the one-shot helper at startup/reload,
output changes, quarter-hour boundaries, and newly encountered extra workspace
IDs. A 1ms timer coalesces preparation requests. Ordinary numbered switches do
not start any wallpaper process or read/decode an image.

`dotfiles/hypr/workspace-wallpapers.py` discovers files, remembers assignments,
and prepares RGB BMPs using EXIF orientation and Lanczos cover resizing. It
optionally converts the resized copy to grayscale and back to RGB for the existing
renderer. Original files are never changed. Color mode is part of the preparation
identity, so switching modes cannot reuse the other mode's cached pixels. Returning
to color can reuse existing color cache entries. Conversion happens during
preparation, without adding work to ordinary workspace switches. The helper
queries Hyprland's physical output dimensions, not a wallpaper daemon. Once all
images are ready it atomically publishes `workspace-wallpapers.json`; unchanged
state is not rewritten. It never applies a potentially stale active-workspace
snapshot: the plugin reads the actual workspace position when rendering.
Within an update, preparation results are shared by source path and output
dimensions, including repeated assignments, equal-sized outputs and retries
after a failed source. Each later update rechecks source metadata normally;
EXIF orientation, RGB conversion and Lanczos cover resizing are unchanged.

A second cache keeps exact prepared BMPs across logins and later refreshes under
`$XDG_CACHE_HOME/workspace-wallpapers` (`~/.cache/workspace-wallpapers` by default).
The wrapper declares its location and 512 MiB budget in `desktop.nix`; there is
no separate daemon, initial import, or manual warm-up step. Entries are populated
on demand and keyed by processing version/color mode, source path/size/mtime and output
dimensions. Existing session images also seed the disk cache without decoding
their originals again. Least-recently-used generated files are evicted when the
budget is exceeded; a single image larger than the budget is not stored.

Cache hits validate the RGB BMP header, dimensions and payload length, then copy
the file atomically into the session cache. Copies have separate inodes so either
cache can be pruned independently. A cross-session file lock protects disk-cache
copies and eviction, without holding it during original-image decoding. Missing,
unwritable or structurally corrupt cache entries fall back to normal preparation;
a failed cache write does not reject a usable original. Only hash-named regular
BMPs count toward eviction; symlinks and unrelated files are preserved. The disk
budget excludes the lock and transient copy files. It does not reduce resident
GPU memory, and first use still requires decoding/resizing the original.

The plugin watches the session directory using inotify and stages at most one
distinct changed image per render pass. It continues drawing the complete old
set until all replacements have been processed, then publishes the new assignments
together. A deferred event-loop callback damages outputs for the next pass even
on an idle desktop; there is no independent loading timer. A newer manifest
discards superseded staged textures. Textures are reused by prepared-image path
across workspaces and outputs, including within a new manifest. Unreferenced
textures expire after replacement; there is no permanent GPU history cache.
Invalid replacements retain their previous resident images and defer cleanup.
Invalid state does not clear a working backdrop. There is no awww service,
native last-image cache, or parallel wallpaper renderer.

## Runtime state and memory

Session state and renderer-facing images live under
`$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE`:

- `workspace-wallpapers.json`: assignments and per-output prepared-image paths.
- `workspace-wallpapers.lock`: serializes preparation and renderer cache access.
  The renderer takes this lock nonblockingly so preparation cannot stall frames.
- `workspace-wallpaper-images/`: hash-named RGB BMPs, deduplicated by source
  path/size/mtime and output dimensions.

The helper retains current and previous selected sets during publication. Once
the renderer has loaded every replacement, it prunes superseded generated BMPs
outside the render callback. Cleanup takes the same nonblocking lock and rechecks
that the published manifest still matches the loaded one. A newer publication,
an incomplete load or a sleeping renderer defers cleanup. Only hash-named regular
BMP files are pruned; originals, unrelated names and symlinks are preserved.
For ten 1920×1200 images, the BMP cache is about 66 MiB after successful loading,
temporarily up to about 132 MiB for current/previous sets. The plugin also
keeps resident textures: ten distinct 32-bit images at that size have about 88 MiB of
pixel payload. Staging a complete replacement can temporarily double that payload
to about 176 MiB until the assignments switch, excluding allocation overhead and
the temporary decode surface for one image.
These are component estimates, not measured total process memory. More outputs
or workspaces increase usage. Originals and unrelated files are never removed.
Assignments survive config/plugin reloads, not a new login. The secondary disk
cache survives logins but holds no assignment policy or renderer state. Generated
data is never committed; deleting the secondary cache only causes later
preparations to run normally. Source metadata/dimension changes invalidate its
entries; bump the processing-version string when changing preparation semantics.

## Validation, limitations and recovery

`nix flake check --show-trace` runs Python policy/image-cache tests, generated Lua
syntax checks, and scheduling regression tests. The system build compiles the
plugin against the pinned compositor. Disk-cache tests include pixel-identical
EXIF-oriented output, reuse across sessions without original decoding, source and
size invalidation, LRU budgeting, corrupt/unavailable caches, interrupted copies,
symlink preservation and concurrent sessions. Isolated nested-compositor testing covers
plugin load, atomic image loading, actual mid-tone screenshot pixels over a light
fallback, repeated redraws, moving both wallpapers on an empty-workspace switch,
rapid reversals and third-workspace interruptions (checking rendered scanlines
for exposed fallback), texture sharing/reassignment without new uploads,
preparation-lock contention, failed replacement recovery, safe cache cleanup,
padded BMP rows and channel/orientation accuracy, malformed BMP rejection,
atomic staging, superseded manifests, and unload during pending work.
Run `tests/hyprmosaic-render.py` manually
with a Pillow-enabled Python, passing the built plugin library and `grim` executable as its two
arguments. It briefly opens a disposable nested compositor with isolated runtime
and D-Bus paths; it never loads a test plugin into the host. This GPU/session test
is not part of the sandboxed flake checks. It does not substitute for checking
real touchpad gestures, multiple physical outputs, or tablet rotation.

Image decoding and GPU upload still happen on the compositor thread, limited to
one distinct image per render pass when assignments change. Bulk decoding and
staging avoid doing a complete rotation's work in one frame; image preparation,
quarter-hour scheduling and the visible all-at-once assignment switch stay the
same. Very large outputs can still take more than one frame's budget for a single
image. Rotated outputs, non-slide workspace styles, and unusual multi-monitor
interactions need separate visual validation.

Read-only diagnostics:

```bash
hyprctl plugin list
hyprctl hyprmosaic:status
hyprctl configerrors
```

Status retains the resident assignment count and most recently drawn workspace
IDs, positions and prepared paths. It also reports distinct resident textures,
successful texture uploads and manifest loads for checking reuse. JSON is built
only when status is requested; rendering records compact coordinates and shared
path references without copying strings or retaining old GPU textures for status.
Status does not expose original photo contents.
To recover the previous renderer, use `sudo nixos-rebuild switch --rollback`
and reload Hyprland's config if necessary. This is a generation rollback, not a
request to log out or restart the compositor. Keep the repository consistent
with whichever configuration is chosen before the next normal rebuild.
