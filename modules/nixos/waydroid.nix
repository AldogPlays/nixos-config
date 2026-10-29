{
  config,
  lib,
  pkgs,
  ...
}:

let
  android = import ../../packages/waydroid { inherit pkgs; };
  desktopUsers = lib.mapAttrsToList (name: home: {
    inherit name;
    directory = home.home.homeDirectory;
    data = "${home.xdg.dataHome}/waydroid/data";
  }) config.home-manager.users;
in
{
  virtualisation.waydroid = {
    enable = true;
    package = pkgs.waydroid-nftables;
  };

  environment.etc = {
    "waydroid-extra/images".source = android.images;
    "waydroid-extra/aurora-store.apk".source = android.auroraStore;
  };

  # Prepare pinned images before first use, without resetting existing Android data.
  systemd.services.waydroid-initialize = {
    description = "Initialize Waydroid from pinned Android images";
    wantedBy = [ "multi-user.target" ];
    before = [ "waydroid-container.service" ];
    unitConfig.ConditionPathExists = "!/var/lib/waydroid/waydroid_base.prop";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${config.virtualisation.waydroid.package}/bin/waydroid init";
      ExecStartPost = "${pkgs.coreutils}/bin/test -f /var/lib/waydroid/waydroid_base.prop";
    };
  };
  systemd.services.waydroid-container = {
    # D-Bus starts the controller when Android is opened, not at system boot.
    wantedBy = lib.mkForce [ ];
    requires = [ "waydroid-initialize.service" ];
    after = [ "waydroid-initialize.service" ];
    restartTriggers = [ android.images ];
  };

  boot.supportedFilesystems = [ "fuse.bindfs" ];

  systemd.services.waydroid-storage-prepare = {
    description = "Prepare Android shared storage";
    requires = [ "waydroid-initialize.service" ];
    after = [ "waydroid-initialize.service" ];
    serviceConfig.Type = "oneshot";
    script = lib.concatMapStringsSep "\n" (user: ''
      ${pkgs.util-linux}/bin/runuser -u ${lib.escapeShellArg user.name} -- \
        ${pkgs.coreutils}/bin/mkdir -p \
        ${lib.escapeShellArg user.data}
      ${pkgs.coreutils}/bin/install -d -m 0770 -o 1023 -g 1023 \
        ${lib.escapeShellArg "${user.data}/media"} \
        ${lib.escapeShellArg "${user.data}/media/0"}
    '') desktopUsers;
  };

  systemd.mounts = map (user: {
    description = "Android shared storage for ${user.name}";
    what = "${user.data}/media/0";
    where = "${user.directory}/Waydroid";
    type = "fuse.bindfs";
    # This late, on-demand mount must not order before local-fs.target.
    options = "nofail,mirror-only=${user.name},create-for-user=1023,create-for-group=1023,perms=u+rwX,chown-ignore,chgrp-ignore,chmod-ignore,nosuid,nodev";
    requiredBy = [ "waydroid-container.service" ];
    requires = [ "waydroid-storage-prepare.service" ];
    before = [ "waydroid-container.service" ];
    after = [ "waydroid-storage-prepare.service" ];
  }) desktopUsers;

  # The storage shortcut is usable even while Android is stopped.
  systemd.automounts = map (user: {
    where = "${user.directory}/Waydroid";
    wantedBy = [ "multi-user.target" ];
  }) desktopUsers;

  # Host writes bypass Android's emulated-storage notifications. Refresh its
  # media database after direct photo-folder pastes, without starting Android.
  systemd.paths.waydroid-media = {
    description = "Watch shared Android photo folders";
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathChanged = lib.concatMap (
        user:
        map (folder: "${user.data}/media/0/${folder}") [
          "Pictures"
          "DCIM"
          "Download"
        ]
      ) desktopUsers;
      Unit = "waydroid-media-scan.service";
    };
  };
  systemd.services.waydroid-media-scan = {
    description = "Refresh Android's shared-media index";
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = 40;
    };
    script = ''
      if [[ "$(${pkgs.lxc}/bin/lxc-info -P /var/lib/waydroid/lxc -n waydroid -sH 2>/dev/null)" == RUNNING ]]; then
        ${pkgs.coreutils}/bin/sleep 2
        ${pkgs.coreutils}/bin/timeout 30 \
          ${config.virtualisation.waydroid.package}/bin/waydroid shell --uid 2000 -- \
          content call --uri content://media --method scan_volume --arg external_primary
      fi
    '';
  };
}
