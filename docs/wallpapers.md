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
- The shared Latte theme and opaque lock screen remain independent. The shared
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
The pinned hyprgraphics BMP loader supplies zero alpha and does not free its
decoded pixel allocation. The adapter explicitly treats prepared RGB wallpapers
as opaque and attaches the pixel-buffer destructor to the temporary Cairo
surface. Without the opacity correction, colors add to the light fallback and
wash out to white.

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
queries Hyprland's physical output dimensions, not a wallpaper daemon. Once all
images are ready it atomically publishes `workspace-wallpapers.json`; unchanged
state is not rewritten. It never applies a potentially stale active-workspace
snapshot: the plugin reads the actual workspace position when rendering.
Within an update, preparation results are shared by source path and output
dimensions, including repeated assignments, equal-sized outputs and retries
after a failed source. Each later update rechecks source metadata normally;
EXIF orientation, RGB conversion and Lanczos cover resizing are unchanged.

The plugin watches the session directory using inotify, reads new manifests,
and uploads changed prepared images on the next render. Textures are reused by
prepared-image path across workspaces and outputs, including within a new
manifest. Unreferenced textures expire after replacement; there is no permanent
GPU history cache. Invalid state does not clear a working backdrop. There is no awww
service, native last-image cache, or parallel wallpaper renderer.

## Runtime state and memory

All generated data lives under
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
pixel payload, excluding allocation overhead and transient decode storage.
These are component estimates, not measured total process memory. More outputs
or workspaces increase usage. Originals and unrelated files are never removed.
State survives config/plugin reloads, not a new login, and is never committed.

## Validation, limitations and recovery

`nix flake check --show-trace` runs Python policy/image-cache tests, generated Lua
syntax checks, and scheduling regression tests. The system build compiles the
plugin against the pinned compositor. Isolated nested-compositor testing covers
plugin load, atomic image loading, actual mid-tone screenshot pixels over a light
fallback, repeated redraws, moving both wallpapers on an empty-workspace switch,
rapid reversals and third-workspace interruptions (checking rendered scanlines
for exposed fallback), texture sharing/reassignment without new uploads,
preparation-lock contention, failed replacement recovery, safe cache cleanup,
and unload/reload. Run `tests/hyprmosaic-render.py` manually
with a Pillow-enabled Python, passing the built plugin library and `grim` executable as its two
arguments. It briefly opens a disposable nested compositor with isolated runtime
and D-Bus paths; it never loads a test plugin into the host. This GPU/session test
is not part of the sandboxed flake checks. It does not substitute for checking
real touchpad gestures, multiple physical outputs, or tablet rotation.

Image decoding and GPU upload still happen on the compositor thread when an
assignment changes. Pre-sized images avoid large-original work there, but do
not guarantee stutter-free startup/rotation. Rotated outputs, non-slide workspace
styles, and unusual multi-monitor interactions need separate visual validation.

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
