{ waybar }:

waybar.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [
    ./tray-popup.patch
    ./network-address-family.patch
    ./per-output-visibility.patch
    ./workspace-groups.patch
    ./lua-workspace-dispatch.patch
  ];
})
