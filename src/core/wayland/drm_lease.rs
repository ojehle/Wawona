//! DRM Lease protocol implementation.
//!
//! Allows clients to lease DRM resources for VR/AR displays.

use wayland_server::{
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New,
};
use wayland_protocols::wp::drm_lease::v1::server::{
    wp_drm_lease_device_v1::{self, WpDrmLeaseDeviceV1},
    wp_drm_lease_connector_v1::{self, WpDrmLeaseConnectorV1},
    wp_drm_lease_request_v1::{self, WpDrmLeaseRequestV1},
    wp_drm_lease_v1::{self, WpDrmLeaseV1},
};

use crate::core::state::CompositorState;

#[derive(Debug, Clone, Default)]
pub struct LeaseConnectorData {
    pub connector_id: u32,
}

#[derive(Debug, Clone, Default)]
pub struct LeaseRequestData;

#[derive(Debug, Clone, Default)]
pub struct LeaseData;

impl GlobalDispatch<WpDrmLeaseDeviceV1, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<WpDrmLeaseDeviceV1>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
        tracing::debug!("Bound wp_drm_lease_device_v1");
    }
}

impl Dispatch<WpDrmLeaseDeviceV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &WpDrmLeaseDeviceV1,
        request: wp_drm_lease_device_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            wp_drm_lease_device_v1::Request::CreateLeaseRequest { id } => {
                // let _r = data_init.init(id, LeaseRequestData);
                let _r = data_init.init(id, ());
                tracing::debug!("Created lease request");
            }
            wp_drm_lease_device_v1::Request::Release => {}
            _ => {}
        }
    }
}

impl Dispatch<WpDrmLeaseConnectorV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &WpDrmLeaseConnectorV1,
        request: wp_drm_lease_connector_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            wp_drm_lease_connector_v1::Request::Destroy => {}
            _ => {}
        }
    }
}

impl Dispatch<WpDrmLeaseRequestV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &WpDrmLeaseRequestV1,
        request: wp_drm_lease_request_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            wp_drm_lease_request_v1::Request::RequestConnector { .. } => {}
            wp_drm_lease_request_v1::Request::Submit { id } => {
                // let _l = data_init.init(id, LeaseData);
                let _l = data_init.init(id, ());
            }
            _ => {}
        }
    }
}

impl Dispatch<WpDrmLeaseV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &WpDrmLeaseV1,
        request: wp_drm_lease_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            wp_drm_lease_v1::Request::Destroy => {}
            _ => {}
        }
    }
}

pub fn register_drm_lease(display: &DisplayHandle) -> wayland_server::backend::GlobalId {
    display.create_global::<CompositorState, WpDrmLeaseDeviceV1, ()>(1, ())
}
