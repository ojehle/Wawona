//! Background Effect protocol implementation.
//!
//! Allows surfaces to request background blur effects.

use wayland_server::{
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New, Resource,
};
use wayland_protocols::ext::background_effect::v1::server::{
    ext_background_effect_manager_v1::{self, ExtBackgroundEffectManagerV1},
    ext_background_effect_surface_v1::{self, ExtBackgroundEffectSurfaceV1},
};

use crate::core::state::CompositorState;

#[derive(Debug, Clone, Default)]
pub struct BackgroundEffectSurfaceData {
    pub surface_id: u32,
}

impl GlobalDispatch<ExtBackgroundEffectManagerV1, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<ExtBackgroundEffectManagerV1>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
        tracing::debug!("Bound ext_background_effect_manager_v1");
    }
}

impl Dispatch<ExtBackgroundEffectManagerV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &ExtBackgroundEffectManagerV1,
        request: ext_background_effect_manager_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            ext_background_effect_manager_v1::Request::GetBackgroundEffect { id, surface } => {
                let surface_id = surface.id().protocol_id();
                // let _e = data_init.init(id, BackgroundEffectSurfaceData { surface_id });
                let _e = data_init.init(id, ());
                tracing::debug!("Created background effect for surface {}", surface_id);
            }
            ext_background_effect_manager_v1::Request::Destroy => {}
            _ => {}
        }
    }
}

impl Dispatch<ExtBackgroundEffectSurfaceV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &ExtBackgroundEffectSurfaceV1,
        request: ext_background_effect_surface_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            ext_background_effect_surface_v1::Request::SetBlurRegion { region: _ } => {
                tracing::debug!("Set blur region for surface {}", 0); // data.surface_id
            }
            ext_background_effect_surface_v1::Request::Destroy => {}
            _ => {}
        }
    }
}

pub fn register_background_effect(display: &DisplayHandle) -> wayland_server::backend::GlobalId {
    display.create_global::<CompositorState, ExtBackgroundEffectManagerV1, ()>(1, ())
}
