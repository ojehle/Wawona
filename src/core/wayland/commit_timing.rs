//! Commit Timing protocol implementation.
//!
//! This protocol allows clients to specify timing constraints for commits.

use wayland_server::{
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New, Resource,
};
use wayland_protocols::wp::commit_timing::v1::server::{
    wp_commit_timing_manager_v1::{self, WpCommitTimingManagerV1},
    wp_commit_timer_v1::{self, WpCommitTimerV1},
};

use crate::core::state::CompositorState;

// ============================================================================
// Data Types
// ============================================================================

#[derive(Debug, Clone, Default)]
pub struct CommitTimerData {
    pub surface_id: u32,
}

// ============================================================================
// wp_commit_timing_manager_v1
// ============================================================================

impl GlobalDispatch<WpCommitTimingManagerV1, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<WpCommitTimingManagerV1>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
        tracing::debug!("Bound wp_commit_timing_manager_v1");
    }
}

impl Dispatch<WpCommitTimingManagerV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &WpCommitTimingManagerV1,
        request: wp_commit_timing_manager_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            wp_commit_timing_manager_v1::Request::GetTimer { id, surface } => {
                let surface_id = surface.id().protocol_id();
                // let data = CommitTimerData { surface_id };
                let _timer = data_init.init(id, ());
                tracing::debug!("Created commit timer for surface {}", surface_id);
            }
            wp_commit_timing_manager_v1::Request::Destroy => {
                tracing::debug!("wp_commit_timing_manager_v1 destroyed");
            }
            _ => {}
        }
    }
}

// ============================================================================
// wp_commit_timer_v1
// ============================================================================

impl Dispatch<WpCommitTimerV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &WpCommitTimerV1,
        request: wp_commit_timer_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            wp_commit_timer_v1::Request::SetTimestamp { tv_sec_hi, tv_sec_lo, tv_nsec } => {
                let secs = ((tv_sec_hi as u64) << 32) | (tv_sec_lo as u64);
                tracing::debug!("Set timestamp {}.{:09} for surface", secs, tv_nsec);
            }
            wp_commit_timer_v1::Request::Destroy => {
                tracing::debug!("wp_commit_timer_v1 destroyed");
            }
            _ => {}
        }
    }
}

/// Register wp_commit_timing_manager_v1 global
pub fn register_commit_timing(display: &DisplayHandle) -> wayland_server::backend::GlobalId {
    display.create_global::<CompositorState, WpCommitTimingManagerV1, ()>(1, ())
}
