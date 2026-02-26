# Wawona Project Goals

Wawona aims to be **the** Wayland compositor for macOS, iOS, and Android. It serves as a central hub for downstream patches and fixes for the Wayland ecosystem on Apple platforms, with the goal of upstreaming improvements.

## Vision

1. **The Definitive macOS Wayland Experience**
   - Establish Wawona as the standard Wayland compositor for macOS
   - Foster adoption and build a collaborative open-source community

2. **Cross-Platform Stability**
   - Deliver a stable Wayland compositor for **macOS, iOS, and Android**
   - Shared, maintainable codebase (Rust core + native frontends)

3. **Modern & Forward-Looking**
   - **No X11 / XWayland**: Focus on native Wayland protocols
   - **Target modern OS versions**: macOS 26+, iOS 26+
   - Clean, professional-grade codebase

## Technical Objectives

- **Nix Build System**: Hermetic, reproducible builds
- **Host Platform**: Apple Silicon macOS only
- **Full Protocol Support**: Core, XDG, wlroots, KDE protocols
- **Zero-Copy**: IOSurface on Apple; efficient buffer paths
- **Waypipe**: Remote Wayland apps over SSH on all platforms

## Community

Contributions and donations are vital. Wawona acts as a staging ground for macOS/iOS patches to be upstreamed.
