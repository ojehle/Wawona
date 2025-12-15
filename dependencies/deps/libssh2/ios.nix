{
  lib,
  pkgs,
  buildPackages,
  common,
  buildModule,
}:

let
  xcodeUtils = import ../../../utils/xcode-wrapper.nix { inherit lib pkgs; };
  # libssh2 source - fetch from GitHub
  # Use 1.11.1+ for mbedTLS 3.6.0 compatibility
  src = pkgs.fetchFromGitHub {
    owner = "libssh2";
    repo = "libssh2";
    rev = "libssh2-1.11.1";
    sha256 = "sha256-yz97oqqN+NJTDL/HPJe3niFynbR8QXHuuiKr+uuKJtw=";
  };
  # zlib is needed for libssh2
  zlib = buildModule.buildForIOS "zlib" { };
  # mbedtls is needed for crypto backend on iOS
  mbedtls = buildModule.buildForIOS "mbedtls" { };
in
pkgs.stdenv.mkDerivation {
  name = "libssh2-ios";
  inherit src;
  patches = [ ];
  nativeBuildInputs = with buildPackages; [
    autoconf
    automake
    libtool
    pkg-config
  ];
  buildInputs = [
    zlib
    mbedtls
  ];
  preConfigure = ''
    if [ -z "''${XCODE_APP:-}" ]; then
      XCODE_APP=$(${xcodeUtils.findXcodeScript}/bin/find-xcode || true)
      if [ -n "$XCODE_APP" ]; then
        export XCODE_APP
        export DEVELOPER_DIR="$XCODE_APP/Contents/Developer"
        export PATH="$DEVELOPER_DIR/usr/bin:$PATH"
        export SDKROOT="$DEVELOPER_DIR/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk"
      fi
    fi
    export NIX_CFLAGS_COMPILE=""
    export NIX_CXXFLAGS_COMPILE=""
    if [ -n "''${SDKROOT:-}" ] && [ -d "$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin" ]; then
      IOS_CC="$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"
      IOS_CXX="$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang++"
    else
      IOS_CC="${buildPackages.clang}/bin/clang"
      IOS_CXX="${buildPackages.clang}/bin/clang++"
    fi
    
    # libssh2 uses autotools, need to run buildconf first
    # Check if configure script exists, if not run buildconf
    if [ ! -f configure ]; then
      if [ -f buildconf ]; then
        ./buildconf
      elif [ -f buildconf.sh ]; then
        ./buildconf.sh
      elif [ -f autogen.sh ]; then
        ./autogen.sh
      else
        # Try to generate configure script
        autoreconf -fi || true
      fi
    fi
  '';
  configurePhase = ''
    runHook preConfigure
    export CC="$IOS_CC"
    export CXX="$IOS_CXX"
    export CFLAGS="-arch arm64 -isysroot $SDKROOT -mios-simulator-version-min=15.0 -fPIC -I${zlib}/include -I${mbedtls}/include"
    export CXXFLAGS="-arch arm64 -isysroot $SDKROOT -mios-simulator-version-min=15.0 -fPIC -I${zlib}/include -I${mbedtls}/include"
    export LDFLAGS="-arch arm64 -isysroot $SDKROOT -mios-simulator-version-min=15.0 -L${zlib}/lib -L${mbedtls}/lib"
    export PKG_CONFIG_PATH="${zlib}/lib/pkgconfig:${mbedtls}/lib/pkgconfig:$PKG_CONFIG_PATH"
    
    # Configure libssh2 with mbedtls crypto backend
    # mbedtls is lightweight and well-suited for iOS/mobile
    ./configure \
      --prefix=$out \
      --host=arm64-apple-ios \
      --enable-static \
      --disable-shared \
      --with-crypto=mbedtls \
      --with-libz \
      --with-libz-prefix=${zlib} \
      --with-libmbedcrypto-prefix=${mbedtls} \
      --disable-examples-build \
      --disable-tests
    runHook postConfigure
  '';
  buildPhase = ''
    runHook preBuild
    make
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    make install
    runHook postInstall
  '';
}
