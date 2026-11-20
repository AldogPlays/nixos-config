# Full-edge cursor crossing

I use this local plugin to map each entire shared screen edge proportionally
onto its neighbour. It covers dead corners caused by different logical
resolutions without changing resolution or scale. Outer edges and diagonal-only
neighbours do not wrap. Relative input within a screen retains Hyprland's normal
acceleration.

Hyprland 0.55.4 has no native setting or Lua mouse-motion event for this behavior.
The plugin hooks `CPointerManager::move`, preserving the original function for
ordinary motion. Pointer constraints and session locking bypass the mapping;
touch and tablet absolute coordinates are untouched. Monitors are read on each
relative motion, excluding disabled, sleeping and mirrored outputs. Multiple
neighbours on one edge use the first crossing in monitor order.

The plugin uses Nixpkgs' `mkHyprlandPlugin` and refuses a compositor ABI mismatch.
`home/jeffreyc/desktop.nix` builds it and the managed Hyprland Lua file loads it.
No process, polling loop, input-device permission or service is added. The package
build runs `test.cpp` against the pure mapping logic in `geometry.hpp`.

When I upgrade Hyprland, I review the pointer hook API and test crossing,
dragging, constrained games and lock-screen input. To disable it live, I use
`hyprctl plugin unload` with the plugin path from `hyprctl plugin list`; I
remove its Lua load call and package substitution for a persistent removal.
