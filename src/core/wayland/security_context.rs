//! Security Context protocol implementation.
//!
//! Allows sandboxed clients to establish secure connections.

use wayland_server::{
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New,
};
use wayland_protocols::wp::security_context::v1::server::{
    wp_security_context_manager_v1::{self, WpSecurityContextManagerV1},
    wp_security_context_v1::{self, WpSecurityContextV1},
};

use crate::core::state::CompositorState;

#[derive(Debug, Clone, Default)]
pub struct SecurityContextData;

impl GlobalDispatch<WpSecurityContextManagerV1, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<WpSecurityContextManagerV1>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
        tracing::debug!("Bound wp_security_context_manager_v1");
    }
}

impl Dispatch<WpSecurityContextManagerV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &WpSecurityContextManagerV1,
        request: wp_security_context_manager_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            wp_security_context_manager_v1::Request::CreateListener { id, listen_fd: _, close_fd: _ } => {
                let _ctx = data_init.init(id, ());
                tracing::debug!("Created security context");
            }
            wp_security_context_manager_v1::Request::Destroy => {}
            _ => {}
        }
    }
}

impl Dispatch<WpSecurityContextV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &WpSecurityContextV1,
        request: wp_security_context_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            wp_security_context_v1::Request::SetSandboxEngine { .. } => {}
            wp_security_context_v1::Request::SetAppId { .. } => {}
            wp_security_context_v1::Request::SetInstanceId { .. } => {}
            wp_security_context_v1::Request::Commit => {}
            wp_security_context_v1::Request::Destroy => {}
            _ => {}
        }
    }
}

pub fn register_security_context(display: &DisplayHandle) -> wayland_server::backend::GlobalId {
    display.create_global::<CompositorState, WpSecurityContextManagerV1, ()>(1, ())
}
