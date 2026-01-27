//! Image Capture Source protocol implementation.
//!
//! Provides sources for screen capture.

use wayland_server::{
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New,
};
use wayland_protocols::ext::image_capture_source::v1::server::{
    ext_image_capture_source_v1::{self, ExtImageCaptureSourceV1},
    ext_output_image_capture_source_manager_v1::{self, ExtOutputImageCaptureSourceManagerV1},
};

use crate::core::state::CompositorState;

#[derive(Debug, Clone, Default)]
pub struct ImageCaptureSourceData;

impl GlobalDispatch<ExtOutputImageCaptureSourceManagerV1, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<ExtOutputImageCaptureSourceManagerV1>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
        tracing::debug!("Bound ext_output_image_capture_source_manager_v1");
    }
}

impl Dispatch<ExtOutputImageCaptureSourceManagerV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &ExtOutputImageCaptureSourceManagerV1,
        request: ext_output_image_capture_source_manager_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            ext_output_image_capture_source_manager_v1::Request::CreateSource { source, output: _ } => {
                let _s = data_init.init(source, ());
                tracing::debug!("Created image capture source");
            }
            ext_output_image_capture_source_manager_v1::Request::Destroy => {}
            _ => {}
        }
    }
}

impl Dispatch<ExtImageCaptureSourceV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &ExtImageCaptureSourceV1,
        request: ext_image_capture_source_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            ext_image_capture_source_v1::Request::Destroy => {}
            _ => {}
        }
    }
}

pub fn register_image_capture_source(display: &DisplayHandle) -> wayland_server::backend::GlobalId {
    display.create_global::<CompositorState, ExtOutputImageCaptureSourceManagerV1, ()>(1, ())
}
