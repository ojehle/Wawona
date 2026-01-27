
use wayland_server::{
    Dispatch, DisplayHandle, GlobalDispatch,
};

use crate::core::state::CompositorState;
use crate::core::wayland::wlroots::wlr_gamma_control_unstable_v1::{
    zwlr_gamma_control_manager_v1,
    zwlr_gamma_control_v1,
};

pub struct GammaControlManagerData;

impl GlobalDispatch<zwlr_gamma_control_manager_v1::ZwlrGammaControlManagerV1, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &wayland_server::Client,
        resource: wayland_server::New<zwlr_gamma_control_manager_v1::ZwlrGammaControlManagerV1>,
        _global_data: &(),
        data_init: &mut wayland_server::DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
    }
}

impl Dispatch<zwlr_gamma_control_manager_v1::ZwlrGammaControlManagerV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &wayland_server::Client,
        _resource: &zwlr_gamma_control_manager_v1::ZwlrGammaControlManagerV1,
        request: zwlr_gamma_control_manager_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut wayland_server::DataInit<'_, Self>,
    ) {
        match request {
            zwlr_gamma_control_manager_v1::Request::GetGammaControl { id, output: _ } => {
                let _output_id = 0; // output.data::<u32>().copied().unwrap_or(0);
                
                // Check if someone else already has control? 
                // For now we just allow it, but we should ideally track this.
                let control = data_init.init(id, ());
                
                // Advertise gamma size. 256 is a common value for 8-bit channels.
                control.gamma_size(256);
            }
            zwlr_gamma_control_manager_v1::Request::Destroy => {
                // Destructor
            }
            _ => {}
        }
    }
}

impl Dispatch<zwlr_gamma_control_v1::ZwlrGammaControlV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &wayland_server::Client,
        _resource: &zwlr_gamma_control_v1::ZwlrGammaControlV1,
        request: zwlr_gamma_control_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut wayland_server::DataInit<'_, Self>,
    ) {
        match request {
            zwlr_gamma_control_v1::Request::SetGamma { fd: _ } => {
                // Receive FD for gamma ramps.
                // Actual hardware application would happen here.
                // This would involve reading the FD and calling platform APIs.
            }
            zwlr_gamma_control_v1::Request::Destroy => {
                // Destructor
                // Original gamma tables should be restored here if we had changed them.
            }
            _ => {}
        }
    }
}
