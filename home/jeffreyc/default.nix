{
  config,
  lib,
  pkgs,
  ...
}:

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
      TERMINAL = "alacritty";
    };
  };

  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
    };
    mimeApps = {
      enable = true;
      # Native archive/image associations, rather than a second handwritten MIME list.
      defaultApplicationPackages = [
        pkgs.kdePackages.ark
        pkgs.kdePackages.gwenview
      ];
      defaultApplications = {
        "x-scheme-handler/http" = [ "librewolf.desktop" ];
        "x-scheme-handler/https" = [ "librewolf.desktop" ];
        "text/html" = [ "librewolf.desktop" ];
        "application/xhtml+xml" = [ "librewolf.desktop" ];
        "application/pdf" = [ "librewolf.desktop" ];
        "inode/directory" = [ "org.kde.dolphin.desktop" ];
        "x-scheme-handler/codex" = [ "chatgpt.desktop" ];
      };
      # The desktop client also advertises generic web URLs; keep those in the browser.
      associations.removed = {
        "x-scheme-handler/http" = [ "chatgpt.desktop" ];
        "x-scheme-handler/https" = [ "chatgpt.desktop" ];
      };
      associations.added."application/pdf" = [ "librewolf.desktop" ];
    };
    terminal-exec = {
      enable = true;
      settings.default = [ "Alacritty.desktop" ];
    };
  };

  # These are writable user-content directories, not files managed in the store.
  home.activation.createDesktopDirectories =
    lib.hm.dag.entryBetween [ "reloadSystemd" ] [ "createXdgUserDirectories" ]
      ''
        run mkdir -p ${lib.escapeShellArg "${config.xdg.userDirs.pictures}/Screenshots"} \
          ${lib.escapeShellArg "${config.xdg.userDirs.pictures}/Wallpapers"}
      '';
  programs.home-manager.enable = true;
}
