{
  description = "Wawona";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, rust-overlay }: let
    system = "aarch64-darwin";
    pkgs = import nixpkgs {
      inherit system;
      overlays = [ (import rust-overlay) ];
      config = { allowUnfree = true; android_sdk.accept_license = true; };
    };

    androidSDK = pkgs.androidenv.composeAndroidPackages {
      cmdLineToolsVersion = "latest";
      platformToolsVersion = "latest";
      buildToolsVersions = [ "36.0.0" ];
      platformVersions = [ "36" ];
      abiVersions = [ "arm64-v8a" ];
      includeEmulator = true;
      emulatorVersion = "36.4.2";
      includeSystemImages = true;
      systemImageTypes = [ "google_apis_playstore" ];
    };

    buildModule = import ./dependencies/build.nix {
      lib = pkgs.lib;
      inherit pkgs;
      stdenv = pkgs.stdenv;
      buildPackages = pkgs.buildPackages;
    };

    wawonaSrc = pkgs.lib.cleanSourceWith {
      src = ./.;
      filter = path: type:
        let base = baseNameOf path; in
        !(base == ".git" || base == "build" || base == "result" || base == ".direnv" || pkgs.lib.hasPrefix "result" base);
    };

    wawonaBuildModule = import ./dependencies/wawona.nix {
      lib = pkgs.lib;
      inherit pkgs buildModule wawonaSrc androidSDK;
    };

    androidToolchain = import ./dependencies/common/android-toolchain.nix {
      inherit (pkgs) lib;
      inherit pkgs;
    };

    updateAndroidDeps = pkgs.writeShellScriptBin "update-android-deps" ''
      export ANDROID_SDK_ROOT="${androidSDK.androidsdk}/libexec/android-sdk"
      export GRADLE_USER_HOME=$(pwd)/.gradle-home
      cd src/android
      ${pkgs.gradle}/bin/gradle dependencyUpdates
    '';

    multiplexDev = pkgs.writeShellScriptBin "wawona-multiplex" ''
      tmux="${pkgs.tmux}/bin/tmux"
      $tmux new-session -d -s wawona "nix run .#wawona-macos"
      $tmux split-window -t wawona "nix run .#wawona-ios"
      $tmux split-window -t wawona "nix run .#wawona-android"
      $tmux select-layout -t wawona tiled
      $tmux attach -t wawona
    '';

  in {
    packages.${system} = {
      default = wawonaBuildModule.macos;
      wawona-ios = wawonaBuildModule.ios;
      wawona-macos = wawonaBuildModule.macos;
      wawona-android = wawonaBuildModule.android;
    };

    apps.${system} = {
      default = { type = "app"; program = "${multiplexDev}/bin/wawona-multiplex"; };
      wawona-ios = { type = "app"; program = "${wawonaBuildModule.ios}/bin/wawona-ios-simulator"; };
      wawona-android = { type = "app"; program = "${wawonaBuildModule.android}/bin/wawona-android-run"; };
      wawona-macos = { type = "app"; program = "${wawonaBuildModule.macos}/bin/Wawona"; };
      update-android-deps = { type = "app"; program = "${updateAndroidDeps}/bin/update-android-deps"; };
    };
    
    devShells.${system}.default = pkgs.mkShell {
      buildInputs = [
        pkgs.gradle
        pkgs.jdk17
        androidSDK.androidsdk
      ];
      ANDROID_SDK_ROOT = "${androidSDK.androidsdk}/libexec/android-sdk";
      ANDROID_NDK_ROOT = "${androidToolchain.androidndkRoot}";
    };
  };
}
