{ lib, hyprlandPlugins }:

hyprlandPlugins.mkHyprlandPlugin {
  pluginName = "full-edges";
  version = "1.0";
  src = ./.;
  dontUseCmakeConfigure = true;
  buildPhase = ''
    runHook preBuild
    $CXX -std=c++23 -O2 -fPIC -shared $(pkg-config --cflags hyprland) plugin.cpp -o libfull-edges.so
    $CXX -std=c++23 -O2 test.cpp -o geometry-check
    ./geometry-check
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    install -Dm755 libfull-edges.so $out/lib/libfull-edges.so
    runHook postInstall
  '';
  meta = {
    description = "Full-edge proportional cursor crossing for pinned Hyprland";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
