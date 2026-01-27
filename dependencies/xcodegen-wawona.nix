{
  pkgs,
  rustPlatform,
  hiahkernel ? null,
  wawonaVersion,
  TEAM_ID ? null,
  compositor,
}:

let
  lib = pkgs.lib;
  buildPackages = pkgs.buildPackages;
  buildModule = import ./build.nix {
    inherit (pkgs) lib pkgs stdenv buildPackages;
  };
  common = import ./common/common.nix { inherit lib pkgs; };
  xcodeUtils = import ./utils/xcode-wrapper.nix { inherit lib pkgs TEAM_ID; };

  libwayland = import ./deps/libwayland/ios.nix {
    inherit pkgs lib buildPackages common buildModule;
  };
  zstd = import ./deps/zstd/ios.nix {
    inherit pkgs lib buildPackages common buildModule;
  };
  lz4 = import ./deps/lz4/ios.nix {
    inherit pkgs lib buildPackages common buildModule;
  };
  ffmpeg = import ./deps/ffmpeg/ios.nix {
    inherit pkgs lib buildPackages common buildModule;
  };
  pixman = import ./deps/pixman/ios.nix {
    inherit pkgs lib buildPackages common buildModule;
  };
  xkbcommon = import ./deps/xkbcommon/ios.nix {
    inherit pkgs lib buildPackages common buildModule;
  };
  libffi = import ./deps/libffi/ios.nix {
    inherit pkgs lib buildPackages common buildModule;
  };
  expat = import ./deps/expat/ios.nix {
    inherit pkgs lib buildPackages common buildModule;
  };
  libxml2 = import ./deps/libxml2/ios.nix {
    inherit pkgs lib buildPackages common buildModule;
  };
  zlib = import ./deps/zlib/ios.nix {
    inherit pkgs lib buildPackages common buildModule;
  };
  kosmickrisp = import ./deps/kosmickrisp/ios.nix {
    inherit pkgs lib buildPackages common buildModule;
  };
  epollShim = import ./deps/epoll-shim/ios.nix {
    inherit pkgs lib buildPackages common buildModule;
  };
  hiahLibrary =
    if hiahkernel != null then
      (hiahkernel.packages.${pkgs.stdenv.hostPlatform.system}.hiah-library-ios-sim or hiahkernel.packages.${pkgs.stdenv.hostPlatform.system}.hiah-library-ios)
    else
      null;
  hiahHeaders =
    if hiahkernel != null then
      (hiahkernel.packages.${pkgs.stdenv.hostPlatform.system}.hiah-library-headers or null)
    else
      null;

  rustLibDir = "${compositor}/lib";

  projectConfig = {
    name = "Wawona";
    options = {
      bundleIdPrefix = "com.aspauldingcode";
      deploymentTarget.iOS = "16.0";
      developmentLanguage = "en";
      generateEmptyDirectories = true;
    };
    schemes.Wawona = {
      build.targets.Wawona = "all";
      run.config = "Debug";
      profile.config = "Release";
      analyze.config = "Debug";
      archive.config = "Release";
    };
    targets.Wawona = {
      type = "application";
      platform = "iOS";
      info = {
        path = "src/resources/app-bundle/Info.plist";
        properties = {
          LSRequiresIPhoneOS = true;
          UILaunchStoryboardName = "LaunchScreen";
        };
      };
      sources = (map (dir: {
        path = dir;
        excludes = [
          "**/*.rs"
          "**/*_macos*"
          "**/*_android*"
          "WawonaWindow.*"
          "WawonaWindowManager.*"
          "WawonaDisplayLinkManager.*"
          "WawonaEventLoopManager.*"
          "WawonaWindowDelegate.*"
          "WawonaCompositorView.*"
          "**/*.png"
          "**/*.md"
          "**/*.txt"
          "**/*.toml"
          "**/*.lock"
          "**/*.nix"
          "**/*.xml"
          "**/Info.plist"
          "**/*.backup"
          "**/*_fixed.m"
        ];
      }) [
        "src/core"
        "src/rendering"
        "src/input"
        "src/ui"
        "src/logging"
        "src/stubs"
        "src/compositor_implementations"
        "src/extensions"
        "src/protocols"
      ]) ++ [
        { path = "src/resources/Settings.bundle"; }
        { path = "src/resources/wayland.png"; }
      ];
      settings = {
        base = {
          PRODUCT_NAME = "Wawona";
          PRODUCT_BUNDLE_IDENTIFIER = "com.aspauldingcode.Wawona";
          MARKETING_VERSION = wawonaVersion;
          CURRENT_PROJECT_VERSION = wawonaVersion;
          ENABLE_BITCODE = "NO";
          CLANG_ENABLE_MODULES = "YES";
          CLANG_ENABLE_OBJC_ARC = "YES";
          CLANG_CXX_LANGUAGE_STANDARD = "gnu++14";
          CLANG_CXX_LIBRARY = "libc++";
          CODE_SIGN_STYLE = "Automatic";
          DEVELOPMENT_TEAM = "\${TEAM_ID}";
          IPHONEOS_DEPLOYMENT_TARGET = "16.0";
          "EXCLUDED_ARCHS[sdk=iphonesimulator*]" = "x86_64";
          GCC_PREPROCESSOR_DEFINITIONS = [
            "$(inherited)"
            "USE_RUST_CORE=1"
            "TARGET_OS_IPHONE=1"
          ];
          SWIFT_VERSION = "5.0";
          MTL_FAST_MATH = "YES";
          TARGETED_DEVICE_FAMILY = "1,2";
          LD_RUNPATH_SEARCH_PATHS = [
            "$(inherited)"
            "@executable_path/Frameworks"
          ];
          FRAMEWORK_SEARCH_PATHS = [
            "$(inherited)"
            "."
          ];
          HEADER_SEARCH_PATHS = [
            "$(SRCROOT)/src"
            "$(SRCROOT)/src/core"
            "$(SRCROOT)/src/rendering"
            "$(SRCROOT)/src/input"
            "$(SRCROOT)/src/ui"
            "$(SRCROOT)/src/logging"
            "$(SRCROOT)/src/stubs"
            "$(SRCROOT)/src/compositor_implementations"
            "$(SRCROOT)/src/protocols"
            "$(SRCROOT)/src/extensions"
            "${libwayland}/include"
            "${zstd}/include"
            "${lz4}/include"
            "${ffmpeg}/include"
            "${pixman}/include"
            "${xkbcommon}/include"
            "${libffi}/include"
            "${expat}/include"
            "${libxml2}/include"
            "${zlib}/include"
            "${kosmickrisp}/include"
            "${pkgs.vulkan-headers}/include"
            "${epollShim}/include"
          ] ++ (lib.optional (hiahHeaders != null) "${hiahHeaders}/include");
          OTHER_LDFLAGS = [
            "-lc++"
            "-lwayland-client"
            "-lwayland-server"
            "-lpixman-1"
            "-lxkbcommon"
            "-lz"
            "-lzstd"
            "-llz4"
            "-lavcodec"
            "-lavutil"
            "-lavformat"
            "${rustLibDir}/libwawona.a"
          ] ++ (lib.optional (hiahLibrary != null) "-lHIAHKernel");
          LIBRARY_SEARCH_PATHS = [
            "$(inherited)"
            "${rustLibDir}"
            "${libwayland}/lib"
            "${zstd}/lib"
            "${lz4}/lib"
            "${ffmpeg}/lib"
            "${pixman}/lib"
            "${xkbcommon}/lib"
            "${libffi}/lib"
            "${expat}/lib"
            "${libxml2}/lib"
            "${zlib}/lib"
            "${kosmickrisp}/lib"
            "${epollShim}/lib"
          ] ++ (lib.optional (hiahLibrary != null) "${hiahLibrary}/lib");
        };
        configs = {
          Debug = {
            CLANG_ENABLE_MODULES = "YES";
            GCC_OPTIMIZATION_LEVEL = "0";
            DEBUG_INFORMATION_FORMAT = "dwarf";
            MTL_ENABLE_DEBUG_INFO = "INCLUDE_SOURCE";
            ONLY_ACTIVE_ARCH = "YES";
          };
          Release = {
            CLANG_ENABLE_MODULES = "YES";
            DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
            MTL_ENABLE_DEBUG_INFO = "NO";
          };
        };
      };
      dependencies = [
        { framework = "UIKit.framework"; }
        { framework = "Foundation.framework"; }
        { framework = "CoreGraphics.framework"; }
        { framework = "QuartzCore.framework"; }
        { framework = "CoreVideo.framework"; }
        { framework = "Metal.framework"; }
        { framework = "MetalKit.framework"; }
        { framework = "IOSurface.framework"; }
        { framework = "CoreMedia.framework"; }
        { framework = "AVFoundation.framework"; }
        { framework = "Security.framework"; }
        { framework = "Network.framework"; }
      ];
    };
  };

  projectYamlFile = pkgs.writeText "project.yml" (builtins.toJSON projectConfig);
  projectDrv = pkgs.stdenv.mkDerivation {
    pname = "WawonaXcodeProject";
    version = wawonaVersion;
    src = ./..;

    nativeBuildInputs = [ pkgs.xcodegen ];

    buildPhase = ''
      runHook preBuild
      cp ${projectYamlFile} project.yml
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      export HOME="$TMPDIR"
      export USER="nobody"
      ${pkgs.xcodegen}/bin/xcodegen generate --spec project.yml
      mkdir -p $out
      if [ -d "Wawona.xcodeproj" ]; then
        cp -r Wawona.xcodeproj $out/
      else
        find . -maxdepth 1 -name "*.xcodeproj" -exec cp -r {} $out/ \; || true
      fi
      runHook postInstall
    '';
  };

  # Script to generate project (headless)
  generateScript = pkgs.writeShellScriptBin "xcodegen" ''
    set -e
    SPEC_PATH=${projectYamlFile}

    if [ -d "Wawona.xcodeproj" ]; then
      chmod -R u+w "Wawona.xcodeproj" 2>/dev/null || true
      rm -rf "Wawona.xcodeproj"
    fi

    rm -f "./project.yml"
    cp "$SPEC_PATH" "./project.yml"
    chmod u+w "./project.yml"
    
    if [ -n "''${TEAM_ID:-}" ]; then
      echo "Using TEAM_ID from environment."
      TEAM_ID="$TEAM_ID" ${xcodeUtils.xcodeWrapper}/bin/xcode-wrapper ${pkgs.xcodegen}/bin/xcodegen generate --spec "./project.yml"
    else
      echo "warning: TEAM_ID not set. Xcode project may not build properly."
      echo "Consider adding TEAM_ID to your .envrc file."
      ${xcodeUtils.xcodeWrapper}/bin/xcode-wrapper ${pkgs.xcodegen}/bin/xcodegen generate --spec "./project.yml"
    fi
    
    rm -f "./project.yml"
    echo "Wawona.xcodeproj generated in current directory."
  '';

  # Script to generate AND open project
  openScript = pkgs.writeShellScriptBin "xcodegen-open" ''
    set -e
    ${generateScript}/bin/xcodegen
    
    echo "Opening Wawona.xcodeproj..."
    if [ -d "Wawona.xcodeproj" ]; then
      open Wawona.xcodeproj
      echo "Project opened in Xcode."
    else
      echo "Error: Wawona.xcodeproj was not generated."
      exit 1
    fi
  '';
in {
  project = projectDrv;
  app = generateScript;
  inherit openScript;
}
