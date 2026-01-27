//! Linux DRM Syncobj protocol implementation.
//!
//! Provides explicit synchronization using DRM synchronization objects.

use wayland_server::{
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New, Resource,
};
use wayland_protocols::wp::linux_drm_syncobj::v1::server::{
    wp_linux_drm_syncobj_manager_v1::{self, WpLinuxDrmSyncobjManagerV1},
    wp_linux_drm_syncobj_surface_v1::{self, WpLinuxDrmSyncobjSurfaceV1},
    wp_linux_drm_syncobj_timeline_v1::{self, WpLinuxDrmSyncobjTimelineV1},
};

use crate::core::state::CompositorState;

#[derive(Debug, Clone, Default)]
pub struct SyncobjSurfaceData {
    pub surface_id: u32,
}

#[derive(Debug, Clone, Default)]
pub struct SyncobjTimelineData {
    pub fd: Option<i32>,
}

impl GlobalDispatch<WpLinuxDrmSyncobjManagerV1, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<WpLinuxDrmSyncobjManagerV1>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
        tracing::debug!("Bound wp_linux_drm_syncobj_manager_v1");
    }
}

impl Dispatch<WpLinuxDrmSyncobjManagerV1, ()> for CompositorState {
    fn request(
        state: &mut Self,
        _client: &Client,
        _resource: &WpLinuxDrmSyncobjManagerV1,
        request: wp_linux_drm_syncobj_manager_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            wp_linux_drm_syncobj_manager_v1::Request::GetSurface { id, surface } => {
                let surface_id = surface.id().protocol_id();
                // let _s = data_init.init(id, SyncobjSurfaceData { surface_id });
                let s = data_init.init(id, ());
                state.syncobj_surfaces.insert(s.id().protocol_id(), surface_id);
                tracing::debug!("Created syncobj surface for {}", surface_id);
            }
            wp_linux_drm_syncobj_manager_v1::Request::ImportTimeline { id, fd } => {
                // let _t = data_init.init(id, SyncobjTimelineData { fd: Some(fd.as_raw_fd()) });
                let t = data_init.init(id, ());
                state.syncobj_timelines.insert(t.id().protocol_id(), Some(fd.as_raw_fd()));
                // We keep the fd open by duping or just consuming it (AsRawFd doesn't consume)
                // In real impl we would use OwnedFd
                tracing::debug!("Imported syncobj timeline");
            }
            wp_linux_drm_syncobj_manager_v1::Request::Destroy => {}
            _ => {}
        }
    }
}

impl Dispatch<WpLinuxDrmSyncobjSurfaceV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &WpLinuxDrmSyncobjSurfaceV1,
        request: wp_linux_drm_syncobj_surface_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            wp_linux_drm_syncobj_surface_v1::Request::Destroy => {}
            wp_linux_drm_syncobj_surface_v1::Request::SetAcquirePoint { .. } => {}
            wp_linux_drm_syncobj_surface_v1::Request::SetReleasePoint { .. } => {}
            _ => {}
        }
    }
}

impl Dispatch<WpLinuxDrmSyncobjTimelineV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &WpLinuxDrmSyncobjTimelineV1,
        request: wp_linux_drm_syncobj_timeline_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            wp_linux_drm_syncobj_timeline_v1::Request::Destroy => {}
            _ => {}
        }
    }
}

use std::os::fd::AsRawFd;

pub fn register_linux_drm_syncobj(display: &DisplayHandle) -> wayland_server::backend::GlobalId {
    display.create_global::<CompositorState, WpLinuxDrmSyncobjManagerV1, ()>(1, ())
}
