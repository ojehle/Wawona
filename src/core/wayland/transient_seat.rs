//! Transient Seat protocol implementation.
//!
//! Allows creating temporary input seats for remote desktop scenarios.

use wayland_server::{
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New,
};
use wayland_protocols::ext::transient_seat::v1::server::{
    ext_transient_seat_manager_v1::{self, ExtTransientSeatManagerV1},
    ext_transient_seat_v1::{self, ExtTransientSeatV1},
};

use crate::core::state::CompositorState;

#[derive(Debug, Clone, Default)]
pub struct TransientSeatData;

impl GlobalDispatch<ExtTransientSeatManagerV1, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<ExtTransientSeatManagerV1>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
        tracing::debug!("Bound ext_transient_seat_manager_v1");
    }
}

impl Dispatch<ExtTransientSeatManagerV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &ExtTransientSeatManagerV1,
        request: ext_transient_seat_manager_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            ext_transient_seat_manager_v1::Request::Create { seat } => {
                let _ts = data_init.init(seat, ());
                tracing::debug!("Created transient seat");
            }
            ext_transient_seat_manager_v1::Request::Destroy => {}
            _ => {}
        }
    }
}

impl Dispatch<ExtTransientSeatV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &ExtTransientSeatV1,
        request: ext_transient_seat_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            ext_transient_seat_v1::Request::Destroy => {}
            _ => {}
        }
    }
}

pub fn register_transient_seat(display: &DisplayHandle) -> wayland_server::backend::GlobalId {
    display.create_global::<CompositorState, ExtTransientSeatManagerV1, ()>(1, ())
}
