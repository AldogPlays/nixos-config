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

  programs.kitty = {
    enable = true;
    font = {
      name = "JetBrainsMono Nerd Font";
      size = 11;
    };
    settings = {
      confirm_os_window_close = 0;
      enable_audio_bell = false;
      scrollback_lines = 10000;
      window_padding_width = 8;
    };
  };
}
