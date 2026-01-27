//! Idle Notify protocol implementation.
//!
//! This protocol allows clients to be notified when the user becomes idle.


use wayland_server::{
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New, Resource,
};
use wayland_protocols::ext::idle_notify::v1::server::{
    ext_idle_notifier_v1::{self, ExtIdleNotifierV1},
    ext_idle_notification_v1::{self, ExtIdleNotificationV1},
};

use crate::core::state::CompositorState;

// ============================================================================
// Data Types
// ============================================================================

#[derive(Debug, Clone)]
pub struct IdleNotificationData {
    pub timeout_ms: u32,
    pub seat_id: u32,
}

// ============================================================================
// ext_idle_notifier_v1
// ============================================================================

impl GlobalDispatch<ExtIdleNotifierV1, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<ExtIdleNotifierV1>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
        tracing::debug!("Bound ext_idle_notifier_v1");
    }
}

impl Dispatch<ExtIdleNotifierV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &ExtIdleNotifierV1,
        request: ext_idle_notifier_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            ext_idle_notifier_v1::Request::GetIdleNotification { id, timeout, seat } => {
                let seat_id = seat.id().protocol_id();
                // let data = IdleNotificationData {
                //     timeout_ms: timeout,
                //     seat_id,
                // };
                let _notification = data_init.init(id, ());
                tracing::debug!("Created idle notification: timeout={}ms, seat={}", timeout, seat_id);
            }
            ext_idle_notifier_v1::Request::Destroy => {
                tracing::debug!("ext_idle_notifier_v1 destroyed");
            }
            _ => {}
        }
    }
}

// ============================================================================
// ext_idle_notification_v1
// ============================================================================

impl Dispatch<ExtIdleNotificationV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &ExtIdleNotificationV1,
        request: ext_idle_notification_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            ext_idle_notification_v1::Request::Destroy => {
                tracing::debug!("ext_idle_notification_v1 destroyed");
            }
            _ => {}
        }
    }
}

/// Register ext_idle_notifier_v1 global
pub fn register_idle_notify(display: &DisplayHandle) -> wayland_server::backend::GlobalId {
    display.create_global::<CompositorState, ExtIdleNotifierV1, ()>(1, ())
}
