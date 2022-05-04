{
  lib,
  pkgs,

  # dream2nix
  satisfiesSemver,
  ...
}: 

let
  versionGate = pkg: target:
    assert
      lib.assertMsg (lib.versionAtLeast target.version pkg.version)
      "${pkg.name} has reached the desired version upstream";
      target;

  vips_8_12_2' = pkgs.vips.overrideAttrs (_: {
    version = "8.12.2";
    src = pkgs.fetchFromGitHub {
      owner = "libvips";
      repo = "libvips";
      rev = "v8.12.2";
      sha256 = "sha256-ffDJJWe/SzG+lppXEiyfXXL5KLdZgnMjv1SYnuYnh4c=";
      extraPostFetch = ''
        rm -r $out/test/test-suite/images/
      '';
    };
  });

  vips_8_12_2 = versionGate pkgs.vips vips_8_12_2';
in

{
  sharp.build = with pkgs; {
    nativeBuildInputs = old: old ++ [
      pkg-config
    ];
    buildInputs = old: old ++ [
      vips_8_12_2
    ];
  };
  ghost.build = {
    # zip comes pre-built
    runBuild = "";

    nativeBuildInputs = [
      pkgs.makeWrapper
    ];

    postInstall = ''
      makeWrapper $(command -v node) $out/bin/ghost \
        --add-flags "index.js" \
        --run "cd $out/lib/node_modules/ghost" \
        --set NODE_PATH "$out/lib/node_modules/ghost/node_modules"
    '';
  };

  puppeteer.dummy-build = {
    # HACK: doesn't build, but we don't need it anywhere
    configurePhase = "exit 0";
  };

  uptime-kuma.runtime-bugfixes = {
    patches = [
      ./uptime-kuma/log-in-data-dir.patch
      ./uptime-kuma/chmod-database.patch
      ./uptime-kuma/data-dir-concat-with-slash.patch
    ];
  };

  uptime-kuma.build = {
    # HACK: rollup.js is garbage and expects the contents of node_modules to not be symlinks
    # obey its wishes by copying dependencies into place
    preBuild = ''
      cp -r node_modules $NIX_BUILD_TOP/node_modules_saved
      find node_modules node_modules/@* -maxdepth 1 -type l -exec \
        bash -c 'LOC=$(readlink -f {}); echo unsymlinking: {}; rm {}; cp -r $LOC {}' \;

      chmod +w -R node_modules
      find node_modules -mindepth 2 -name node_modules | xargs rm -rf
    '';

    preInstall = ''
      echo restoring original node_modules directory
      rm -rf node_modules
      mv $NIX_BUILD_TOP/node_modules_saved node_modules
    '';

    postInstall = ''
      makeWrapper $(command -v node) $out/bin/uptime-kuma \
        --add-flags "server/server.js" \
        --run "cd $out/lib/node_modules/uptime-kuma" \
        --set NODE_PATH "$out/lib/node_modules/uptime-kuma/node_modules"
    '';
  };

  excalidraw.build = {
    nativeBuildInputs = [ pkgs.yarn ];

    installPhase = ''
      mv $out/lib/node_modules/*/build $out/dist
      rm -rf $out/lib
      find $out/dist -type f -name "*.map" -delete
    '';
  };
}
