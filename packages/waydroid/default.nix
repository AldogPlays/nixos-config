{ pkgs }:

let
  systemImage = pkgs.fetchurl {
    urls = [
      "https://phoenixnap.dl.sourceforge.net/project/waydroid/images/system/lineage/waydroid_x86_64/lineage-20.0-20260927-VANILLA-waydroid_x86_64-system.zip"
      "https://downloads.sourceforge.net/project/waydroid/images/system/lineage/waydroid_x86_64/lineage-20.0-20260927-VANILLA-waydroid_x86_64-system.zip"
    ];
    hash = "sha256-BTVSclv0riXi0/fm8ZRyAylKqdc9wX/h86vmRuXTvYo=";
  };
  vendorImage = pkgs.fetchurl {
    url = "https://downloads.sourceforge.net/project/waydroid/images/vendor/waydroid_x86_64/lineage-20.0-20261022-MAINLINE-waydroid_x86_64-vendor.zip";
    hash = "sha256-kWY8M3ATFFIItsUz1+H6KpFamGTdyPxWlm9AzXWWSKw=";
  };
  originalImages =
    pkgs.runCommand "waydroid-lineage-20-images" { nativeBuildInputs = [ pkgs.unzip ]; }
      ''
        mkdir -p "$out"
        unzip -q ${systemImage} system.img -d "$out"
        unzip -q ${vendorImage} vendor.img -d "$out"
      '';
  graphics = import ./graphics.nix {
    pkgs = pkgs;
    images = originalImages;
  };
in
{
  inherit graphics;
  images =
    pkgs.runCommand "waydroid-lineage-20-yv12-images" { nativeBuildInputs = [ pkgs.e2fsprogs ]; }
      ''
        mkdir -p "$out"
        ln -s ${originalImages}/system.img "$out/system.img"
        cp --reflink=auto ${originalImages}/vendor.img "$out/vendor.img"
        chmod u+w "$out/vendor.img"
        export E2FSPROGS_FAKE_TIME=1
        # The upstream filesystem has zero free blocks; reserve room for the adapter.
        truncate -s +8M "$out/vendor.img"
        resize2fs "$out/vendor.img"
        debugfs -w -R 'rm /lib64/libminigbm_gralloc_gbm_mesa.so' "$out/vendor.img"
        for library in libminigbm_gralloc_gbm_mesa.so libminigbm_gralloc_gbm_mesa_base.so; do
          debugfs -w -R "write ${graphics}/lib64/$library /lib64/$library" "$out/vendor.img"
          debugfs -w -R "set_inode_field /lib64/$library mode 0100644" "$out/vendor.img"
          debugfs -R "dump /lib64/$library extracted.so" "$out/vendor.img"
          cmp extracted.so "${graphics}/lib64/$library"
          rm extracted.so
        done
        e2fsck -fn "$out/vendor.img"
      '';

  auroraStore = pkgs.fetchurl {
    name = "AuroraStore-4.8.4.apk";
    url = "https://auroraoss.com/downloads/AuroraStore/Release/AuroraStore-4.8.4.apk";
    hash = "sha256-ih7ZqgljEpDakct5PgUXsPINxwI5rJSuZoLNlPkaS60=";
  };
}
