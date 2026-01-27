//! XDG Dialog protocol implementation.
//!
//! This protocol allows clients to mark toplevels as dialog windows.

use wayland_server::{
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New, Resource,
};
use wayland_protocols::xdg::dialog::v1::server::{
    xdg_dialog_v1::{self, XdgDialogV1},
    xdg_wm_dialog_v1::{self, XdgWmDialogV1},
};

use crate::core::state::CompositorState;

// ============================================================================
// Data Types
// ============================================================================

#[derive(Debug, Clone, Default)]
pub struct DialogData {
    pub toplevel_id: u32,
    pub modal: bool,
}

// ============================================================================
// xdg_wm_dialog_v1
// ============================================================================

impl GlobalDispatch<XdgWmDialogV1, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<XdgWmDialogV1>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
        tracing::debug!("Bound xdg_wm_dialog_v1");
    }
}

impl Dispatch<XdgWmDialogV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &XdgWmDialogV1,
        request: xdg_wm_dialog_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            xdg_wm_dialog_v1::Request::GetXdgDialog { id, toplevel } => {
                let toplevel_id = toplevel.id().protocol_id();
                // Ignore tracking for now
                let _dialog = data_init.init(id, ());
                tracing::debug!("Created dialog for toplevel {}", toplevel_id);
            }
            xdg_wm_dialog_v1::Request::Destroy => {
                tracing::debug!("xdg_wm_dialog_v1 destroyed");
            }
            _ => {}
        }
    }
}

// ============================================================================
// xdg_dialog_v1
// ============================================================================

impl Dispatch<XdgDialogV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &XdgDialogV1,
        request: xdg_dialog_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            xdg_dialog_v1::Request::SetModal => {
                tracing::debug!("Dialog {} set as modal", 0);
            }
            xdg_dialog_v1::Request::UnsetModal => {
                tracing::debug!("Dialog {} unset modal", 0);
            }
            xdg_dialog_v1::Request::Destroy => {
                tracing::debug!("xdg_dialog_v1 destroyed");
            }
            _ => {}
        }
    }
}

/// Register xdg_wm_dialog_v1 global
pub fn register_xdg_dialog(display: &DisplayHandle) -> wayland_server::backend::GlobalId {
    display.create_global::<CompositorState, XdgWmDialogV1, ()>(1, ())
}
