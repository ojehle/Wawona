//! wlroots Protocol Re-exports
//!
//! This module re-exports wlroots protocol bindings from the wayland-protocols-wlr crate.
//! All server-side types are available for implementing Dispatch traits.
//!
//! wlroots protocols provide compatibility with Sway, Hyprland, river,
//! and other wlroots-based compositors.

// =============================================================================
// Core wlroots Protocols
// =============================================================================

/// zwlr_layer_shell_v1 - Layer shell for panels, wallpapers, overlays
pub mod wlr_layer_shell_unstable_v1 {
    pub use wayland_protocols_wlr::layer_shell::v1::server::*;
}

/// zwlr_output_management_v1 - Output configuration
pub mod wlr_output_management_unstable_v1 {
    pub use wayland_protocols_wlr::output_management::v1::server::*;
}

/// zwlr_output_power_management_v1 - Output power control (DPMS)
pub mod wlr_output_power_management_unstable_v1 {
    pub use wayland_protocols_wlr::output_power_management::v1::server::*;
}

/// zwlr_foreign_toplevel_management_v1 - Task bars, dock support
pub mod wlr_foreign_toplevel_management_unstable_v1 {
    pub use wayland_protocols_wlr::foreign_toplevel::v1::server::*;
}

/// zwlr_screencopy_v1 - Screen capture
pub mod wlr_screencopy_unstable_v1 {
    pub use wayland_protocols_wlr::screencopy::v1::server::*;
}

/// zwlr_gamma_control_v1 - Gamma/color temperature adjustment
pub mod wlr_gamma_control_unstable_v1 {
    pub use wayland_protocols_wlr::gamma_control::v1::server::*;
}

/// zwlr_data_control_v1 - Clipboard managers
pub mod wlr_data_control_unstable_v1 {
    pub use wayland_protocols_wlr::data_control::v1::server::*;
}

/// zwlr_export_dmabuf_v1 - Low-overhead screen capture
pub mod wlr_export_dmabuf_unstable_v1 {
    pub use wayland_protocols_wlr::export_dmabuf::v1::server::*;
}

/// zwlr_virtual_pointer_v1 - Virtual pointer devices
pub mod wlr_virtual_pointer_unstable_v1 {
    pub use wayland_protocols_wlr::virtual_pointer::v1::server::*;
}

/// zwlr_input_inhibitor_v1 - Input inhibitor for lock screens
pub mod wlr_input_inhibitor_unstable_v1 {
    pub use wayland_protocols_wlr::input_inhibitor::v1::server::*;
}

// =============================================================================
// From wayland-protocols-misc (virtual keyboard)
// =============================================================================

/// zwp_virtual_keyboard_v1 - Virtual keyboard input
pub mod zwp_virtual_keyboard_v1 {
    pub use wayland_protocols_misc::zwp_virtual_keyboard_v1::server::*;
}
