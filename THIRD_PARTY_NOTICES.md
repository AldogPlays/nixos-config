# Third-party notices

The root [MIT license](LICENSE) covers original source and documentation in this
repository. It does not replace the licenses of adapted code, palette data or
software fetched and installed through Nix.

## Source and data included here

| Files | Upstream source | License and retained notice |
| --- | --- | --- |
| `packages/hyprmosaic/wallpaper.cpp` | [La5u/hyprmosaic, revision 7597c5e](https://github.com/La5u/hyprmosaic/tree/7597c5ef1fc7ce7265a0117089cf88da7cd7e08f) | MIT, with upstream Hyprland BSD-3-Clause attribution; [complete notice](packages/hyprmosaic/LICENSE) |
| `theme/palettes/latte.nix` | [Catppuccin palette v1.8.0](https://github.com/catppuccin/palette/tree/v1.8.0) | MIT; [complete notice](theme/palettes/LICENSE) |
| `packages/slurp/click-drag-threshold.patch` and the Slurp-based selection test | [emersion/slurp v1.5.0](https://github.com/emersion/slurp/tree/v1.5.0) | MIT; [upstream notice](packages/slurp/LICENSE) |
| `packages/waybar-tray/tray-popup.patch` | [Alexays/Waybar 0.15.0](https://github.com/Alexays/Waybar/tree/0.15.0) | MIT; [upstream notice](packages/waybar-tray/LICENSE) |

The wallpaper package also installs upstream's license notice with its compiled
plugin. The local adaptation changes wallpaper behavior and compositor API
integration; it does not claim ownership of the upstream implementation.

## Packages and assets fetched by Nix

Nixpkgs, Home Manager, Hyprland, application packages, fonts, cursor/icon assets,
and the pinned Wiremix/wlctl sources retain their own licenses. Their source and
package metadata are referenced by the Nix configuration and `flake.lock`.
The [Wiremix fork](https://github.com/AldogPlays/wiremix) identifies its license as
Apache-2.0; it is a separate dependency, not relicensed by this repository.

Proprietary software, including Cisco Packet Tracer, requires its own applicable
terms and download access. No proprietary installer, personal wallpaper collection,
credential or application account is distributed as part of this source tree.
