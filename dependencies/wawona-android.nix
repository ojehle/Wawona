{
  lib,
  pkgs,
  buildModule,
  wawonaSrc,
  wawonaVersion ? null,
  androidSDK ? null,
}:

let
  common = import ./wawona-common.nix { inherit lib pkgs wawonaSrc; };

  androidToolchain = import ./common/android-toolchain.nix { inherit lib pkgs; };
  
  gradleDeps = pkgs.callPackage ./gradle-deps.nix {
    inherit wawonaSrc androidSDK;
    inherit (pkgs) gradle jdk17;
    inherit gradlegen;
  };

  gradlegen = pkgs.callPackage ./gradlegen-wawona.nix { };

  projectVersion =
    if (wawonaVersion != null && wawonaVersion != "") then wawonaVersion
    else
      let v = lib.removeSuffix "\n" (lib.fileContents (wawonaSrc + "/VERSION"));
      in if v == "" then "0.0.1" else v;

  androidDeps = common.commonDeps ++ [
    "swiftshader"
    "pixman"
  ];

  getDeps =
    platform: depNames:
    map (
      name:
      if name == "pixman" then
        if platform == "android" then
          buildModule.android.pixman
        else
          pkgs.pixman # Should not happen here but kept for logic consistency
      else if name == "vulkan-headers" then
        pkgs.vulkan-headers
      else if name == "vulkan-loader" then
        pkgs.vulkan-loader
      else if name == "xkbcommon" then
        pkgs.libxkbcommon
      else
        buildModule.${platform}.${name}
    ) depNames;

  androidSources =
    lib.filter (
      f:
      (!(lib.hasSuffix ".m" f) || f == "src/core/WawonaCompositor.m")
      # Allow WawonaCompositor.m (dual C/ObjC)
      && f != "src/compositor_implementations/wayland_color_management.c"
      # Uses TargetConditionals.h
      && f != "src/compositor_implementations/wayland_color_management.h"
      # Uses TargetConditionals.h
      && f != "src/stubs/egl_buffer_handler.h"
      # Header for Apple-specific implementation
      && f != "src/core/main.m" # Use Android-specific entry point
    ) common.commonSources
    ++ [
      "src/stubs/egl_buffer_handler.c" # Android has its own EGL implementation
      "src/platform/android/android_jni.c" # Android JNI bridge
      "src/rendering/renderer_android.c"
      "src/rendering/renderer_android.h"
    ];

  androidSourcesFiltered = common.filterSources androidSources;

