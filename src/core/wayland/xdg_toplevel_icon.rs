//! XDG Toplevel Icon protocol implementation.
//!
//! This protocol allows clients to set icons for their toplevels.


use wayland_server::{
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New, Resource,
};
use wayland_protocols::xdg::toplevel_icon::v1::server::{
    xdg_toplevel_icon_v1::{self, XdgToplevelIconV1},
    xdg_toplevel_icon_manager_v1::{self, XdgToplevelIconManagerV1},
};

use crate::core::state::CompositorState;

// ============================================================================
// Data Types
// ============================================================================

#[derive(Debug, Clone, Default)]
pub struct ToplevelIconData {
    pub toplevel_id: u32,
}

// ============================================================================
// xdg_toplevel_icon_manager_v1
// ============================================================================

impl GlobalDispatch<XdgToplevelIconManagerV1, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<XdgToplevelIconManagerV1>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
        tracing::debug!("Bound xdg_toplevel_icon_manager_v1");
    }
}

impl Dispatch<XdgToplevelIconManagerV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &XdgToplevelIconManagerV1,
        request: xdg_toplevel_icon_manager_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            xdg_toplevel_icon_manager_v1::Request::CreateIcon { id } => {
                // let data = ToplevelIconData::default();
                let _icon = data_init.init(id, ());
                tracing::debug!("Created toplevel icon");
            }
            xdg_toplevel_icon_manager_v1::Request::SetIcon { toplevel, icon } => {
                let toplevel_id = toplevel.id().protocol_id();
                tracing::debug!("Set icon for toplevel {}", toplevel_id);
                let _ = icon;
            }
            xdg_toplevel_icon_manager_v1::Request::Destroy => {
                tracing::debug!("xdg_toplevel_icon_manager_v1 destroyed");
            }
            _ => {}
        }
    }
}

// ============================================================================
// xdg_toplevel_icon_v1
// ============================================================================

impl Dispatch<XdgToplevelIconV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &XdgToplevelIconV1,
        request: xdg_toplevel_icon_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            xdg_toplevel_icon_v1::Request::AddBuffer { buffer, scale } => {
                tracing::debug!("Add buffer to icon at scale {}", scale);
                let _ = buffer;
            }
            xdg_toplevel_icon_v1::Request::Destroy => {
                tracing::debug!("xdg_toplevel_icon_v1 destroyed");
            }
            _ => {}
        }
    }
}

/// Register xdg_toplevel_icon_manager_v1 global
pub fn register_xdg_toplevel_icon(display: &DisplayHandle) -> wayland_server::backend::GlobalId {
    display.create_global::<CompositorState, XdgToplevelIconManagerV1, ()>(1, ())
}
