//! WP Relative Pointer protocol implementation.
//!
//! This protocol provides relative pointer motion events, essential for:
//! - First-person games and 3D applications
//! - CAD software with infinite panning
//! - Any application needing raw pointer motion


use wayland_server::{
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New, Resource,
};
use wayland_protocols::wp::relative_pointer::zv1::server::{
    zwp_relative_pointer_manager_v1::{self, ZwpRelativePointerManagerV1},
    zwp_relative_pointer_v1::{self, ZwpRelativePointerV1},
};


use crate::core::state::CompositorState;

// ============================================================================
// Data Types
// ============================================================================

/// Data stored with each relative pointer
#[derive(Debug, Clone)]
pub struct RelativePointerData {
    /// Associated wl_pointer
    pub pointer_id: u32,
}

impl RelativePointerData {
    pub fn new(pointer_id: u32) -> Self {
        Self { pointer_id }
    }
}

// ============================================================================
// zwp_relative_pointer_manager_v1
// ============================================================================

impl GlobalDispatch<ZwpRelativePointerManagerV1, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<ZwpRelativePointerManagerV1>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
        tracing::debug!("Bound zwp_relative_pointer_manager_v1");
    }
}

impl Dispatch<ZwpRelativePointerManagerV1, ()> for CompositorState {
    fn request(
        state: &mut Self,
        _client: &Client,
        _resource: &ZwpRelativePointerManagerV1,
        request: zwp_relative_pointer_manager_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            zwp_relative_pointer_manager_v1::Request::GetRelativePointer { id, pointer } => {
                let pointer_id = pointer.id().protocol_id();
                // let rel_pointer_data = RelativePointerData::new(pointer_id);
                let rel_pointer = data_init.init(id, ());
                let rel_id = rel_pointer.id().protocol_id();
                state.relative_pointers.insert(rel_id, pointer_id);
                
                tracing::debug!("Created relative pointer for pointer {}", pointer_id);
            }
            zwp_relative_pointer_manager_v1::Request::Destroy => {
                tracing::debug!("zwp_relative_pointer_manager_v1 destroyed");
            }
            _ => {}
        }
    }
}

// ============================================================================
// zwp_relative_pointer_v1
// ============================================================================

impl Dispatch<ZwpRelativePointerV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &ZwpRelativePointerV1,
        request: zwp_relative_pointer_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            zwp_relative_pointer_v1::Request::Destroy => {
                // state.relative_pointers.remove(&resource.id().protocol_id());
                tracing::debug!("zwp_relative_pointer_v1 destroyed");
            }
            _ => {}
        }
    }
}

/// Register zwp_relative_pointer_manager_v1 global
pub fn register_relative_pointer_manager(display: &DisplayHandle) -> wayland_server::backend::GlobalId {
    display.create_global::<CompositorState, ZwpRelativePointerManagerV1, ()>(1, ())
}

// Helper to send relative motion would go here
// The actual sending is done when the compositor has pointer motion to report
