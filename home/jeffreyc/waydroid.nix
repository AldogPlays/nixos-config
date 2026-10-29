{
  config,
  lib,
  pkgs,
  ...
}:

let
  waydroid = pkgs.waydroid-nftables;
  setup = pkgs.writeShellApplication {
    name = "waydroid-setup";
    runtimeInputs = [
      waydroid
      pkgs.systemd
      pkgs.gnugrep
      pkgs.coreutils
    ];
    text = ''
      systemctl --user start waydroid-session.service
      ready=false
      for _ in $(seq 1 120); do
        if waydroid app list 2>/dev/null | grep -q 'packageName:'; then
          ready=true
          break
        fi
        sleep 1
      done
      if [[ "$ready" != true ]]; then
        echo 'Android did not become ready. Check journalctl --user -u waydroid-session.' >&2
        exit 1
      fi
      if ! waydroid app list | grep -q 'packageName: com.aurora.store$'; then
        waydroid app install /etc/waydroid-extra/aurora-store.apk
      fi
      # Package installation finishes asynchronously inside Android.
      for _ in $(seq 1 30); do
        if waydroid app list | grep -q 'packageName: com.aurora.store$'; then
          break
        fi
        sleep 1
      done
      if ! waydroid app list | grep -q 'packageName: com.aurora.store$'; then
        echo 'Aurora Store installation did not succeed.' >&2
        exit 1
      fi
      exec waydroid app launch com.aurora.store
    '';
  };
  openAndroid = pkgs.writeShellApplication {
    name = "waydroid-open";
    runtimeInputs = [
      waydroid
      pkgs.systemd
    ];
    text = ''
      systemctl --user start waydroid-session.service
      exec waydroid show-full-ui
    '';
  };
in
{
  home.packages = [
    setup
    openAndroid
  ];

  systemd.user.services.waydroid-session = {
    Unit = {
      Description = "On-demand Android session";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${waydroid}/bin/waydroid session start";
      ExecStop = "${waydroid}/bin/waydroid session stop";
      TimeoutStopSec = 30;
    };
  };

  xdg.desktopEntries = {
    Waydroid = {
      name = "Waydroid";
      genericName = "Android";
      exec = "${openAndroid}/bin/waydroid-open";
      icon = "waydroid";
      categories = [ "Utility" ];
      actions.stop = {
        name = "Stop Android";
        exec = "${waydroid}/bin/waydroid session stop";
      };
    };
    waydroid-setup = {
      name = "Set Up Aurora Store";
      exec = "${setup}/bin/waydroid-setup";
      icon = "waydroid";
      categories = [ "Utility" ];
      terminal = true;
    };
  };

  home.activation.waydroidPlace = lib.hm.dag.entryAfter [ "createDesktopDirectories" ] ''
    run ${pkgs.python3}/bin/python3 ${../../scripts/dolphin-place.py} \
      ${lib.escapeShellArg "${config.xdg.dataHome}/user-places.xbel"} \
      ${lib.escapeShellArg "${config.home.homeDirectory}/Waydroid"} \
      'Waydroid'
  '';
}
