{ ... }:

{
  imports = [
    ./packages.nix
    ./programs.nix
    ./desktop.nix
  ];

  home = {
    username = "jeffreyc";
    homeDirectory = "/home/jeffreyc";
    stateVersion = "26.05";

    sessionVariables = {
      EDITOR = "nano";
      BROWSER = "librewolf";
      TERMINAL = "kitty";
    };
  };

  xdg.enable = true;
  programs.home-manager.enable = true;
}
