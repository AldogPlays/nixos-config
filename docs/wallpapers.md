# Workspace wallpapers

awww is the sole wallpaper renderer. It keeps its background surface and updates
image buffers in place, avoiding the exposed compositor fallback that occurred
when hyprpaper replaced its surface. There is no local backend patch, compositor
plugin, extra resident controller, or polling loop.

## Behavior

- Images come recursively from `~/Pictures/Wallpapers`. Each regular workspace
  remembers a random choice even when Hyprland destroys that empty workspace.
- Assignments refresh at :00, :15, :30 and :45, so the initial cycle may be
  shorter. Distinct images are used when enough are available; immediate repeats
  are avoided when possible. The ten numbered workspaces are reserved up front.
- Each monitor displays its regular active workspace's image. Special workspaces
  preserve the underlying backdrop. Images cover the display without stretching.
- Transitions and wallpaper-layer animations are disabled. Hyprland's fallback
  artwork and splash are disabled; the shared Latte background is the fallback.
- The theme and opaque lock screen are independent of wallpaper selection.

PNG, JPEG and WebP originals are considered. The pinned awww package does not
enable its optional AVIF/JPEG XL decoders. Commas and quotes in names work; line
breaks are excluded from the plain-data cache format. New files enter the pool
on refresh. Missing files and corrupt/unsafe-sized images are replaced on
reconciliation. An empty or missing collection leaves the existing image alone.
Activation creates the wallpaper folder but never adds placeholder images.

## Configuration and startup

- `home/jeffreyc/desktop.nix` enables Home Manager's `awww.service`, sets the
  interval, and supplies the pinned awww, Hyprland, and Pillow-enabled Python
  paths. The graphical session starts the unit. `--no-cache` prevents a separate
  native last-wallpaper restore; `ExecStartPost` restores our workspace choices.
- `dotfiles/hypr/hyprland.lua` handles workspace/output/reload events and the
  quarter-hour timer. Normal switches read tiny cached records and invoke awww
  directly with `--transition-type none --resize no`, without Python startup,
  original-image decoding/resizing, directory scans, or status queries. A 1ms
  next-loop coalescer combines events.
- `dotfiles/hypr/workspace-wallpapers.py` is a short-lived helper for preparation,
  refreshes, and reconciliation. Filesystem scans and subprocess waits stay off
  the compositor thread. It queries awww's actual JSON state and re-reads active
  workspaces after preparation, avoiding stale workspace snapshots.

Missing/unreadable fast-path entries invoke reconciliation. An expired record
can still display its ready image while the next cycle is prepared. Reloading
the config or restarting awww restores assignments without reshuffling them
within the same cycle. These are session-local choices, not a new-login restore.

## Prepared-image cache

Pillow decodes and Lanczos cover-resizes selected originals into display-sized
RGB BMPs once. This moves expensive original-image work off the switching path;
awww only reads the prepared copy. Output-size changes regenerate copies without
reshuffling sources. Original wallpapers are never modified.

All generated data lives under
`$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE`:

- `workspace-wallpapers.json`: source assignments and prepared-image metadata.
- `workspace-wallpapers.lock`: serializes helper invocations.
- `workspace-wallpapers/<hex-output-name>/<workspace-id>`: atomic plain-data
  records containing cycle, source, and prepared-image path; never executable Lua.
- `workspace-wallpaper-images/`: generated BMPs, deduplicated by source
  path/size/mtime and output dimensions.

The image cache retains at most the current and previous selected sets for
in-flight requests. Ten 1920×1200 RGB images use about 66–132 MiB of runtime/tmpfs
data. More/larger outputs or additional workspaces increase that bound. Only our
hash-named generated BMPs are pruned; unrelated files and originals are untouched.
These files survive config/backend reloads, not a new login. Neither the image
collection nor generated data belongs in Git or the Nix store.

## Validation and limitations

`nix flake check --show-trace` runs the Python policy/image-cache tests, checks the
generated Lua syntax, and exercises the Lua fast path with a stub compositor.
These checks do not prove compositor frame timing or a visually seamless switch.
Wallpapers are not native per-workspace surfaces synchronized to workspace slides.

Known runtime caveat: pinned awww 0.12.1 emits unmatched Wayland buffer-release
warnings on this host. Surface-retention and assignment checks pass without
daemon restarts, but the warning's cause remains unresolved. Do not interpret
passing tests as proof that the daemon is warning-free.

Useful read-only diagnostics:

```bash
systemctl --user status awww.service
journalctl --user -u awww.service -b
awww query --json
hyprctl configerrors
```
