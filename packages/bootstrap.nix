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
    if [[ ! -f ${lib.escapeShellArg packetTracerSource} ]]; then
      installer="$HOME/Downloads/${packetTracerInstaller.name}"
      if [[ -f "$installer" ]]; then
        installerHash=$(nix --extra-experimental-features 'nix-command flakes' hash file --type sha256 "$installer")
        if [[ "$installerHash" != ${lib.escapeShellArg packetTracerInstaller.outputHash} ]]; then
          echo "Packet Tracer installer checksum does not match the pinned package." >&2
          exit 1
        fi
        nix-store --add-fixed sha256 "$installer" >/dev/null
      else
        echo "Packet Tracer requires ${packetTracerInstaller.name} from https://www.netacad.com/resources/lab-downloads in ~/Downloads before --apply can build." >&2
      fi
    fi
    exec ${python3}/bin/python3 ${../scripts/bootstrap.py} \
      --project-source ${projectSource} --nixpkgs-source ${nixpkgsSource} "$@"
  '';
}
