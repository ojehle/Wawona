//! Fullscreen Shell protocol implementation.
//!
//! A simple shell for fullscreen applications (kiosk mode).

use wayland_server::{
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New,
};
use wayland_protocols::wp::fullscreen_shell::zv1::server::{
    zwp_fullscreen_shell_v1::{self, ZwpFullscreenShellV1},
    zwp_fullscreen_shell_mode_feedback_v1::{self, ZwpFullscreenShellModeFeedbackV1},
};

use crate::core::state::CompositorState;

#[derive(Debug, Clone, Default)]
pub struct ModeFeedbackData;

impl GlobalDispatch<ZwpFullscreenShellV1, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<ZwpFullscreenShellV1>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
        tracing::debug!("Bound zwp_fullscreen_shell_v1");
    }
}

impl Dispatch<ZwpFullscreenShellV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &ZwpFullscreenShellV1,
        request: zwp_fullscreen_shell_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            zwp_fullscreen_shell_v1::Request::PresentSurface { surface: _, method: _, output: _ } => {
                tracing::debug!("Fullscreen shell present surface");
            }
            zwp_fullscreen_shell_v1::Request::PresentSurfaceForMode { surface: _, output: _, framerate: _, feedback } => {
                let _fb = data_init.init(feedback, ());
            }
            zwp_fullscreen_shell_v1::Request::Release => {}
            _ => {}
        }
    }
}

impl Dispatch<ZwpFullscreenShellModeFeedbackV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &ZwpFullscreenShellModeFeedbackV1,
        _request: zwp_fullscreen_shell_mode_feedback_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        // No requests defined for mode feedback
    }
}

pub fn register_fullscreen_shell(display: &DisplayHandle) -> wayland_server::backend::GlobalId {
    display.create_global::<CompositorState, ZwpFullscreenShellV1, ()>(1, ())
}
