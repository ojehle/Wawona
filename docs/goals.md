# Wawona Project Goals

Wawona aims to be **THE** Wayland compositor for macOS. It serves as the central hub for downstream patches and fixes for the entire Wayland ecosystem on macOS (including Wayland, Waypipe, and other core dependencies), with the ultimate goal of upstreaming these improvements.

## Vision

1.  **The Definitive macOS Wayland Experience**
    - Establish Wawona as the standard, "proper" Wayland compositor for macOS.
    - Foster mass adoption and build a collaborative open-source community.
    - Aspire for industry backing (Apple, Google, etc.) as the project matures.

2.  **Cross-Platform Stability**
    - Deliver a stable, mature Wayland compositor for **macOS, iOS, and Android** within the next 5 years.
    - Ensure a shared, maintainable codebase across all three platforms (C/Objective-C/Rust/JNI).

3.  **Modern & Forward-Looking**
    - **No X11 / XWayland Support**: Strictly focus on forward-moving applications adopting native Wayland protocols.
    - **Target Modern OS Versions**: Focus exclusively on **macOS 26+** and **iOS 26+**. Legacy support is not a priority.
    - **Clean Codebase**: Prioritize code cleanliness, readability, and maintainability. Avoid "vibecoded" hacks; strive for professional-grade engineering.

## Technical Objectives

### Build & Infrastructure
-   **Nix Build System**: Utilize Nix exclusively for hermetic, reproducible builds.
-   **Host Platform**: Compilation is supported **only on Apple Silicon macOS**. No support for Linux or x86_64 macOS hosts.
-   **Testing**: Validation on real hardware and simulators (iOS Simulator, Android Emulator).

### Graphics & Rendering
-   **Vulkan Compliance**: Strict adherence to Vulkan standards. No compromises for Metal-specific constraints (MoltenVK/MoltenGL details are implementation details, but the goal is Vulkan conformance).
-   **Future Android Support**: Bring support to Adreno/Freedreno/Turnip for supported Android chipsets.
-   **OpenGL/GLX**: Enable working OpenGL/GLX support moving forward.
-   **Zero-Copy**: Achieve near-zero-copy rendering for Waypipe clients to maximize performance and minimize CPU usage.

### Ecosystem & Features
-   **Full Protocol Support**: Support **ALL** Wayland protocols (Core, Wlroots, KDE, etc.) to ensure compatibility with a wide range of compositors and clients.
-   **Desktop Environments**: Enable support for major desktops and compositors:
    -   Sway
    -   Niri
    -   GNOME Desktop
    -   Plasma KDE
    -   Phosh
-   **Bundled Weston**: Bundle a natively compiled Weston as a nested compositor for macOS, iOS, and Android.
-   **Native Integration**: Deep integration into the macOS desktop environment.

### Deployment & Restrictions
-   **Zero Limitations**: The project prioritizes functionality over App Store restrictions. It will not be limited by App Store policies.
-   **Sandboxing**: Adopt platform sandboxing on iOS and Android where appropriate, but remain unencumbered on macOS.

## Community & Sustainability

-   **Collaborative Effort**: This project relies on the community. Contributions and donations are vital.
-   **Upstreaming**: Act as a staging ground for macOS/iOS patches to be upstreamed to their respective projects.
