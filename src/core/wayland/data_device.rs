//! wl_data_device_manager and related protocols implementation
//!
//! The data device manager handles clipboard operations and drag-and-drop.
//! This is essential for:
//! - Copy/paste operations
//! - Drag-and-drop between applications
//! - MIME type negotiation


use wayland_server::{
    protocol::{
        wl_data_device::{self, WlDataDevice},
        wl_data_device_manager::{self, WlDataDeviceManager},
        wl_data_offer::{self, WlDataOffer},
        wl_data_source::{self, WlDataSource},

    },
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New, Resource,
};

use crate::core::state::{CompositorState, DataSourceData, DataDeviceData};

// ============================================================================
// wl_data_device_manager implementation
// ============================================================================

impl GlobalDispatch<WlDataDeviceManager, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<WlDataDeviceManager>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
    }
}

impl Dispatch<WlDataDeviceManager, ()> for CompositorState {
    fn request(
        state: &mut Self,
        _client: &Client,
        _resource: &WlDataDeviceManager,
        request: wl_data_device_manager::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            wl_data_device_manager::Request::CreateDataSource { id } => {
                let source_data = DataSourceData::new();
                let source = data_init.init(id, ());
                state.data_sources.insert(source.id().protocol_id(), source_data);
                
                tracing::debug!("Created data source");
            }
            wl_data_device_manager::Request::GetDataDevice { id, seat } => {
                let device_data = DataDeviceData { seat_id: seat.id().protocol_id() };
                let device = data_init.init(id, ());
                state.data_devices.insert(device.id().protocol_id(), device_data);
                
                tracing::debug!("Created data device for seat");
            }
            _ => {}
        }
    }
}

// ============================================================================
// wl_data_source implementation
// ============================================================================

impl Dispatch<WlDataSource, ()> for CompositorState {
    fn request(
        state: &mut Self,
        _client: &Client,
        resource: &WlDataSource,
        request: wl_data_source::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        let source_id = resource.id().protocol_id();
        
        match request {
            wl_data_source::Request::Offer { mime_type } => {
                tracing::debug!("Data source offers MIME type: {}", mime_type);
                if let Some(data) = state.data_sources.get_mut(&source_id) {
                    data.mime_types.push(mime_type);
                }
            }
            wl_data_source::Request::SetActions { dnd_actions } => {
                tracing::debug!("Data source set DnD actions: {:?}", dnd_actions);
                if let Some(data) = state.data_sources.get_mut(&source_id) {
                    data.dnd_actions = dnd_actions.into_result().unwrap_or(wayland_server::protocol::wl_data_device_manager::DndAction::empty());
                }
            }
            wl_data_source::Request::Destroy => {
                state.data_sources.remove(&source_id);
                tracing::debug!("Data source destroyed");
            }
            _ => {}
        }
    }
}

// ============================================================================
// wl_data_device implementation
// ============================================================================

impl Dispatch<WlDataDevice, ()> for CompositorState {
    fn request(
        state: &mut Self,
        _client: &Client,
        resource: &WlDataDevice,
        request: wl_data_device::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            wl_data_device::Request::StartDrag {
                source,
                origin,
                icon,
                serial,
            } => {
                tracing::debug!(
                    "Start drag: serial={}, has_source={}, has_icon={}",
                    serial,
                    source.is_some(),
                    icon.is_some()
                );
                
                state.start_drag(
                    source.as_ref().map(|s| s.id().protocol_id()),
                    origin.id().protocol_id(),
                    icon.as_ref().map(|i| i.id().protocol_id()),
                );
            }
            wl_data_device::Request::SetSelection { source, serial } => {
                tracing::debug!(
                    "Set selection (clipboard): serial={}, has_source={}",
                    serial,
                    source.is_some()
                );
                
                state.set_clipboard_source(source.as_ref().map(|s| s.id().protocol_id()));
            }
            wl_data_device::Request::Release => {
                state.data_devices.remove(&resource.id().protocol_id());
                tracing::debug!("Data device released");
            }
            _ => {}
        }
    }
}

// ============================================================================
// wl_data_offer implementation
// ============================================================================

impl Dispatch<WlDataOffer, ()> for CompositorState {
    fn request(
        state: &mut Self,
        _client: &Client,
        resource: &WlDataOffer,
        request: wl_data_offer::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            wl_data_offer::Request::Accept { serial, mime_type } => {
                tracing::debug!(
                    "Data offer accept: serial={}, mime_type={:?}",
                    serial,
                    mime_type
                );
            }
            wl_data_offer::Request::Receive { mime_type, fd } => {
                tracing::debug!("Data offer receive: mime_type={}", mime_type);
                // Implementation would forward to source
                drop(fd); 
            }
            wl_data_offer::Request::Destroy => {
                state.data_offers.remove(&resource.id().protocol_id());
                tracing::debug!("Data offer destroyed");
            }
            wl_data_offer::Request::Finish => {
                tracing::debug!("Data offer finished (DnD complete)");
            }
            wl_data_offer::Request::SetActions {
                dnd_actions,
                preferred_action,
            } => {
                tracing::debug!(
                    "Data offer set actions: {:?}, preferred: {:?}",
                    dnd_actions,
                    preferred_action
                );
            }
            _ => {}
        }
    }
}

/// Register wl_data_device_manager global
pub fn register_data_device_manager(display: &DisplayHandle) -> wayland_server::backend::GlobalId {
    display.create_global::<CompositorState, WlDataDeviceManager, ()>(3, ())
}
