# Graphics validation orchestrator - runs Vulkan/GL CTS with manifests, retries, artifact capture
{
  lib,
  pkgs,
  vulkanCts ? null,
  glCts ? null,
  vulkanCtsAndroid ? null,
  glCtsAndroid ? null,
  vulkanCtsIos ? null,
  graphicsSmoke ? null,
}:

let
  vulkanSmokeList = ./vulkan-mustpass-smoke.txt;
  glSmokeList = ./gl-mustpass-smoke.txt;
  vkCts = if vulkanCts != null then vulkanCts else "/dev/null";
  glCtsPath = if glCts != null then glCts else "/dev/null";
  graphicsSmokeBin = if graphicsSmoke != null then graphicsSmoke else "/dev/null";
  vkAndroid = if vulkanCtsAndroid != null then vulkanCtsAndroid else "/dev/null";
  glAndroid = if glCtsAndroid != null then glCtsAndroid else "/dev/null";
  vkIos = if vulkanCtsIos != null then vulkanCtsIos else "/dev/null";

  dataDir = pkgs.runCommand "graphics-validate-data" {} ''
    mkdir -p $out/share/graphics-validate
    cp ${vulkanSmokeList} $out/share/graphics-validate/vulkan-mustpass-smoke.txt
    cp ${glSmokeList} $out/share/graphics-validate/gl-mustpass-smoke.txt
  '';

  graphics-validate-macos = pkgs.writeShellScriptBin "graphics-validate-macos" ''
    set -euo pipefail
    # Override driver: VK_DRIVER_FILES=/path/to/icd.json graphics-validate-macos
    DATA_DIR="${dataDir}"
    OUT_DIR="''${GRAPHICS_VALIDATE_OUT:-$PWD/graphics-validate-results}"
    MODE="''${1:-smoke}"
    mkdir -p "$OUT_DIR"
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    LOG="$OUT_DIR/macos-$TIMESTAMP.log"
    echo "=== Graphics Validation (macOS) ===" | tee "$LOG"
    echo "Mode: $MODE | Out: $OUT_DIR" | tee -a "$LOG"

    run_vk() {
      local vk="$1"
      local retries=2
      for i in $(seq 0 $retries); do
        if [ -x "$vk/bin/deqp-vk" ]; then
          echo "Running Vulkan CTS (attempt $((i+1))/$((retries+1)))..." | tee -a "$LOG"
          if [ "$MODE" = "full" ]; then
            "$vk/bin/deqp-vk" --deqp-archive-dir="$vk/archive-dir" --deqp-log-filename="$OUT_DIR/vk-full-$TIMESTAMP.qpa" --deqp-log-images=disable 2>&1 | tee -a "$LOG" || true
          else
            "$vk/bin/deqp-vk" --deqp-archive-dir="$vk/archive-dir" --deqp-caselist-file="$DATA_DIR/share/graphics-validate/vulkan-mustpass-smoke.txt" --deqp-log-filename="$OUT_DIR/vk-smoke-$TIMESTAMP.qpa" --deqp-log-images=disable 2>&1 | tee -a "$LOG" || true
          fi
          break
        fi
      done
    }

    run_gl() {
      local gl="$1"
      if [ -x "$gl/bin/glcts" ]; then
        echo "Running GL CTS..." | tee -a "$LOG"
        "$gl/bin/glcts" --deqp-archive-dir="$gl/archive-dir" --deqp-caselist-file="$DATA_DIR/share/graphics-validate/gl-mustpass-smoke.txt" --deqp-log-filename="$OUT_DIR/gl-smoke-$TIMESTAMP.qpa" --deqp-log-images=disable 2>&1 | tee -a "$LOG" || true
      elif [ -x "$gl/bin/cts-runner" ]; then
        "$gl/bin/cts-runner" --deqp-archive-dir="$gl/archive-dir" 2>&1 | tee -a "$LOG" || true
      fi
    }

    # Run Wawona graphics smoke first (driver metadata for artifact capture)
    if [ -x "${graphicsSmokeBin}/bin/graphics-smoke" ]; then
      echo "Running graphics-smoke (driver probe)..." | tee -a "$LOG"
      "${graphicsSmokeBin}/bin/graphics-smoke" 2>&1 | tee -a "$LOG" | tee "$OUT_DIR/driver-metadata-$TIMESTAMP.json" || true
    fi

    run_vk "${vkCts}"
    run_gl "${glCtsPath}"

    echo "Results in $OUT_DIR" | tee -a "$LOG"
  '';

  graphics-validate-android = pkgs.writeShellScriptBin "graphics-validate-android" ''
    set -euo pipefail
    OUT_DIR="''${GRAPHICS_VALIDATE_OUT:-$PWD/graphics-validate-results}"
    MODE="''${1:-smoke}"
    mkdir -p "$OUT_DIR"
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    LOG="$OUT_DIR/android-$TIMESTAMP.log"
    echo "=== Graphics Validation (Android) ===" | tee "$LOG"

    if [ -x "${vkAndroid}/bin/vulkan-cts-android-run" ]; then
      echo "Running Vulkan CTS on device..." | tee -a "$LOG"
      "${vkAndroid}/bin/vulkan-cts-android-run" 2>&1 | tee -a "$LOG" || true
    fi

    if [ -x "${glAndroid}/bin/gl-cts-android-run" ]; then
      echo "Running GL CTS on device..." | tee -a "$LOG"
      "${glAndroid}/bin/gl-cts-android-run" 2>&1 | tee -a "$LOG" || true
    fi

    echo "Results in $OUT_DIR" | tee -a "$LOG"
  '';

  graphics-validate-ios = pkgs.writeShellScriptBin "graphics-validate-ios" ''
    set -euo pipefail
    OUT_DIR="''${GRAPHICS_VALIDATE_OUT:-$PWD/graphics-validate-results}"
    mkdir -p "$OUT_DIR"
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    LOG="$OUT_DIR/ios-$TIMESTAMP.log"
    echo "=== Graphics Validation (iOS) ===" | tee "$LOG"

    if [ -x "${vkIos}/bin/vulkan-cts-ios-run" ]; then
      echo "Launching Vulkan CTS on iOS Simulator..." | tee -a "$LOG"
      "${vkIos}/bin/vulkan-cts-ios-run" 2>&1 | tee -a "$LOG" || true
    fi

    echo "Results in $OUT_DIR" | tee -a "$LOG"
  '';

  graphics-validate-all = pkgs.writeShellScriptBin "graphics-validate-all" ''
    set -euo pipefail
    echo "=== Graphics Validation (All Platforms) ==="
    if [[ "$(uname -s)" == "Darwin" ]]; then
      ${graphics-validate-macos}/bin/graphics-validate-macos "''${1:-smoke}"
      ${graphics-validate-ios}/bin/graphics-validate-ios
    fi
    if command -v adb >/dev/null 2>&1 && adb devices | grep -q "device$"; then
      ${graphics-validate-android}/bin/graphics-validate-android "''${1:-smoke}"
    fi
  '';
in
pkgs.symlinkJoin {
  name = "graphics-validate";
  paths = [
    graphics-validate-macos
    graphics-validate-android
    graphics-validate-ios
    graphics-validate-all
    dataDir
  ];
  meta = {
    description = "Graphics driver validation orchestrator (Vulkan/GL CTS)";
    license = lib.licenses.mit;
  };
}
