//! XDG Activation protocol implementation.
//!
//! This protocol allows clients to request activation (focus) for a surface,
//! using activation tokens to prevent focus stealing.


use wayland_server::{
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New, Resource,
};
use wayland_protocols::xdg::activation::v1::server::{
    xdg_activation_v1::{self, XdgActivationV1},
    xdg_activation_token_v1::{self, XdgActivationTokenV1},
};

use crate::core::state::{CompositorState, ActivationTokenData};

// ============================================================================
// xdg_activation_v1
// ============================================================================

impl GlobalDispatch<XdgActivationV1, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<XdgActivationV1>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
        tracing::debug!("Bound xdg_activation_v1");
    }
}

impl Dispatch<XdgActivationV1, ()> for CompositorState {
    fn request(
        state: &mut Self,
        _client: &Client,
        _resource: &XdgActivationV1,
        request: xdg_activation_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            xdg_activation_v1::Request::GetActivationToken { id } => {
                let token_data = ActivationTokenData::default();
                let token = data_init.init(id, ());
                state.activation_tokens.insert(token.id().protocol_id(), token_data);
                
                tracing::debug!("Created activation token");
            }
            xdg_activation_v1::Request::Activate { token, surface } => {
                let surface_id = surface.id().protocol_id();
                tracing::debug!("Activate request for surface {} with token {}", surface_id, token);
                // TODO: Validate token and activate surface
            }
            xdg_activation_v1::Request::Destroy => {
                tracing::debug!("xdg_activation_v1 destroyed");
            }
            _ => {}
        }
    }
}

// ============================================================================
// xdg_activation_token_v1
// ============================================================================

impl Dispatch<XdgActivationTokenV1, ()> for CompositorState {
    fn request(
        state: &mut Self,
        _client: &Client,
        resource: &XdgActivationTokenV1,
        request: xdg_activation_token_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        let token_id = resource.id().protocol_id();
        
        match request {
            xdg_activation_token_v1::Request::SetSerial { serial, seat: _ } => {
                if let Some(data) = state.activation_tokens.get_mut(&token_id) {
                    data.serial = Some(serial);
                    tracing::debug!("Set serial {} for activation token", serial);
                }
            }
            xdg_activation_token_v1::Request::SetAppId { app_id } => {
                if let Some(data) = state.activation_tokens.get_mut(&token_id) {
                    data.app_id = Some(app_id.clone());
                    tracing::debug!("Set app_id {} for activation token", app_id);
                }
            }
            xdg_activation_token_v1::Request::SetSurface { surface } => {
                let surface_id = surface.id().protocol_id();
                if let Some(data) = state.activation_tokens.get_mut(&token_id) {
                    data.surface_id = Some(surface_id);
                    tracing::debug!("Set surface {} for activation token", surface_id);
                }
            }
            xdg_activation_token_v1::Request::Commit => {
                // Send the token back to the client
                if let Some(data) = state.activation_tokens.get(&token_id) {
                    resource.done(data.token.clone());
                    tracing::debug!("Committed activation token: {}", data.token);
                }
            }
            xdg_activation_token_v1::Request::Destroy => {
                state.activation_tokens.remove(&token_id);
                tracing::debug!("xdg_activation_token_v1 destroyed");
            }
            _ => {}
        }
    }
}

/// Register xdg_activation_v1 global
pub fn register_xdg_activation(display: &DisplayHandle) -> wayland_server::backend::GlobalId {
    display.create_global::<CompositorState, XdgActivationV1, ()>(1, ())
}
