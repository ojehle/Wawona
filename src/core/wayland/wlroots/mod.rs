//! wlroots Protocol Support
//!
//! This module provides re-exports from the `wawona-wlr-protocols` crate.
//! These protocols provide compatibility with Sway, Hyprland, and other
//! wlroots-based tools.

// Re-export protocol modules from the dedicated crate
pub use crate::core::wayland::protocol::wlroots::*;

// Protocol modules for categorization
// (Implementation of Dispatch traits will happen in these modules or in the compositor)
pub mod layer_shell;
pub use layer_shell::LayerSurfaceData;
pub mod output_management;
pub mod output_power_management;
pub mod foreign_toplevel_management;
pub mod screencopy;
pub mod gamma_control;
pub mod data_control;
pub mod export_dmabuf;
pub mod virtual_pointer;
pub mod virtual_keyboard;


