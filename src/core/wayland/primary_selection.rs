//! Primary Selection protocol implementation.
//!
//! This protocol provides primary selection (middle-click paste) functionality,
//! commonly used in X11 applications.


use wayland_server::{
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New, Resource,
};
use wayland_protocols::wp::primary_selection::zv1::server::{
    zwp_primary_selection_device_manager_v1::{self, ZwpPrimarySelectionDeviceManagerV1},
    zwp_primary_selection_device_v1::{self, ZwpPrimarySelectionDeviceV1},
    zwp_primary_selection_source_v1::{self, ZwpPrimarySelectionSourceV1},
    zwp_primary_selection_offer_v1::{self, ZwpPrimarySelectionOfferV1},
};

use crate::core::state::CompositorState;

// ============================================================================
// Data Types
// ============================================================================

#[derive(Debug, Clone, Default)]
pub struct PrimarySelectionDeviceData {
    pub seat_id: u32,
}

#[derive(Debug, Clone, Default)]
pub struct PrimarySelectionSourceData {
    pub mime_types: Vec<String>,
}

#[derive(Debug, Clone, Default)]
pub struct PrimarySelectionOfferData {
    pub source_id: u32,
}

// ============================================================================
// zwp_primary_selection_device_manager_v1
// ============================================================================

impl GlobalDispatch<ZwpPrimarySelectionDeviceManagerV1, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<ZwpPrimarySelectionDeviceManagerV1>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
        tracing::debug!("Bound zwp_primary_selection_device_manager_v1");
    }
}

impl Dispatch<ZwpPrimarySelectionDeviceManagerV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &ZwpPrimarySelectionDeviceManagerV1,
        request: zwp_primary_selection_device_manager_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            zwp_primary_selection_device_manager_v1::Request::CreateSource { id } => {
                // let data = PrimarySelectionSourceData::default();
                let _source = data_init.init(id, ());
                tracing::debug!("Created primary selection source");
            }
            zwp_primary_selection_device_manager_v1::Request::GetDevice { id, seat } => {
                let seat_id = seat.id().protocol_id();
                // let data = PrimarySelectionDeviceData { seat_id };
                let _device = data_init.init(id, ());
                tracing::debug!("Created primary selection device for seat {}", seat_id);
            }
            zwp_primary_selection_device_manager_v1::Request::Destroy => {
                tracing::debug!("zwp_primary_selection_device_manager_v1 destroyed");
            }
            _ => {}
        }
    }
}

// ============================================================================
// zwp_primary_selection_device_v1
// ============================================================================

impl Dispatch<ZwpPrimarySelectionDeviceV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &ZwpPrimarySelectionDeviceV1,
        request: zwp_primary_selection_device_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            zwp_primary_selection_device_v1::Request::SetSelection { source, serial } => {
                tracing::debug!("Set primary selection: serial={}", serial);
                let _ = source;
            }
            zwp_primary_selection_device_v1::Request::Destroy => {
                tracing::debug!("zwp_primary_selection_device_v1 destroyed");
            }
            _ => {}
        }
    }
}

// ============================================================================
// zwp_primary_selection_source_v1
// ============================================================================

impl Dispatch<ZwpPrimarySelectionSourceV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &ZwpPrimarySelectionSourceV1,
        request: zwp_primary_selection_source_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            zwp_primary_selection_source_v1::Request::Offer { mime_type } => {
                tracing::debug!("Primary selection source offer: {}", mime_type);
            }
            zwp_primary_selection_source_v1::Request::Destroy => {
                tracing::debug!("zwp_primary_selection_source_v1 destroyed");
            }
            _ => {}
        }
    }
}

// ============================================================================
// zwp_primary_selection_offer_v1
// ============================================================================

impl Dispatch<ZwpPrimarySelectionOfferV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &ZwpPrimarySelectionOfferV1,
        request: zwp_primary_selection_offer_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            zwp_primary_selection_offer_v1::Request::Receive { mime_type, fd } => {
                tracing::debug!("Primary selection receive: {}", mime_type);
                let _ = fd;
            }
            zwp_primary_selection_offer_v1::Request::Destroy => {
                tracing::debug!("zwp_primary_selection_offer_v1 destroyed");
            }
            _ => {}
        }
    }
}

/// Register zwp_primary_selection_device_manager_v1 global
pub fn register_primary_selection(display: &DisplayHandle) -> wayland_server::backend::GlobalId {
    display.create_global::<CompositorState, ZwpPrimarySelectionDeviceManagerV1, ()>(1, ())
}
