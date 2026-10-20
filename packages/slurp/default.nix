{ slurp }:

slurp.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [ ./click-drag-threshold.patch ];
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    # Exercise Slurp's real selection handlers without connecting to Wayland.
    cc -std=c11 -O2 -ffunction-sections -fdata-sections \
      -UNDEBUG -I.. -I../include -Islurp.p ${./selection-test.c} \
      -Wl,--gc-sections -o selection-test \
      $(pkg-config --cflags --libs wayland-client wayland-cursor xkbcommon cairo)
    ./selection-test
    runHook postCheck
  '';
})
