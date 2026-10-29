{ pkgs, images }:
let
  androidenv = pkgs.androidenv.override { licenseAccepted = true; };
  ndk =
    (androidenv.composeAndroidPackages {
      includeNDK = true;
      ndkVersions = [ "27.0.12077973" ];
    }).ndk-bundle;
  upstream = pkgs.fetchFromGitHub {
    owner = "waydroid";
    repo = "android_external_minigbm";
    rev = "e5a7769a4892cd1b6c61c56a8bedfc9b93584704";
    hash = "sha256-+A/eA6Bz45HvudQri9ItBBopb4B6OAmPuWjA1/SbD3Y=";
  };
in
pkgs.runCommand "waydroid-yv12-layout"
  {
    nativeBuildInputs = [
      pkgs.e2fsprogs
      pkgs.patchelf
      pkgs.binutils
    ];
  }
  ''
    mkdir -p "$out/lib64"
    debugfs -R 'dump /lib64/libminigbm_gralloc_gbm_mesa.so original.so' ${images}/vendor.img
    echo 'b1fd9ad2f7790d659e246e55aa828d8d61a677cfad2d0c983ddab9f3f0044644  original.so' | sha256sum -c -
    cp original.so "$out/lib64/libminigbm_gralloc_gbm_mesa_base.so"
    chmod u+w "$out/lib64/libminigbm_gralloc_gbm_mesa_base.so"
    patchelf --set-soname libminigbm_gralloc_gbm_mesa_base.so "$out/lib64/libminigbm_gralloc_gbm_mesa_base.so"
    ${ndk}/libexec/android-sdk/ndk-bundle/toolchains/llvm/prebuilt/linux-x86_64/bin/x86_64-linux-android33-clang \
      -std=c11 -D_GNU_SOURCE -O2 -Wall -Wextra -Werror -fPIC -shared \
      -I${upstream} -I${pkgs.libdrm.dev}/include/libdrm \
      ${./yv12-layout.c} \
      -L"$out/lib64" -Wl,--no-as-needed -l:libminigbm_gralloc_gbm_mesa_base.so \
      -Wl,-z,defs -Wl,--allow-shlib-undefined \
      -Wl,-soname,libminigbm_gralloc_gbm_mesa.so -ldl -llog \
      -o "$out/lib64/libminigbm_gralloc_gbm_mesa.so"
    mkdir -p "$out/bin"
    ${ndk}/libexec/android-sdk/ndk-bundle/toolchains/llvm/prebuilt/linux-x86_64/bin/x86_64-linux-android33-clang \
      -std=gnu11 -D_GNU_SOURCE -O2 -Wall -Wextra -Werror \
      -I${upstream} -I${pkgs.libdrm.dev}/include/libdrm \
      ${./yv12-probe.c} -ldl -o "$out/bin/waydroid-yv12-probe"
  ''
