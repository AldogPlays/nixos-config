{
  inputs,
  pkgs,
  pkgsUnstable,
  ...
}:

{
  home.packages = with pkgs; [
    # Desktop applications
    kdePackages.dolphin
    librewolf
    # Official desktop client, including graphical Codex, from the pinned input.
    pkgsUnstable.chatgpt

    # On-demand TUI controls; NetworkManager, BlueZ, and PipeWire stay in place.
    inputs.wlctl.packages.${pkgs.stdenv.hostPlatform.system}.default
    bluetui
    wiremix

    # Hyprland utilities used by the declarative keybindings/session
    brightnessctl
    hyprlock
    hyprpolkitagent
    playerctl
    wl-clipboard
    (pkgs.callPackage ../../packages/snap.nix { src = inputs.snap-src; })

    # Command-line workflow
    fd
    jq
    ripgrep
    tree

    # Keep Codex on the fast-moving pinned nixpkgs input.
    pkgsUnstable.codex
  ];
}
