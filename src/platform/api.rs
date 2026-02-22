//! Platform API Trait
//!
//! This trait defines what a platform adapter must implement.
//! However, since frontends are native code, this trait is primarily
//! for documentation purposes and potential future Rust-based testing.

use anyhow::Result;

/// Platform adapter interface.
///
/// Native frontends implement this interface in their native language
/// by calling the corresponding FFI functions in `src/ffi/api.rs`.
///
/// # Native Implementation Guide
///
/// ## Lifecycle
/// - `initialize()` → Call `wawona_compositor_new()` and `wawona_compositor_start()`
/// - `run()` → Start native event loop, poll Rust for events
/// - `shutdown()` → Call `wawona_compositor_stop()`
///
/// ## Event Loop (in native runloop)
/// 1. Translate native input events → call `inject_pointer_motion()`, `inject_key()`, etc.
/// 2. Call `process_events()` to let Rust handle Wayland clients
/// 3. Call `get_render_scene()` to get drawable scene
/// 4. Render scene using native GPU API (Metal/Vulkan/Canvas)
/// 5. Call `notify_frame_complete()`
///
/// ## Window Management
/// - When Rust requests a window → native code creates NSWindow/UIWindow/Activity
/// - Native code owns window lifecycle, Rust tracks logical state
pub trait Platform {
    /// Initialize the platform adapter.
    ///
    /// Native impl: Create compositor instance, set up callbacks.
    fn initialize(&mut self) -> Result<()>;

    /// Run the platform event loop.
    ///
    /// Native impl: Start NSApplication.run() / UIApplication.main() / Activity lifecycle.
    fn run(&mut self) -> Result<()>;
}

/// Stub implementation for testing.
pub struct StubPlatform;

impl Platform for StubPlatform {
    fn initialize(&mut self) -> Result<()> {
        tracing::info!("StubPlatform initialized (no-op)");
        Ok(())
    }

    fn run(&mut self) -> Result<()> {
        tracing::info!("StubPlatform run (blocking)");
        loop {
            std::thread::sleep(std::time::Duration::from_millis(100));
        }
    }
}
