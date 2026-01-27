//! Content Type protocol implementation.
//!
//! This protocol allows clients to hint the compositor about the content type
//! of a surface (e.g., video, game, photo), enabling compositor optimizations.

use wayland_server::{
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New, Resource,
};
use wayland_protocols::wp::content_type::v1::server::{
    wp_content_type_manager_v1::{self, WpContentTypeManagerV1},
    wp_content_type_v1::{self, WpContentTypeV1},
};

use crate::core::state::CompositorState;

// ============================================================================
// Data Types
// ============================================================================

#[derive(Debug, Clone, Default)]
pub struct ContentTypeData {
    pub surface_id: u32,
}

// ============================================================================
// wp_content_type_manager_v1
// ============================================================================

impl GlobalDispatch<WpContentTypeManagerV1, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<WpContentTypeManagerV1>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
        tracing::debug!("Bound wp_content_type_manager_v1");
    }
}

impl Dispatch<WpContentTypeManagerV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &WpContentTypeManagerV1,
        request: wp_content_type_manager_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            wp_content_type_manager_v1::Request::GetSurfaceContentType { id, surface } => {
                let surface_id = surface.id().protocol_id();
                // let data = ContentTypeData { surface_id };
                let _ct = data_init.init(id, ());
                tracing::debug!("Created content type for surface {}", surface_id);
            }
            wp_content_type_manager_v1::Request::Destroy => {
                tracing::debug!("wp_content_type_manager_v1 destroyed");
            }
            _ => {}
        }
    }
}

// ============================================================================
// wp_content_type_v1
// ============================================================================

impl Dispatch<WpContentTypeV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &WpContentTypeV1,
        request: wp_content_type_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            wp_content_type_v1::Request::SetContentType { content_type } => {
                tracing::debug!("Set content type {:?} for surface", content_type);
                // TODO: Store content type hint
            }
            wp_content_type_v1::Request::Destroy => {
                tracing::debug!("wp_content_type_v1 destroyed");
            }
            _ => {}
        }
    }
}

/// Register wp_content_type_manager_v1 global
pub fn register_content_type(display: &DisplayHandle) -> wayland_server::backend::GlobalId {
    display.create_global::<CompositorState, WpContentTypeManagerV1, ()>(1, ())
}