in
  pkgs.stdenv.mkDerivation rec {
    name = "wawona-android";
    version = projectVersion;
    src = wawonaSrc;

    # Skip fixup phase - Android binaries can't execute on macOS
    dontFixup = true;

    nativeBuildInputs = with pkgs; [
      clang
      pkg-config
      jdk17 # Full JDK needed for Gradle
      gradle
      unzip
      zip
      patchelf
      file
      util-linux # Provides setsid for creating new process groups
    ];

    buildInputs = (getDeps "android" androidDeps) ++ [
      pkgs.mesa
    ];

    # Fix egl_buffer_handler.c for Android (create Android-compatible stub)
    postPatch = ''
            # Android doesn't have Wayland EGL extensions, so we need to create a stub
            # Replace the entire file with an Android-compatible stub
            cat > src/stubs/egl_buffer_handler.c <<'EOF'
      #include "egl_buffer_handler.h"
      #include <stdbool.h>
      #include <stdio.h>
      #include <stdlib.h>
      #include <string.h>

      // Android stub: EGL Wayland extensions are not available on Android
      // This provides stub implementations to avoid compilation errors

      static void egl_buffer_handler_translation_unit_silence(void) {}

      int egl_buffer_handler_init(struct egl_buffer_handler *handler, struct wl_display *display) {
          (void)handler; (void)display;
          // EGL Wayland extensions not available on Android
          return -1;
      }

      void egl_buffer_handler_cleanup(struct egl_buffer_handler *handler) {
          (void)handler;
      }

      int egl_buffer_handler_query_buffer(struct egl_buffer_handler *handler,
                                           struct wl_resource *buffer_resource,
                                           int32_t *width, int32_t *height,
                                           int *texture_format) {
          (void)handler; (void)buffer_resource; (void)width; (void)height; (void)texture_format;
          return -1;
      }

      void* egl_buffer_handler_create_image(struct egl_buffer_handler *handler,
                                            struct wl_resource *buffer_resource) {
          (void)handler; (void)buffer_resource;
          return NULL;
      }

      bool egl_buffer_handler_is_egl_buffer(struct egl_buffer_handler *handler,
                                             struct wl_resource *buffer_resource) {
          (void)handler; (void)buffer_resource;
          return false;
      }
      EOF
    '';

    preConfigure = ''
      export CC="${androidToolchain.androidCC}"
      export CXX="${androidToolchain.androidCXX}"
      export AR="${androidToolchain.androidAR}"
      export STRIP="${androidToolchain.androidSTRIP}"
      export RANLIB="${androidToolchain.androidRANLIB}"
      export CFLAGS="--target=${androidToolchain.androidTarget} -fPIC"
      export CXXFLAGS="--target=${androidToolchain.androidTarget} -fPIC"
      export LDFLAGS="--target=${androidToolchain.androidTarget}"

      # Android dependencies setup
      mkdir -p android-dependencies/include
      mkdir -p android-dependencies/lib
      mkdir -p android-dependencies/lib/pkgconfig

      for dep in $buildInputs; do
         if [ -d "$dep/include" ]; then
           cp -rn "$dep/include/"* android-dependencies/include/ 2>/dev/null || true
         fi
         if [ -d "$dep/lib" ]; then
           cp -rn "$dep/lib/"* android-dependencies/lib/ 2>/dev/null || true
         fi
         if [ -d "$dep/lib/pkgconfig" ]; then
            cp -rn "$dep/lib/pkgconfig/"* android-dependencies/lib/pkgconfig/ 2>/dev/null || true
         fi
      done

      export PKG_CONFIG_PATH="$PWD/android-dependencies/lib/pkgconfig:$PKG_CONFIG_PATH"
    '';

    buildPhase = ''
      runHook preBuild

      # Compile C/C++ code for Android (native library)
      OBJ_FILES=""
      for src_file in ${lib.concatStringsSep " " androidSourcesFiltered}; do
        if [[ "$src_file" == *.c ]]; then
          obj_file="''${src_file//\//_}.o"
          obj_file="''${obj_file//src_/}"
          
          if $CC -c "$src_file" \
             -Isrc -Isrc/core -Isrc/compositor_implementations \
             -Isrc/rendering -Isrc/input -Isrc/ui \
             -Isrc/logging -Isrc/stubs -Isrc/protocols \
             -Iandroid-dependencies/include \
             -fPIC \
             ${lib.concatStringsSep " " common.commonCFlags} \
             ${lib.concatStringsSep " " common.debugCFlags} \
             --target=${androidToolchain.androidTarget} \
             -o "$obj_file"; then
            OBJ_FILES="$OBJ_FILES $obj_file"
          else
            exit 1
          fi
        fi
      done

      # Link shared library
      $CC -shared $OBJ_FILES \
         -Landroid-dependencies/lib \
         $(pkg-config --libs wayland-server wayland-client pixman-1) \
         -llog -landroid -lvulkan \
         -g --target=${androidToolchain.androidTarget} \
         -o libwawona.so
         
      # Setup Gradle and dependencies
      export GRADLE_USER_HOME=$(pwd)/.gradle_home
      export ANDROID_USER_HOME=$(pwd)/.android_home
      mkdir -p $ANDROID_USER_HOME

      # Copy gradleDeps to writable location
      cp -r ${gradleDeps} $GRADLE_USER_HOME
      chmod -R u+w $GRADLE_USER_HOME

      export ANDROID_SDK_ROOT="${androidSDK.androidsdk}/libexec/android-sdk"
      export ANDROID_HOME="$ANDROID_SDK_ROOT"
      
      # Prepare source directory for Gradle build (emulating project root)
      mkdir -p project-root
      cd project-root
      
      # Copy Android sources from src/platform/android
      cp -r ${wawonaSrc}/src/platform/android/java .
      cp -r ${wawonaSrc}/src/platform/android/res .
      cp ${wawonaSrc}/src/platform/android/AndroidManifest.xml .
      
      # Place native libs where Gradle expects them (jniLibs)
      mkdir -p jniLibs/arm64-v8a
      cp ../libwawona.so jniLibs/arm64-v8a/

      # Copy other shared libs (dependencies)
      if [ -d ../android-dependencies/lib ]; then
        find ../android-dependencies/lib -name "*.so*" -exec cp -L {} jniLibs/arm64-v8a/ \;
      fi

      # Also copy libc++_shared.so
      NDK_ROOT="${androidToolchain.androidndkRoot}"
      LIBCPP_SHARED=$(find "$NDK_ROOT" -name "libc++_shared.so" | grep "aarch64" | head -n 1)
      if [ -f "$LIBCPP_SHARED" ]; then
        cp "$LIBCPP_SHARED" jniLibs/arm64-v8a/
      fi

      # Fix SONAMEs in copied libs
      chmod +w -R jniLibs
      cd jniLibs/arm64-v8a
      for lib in *.so*; do
          if [[ "$lib" =~ \.so\.[0-9]+ ]]; then
             newname=$(echo "$lib" | sed -E 's/\.so\.[0-9.]*$/.so/')
             if [ "$lib" != "$newname" ]; then
               mv "$lib" "$newname"
               patchelf --set-soname "$newname" "$newname"
             fi
          fi
      done

      # Fix dependencies
      for lib in *.so; do
         needed=$(patchelf --print-needed "$lib")
         for n in $needed; do
           if [[ "$n" =~ \.so\.[0-9]+ ]]; then
             newn=$(echo "$n" | sed -E 's/\.so\.[0-9.]*$/.so/')
             if [ -f "$newn" ]; then
                patchelf --replace-needed "$n" "$newn" "$lib"
             fi
           fi
         done
      done
      
      # Return to project root
      cd ../..
      cd project-root

      # Create Gradle build files (using gradlegen)
      cp ${gradlegen.buildGradle} build.gradle.kts
      cp ${gradlegen.settingsGradle} settings.gradle.kts
      chmod u+w build.gradle.kts settings.gradle.kts

      # Build APK
      gradle assembleDebug --offline --no-daemon

      runHook postBuild
    '';

    installPhase = ''
            runHook preInstall
            
            mkdir -p $out/bin
            mkdir -p $out/lib
            
            # Copy APK - APK is built in project-root/build/outputs/apk/debug/
            APK_PATH=""
            if [ -f "project-root/build/outputs/apk/debug/Wawona-debug.apk" ]; then
              APK_PATH="project-root/build/outputs/apk/debug/Wawona-debug.apk"
            else
              echo "APK not found in expected locations, searching..."
              APK_PATH=$(find . -name "*.apk" -type f | head -1)
              if [ -z "$APK_PATH" ]; then
                echo "Error: No APK found!"
                exit 1
              fi
              echo "Found APK at: $APK_PATH"
            fi
            
            cp "$APK_PATH" $out/bin/Wawona.apk
            echo "Copied APK to $out/bin/Wawona.apk"
            
            # Copy runtime shared libraries (still useful for debugging or other purposes, 
            # though they are now inside the APK)
            if [ -d android-dependencies/lib ]; then
              find android-dependencies/lib -name "*.so*" -exec cp -L {} $out/lib/ \;
            fi
            
            # Create wrapper script that uses Nix-provided Android emulator
            cat > $out/bin/wawona-android-run <<EOF
      #!/usr/bin/env bash
      # Don't use set -e here - we want to handle errors gracefully
      set +e

      # Setup environment from Nix build
      export PATH="${
        lib.makeBinPath [
          androidSDK.platform-tools
          androidSDK.emulator
          androidSDK.androidsdk
          pkgs.util-linux
        ]
      }:\$PATH"
      export ANDROID_SDK_ROOT="${androidSDK.androidsdk}/libexec/android-sdk"
      export ANDROID_HOME="\$ANDROID_SDK_ROOT"

      APK_PATH="\$1"
      if [ -z "\$APK_PATH" ]; then
        APK_PATH="\$(dirname "\$0")/Wawona.apk"
      fi

      if [ ! -f "\$APK_PATH" ]; then
        exit 1
      fi

      # Tools are provided via Nix runtimeInputs - they should be in PATH
      if ! command -v adb >/dev/null 2>&1; then
        exit 1
      fi

      if ! command -v emulator >/dev/null 2>&1; then
        exit 1
      fi

      # Set up AVD home in a user-writable directory (use local directory to avoid permission issues)
      export ANDROID_USER_HOME="\$(pwd)/.android_home"
      export ANDROID_AVD_HOME="\$ANDROID_USER_HOME/avd"
      mkdir -p "\$ANDROID_AVD_HOME"

      AVD_NAME="WawonaEmulator_API36"
      SYSTEM_IMAGE="system-images;android-36;google_apis_playstore;arm64-v8a"

      # Check if AVD exists
      if ! emulator -list-avds | grep -q "^\$AVD_NAME\$"; then
        
        if ! command -v avdmanager >/dev/null 2>&1; then
          exit 1
        fi
        
        # Create AVD
        echo "no" | avdmanager create avd -n "\$AVD_NAME" -k "\$SYSTEM_IMAGE" --device "pixel" --force
        
      fi

      # Check for running emulators
      # Ensure adb server is running
      adb start-server

      # Check for running emulators by processes
      EMULATOR_PROCESS=\$(pgrep -f "emulator.*\$AVD_NAME" | head -n 1)

      if [ -n "\$EMULATOR_PROCESS" ]; then
        sleep 2
        RUNNING_EMULATORS=\$(adb devices | grep -E "emulator-[0-9]+" | grep "device$" | wc -l | tr -d ' ')
        if [ "\$RUNNING_EMULATORS" -eq 0 ]; then
          if kill -0 "\$EMULATOR_PROCESS" 2>/dev/null; then
            sleep 3
            RUNNING_EMULATORS=\$(adb devices | grep -E "emulator-[0-9]+" | grep "device$" | wc -l | tr -d ' ')
          else
            EMULATOR_PROCESS=""
          fi
        fi
      else
        RUNNING_EMULATORS=\$(adb devices | grep -E "emulator-[0-9]+" | grep "device$" | wc -l | tr -d ' ')
      fi

      if [ "\$RUNNING_EMULATORS" -gt 0 ]; then
        EMULATOR_SERIAL=\$(adb devices | grep -E "emulator-[0-9]+" | grep "device$" | head -n 1 | awk '{print \$1}')
      else
        
        setsid nohup emulator -avd "\$AVD_NAME" -no-snapshot-load -gpu auto < /dev/null >>/tmp/emulator.log 2>&1 &
        
        sleep 3
        
        EMULATOR_PID=""
        for i in 1 2 3 4 5; do
          EMULATOR_PID=\$(pgrep -f "emulator.*\$AVD_NAME" | head -n 1)
          if [ -n "\$EMULATOR_PID" ]; then
            break
          fi
          sleep 1
        done
        
        if [ -z "\$EMULATOR_PID" ]; then
          echo "Warning: Could not find emulator PID"
        fi
        
        cleanup() {
          exit 0
        }
        trap cleanup SIGTERM SIGINT
        
        TIMEOUT=300
        ELAPSED=0
        BOOTED=false
        
        while [ \$ELAPSED -lt \$TIMEOUT ]; do
          if ! kill -0 \$EMULATOR_PID 2>/dev/null; then
             if ! adb devices | grep -E "emulator-[0-9]+" | grep -q "device$"; then
               cat /tmp/emulator.log
               exit 1
             fi
          fi

          if adb devices | grep -E "emulator-[0-9]+" | grep -q "device$"; then
            sleep 2
            BOOT_COMPLETE=\$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || echo "0")
            if [ "\$BOOT_COMPLETE" = "1" ]; then
              BOOTED=true
              break
            fi
          fi
          
          sleep 2
          ELAPSED=\$((ELAPSED + 2))
        done
        
        if [ "\$BOOTED" = "true" ]; then
          sleep 5
        else
          if adb devices | grep -E "emulator-[0-9]+" | grep -q "device$"; then
            BOOTED=true
          else
            cat /tmp/emulator.log
            exit 1
          fi
        fi
        
        trap - SIGTERM SIGINT
      fi

      graceful_exit() {
        echo ""
        echo "Script terminated. Emulator continues running in background."
        exit 0
      }
      trap graceful_exit SIGTERM SIGINT

      adb uninstall com.aspauldingcode.wawona || true

      adb logcat -c || true

      adb install -r "\$APK_PATH"

      echo "Launching Wawona app..."
      adb shell am start -n com.aspauldingcode.wawona/.MainActivity

      sleep 5

      echo "=== Recent crash logs ==="
      adb logcat -d -v time | grep -i -E "(wawona|androidruntime|fatal|exception|error.*3995)" | tail -200

      echo ""
      echo "=== Starting live logcat stream ==="
      adb logcat -v time -s Wawona:D WawonaJNI:D WawonaNative:D AndroidRuntime:E

      EOF
            chmod +x $out/bin/wawona-android-run
            
            runHook postInstall
    '';
  }
