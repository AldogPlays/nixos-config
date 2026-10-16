{ pkgs, pkgsUnstable, ... }:

{
  home.packages = with pkgs; [
    # Desktop applications
    kdePackages.dolphin
    librewolf
    pavucontrol

    # Hyprland utilities used by the declarative keybindings/session
    brightnessctl
    grim
    hyprlauncher
    hyprlock
    hyprpolkitagent
    networkmanagerapplet
    playerctl
    slurp
    wl-clipboard

    # Command-line workflow
    fd
    jq
    ripgrep
    tree

    # Keep Codex on the fast-moving pinned nixpkgs input.
    pkgsUnstable.codex
  ];
}
