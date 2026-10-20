# Waybar inline app tray

This overrides pinned Waybar with a small extension to its native drawer group.
The tray expands to the left inside the bar using GTK's existing revealer and
native StatusNotifier icons and application menus. No extra window, tray host,
or service is started.

`drawer.signal = 8` adds the symbolic arrow and caches the signal number during
construction (upstream passes a constructor-local JSON copy). SIGRTMIN+8 opens
and pins the drawer; SIGRTMIN+9 closes it. Hyprland's Meta+Shift+T binding sends
these explicit commands and keeps the existing bar visible while pinned, even
on an empty workspace. Hover opens temporarily and pointer exit closes it
unless pinned. The stylesheet rotates the arrow to indicate expansion.

After a Waybar input upgrade, rebase the patch against `group.hpp`/`group.cpp`,
build, and manually check hover, Meta+Shift+T, native app menus, empty tray state,
and visibility on an empty workspace. Restart `waybar.service` after code changes.
