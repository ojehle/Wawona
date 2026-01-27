//! FIFO protocol implementation.
//!
//! This protocol allows clients to request FIFO (first-in-first-out)
//! buffer presentation ordering.

use wayland_server::{
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New, Resource,
};
use wayland_protocols::wp::fifo::v1::server::{
    wp_fifo_manager_v1::{self, WpFifoManagerV1},
    wp_fifo_v1::{self, WpFifoV1},
};

use crate::core::state::CompositorState;

// ============================================================================
// Data Types
// ============================================================================

#[derive(Debug, Clone, Default)]
pub struct FifoData {
    pub surface_id: u32,
}

// ============================================================================
// wp_fifo_manager_v1
// ============================================================================

impl GlobalDispatch<WpFifoManagerV1, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<WpFifoManagerV1>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
        tracing::debug!("Bound wp_fifo_manager_v1");
    }
}

impl Dispatch<WpFifoManagerV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &WpFifoManagerV1,
        request: wp_fifo_manager_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            wp_fifo_manager_v1::Request::GetFifo { id, surface } => {
                let surface_id = surface.id().protocol_id();
                // let data = FifoData { surface_id };
                let _fifo = data_init.init(id, ());
                tracing::debug!("Created FIFO for surface {}", surface_id);
            }
            wp_fifo_manager_v1::Request::Destroy => {
                tracing::debug!("wp_fifo_manager_v1 destroyed");
            }
            _ => {}
        }
    }
}

// ============================================================================
// wp_fifo_v1
// ============================================================================

impl Dispatch<WpFifoV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &WpFifoV1,
        request: wp_fifo_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            wp_fifo_v1::Request::SetBarrier => {
                tracing::debug!("Set FIFO barrier");
            }
            wp_fifo_v1::Request::WaitBarrier => {
                tracing::debug!("Wait FIFO barrier");
            }
            wp_fifo_v1::Request::Destroy => {
                tracing::debug!("wp_fifo_v1 destroyed");
            }
            _ => {}
        }
    }
}

/// Register wp_fifo_manager_v1 global
pub fn register_fifo(display: &DisplayHandle) -> wayland_server::backend::GlobalId {
    display.create_global::<CompositorState, WpFifoManagerV1, ()>(1, ())
}
