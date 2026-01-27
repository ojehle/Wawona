//! Input Timestamps protocol implementation.
//!
//! Provides high-resolution timestamps for input events.

use wayland_server::{
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New,
};
use wayland_protocols::wp::input_timestamps::zv1::server::{
    zwp_input_timestamps_manager_v1::{self, ZwpInputTimestampsManagerV1},
    zwp_input_timestamps_v1::{self, ZwpInputTimestampsV1},
};

use crate::core::state::CompositorState;

#[derive(Debug, Clone, Default)]
pub struct InputTimestampsData;

impl GlobalDispatch<ZwpInputTimestampsManagerV1, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<ZwpInputTimestampsManagerV1>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
        tracing::debug!("Bound zwp_input_timestamps_manager_v1");
    }
}

impl Dispatch<ZwpInputTimestampsManagerV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &ZwpInputTimestampsManagerV1,
        request: zwp_input_timestamps_manager_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            zwp_input_timestamps_manager_v1::Request::GetKeyboardTimestamps { id, keyboard: _ } => {
                let _ts = data_init.init(id, ());
                tracing::debug!("Created keyboard timestamps");
            }
            zwp_input_timestamps_manager_v1::Request::GetPointerTimestamps { id, pointer: _ } => {
                let _ts = data_init.init(id, ());
                tracing::debug!("Created pointer timestamps");
            }
            zwp_input_timestamps_manager_v1::Request::GetTouchTimestamps { id, touch: _ } => {
                let _ts = data_init.init(id, ());
                tracing::debug!("Created touch timestamps");
            }
            zwp_input_timestamps_manager_v1::Request::Destroy => {}
            _ => {}
        }
    }
}

impl Dispatch<ZwpInputTimestampsV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &ZwpInputTimestampsV1,
        request: zwp_input_timestamps_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            zwp_input_timestamps_v1::Request::Destroy => {}
            _ => {}
        }
    }
}

pub fn register_input_timestamps(display: &DisplayHandle) -> wayland_server::backend::GlobalId {
    display.create_global::<CompositorState, ZwpInputTimestampsManagerV1, ()>(1, ())
}
