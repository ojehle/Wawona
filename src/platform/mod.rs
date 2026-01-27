//! Platform Integration Module
//!
//! Wawona uses a **Rust backend + Native frontend** architecture.
//! Native frontends (macOS, iOS, Android) call into Rust via FFI.

pub mod api;

pub use api::Platform;
