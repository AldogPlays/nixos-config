{
  writeShellApplication,
  python3,
  nix,
  nixos-rebuild,
  coreutils,
  systemd,
  projectSource,
  nixpkgsSource,
}:

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
      --project-source ${projectSource} --nixpkgs-source ${nixpkgsSource} "$@"
  '';
}
