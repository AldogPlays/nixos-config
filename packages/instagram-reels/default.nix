{
  lib,
  stdenvNoCC,
  fetchurl,
  kotlin,
  jdk25,
  python3,
  writeShellApplication,
}:
let
  supported = builtins.fromJSON (builtins.readFile ./supported.json);
  cli = fetchurl {
    url = "https://github.com/MorpheApp/morphe-desktop/releases/download/v1.19.1/morphe-desktop-1.19.1-all.jar";
    hash = "sha256-pRRyJSzWOy6sY127WhVP+Ri/wVJo2olnn+s9dgIwxXM=";
  };
  cloneBundle = fetchurl {
    url = "https://github.com/crimera/piko/releases/download/v3.10.0/patches-3.10.0.mpp";
    hash = "sha256-AcuCj8xmvN2nxCQv3FCVGBB7iD6vJmZbDaSClFt6gDM=";
  };
  bundle = stdenvNoCC.mkDerivation {
    pname = "instagram-reels-patches";
    version = "1.0";
    src = lib.fileset.toSource {
      root = ./.;
      fileset = lib.fileset.unions [
        ./Reels.kt
        ./LocalCompatibility.java
        ./LICENSE
      ];
    };
    nativeBuildInputs = [
      kotlin
      jdk25
    ];
    JAVA_OPTS = "-Xmx1024m -XX:ActiveProcessorCount=2";
    buildPhase = ''
      runHook preBuild
      substituteInPlace Reels.kt \
        --replace-fail '@INSTAGRAM_VERSION@' '${supported.version}' \
        --replace-fail '@INSTAGRAM_VERSION_CODE@' '${supported.versionCode}'
      javac --release 17 -cp ${cli} -d classes LocalCompatibility.java
      kotlinc -Xcontext-parameters -jvm-target 17 -classpath ${cli}:classes Reels.kt -d classes
      jar --create --date=1980-01-01T00:00:02Z --file local-reels.mpp -C classes .
      runHook postBuild
    '';
    installPhase = ''
      install -Dm644 local-reels.mpp "$out/share/instagram-reels/local-reels.mpp"
      install -Dm644 LICENSE "$out/share/licenses/instagram-reels/LICENSE"
    '';
    meta.license = lib.licenses.gpl3Only;
  };
in
writeShellApplication {
  name = "instagram-reels-patch";
  runtimeInputs = [ python3 ];
  text = ''
    exec python3 ${./patch.py} \
      --java ${jdk25}/bin/java --cli ${cli} \
      --bundle ${bundle}/share/instagram-reels/local-reels.mpp \
      --clone-bundle ${cloneBundle} --supported ${./supported.json} "$@"
  '';
  meta.description = "Build the version-pinned Instagram clone without Home or Reels navigation";
}
