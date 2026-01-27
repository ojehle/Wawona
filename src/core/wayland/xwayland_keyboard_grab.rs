//! XWayland Keyboard Grab protocol implementation.
//!
//! Allows XWayland to grab keyboard input.

use wayland_server::{
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New, Resource,
};
use wayland_protocols::xwayland::keyboard_grab::zv1::server::{
    zwp_xwayland_keyboard_grab_manager_v1::{self, ZwpXwaylandKeyboardGrabManagerV1},
    zwp_xwayland_keyboard_grab_v1::{self, ZwpXwaylandKeyboardGrabV1},
};

use crate::core::state::CompositorState;

#[derive(Debug, Clone, Default)]
pub struct XwaylandKeyboardGrabData {
    pub surface_id: u32,
}

impl GlobalDispatch<ZwpXwaylandKeyboardGrabManagerV1, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<ZwpXwaylandKeyboardGrabManagerV1>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
        tracing::debug!("Bound zwp_xwayland_keyboard_grab_manager_v1");
    }
}

impl Dispatch<ZwpXwaylandKeyboardGrabManagerV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &ZwpXwaylandKeyboardGrabManagerV1,
        request: zwp_xwayland_keyboard_grab_manager_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            zwp_xwayland_keyboard_grab_manager_v1::Request::GrabKeyboard { id, surface, seat: _ } => {
                let surface_id = surface.id().protocol_id();
                let _g = data_init.init(id, ());
                tracing::debug!("XWayland keyboard grab for surface {}", surface_id);
            }
            zwp_xwayland_keyboard_grab_manager_v1::Request::Destroy => {}
            _ => {}
        }
    }
}

impl Dispatch<ZwpXwaylandKeyboardGrabV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &ZwpXwaylandKeyboardGrabV1,
        request: zwp_xwayland_keyboard_grab_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            zwp_xwayland_keyboard_grab_v1::Request::Destroy => {}
            _ => {}
        }
    }
}

pub fn register_xwayland_keyboard_grab(display: &DisplayHandle) -> wayland_server::backend::GlobalId {
    display.create_global::<CompositorState, ZwpXwaylandKeyboardGrabManagerV1, ()>(1, ())
}
