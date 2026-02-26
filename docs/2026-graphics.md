# Graphics Drivers & Validation

> Vulkan, OpenGL, Metal, and driver validation for Wawona on macOS, iOS, and Android.

---

## Quick Reference

| Platform | Native Vulkan? | Recommended |
|----------|----------------|-------------|
| **Android** | Yes | Vulkan native drivers + NDK/SDK |
| **macOS** | No | MoltenVK or KosmicKrisp (Vulkan → Metal) |
| **iOS** | No | MoltenVK or KosmicKrisp |
| **Linux** | Yes | Native Vulkan (Mesa or proprietary) |

---

## Driver Validation (CTS)

### Quick Start

```bash
# macOS: Full validation (smoke + Vulkan CTS + GL CTS)
nix run .#graphics-validate-macos

# Probe Vulkan driver only (fast, outputs JSON)
nix run .#graphics-smoke

# iOS: Vulkan CTS in simulator
nix run .#vulkan-cts-ios

# Android: Run on device/emulator (requires adb)
nix run .#vulkan-cts-android
nix run .#graphics-validate-android
```

### Flake Outputs

| Output | Platform | Description |
|--------|----------|-------------|
| `graphics-smoke` | macOS | Vulkan probe, JSON output |
| `graphics-validate-macos` | macOS | Smoke + Vulkan CTS + GL CTS |
| `graphics-validate-ios` | macOS host | Launches Vulkan CTS on iOS Simulator |
| `graphics-validate-android` | Any | Runs CTS on Android via adb |
| `vulkan-cts` | macOS | Khronos Vulkan CTS (deqp-vk) |
| `vulkan-cts-ios` | macOS | Vulkan CTS for iOS Simulator |
| `vulkan-cts-android` | Any | Vulkan CTS for Android |
| `gl-cts` | macOS | Khronos OpenGL/GLES CTS |
| `gl-cts-android` | Any | GL CTS for Android |

### Driver Selection

**macOS:** Override via `VK_DRIVER_FILES`:

```bash
# KosmicKrisp (default when available)
nix run .#graphics-smoke

# MoltenVK
VK_DRIVER_FILES=/path/to/MoltenVK_icd.json nix run .#graphics-smoke
```

**Android:** Configure in Wawona Settings (SwiftShader, Turnip, system).

### Test Manifests

- `dependencies/tests/vulkan-mustpass-smoke.txt`
- `dependencies/tests/gl-mustpass-smoke.txt`

### Artifacts

Results in `./graphics-validate-results/`:

- `driver-metadata-<timestamp>.json`
- `macos-<timestamp>.log`
- `vk-smoke-<timestamp>.qpa`
- `gl-smoke-<timestamp>.qpa`

### CI Check

```bash
nix build .#checks.aarch64-darwin.graphics-validate-smoke
```

---

## Driver Settings Design

### Settings Keys

| Platform | Key | Type | Default |
|----------|-----|------|---------|
| All | `VulkanDriver` | string | platform-specific |
| All | `OpenGLDriver` | string | platform-specific |

### Vulkan Driver Values

| Platform | Values | Default |
|----------|--------|---------|
| **Android** | `none`, `swiftshader`, `turnip`, `system` | `system` |
| **macOS** | `none`, `moltenvk`, `kosmickrisp` | `moltenvk` |
| **iOS** | `none`, `moltenvk`, `kosmickrisp` | `moltenvk` |

### OpenGL Driver Values

| Platform | Values | Default |
|----------|--------|---------|
| **Android** | `none`, `angle`, `system` | `system` |
| **macOS** | `none`, `angle`, `moltengl` | `angle` |
| **iOS** | `none`, `angle` | `angle` |

---

## iOS Static Drivers

All graphics drivers on iOS must be **static libraries** (`.a`). Dynamic libraries are not allowed.

| Driver | Purpose | Nix Path |
|--------|---------|----------|
| KosmicKrisp | Vulkan over Metal | `dependencies/libs/kosmickrisp/ios.nix` |
| MoltenVK | Vulkan over Metal | `dependencies/libs/moltenvk/ios.nix` |
| ANGLE | OpenGL ES over Metal | `dependencies/libs/angle/ios.nix` |

**Build strategy:** Mesa with `-Dvulkan-drivers=kosmickrisp` for KosmicKrisp; static linkage for MoltenVK and ANGLE.

**Integration:** Link exactly one Vulkan implementation at build time. Runtime switching would require separate app variants.

---

## Platform Drivers Overview

### Apple (macOS / iOS)

- **Metal** — native GPU API
- **MoltenVK** — Vulkan → Metal
- **KosmicKrisp** — Mesa-based Vulkan-on-Metal (experimental)

### Android

- **Mesa:** Freedreno (GLES), Turnip (Vulkan), Panfrost (Mali), PanVK (Mali)
- **Vendor:** Qualcomm Adreno, ARM Mali, PowerVR (proprietary)

### Linux / Wayland

- **Mesa:** RADV (AMD), ANV (Intel), NVK (NVIDIA)
- **Zink:** OpenGL over Vulkan
- **Compatibility:** DXVK, VKD3D-Proton

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "No Vulkan loader" | Ensure vulkan-loader in closure; use KosmicKrisp or MoltenVK on macOS |
| "deqp-vk not found" | Run `nix build .#vulkan-cts` first |
| iOS simulator not booting | Install iOS runtime via Xcode; `xcrun simctl list runtimes` |
| Android "device offline" | `adb kill-server && adb start-server` |
| GL CTS missing data | Ensure `--deqp-archive-dir` points to built archive |
| CTS build fails | Skip via `vulkanCtsAndroid = null` in flake.nix graphics-validate |

---

## See Also

- [drivers-how-to/](drivers-how-to/README.md) — architecture, platforms, MoltenVK/KosmicKrisp, Android Vulkan integration
