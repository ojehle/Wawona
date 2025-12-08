# macOS-specific dependency builds

{ lib, pkgs, common }:

let
  getBuildSystem = common.getBuildSystem;
  fetchSource = common.fetchSource;
in

{
  # Build a dependency for macOS
  buildForMacOS = name: entry:
    let
      src = fetchSource entry;
      
      buildSystem = getBuildSystem entry;
      buildFlags = entry.buildFlags.macos or [];
      patches = entry.patches.macos or [];
      
      # Determine build inputs based on dependency name
      waylandDeps = with pkgs; [ expat libffi libxml2 ];
      mesaDeps = with pkgs; [
        libclc  # Required by Mesa build system
        zlib  # Required by Mesa
        zstd  # libzstd
        expat  # XML parsing
        llvmPackages.llvm  # LLVM (may be needed for some drivers)
      ];
      defaultDeps = [];
      depInputs = if name == "wayland" then waylandDeps
                 else if name == "mesa-kosmickrisp" then mesaDeps
                 else defaultDeps;
    in
      if buildSystem == "cmake" then
        pkgs.stdenv.mkDerivation {
          name = "${name}-macos";
          inherit src patches;
          
          nativeBuildInputs = with pkgs; [
            cmake
            pkg-config
          ];
          
          buildInputs = depInputs;
          
          cmakeFlags = buildFlags;
        }
      else if buildSystem == "meson" then
        pkgs.stdenv.mkDerivation {
          name = "${name}-macos";
          src = src;
          patches = lib.filter (p: p != null && builtins.pathExists (toString p)) patches;
          
          nativeBuildInputs = with pkgs; [
            meson
            ninja
            pkg-config
            (python3.withPackages (ps: with ps; [
              setuptools
              pip
              packaging
              mako
              pyyaml
            ]))
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
        # Rust/Cargo build for macOS
        pkgs.rustPlatform.buildRustPackage {
          pname = name;
          version = entry.rev or entry.tag or "unknown";
          inherit src patches;
          
          # Use cargoHash (newer SRI format) or cargoSha256 (older)
          # If neither provided, use fakeHash to let Nix compute it
          cargoHash = if entry ? cargoHash && entry.cargoHash != null then entry.cargoHash else lib.fakeHash;
          cargoSha256 = entry.cargoSha256 or null;
          cargoLock = entry.cargoLock or null;
          
          nativeBuildInputs = with pkgs; [
            pkg-config
          ];
          
          buildInputs = depInputs;
        }
      else
        # Default to autotools
        pkgs.stdenv.mkDerivation {
          name = "${name}-macos";
          inherit src patches;
          
          nativeBuildInputs = with pkgs; [
            autoconf
            automake
            libtool
            pkg-config
          ];
          
          buildInputs = depInputs;
          
          configureFlags = buildFlags;
        };
}
