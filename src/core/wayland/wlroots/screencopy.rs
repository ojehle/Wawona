
use wayland_server::{

    protocol::wl_shm,
    Dispatch, DisplayHandle, GlobalDispatch, Resource,

};

use crate::core::state::CompositorState;
use crate::core::wayland::wlroots::wlr_screencopy_unstable_v1::{
    zwlr_screencopy_manager_v1,
    zwlr_screencopy_frame_v1,
};

pub struct ScreencopyManagerData;

impl GlobalDispatch<zwlr_screencopy_manager_v1::ZwlrScreencopyManagerV1, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &wayland_server::Client,
        resource: wayland_server::New<zwlr_screencopy_manager_v1::ZwlrScreencopyManagerV1>,
        _global_data: &(),
        data_init: &mut wayland_server::DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
    }
}

impl Dispatch<zwlr_screencopy_manager_v1::ZwlrScreencopyManagerV1, ()> for CompositorState {
    fn request(
        state: &mut Self,
        _client: &wayland_server::Client,
        _resource: &zwlr_screencopy_manager_v1::ZwlrScreencopyManagerV1,
        request: zwlr_screencopy_manager_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut wayland_server::DataInit<'_, Self>,
    ) {
        match request {
            zwlr_screencopy_manager_v1::Request::CaptureOutput { frame, overlay_cursor: _, output: _ } => {
                let _output_id = 0; // output.data::<u32>().copied().unwrap_or(0);
                let frame = data_init.init(frame, ());
                
                // Send initial buffer information (default to primary output logic)
                if let Some(output_state) = state.outputs.first() {
                    // Advertise ARGB8888 as the preferred SHM format
                    frame.buffer(
                        wl_shm::Format::Argb8888,
                        output_state.width,
                        output_state.height,
                        output_state.width * 4,
                    );
                    
                    if frame.version() >= 3 {
                        frame.buffer_done();
                    }
                } else {
                    frame.failed();
                }
            }
            zwlr_screencopy_manager_v1::Request::CaptureOutputRegion { frame, overlay_cursor: _, output: _, x: _, y: _, width, height } => {
                let _output_id = 0; // output.data::<u32>().copied().unwrap_or(0);
                let frame = data_init.init(frame, ());
                
                // Advertise requested region dimensions
                frame.buffer(
                    wl_shm::Format::Argb8888,
                    width as u32,
                    height as u32,
                    width as u32 * 4,
                );
                
                if frame.version() >= 3 {
                    frame.buffer_done();
                }
            }
            zwlr_screencopy_manager_v1::Request::Destroy => {
                // Destructor
            }
            _ => {}
        }
    }
}

impl Dispatch<zwlr_screencopy_frame_v1::ZwlrScreencopyFrameV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &wayland_server::Client,
        resource: &zwlr_screencopy_frame_v1::ZwlrScreencopyFrameV1,
        request: zwlr_screencopy_frame_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut wayland_server::DataInit<'_, Self>,
    ) {
        match request {
            zwlr_screencopy_frame_v1::Request::Copy { buffer: _ } => {
                // Actual capture logic would go here.
                // For now, we signal failure as we don't have the render-to-buffer pipeline ready yet.
                resource.failed();
            }
            zwlr_screencopy_frame_v1::Request::CopyWithDamage { buffer: _ } => {
                resource.failed();
            }
            zwlr_screencopy_frame_v1::Request::Destroy => {
                // Destructor
            }
            _ => {}
        }
    }
}
