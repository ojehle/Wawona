# iOS-specific dependency builds

{ lib, pkgs, buildPackages, common }:

let
  getBuildSystem = common.getBuildSystem;
  fetchSource = common.fetchSource;
  
  # iOS cross-compilation setup
  iosPkgs = pkgs.pkgsCross.iphone64;
  
  # Use buildPackages for dependencies to avoid circular dependencies
  # These are host packages, not target packages
  hostPkgs = buildPackages;
in

{
  # Build a dependency for iOS
  buildForIOS = name: entry:
    let
      src = fetchSource entry;
      
      buildSystem = getBuildSystem entry;
      buildFlags = entry.buildFlags.ios or [];
      patches = entry.patches.ios or [];
      
      # Determine build inputs based on dependency name
      # For now, build without explicit dependencies to avoid recursion
      # Dependencies will be resolved by pkg-config during build
      depInputs = [];
    in
      if buildSystem == "cmake" then
        iosPkgs.stdenv.mkDerivation {
          name = "${name}-ios";
          inherit src patches;
          
          nativeBuildInputs = with iosPkgs; [
            cmake
            pkg-config
          ];
          
          buildInputs = depInputs;
          
          cmakeFlags = [
            "-DCMAKE_SYSTEM_NAME=iOS"
            "-DCMAKE_OSX_ARCHITECTURES=arm64"
            "-DCMAKE_OSX_DEPLOYMENT_TARGET=15.0"
          ] ++ buildFlags;
          
          installPhase = ''
            runHook preInstall
            make install DESTDIR=$out
            runHook postInstall
          '';
        }
      else if buildSystem == "meson" then
        iosPkgs.stdenv.mkDerivation {
          name = "${name}-ios";
          src = src;
          patches = lib.filter (p: p != null && builtins.pathExists (toString p)) patches;
          
          nativeBuildInputs = with iosPkgs; [
            meson
            ninja
            pkg-config
            python3
            bison
            flex
          ];
          
          buildInputs = depInputs;
          
          # Meson setup command
          configurePhase = ''
            runHook preConfigure
            meson setup build \
              --prefix=$out \
              --libdir=$out/lib \
              --cross-file=${iosPkgs.stdenv.cc.targetPrefix} \
              ${lib.concatMapStringsSep " \\\n  " (flag: flag) buildFlags}
            runHook postConfigure
          '';
          
          buildPhase = ''
            runHook preBuild
            meson compile -C build
            runHook postBuild
          '';
          
          installPhase = ''
            runHook preInstall
            meson install -C build
            runHook postInstall
          '';
        }
      else if buildSystem == "cargo" || buildSystem == "rust" then
        # Rust/Cargo build for iOS
        iosPkgs.rustPlatform.buildRustPackage {
          pname = name;
          version = entry.rev or entry.tag or "unknown";
          inherit src patches;
          
          # Use cargoHash (newer SRI format) or cargoSha256 (older)
          # If neither provided, use fakeHash to let Nix compute it
          cargoHash = if entry ? cargoHash && entry.cargoHash != null then entry.cargoHash else lib.fakeHash;
          cargoSha256 = entry.cargoSha256 or null;
          cargoLock = entry.cargoLock or null;
          
          nativeBuildInputs = with iosPkgs; [
            pkg-config
          ];
          
          buildInputs = depInputs;
        }
      else
        # Default to autotools
        iosPkgs.stdenv.mkDerivation {
          name = "${name}-ios";
          inherit src patches;
          
          nativeBuildInputs = with iosPkgs; [
            autoconf
            automake
            libtool
            pkg-config
          ];
          
          buildInputs = depInputs;
          
          configureFlags = buildFlags;
        };
}
