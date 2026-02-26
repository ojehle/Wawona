# Android Icon Generator Contract

## Input
- **Source image**: `src/resources/Wawona.icon/Assets/wayland.png`
- Single PNG, shared with macOS/iOS icon composer

## Output Structure
All paths relative to Android `res/` directory.

### Adaptive icon XML (API 26+)
- `mipmap-anydpi-v26/ic_launcher.xml`
- `mipmap-anydpi-v26/ic_launcher_round.xml`

Both reference:
- `@drawable/ic_launcher_background`
- `@drawable/ic_launcher_foreground`
- `@drawable/ic_launcher_monochrome` (API 33+)

### Drawable assets (density-specific PNGs)
Per density: `drawable-{density}/ic_launcher_{background|foreground|monochrome}.png`

| Density | Scale | Size (px) |
|---------|-------|-----------|
| mdpi    | 1x    | 108×108   |
| hdpi    | 1.5x  | 162×162   |
| xhdpi   | 2x    | 216×216   |
| xxhdpi  | 3x    | 324×324   |
| xxxhdpi | 4x    | 432×432   |

### Legacy mipmap fallbacks (pre-API 26)
- `mipmap-mdpi/ic_launcher.png`, `ic_launcher_round.png`
- Same for hdpi, xhdpi, xxhdpi, xxxhdpi
- Full-bleed composite of foreground+background for older devices

## Layer semantics
- **Background**: Solid color or simple gradient; Wawona brand yellow (#E6B800 or derived from source).
- **Foreground**: Source image scaled to fit 108dp viewport, centered in safe zone (66dp).
- **Monochrome**: Silhouette of logo (alpha extracted, filled white) for system theming; system tints per user theme.

## Tooling
- ImageMagick (`convert`, `mogrify`) for resize, composite, alpha extraction.
- Cross-platform (Nix build on Linux/macOS).
