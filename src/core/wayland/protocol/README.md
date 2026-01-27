# Wayland Protocols for Wawona

This directory provides **re-exports** of Wayland protocol bindings from established Rust crates.

## Approach: Crate Re-exports (No Code Generation)

Instead of generating protocol code, we re-export from these pre-built crates:

| Crate | Version | Contents |
|-------|---------|----------|
| `wayland-server` | 0.31.11 | Core wayland protocol (wl_compositor, wl_surface, etc.) |
| `wayland-protocols` | 0.32.10 | Official extensions (wp, xdg, ext, xwayland) |
| `wayland-protocols-wlr` | 0.3.10 | wlroots extensions (layer_shell, screencopy, etc.) |
| `wayland-protocols-misc` | 0.3.10 | Misc protocols (virtual_keyboard, gtk_primary_selection) |

## Module Structure

```
protocol/
├── mod.rs         # Main re-exports (wayland_core, wp, xdg, ext, xwayland, misc)
└── wlroots/
    └── mod.rs     # wlroots protocol re-exports with legacy module aliases
```

## Why Crate Re-exports?

1. **No build-time generation** - Protocols are pre-generated in the crates
2. **Nix-compatible** - No gitignored files needed for builds
3. **Type-safe** - Dispatch trait implementations work correctly
4. **Automatic updates** - Just update crate versions to get new protocols

## Usage

Import protocols from this module:

```rust
// Core wayland
use crate::core::wayland::protocol::wayland_core::wl_surface;

// XDG shell
use crate::core::wayland::protocol::xdg::shell::server::xdg_toplevel;

// wlroots layer shell
use crate::core::wayland::protocol::wlroots::wlr_layer_shell_unstable_v1::zwlr_layer_shell_v1;
```

## Legacy Note

The `_GEN-*.rs` files from the old `wayland-protocol-gen` tool are no longer used. 
All protocol bindings now come from the crates listed above.