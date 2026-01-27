
use wayland_server::{
    Dispatch, DisplayHandle, GlobalDispatch, Resource,
};

use crate::core::state::CompositorState;
use crate::core::wayland::wlroots::wlr_data_control_unstable_v1::{
    zwlr_data_control_manager_v1,
    zwlr_data_control_device_v1,
    zwlr_data_control_source_v1,
    zwlr_data_control_offer_v1,
};

pub struct DataControlManagerData;

impl GlobalDispatch<zwlr_data_control_manager_v1::ZwlrDataControlManagerV1, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &wayland_server::Client,
        resource: wayland_server::New<zwlr_data_control_manager_v1::ZwlrDataControlManagerV1>,
        _global_data: &(),
        data_init: &mut wayland_server::DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
    }
}

impl Dispatch<zwlr_data_control_manager_v1::ZwlrDataControlManagerV1, ()> for CompositorState {
    fn request(
        state: &mut Self,
        _client: &wayland_server::Client,
        _resource: &zwlr_data_control_manager_v1::ZwlrDataControlManagerV1,
        request: zwlr_data_control_manager_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut wayland_server::DataInit<'_, Self>,
    ) {
        match request {
            zwlr_data_control_manager_v1::Request::CreateDataSource { id } => {
                data_init.init(id, ());
            }
            zwlr_data_control_manager_v1::Request::GetDataDevice { id, seat: _ } => {
                let device = data_init.init(id, ());
                
                // Advertise current selection
                if let Some(_source) = &state.selection_source {
                    // In a full implementation, we would create a new offer and send it
                    // For now, we just acknowledge the existence if we had one
                    // dev.selection(Some(&offer));
                } else {
                    device.selection(None);
                }

                if device.version() >= 2 {
                    if let Some(_source) = &state.primary_selection_source {
                        // device.primary_selection(Some(&offer));
                    } else {
                        device.primary_selection(None);
                    }
                }
            }
            zwlr_data_control_manager_v1::Request::Destroy => {
                // Destructor
            }
            _ => {}
        }
    }
}

impl Dispatch<zwlr_data_control_device_v1::ZwlrDataControlDeviceV1, ()> for CompositorState {
    fn request(
        state: &mut Self,
        _client: &wayland_server::Client,
        _resource: &zwlr_data_control_device_v1::ZwlrDataControlDeviceV1,
        request: zwlr_data_control_device_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut wayland_server::DataInit<'_, Self>,
    ) {
        match request {
            zwlr_data_control_device_v1::Request::SetSelection { source } => {
                tracing::debug!("Global selection source updated");
                state.selection_source = source;
            }
            zwlr_data_control_device_v1::Request::SetPrimarySelection { source } => {
                tracing::debug!("Global primary selection source updated");
                state.primary_selection_source = source;
            }
            zwlr_data_control_device_v1::Request::Destroy => {
                // Destructor
            }
            _ => {}
        }
    }
}

impl Dispatch<zwlr_data_control_source_v1::ZwlrDataControlSourceV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &wayland_server::Client,
        _resource: &zwlr_data_control_source_v1::ZwlrDataControlSourceV1,
        request: zwlr_data_control_source_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut wayland_server::DataInit<'_, Self>,
    ) {
        match request {
            zwlr_data_control_source_v1::Request::Offer { mime_type: _ } => {
                // Track offered MIME types
            }
            zwlr_data_control_source_v1::Request::Destroy => {
                // Destructor
            }
            _ => {}
        }
    }
}

impl Dispatch<zwlr_data_control_offer_v1::ZwlrDataControlOfferV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &wayland_server::Client,
        _resource: &zwlr_data_control_offer_v1::ZwlrDataControlOfferV1,
        request: zwlr_data_control_offer_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut wayland_server::DataInit<'_, Self>,
    ) {
        match request {
            zwlr_data_control_offer_v1::Request::Receive { mime_type: _, fd: _ } => {
                // Negotiate transfer
            }
            zwlr_data_control_offer_v1::Request::Destroy => {
                // Destructor
            }
            _ => {}
        }
    }
}
