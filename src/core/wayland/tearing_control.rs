//! Tearing Control protocol implementation.
//!
//! This protocol allows clients to indicate their preference for tearing
//! vs. vsync behavior during presentation.

use wayland_server::{
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New, Resource,
};
use wayland_protocols::wp::tearing_control::v1::server::{
    wp_tearing_control_manager_v1::{self, WpTearingControlManagerV1},
    wp_tearing_control_v1::{self, WpTearingControlV1},
};

use crate::core::state::CompositorState;

// ============================================================================
// Data Types
// ============================================================================

#[derive(Debug, Clone, Default)]
pub struct TearingControlData {
    pub surface_id: u32,
}

// ============================================================================
// wp_tearing_control_manager_v1
// ============================================================================

impl GlobalDispatch<WpTearingControlManagerV1, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<WpTearingControlManagerV1>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
        tracing::debug!("Bound wp_tearing_control_manager_v1");
    }
}

impl Dispatch<WpTearingControlManagerV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &WpTearingControlManagerV1,
        request: wp_tearing_control_manager_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            wp_tearing_control_manager_v1::Request::GetTearingControl { id, surface } => {
                let surface_id = surface.id().protocol_id();
                // let data = TearingControlData { surface_id };
                let _tc = data_init.init(id, ());
                tracing::debug!("Created tearing control for surface {}", surface_id);
            }
            wp_tearing_control_manager_v1::Request::Destroy => {
                tracing::debug!("wp_tearing_control_manager_v1 destroyed");
            }
            _ => {}
        }
    }
}

// ============================================================================
// wp_tearing_control_v1
// ============================================================================

impl Dispatch<WpTearingControlV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &WpTearingControlV1,
        request: wp_tearing_control_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            wp_tearing_control_v1::Request::SetPresentationHint { hint } => {
                tracing::debug!("Set presentation hint {:?} for surface", hint);
            }
            wp_tearing_control_v1::Request::Destroy => {
                tracing::debug!("wp_tearing_control_v1 destroyed");
            }
            _ => {}
        }
    }
}

/// Register wp_tearing_control_manager_v1 global
pub fn register_tearing_control(display: &DisplayHandle) -> wayland_server::backend::GlobalId {
    display.create_global::<CompositorState, WpTearingControlManagerV1, ()>(1, ())
}
