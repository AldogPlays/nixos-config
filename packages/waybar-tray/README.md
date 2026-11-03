# Waybar patches

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

`network-address-family.patch` backports the family-specific address-removal
handling from [upstream Waybar](https://github.com/Alexays/Waybar/blob/master/src/modules/network.cpp).
Waybar 0.15.0 clears both cached address families when either loses an address.
With IPv6 temporary-address expiry, this can erase a still-valid IPv4 address
and leave the module showing its linked-without-IP icon instead of Wi-Fi details.
The patch clears only the removed address's family. It leaves network settings,
module styling and the existing session service unchanged. On upgrades, check
whether upstream already includes this correction before retaining the patch.
