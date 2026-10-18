{
  lib,
  fetchFromGitHub,
  hyprlandPlugins,
  nlohmann_json,
}:

hyprlandPlugins.mkHyprlandPlugin {
  pluginName = "hyprmosaic";
  version = "1.0-jeffrey-0.55.4";

  src = fetchFromGitHub {
    owner = "La5u";
    repo = "hyprmosaic";
    rev = "7597c5ef1fc7ce7265a0117089cf88da7cd7e08f";
    hash = "sha256-iwP9y+dSkHGU410J1XdMaDPZohzNlutMYNDJbXmYs1g=";
  };

  # Wallpaper-only backport: retain upstream's rendering model and license,
  # use the pinned compositor API and our atomic, per-output prepared manifest.
  postPatch = ''
    cp ${./wallpaper.cpp} hyprmosaic.cpp
  '';
  buildInputs = [ nlohmann_json ];
  dontUseCmakeConfigure = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 hyprmosaic.so $out/lib/libhyprmosaic.so
    install -Dm644 LICENSE $out/share/licenses/hyprmosaic/LICENSE
    runHook postInstall
  '';

  meta = {
    description = "Wallpaper-only hyprmosaic backport for the pinned Hyprland";
    homepage = "https://github.com/La5u/hyprmosaic";
    license = [
      lib.licenses.mit
      lib.licenses.bsd3
    ];
    platforms = [ "x86_64-linux" ];
  };
}
