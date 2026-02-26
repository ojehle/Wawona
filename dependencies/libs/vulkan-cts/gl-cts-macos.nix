# OpenGL/GLES CTS for macOS (builds glcts + cts-runner from VK-GL-CTS)
{
  lib,
  pkgs,
}:

let
  common = import ./common.nix { inherit pkgs; };
in
pkgs.stdenv.mkDerivation (finalAttrs: {
  pname = "gl-cts-macos";
  version = common.version;

  src = common.src;

  prePatch = common.prePatch;

  nativeBuildInputs = with pkgs; [
    cmake
    ninja
    pkg-config
    python3
    makeWrapper
  ];

  buildInputs = with pkgs; [
    libffi
    libpng
    zlib
    apple-sdk_26
  ];

  cmakeFlags = [
    "-DCMAKE_INSTALL_BINDIR=bin"
    "-DCMAKE_INSTALL_LIBDIR=lib"
    "-DCMAKE_INSTALL_INCLUDEDIR=include"
    "-DDEQP_TARGET=osx"
    "-DSELECTED_BUILD_TARGETS=${common.glTargets}"
    (lib.cmakeFeature "DGLSLANG_INSTALL_DIR" "${pkgs.glslang}")
    (lib.cmakeFeature "DSPIRV_HEADERS_INSTALL_DIR" "${pkgs.spirv-headers}")
    (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_SHADERC" "${common.sources.shaderc-src}")
  ];

  postInstall = ''
    mkdir -p $out/bin $out/archive-dir
    [ -f external/openglcts/modules/glcts ] && cp -a external/openglcts/modules/glcts $out/bin/ || true
    [ -f external/openglcts/modules/cts-runner ] && cp -a external/openglcts/modules/cts-runner $out/bin/ || true
    for d in gl_cts gles2 gles3 gles31; do
      [ -d external/openglcts/modules/$d ] && cp -a external/openglcts/modules/$d $out/archive-dir/ || true
    done
  '';

  meta = {
    description = "Khronos OpenGL/GLES Conformance Tests (macOS)";
    homepage = "https://github.com/KhronosGroup/VK-GL-CTS";
    license = lib.licenses.asl20;
    platforms = lib.platforms.darwin;
  };
})
