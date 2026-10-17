{
  lib,
  stdenv,
  src,
  xmake,
  pkg-config,
  wayland,
  wayland-protocols,
  wayland-scanner,
  libdeflate,
  qt6,
  kdePackages,
  wl-clipboard,
  tesseract,
  hyprland,
}:

stdenv.mkDerivation {
  pname = "snap";
  version = "1.21.0";
  inherit src;

  nativeBuildInputs = [
    xmake
    pkg-config
    wayland-scanner
    qt6.wrapQtAppsHook
  ];
  buildInputs = [
    wayland
    libdeflate
    qt6.qtbase
    qt6.qtwayland
    kdePackages.layer-shell-qt
  ];

  postPatch = ''
    # Nix supplies dependencies; do not let xmake initialize/fetch its registry.
    substituteInPlace xmake.lua \
      --replace-fail /usr/share/wayland-protocols ${wayland-protocols}/share/wayland-protocols \
      --replace-fail 'add_requires("wayland-client", {system = true})' "" \
      --replace-fail 'add_requires("libdeflate", {system = true})' "" \
      --replace-fail 'add_packages("wayland-client", "libdeflate", {public = true})' \
        'add_syslinks("wayland-client", "deflate", {public = true})' \
      --replace-fail 'find_tool("wayland-scanner", {norun = true})' \
        '{program = "${lib.getExe wayland-scanner}"}'
  '';

  configurePhase = ''
    runHook preConfigure
    export XMAKE_GLOBALDIR="$TMPDIR/xmake-global"
    export XMAKE_PKG_CACHEDIR="$TMPDIR/xmake-packages"
    xmake config --yes --mode=release --qt=${qt6.qtbase.dev}
    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    # Qt-heavy translation units can exhaust this laptop's memory at 16 jobs.
    xmake build --jobs=2 snap
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 build/snap "$out/bin/snap"
    install -Dm644 LICENSE "$out/share/licenses/snap/LICENSE"
    runHook postInstall
  '';

  qtWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath [
      wl-clipboard
      (tesseract.override { enableLanguages = [ "eng" ]; })
      hyprland
    ])
  ];

  meta = {
    description = "Native Wayland screenshot and annotation editor";
    homepage = "https://github.com/yumedots/snap";
    license = lib.licenses.mit;
    mainProgram = "snap";
    platforms = lib.platforms.linux;
  };
}
