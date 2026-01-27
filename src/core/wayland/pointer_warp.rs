//! Pointer Warp protocol implementation.
//!
//! Allows clients to request pointer position changes.

use wayland_server::{
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New,
};
use wayland_protocols::wp::pointer_warp::v1::server::{
    wp_pointer_warp_v1::{self, WpPointerWarpV1},
};

use crate::core::state::CompositorState;

impl GlobalDispatch<WpPointerWarpV1, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<WpPointerWarpV1>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
        tracing::debug!("Bound wp_pointer_warp_v1");
    }
}

impl Dispatch<WpPointerWarpV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &WpPointerWarpV1,
        request: wp_pointer_warp_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            wp_pointer_warp_v1::Request::WarpPointer { surface: _, x, y, pointer: _, serial: _ } => {
                tracing::debug!("Pointer warp requested to ({}, {})", x, y);
            }
            wp_pointer_warp_v1::Request::Destroy => {}
            _ => {}
        }
    }
}

pub fn register_pointer_warp(display: &DisplayHandle) -> wayland_server::backend::GlobalId {
    display.create_global::<CompositorState, WpPointerWarpV1, ()>(1, ())
}
