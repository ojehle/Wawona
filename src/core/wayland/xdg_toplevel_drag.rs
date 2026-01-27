//! XDG Toplevel Drag protocol implementation.
//!
//! This protocol allows clients to initiate drag operations that can
//! move entire toplevels across workspaces or monitors.


use wayland_server::{
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New, Resource,
};
use wayland_protocols::xdg::toplevel_drag::v1::server::{
    xdg_toplevel_drag_v1::{self, XdgToplevelDragV1},
    xdg_toplevel_drag_manager_v1::{self, XdgToplevelDragManagerV1},
};

use crate::core::state::CompositorState;

// ============================================================================
// Data Types
// ============================================================================

#[derive(Debug, Clone, Default)]
pub struct ToplevelDragData {
    pub toplevel_id: Option<u32>,
}

// ============================================================================
// xdg_toplevel_drag_manager_v1
// ============================================================================

impl GlobalDispatch<XdgToplevelDragManagerV1, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<XdgToplevelDragManagerV1>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
        tracing::debug!("Bound xdg_toplevel_drag_manager_v1");
    }
}

impl Dispatch<XdgToplevelDragManagerV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &XdgToplevelDragManagerV1,
        request: xdg_toplevel_drag_manager_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            xdg_toplevel_drag_manager_v1::Request::GetXdgToplevelDrag { id, data_source } => {
                let _source_id = data_source.id().protocol_id();
                // let data = ToplevelDragData { toplevel_id: None };
                let _drag = data_init.init(id, ());
                tracing::debug!("Created toplevel drag");
            }
            xdg_toplevel_drag_manager_v1::Request::Destroy => {
                tracing::debug!("xdg_toplevel_drag_manager_v1 destroyed");
            }
            _ => {}
        }
    }
}

// ============================================================================
// xdg_toplevel_drag_v1
// ============================================================================

impl Dispatch<XdgToplevelDragV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &XdgToplevelDragV1,
        request: xdg_toplevel_drag_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            xdg_toplevel_drag_v1::Request::Attach { toplevel, x_offset, y_offset } => {
                let toplevel_id = toplevel.id().protocol_id();
                tracing::debug!("Attach toplevel {} to drag at offset ({}, {})", 
                    toplevel_id, x_offset, y_offset);
            }
            xdg_toplevel_drag_v1::Request::Destroy => {
                tracing::debug!("xdg_toplevel_drag_v1 destroyed");
            }
            _ => {}
        }
    }
}

/// Register xdg_toplevel_drag_manager_v1 global
pub fn register_xdg_toplevel_drag(display: &DisplayHandle) -> wayland_server::backend::GlobalId {
    display.create_global::<CompositorState, XdgToplevelDragManagerV1, ()>(1, ())
}
