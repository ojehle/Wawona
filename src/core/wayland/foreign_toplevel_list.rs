//! Foreign Toplevel List protocol implementation.
//!
//! Provides a list of toplevels to privileged clients (task bars, etc.).

use wayland_server::{
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New,
};
use wayland_protocols::ext::foreign_toplevel_list::v1::server::{
    ext_foreign_toplevel_list_v1::{self, ExtForeignToplevelListV1},
    ext_foreign_toplevel_handle_v1::{self, ExtForeignToplevelHandleV1},
};

use crate::core::state::CompositorState;

#[derive(Debug, Clone, Default)]
pub struct ForeignToplevelHandleData {
    pub toplevel_id: u32,
}

impl GlobalDispatch<ExtForeignToplevelListV1, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<ExtForeignToplevelListV1>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
        tracing::debug!("Bound ext_foreign_toplevel_list_v1");
    }
}

impl Dispatch<ExtForeignToplevelListV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &ExtForeignToplevelListV1,
        request: ext_foreign_toplevel_list_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            ext_foreign_toplevel_list_v1::Request::Stop => {
                tracing::debug!("Foreign toplevel list stopped");
            }
            ext_foreign_toplevel_list_v1::Request::Destroy => {}
            _ => {}
        }
    }
}

impl Dispatch<ExtForeignToplevelHandleV1, ForeignToplevelHandleData> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &ExtForeignToplevelHandleV1,
        request: ext_foreign_toplevel_handle_v1::Request,
        _data: &ForeignToplevelHandleData,
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            ext_foreign_toplevel_handle_v1::Request::Destroy => {}
            _ => {}
        }
    }
}

pub fn register_foreign_toplevel_list(display: &DisplayHandle) -> wayland_server::backend::GlobalId {
    display.create_global::<CompositorState, ExtForeignToplevelListV1, ()>(1, ())
}
