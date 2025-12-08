# Build module for dependencies
#
# This module provides functions to build dependencies for iOS, macOS, and Android
# using Nix cross-compilation. Platform-specific builds are in separate modules.

{ lib, pkgs, stdenv, buildPackages }:

let
  # Import common utilities
  common = import ./common.nix { inherit lib pkgs; };
  
  # Import platform-specific build modules
  macosModule = import ./macos.nix { inherit lib pkgs buildPackages common; };
  iosModule = import ./ios.nix { inherit lib pkgs buildPackages common; };
  androidModule = import ./android.nix { inherit lib pkgs buildPackages common; };
  
  registry = common.registry;
  
  # Build all dependencies for a platform
  buildAllForPlatform = platform:
    lib.mapAttrs (name: entry:
      if platform == "ios" then iosModule.buildForIOS name entry
      else if platform == "macos" then macosModule.buildForMacOS name entry
      else if platform == "android" then androidModule.buildForAndroid name entry
      else throw "Unknown platform: ${platform}"
    ) (lib.filterAttrs (_: entry:
      let platforms = entry.platforms or [ "ios" "macos" "android" ];
      in lib.elem platform platforms
    ) registry);
in
{
  # Individual build functions
  buildForIOS = iosModule.buildForIOS;
  buildForMacOS = macosModule.buildForMacOS;
  buildForAndroid = androidModule.buildForAndroid;
  
  # Build all dependencies for a platform
  buildAllForPlatform = buildAllForPlatform;
  
  # Convenience functions - build all dependencies for each platform
  ios = buildAllForPlatform "ios";
  macos = buildAllForPlatform "macos";
  android = buildAllForPlatform "android";
}
