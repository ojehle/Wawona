//! Alpha Modifier protocol implementation.
//!
//! This protocol allows clients to specify how alpha should be multiplied
//! when compositing a surface.

use wayland_server::{
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New, Resource,
};
use wayland_protocols::wp::alpha_modifier::v1::server::{
    wp_alpha_modifier_v1::{self, WpAlphaModifierV1},
    wp_alpha_modifier_surface_v1::{self, WpAlphaModifierSurfaceV1},
};

use crate::core::state::CompositorState;

// ============================================================================
// Data Types
// ============================================================================

#[derive(Debug, Clone, Default)]
pub struct AlphaModifierSurfaceData {
    pub surface_id: u32,
    pub multiplier: u32, // Fixed-point 0..UINT32_MAX = 0.0..1.0
}

// ============================================================================
// wp_alpha_modifier_v1
// ============================================================================

impl GlobalDispatch<WpAlphaModifierV1, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<WpAlphaModifierV1>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
        tracing::debug!("Bound wp_alpha_modifier_v1");
    }
}

impl Dispatch<WpAlphaModifierV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &WpAlphaModifierV1,
        request: wp_alpha_modifier_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            wp_alpha_modifier_v1::Request::GetSurface { id, surface } => {
                let surface_id = surface.id().protocol_id();
                // let data = AlphaModifierSurfaceData {
                //     surface_id,
                //     multiplier: u32::MAX, // Default: 1.0 (no modification)
                // };
                let _am = data_init.init(id, ());
                tracing::debug!("Created alpha modifier for surface {}", surface_id);
            }
            wp_alpha_modifier_v1::Request::Destroy => {
                tracing::debug!("wp_alpha_modifier_v1 destroyed");
            }
            _ => {}
        }
    }
}

// ============================================================================
// wp_alpha_modifier_surface_v1
// ============================================================================

impl Dispatch<WpAlphaModifierSurfaceV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &WpAlphaModifierSurfaceV1,
        request: wp_alpha_modifier_surface_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            wp_alpha_modifier_surface_v1::Request::SetMultiplier { factor } => {
                let alpha = (factor as f64) / (u32::MAX as f64);
                tracing::debug!("Set alpha multiplier {} ({:.4}) for surface", 
                    factor, alpha);
            }
            wp_alpha_modifier_surface_v1::Request::Destroy => {
                tracing::debug!("wp_alpha_modifier_surface_v1 destroyed");
            }
            _ => {}
        }
    }
}

/// Register wp_alpha_modifier_v1 global
pub fn register_alpha_modifier(display: &DisplayHandle) -> wayland_server::backend::GlobalId {
    display.create_global::<CompositorState, WpAlphaModifierV1, ()>(1, ())
}
