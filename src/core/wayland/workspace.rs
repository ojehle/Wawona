//! Workspace protocol implementation.
//!
//! Provides workspace/virtual desktop management.

use wayland_server::{
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New,
};
use wayland_protocols::ext::workspace::v1::server::{
    ext_workspace_manager_v1::{self, ExtWorkspaceManagerV1},
    ext_workspace_group_handle_v1::{self, ExtWorkspaceGroupHandleV1},
    ext_workspace_handle_v1::{self, ExtWorkspaceHandleV1},
};

use crate::core::state::CompositorState;

#[derive(Debug, Clone, Default)]
pub struct WorkspaceGroupData {
    pub group_id: u32,
}

#[derive(Debug, Clone, Default)]
pub struct WorkspaceData {
    pub workspace_id: u32,
}

impl GlobalDispatch<ExtWorkspaceManagerV1, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<ExtWorkspaceManagerV1>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
        tracing::debug!("Bound ext_workspace_manager_v1");
    }
}

impl Dispatch<ExtWorkspaceManagerV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &ExtWorkspaceManagerV1,
        request: ext_workspace_manager_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            ext_workspace_manager_v1::Request::Commit => {
                tracing::debug!("Workspace manager commit");
            }
            ext_workspace_manager_v1::Request::Stop => {}
            _ => {}
        }
    }
}

impl Dispatch<ExtWorkspaceGroupHandleV1, WorkspaceGroupData> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &ExtWorkspaceGroupHandleV1,
        request: ext_workspace_group_handle_v1::Request,
        _data: &WorkspaceGroupData,
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            ext_workspace_group_handle_v1::Request::CreateWorkspace { .. } => {}
            ext_workspace_group_handle_v1::Request::Destroy => {}
            _ => {}
        }
    }
}

impl Dispatch<ExtWorkspaceHandleV1, WorkspaceData> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &ExtWorkspaceHandleV1,
        request: ext_workspace_handle_v1::Request,
        _data: &WorkspaceData,
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            ext_workspace_handle_v1::Request::Activate => {}
            ext_workspace_handle_v1::Request::Deactivate => {}
            ext_workspace_handle_v1::Request::Remove => {}
            ext_workspace_handle_v1::Request::Destroy => {}
            _ => {}
        }
    }
}

pub fn register_workspace(display: &DisplayHandle) -> wayland_server::backend::GlobalId {
    display.create_global::<CompositorState, ExtWorkspaceManagerV1, ()>(1, ())
}
