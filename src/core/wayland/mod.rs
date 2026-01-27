//! Wayland protocol implementations for Wawona Compositor.
//!
//! This module contains all Wayland protocol dispatch implementations.
//! Protocols are organized by category and registered in `compositor.rs`.
//!
//! Total: 57 protocols from wayland-protocols 1.45

// Core protocol implementations
pub mod display;
pub mod registry;
pub mod compositor;
pub mod xdg_wm_base;
pub mod xdg_surface;
pub mod xdg_toplevel;
pub mod xdg_popup;
pub mod xdg_positioner;
pub mod seat;
pub mod output;

// Common protocols
pub mod subcompositor;
pub mod data_device;
pub mod decoration;
pub mod xdg_output;
pub mod xdg_foreign;
pub mod xdg_activation;

// Buffer & synchronization
pub mod viewporter;
pub mod linux_dmabuf;
pub mod linux_explicit_sync;
pub mod single_pixel_buffer;
pub mod linux_drm_syncobj;
pub mod drm_lease;

// Input protocols
pub mod relative_pointer;
pub mod pointer_constraints;
pub mod pointer_gestures;
pub mod tablet;
pub mod text_input;
pub mod keyboard_shortcuts_inhibit;
pub mod cursor_shape;
pub mod primary_selection;
pub mod input_method;
pub mod input_timestamps;
pub mod pointer_warp;

// Presentation & timing
pub mod presentation_time;
pub mod fractional_scale;
pub mod fifo;
pub mod tearing_control;
pub mod content_type;
pub mod commit_timing;
pub mod alpha_modifier;
pub mod color_management;
pub mod color_representation;

// Session & security
pub mod idle_inhibit;
pub mod session_lock;
pub mod idle_notify;
pub mod security_context;
pub mod transient_seat;

// Window extensions
pub mod xdg_dialog;
pub mod xdg_toplevel_drag;
pub mod xdg_toplevel_icon;
pub mod xdg_toplevel_tag;
pub mod xdg_system_bell;
pub mod fullscreen_shell;
pub mod foreign_toplevel_list;

// Desktop integration
pub mod data_control;
pub mod workspace;
pub mod background_effect;

// Screen capture
pub mod image_capture_source;
pub mod image_copy_capture;

// XWayland
pub mod xwayland_keyboard_grab;
pub mod xwayland_shell;

// Auto-generated protocol re-exports (57 protocols from wayland-protocols 1.45)
pub mod protocol;

// wlroots protocols (10 protocols for ecosystem compatibility)
// XMLs are fetched via Nix: `nix run .#gen-protocols`
// Implementation requires dedicated crate with proper interface generation.
// See: protocols/wlroots/*.xml
pub mod wlroots;

