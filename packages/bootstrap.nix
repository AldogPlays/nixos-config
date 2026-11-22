{
  writeShellApplication,
  python3,
  nix,
  nixos-rebuild,
  coreutils,
  systemd,
  lib,
  cisco-packet-tracer_9,
  projectSource,
  nixpkgsSource,
}:

let
  packetTracerInstaller = cisco-packet-tracer_9.src.src;
  # The bootstrap must start even when this manually downloaded input is absent.
  packetTracerSource = builtins.unsafeDiscardStringContext packetTracerInstaller.outPath;
in
writeShellApplication {
  name = "nixos-config-bootstrap";
  runtimeInputs = [
    nix
    nixos-rebuild
    coreutils
    systemd
  ];
  text = ''
    exec ${python3}/bin/python3 ${../scripts/bootstrap.py} \
      --project-source ${projectSource} --nixpkgs-source ${nixpkgsSource} \
      --packet-tracer-source ${lib.escapeShellArg packetTracerSource} \
      --packet-tracer-name ${lib.escapeShellArg packetTracerInstaller.name} \
      --packet-tracer-hash ${lib.escapeShellArg packetTracerInstaller.outputHash} "$@"
  '';
}
