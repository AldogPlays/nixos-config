{ ... }:

{
  programs.bash = {
    enable = true;
    enableCompletion = true;
    historyControl = [ "ignoreboth" ];
    shellAliases = {
      rebuild = "sudo nixos-rebuild switch --flake ~/Projects/nixos-config#nixos";
      nix-check = "nix flake check ~/Projects/nixos-config";
      ll = "ls -alF";
    };
  };

  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
    };
  };

  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
  };

  programs.rofi = {
    enable = true;
    font = "Monaspace Neon 11";
    terminal = "alacritty";
    modes = [
      "drun"
      "run"
    ];
  };

  programs.alacritty = {
    enable = true;
    settings = {
      font = {
        normal.family = "Monaspace Neon";
        size = 11;
      };
      window.padding = {
        x = 4;
        y = 4;
      };
      scrolling.history = 10000;
    };
  };
}
