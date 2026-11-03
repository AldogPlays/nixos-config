{ waybar }:

waybar.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [
    ./tray-popup.patch
    ./network-address-family.patch
  ];
})
