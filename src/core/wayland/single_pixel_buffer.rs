//! Single Pixel Buffer protocol implementation.
//!
//! This protocol allows clients to create a buffer with a single pixel,
//! useful for solid color surfaces without needing shared memory.

use wayland_server::{
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New,
};
use wayland_protocols::wp::single_pixel_buffer::v1::server::{
    wp_single_pixel_buffer_manager_v1::{self, WpSinglePixelBufferManagerV1},
};

use crate::core::state::CompositorState;

// ============================================================================
// wp_single_pixel_buffer_manager_v1
// ============================================================================

impl GlobalDispatch<WpSinglePixelBufferManagerV1, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<WpSinglePixelBufferManagerV1>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
        tracing::debug!("Bound wp_single_pixel_buffer_manager_v1");
    }
}

impl Dispatch<WpSinglePixelBufferManagerV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &WpSinglePixelBufferManagerV1,
        request: wp_single_pixel_buffer_manager_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            wp_single_pixel_buffer_manager_v1::Request::CreateU32RgbaBuffer { id, r, g, b, a } => {
                tracing::debug!("Create single pixel buffer: rgba({}, {}, {}, {})", r, g, b, a);
                // TODO: Create wl_buffer with single pixel
                // The id is a New<WlBuffer> that needs to be initialized
                let _ = id;
            }
            wp_single_pixel_buffer_manager_v1::Request::Destroy => {
                tracing::debug!("wp_single_pixel_buffer_manager_v1 destroyed");
            }
            _ => {}
        }
    }
}

/// Register wp_single_pixel_buffer_manager_v1 global
pub fn register_single_pixel_buffer(display: &DisplayHandle) -> wayland_server::backend::GlobalId {
    display.create_global::<CompositorState, WpSinglePixelBufferManagerV1, ()>(1, ())
}
