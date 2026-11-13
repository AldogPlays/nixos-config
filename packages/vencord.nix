{
  vencord,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpm_12,
}:

# Discord's current web client no longer starts with the stable input's Vencord.
# Keep this compatibility update isolated from the rest of the package set.
(vencord.override { pnpm_11 = pnpm_12; }).overrideAttrs (
  finalAttrs: _previousAttrs: {
    version = "1.15.17-unstable-2026-11-11";
    src = fetchFromGitHub {
      owner = "Vendicated";
      repo = "Vencord";
      rev = "d07030c0968e31e41caa0c35fda0ef8ae63a079e";
      hash = "sha256-CA+FBccf6gmTDP6ABMQJ92myGyUgtmTS5b+DYxYd/fk=";
    };

    # This revision already uses React 19 types through its workspace catalogue.
    patches = [ ];
    postPatch = "";
    pnpmDeps = fetchPnpmDeps {
      inherit (finalAttrs) pname src;
      pnpm = pnpm_12;
      fetcherVersion = 4;
      hash = "sha256-3b45LAJfknpWMItWOVnLRaFA3mfI4hk0sZ27h2QqlhI=";
    };
  }
)
