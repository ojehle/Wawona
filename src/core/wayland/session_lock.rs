//! Session Lock protocol implementation.
//!
//! This protocol allows clients to lock the user session and display a lock screen.


use wayland_server::{
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New, Resource,
};
use wayland_protocols::ext::session_lock::v1::server::{
    ext_session_lock_manager_v1::{self, ExtSessionLockManagerV1},
    ext_session_lock_v1::{self, ExtSessionLockV1},
    ext_session_lock_surface_v1::{self, ExtSessionLockSurfaceV1},
};

use crate::core::state::CompositorState;

// ============================================================================
// Data Types
// ============================================================================

#[derive(Debug, Clone, Default)]
pub struct SessionLockData {
    pub locked: bool,
}

#[derive(Debug, Clone, Default)]
pub struct SessionLockSurfaceData {
    pub output_id: u32,
    pub surface_id: u32,
}

// ============================================================================
// ext_session_lock_manager_v1
// ============================================================================

impl GlobalDispatch<ExtSessionLockManagerV1, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<ExtSessionLockManagerV1>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
        tracing::debug!("Bound ext_session_lock_manager_v1");
    }
}

impl Dispatch<ExtSessionLockManagerV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &ExtSessionLockManagerV1,
        request: ext_session_lock_manager_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            ext_session_lock_manager_v1::Request::Lock { id } => {
                // let data = SessionLockData { locked: true };
                let lock = data_init.init(id, ());
                // Acknowledge the lock
                lock.locked();
                tracing::debug!("Session locked");
            }
            ext_session_lock_manager_v1::Request::Destroy => {
                tracing::debug!("ext_session_lock_manager_v1 destroyed");
            }
            _ => {}
        }
    }
}

// ============================================================================
// ext_session_lock_v1
// ============================================================================

impl Dispatch<ExtSessionLockV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &ExtSessionLockV1,
        request: ext_session_lock_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            ext_session_lock_v1::Request::GetLockSurface { id, surface, output } => {
                let output_id = output.id().protocol_id();
                let _surface_id = surface.id().protocol_id();
                // let data = SessionLockSurfaceData { output_id, surface_id };
                let _lock_surface = data_init.init(id, ());
                tracing::debug!("Created lock surface for output {}", output_id);
            }
            ext_session_lock_v1::Request::UnlockAndDestroy => {
                tracing::debug!("Session unlocked and lock destroyed");
            }
            ext_session_lock_v1::Request::Destroy => {
                tracing::debug!("ext_session_lock_v1 destroyed");
            }
            _ => {}
        }
    }
}

// ============================================================================
// ext_session_lock_surface_v1
// ============================================================================

impl Dispatch<ExtSessionLockSurfaceV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        resource: &ExtSessionLockSurfaceV1,
        request: ext_session_lock_surface_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            ext_session_lock_surface_v1::Request::AckConfigure { serial } => {
                tracing::debug!("Lock surface ack configure: serial={}", serial);
            }
            ext_session_lock_surface_v1::Request::Destroy => {
                tracing::debug!("ext_session_lock_surface_v1 destroyed");
            }
            _ => {}
        }
        let _ = resource;
    }
}

/// Register ext_session_lock_manager_v1 global
pub fn register_session_lock(display: &DisplayHandle) -> wayland_server::backend::GlobalId {
    display.create_global::<CompositorState, ExtSessionLockManagerV1, ()>(1, ())
}
