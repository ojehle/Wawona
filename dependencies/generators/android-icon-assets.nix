# Generates Android adaptive launcher icon assets from a single source PNG.
# Output: res/ directory structure (mipmap-*, drawable-*) ready to merge into Android res/.
# See android-icon-contract.md for the resource naming contract.

{ pkgs, lib, wawonaSrc ? null }:

let
  src = if wawonaSrc != null then wawonaSrc else (throw "android-icon-assets requires wawonaSrc");
  waylandPng = src + "/src/resources/Wawona.icon/Assets/wayland.png";
in
pkgs.stdenv.mkDerivation rec {
  pname = "wawona-android-icon-assets";
  version = "1.0";

  nativeBuildInputs = [ pkgs.imagemagick ];

  # Ensure source exists at eval time
  srcPath = waylandPng;

  dontUnpack = true;

  buildPhase = ''
    set -e
    SRC="$srcPath"
    if [ ! -f "$SRC" ]; then
      echo "ERROR: Source icon not found at $SRC"
      exit 1
    fi

    # Android density sizes (108dp base for adaptive layers)
    # mdpi=1x, hdpi=1.5x, xhdpi=2x, xxhdpi=3x, xxxhdpi=4x
    mkdir -p $out/res/mipmap-anydpi-v26
    for d in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
      mkdir -p $out/res/drawable-$d
      mkdir -p $out/res/mipmap-$d
    done

    # Background: solid Wawona yellow (#E6B800)
    for density in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
      case $density in
        mdpi)   size=108 ;;
        hdpi)   size=162 ;;
        xhdpi)  size=216 ;;
        xxhdpi) size=324 ;;
        xxxhdpi) size=432 ;;
      esac
      ${pkgs.imagemagick}/bin/convert -size ''${size}x''${size} xc:'#E6B800' "$out/res/drawable-$density/ic_launcher_background.png"
    done

    # Foreground: source image scaled to fit 108dp viewport
    for density in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
      case $density in
        mdpi)   size=108 ;;
        hdpi)   size=162 ;;
        xhdpi)  size=216 ;;
        xxhdpi) size=324 ;;
        xxxhdpi) size=432 ;;
      esac
      ${pkgs.imagemagick}/bin/convert "$SRC" -resize ''${size}x''${size} -background none -gravity center -extent ''${size}x''${size} "$out/res/drawable-$density/ic_launcher_foreground.png"
    done

    # Monochrome: white shape on transparent (system tints per theme)
    # Use source alpha as mask, fill with white
    for density in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
      case $density in
        mdpi)   size=108 ;;
        hdpi)   size=162 ;;
        xhdpi)  size=216 ;;
        xxhdpi) size=324 ;;
        xxxhdpi) size=432 ;;
      esac
      ${pkgs.imagemagick}/bin/convert "$SRC" -resize ''${size}x''${size} -background none -gravity center -extent ''${size}x''${size} \
        \( -clone 0 -fill white -colorize 100% \) \( -clone 0 -alpha extract \) -delete 0 \
        -compose copy-opacity -composite \
        "$out/res/drawable-$density/ic_launcher_monochrome.png"
    done

    # Legacy mipmap: full composite for pre-API-26
    for density in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
      case $density in
        mdpi)   size=48 ;;
        hdpi)   size=72 ;;
        xhdpi)  size=96 ;;
        xxhdpi) size=144 ;;
        xxxhdpi) size=192 ;;
      esac
      bg="$out/res/drawable-$density/ic_launcher_background.png"
      fg="$out/res/drawable-$density/ic_launcher_foreground.png"
      ${pkgs.imagemagick}/bin/convert "$bg" "$fg" -composite -resize ''${size}x''${size} "$out/res/mipmap-$density/ic_launcher.png"
      cp "$out/res/mipmap-$density/ic_launcher.png" "$out/res/mipmap-$density/ic_launcher_round.png"
    done

    # Adaptive icon XML (API 26+)
    cat > $out/res/mipmap-anydpi-v26/ic_launcher.xml <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
    <monochrome android:drawable="@drawable/ic_launcher_monochrome"/>
</adaptive-icon>
XML

    cp $out/res/mipmap-anydpi-v26/ic_launcher.xml $out/res/mipmap-anydpi-v26/ic_launcher_round.xml

    echo "Generated Android icon assets"
  '';
}
