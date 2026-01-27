//! WP Pointer Gestures protocol implementation.
//!
//! This protocol provides multi-touch gesture events:
//! - Swipe: Multi-finger swipe gestures
//! - Pinch: Two-finger pinch/zoom gestures
//! - Hold: Press and hold gestures (v3+)


use wayland_server::{
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New, Resource,
};
use wayland_protocols::wp::pointer_gestures::zv1::server::{
    zwp_pointer_gestures_v1::{self, ZwpPointerGesturesV1},
    zwp_pointer_gesture_swipe_v1::{self, ZwpPointerGestureSwipeV1},
    zwp_pointer_gesture_pinch_v1::{self, ZwpPointerGesturePinchV1},
};


use crate::core::state::CompositorState;

// ============================================================================
// Data Types
// ============================================================================

/// Data stored with swipe gesture
#[derive(Debug, Clone)]
pub struct SwipeGestureData {
    pub pointer_id: u32,
}

/// Data stored with pinch gesture
#[derive(Debug, Clone)]
pub struct PinchGestureData {
    pub pointer_id: u32,
}

// ============================================================================
// zwp_pointer_gestures_v1
// ============================================================================

impl GlobalDispatch<ZwpPointerGesturesV1, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<ZwpPointerGesturesV1>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
        tracing::debug!("Bound zwp_pointer_gestures_v1");
    }
}

impl Dispatch<ZwpPointerGesturesV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &ZwpPointerGesturesV1,
        request: zwp_pointer_gestures_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            zwp_pointer_gestures_v1::Request::GetSwipeGesture { id, pointer } => {
                let pointer_id = pointer.id().protocol_id();
                // let data = SwipeGestureData { pointer_id };
                let _swipe = data_init.init(id, ());
                tracing::debug!("Created swipe gesture for pointer {}", pointer_id);
            }
            zwp_pointer_gestures_v1::Request::GetPinchGesture { id, pointer } => {
                let pointer_id = pointer.id().protocol_id();
                // let data = PinchGestureData { pointer_id };
                let _pinch = data_init.init(id, ());
                tracing::debug!("Created pinch gesture for pointer {}", pointer_id);
            }
            zwp_pointer_gestures_v1::Request::Release => {
                tracing::debug!("zwp_pointer_gestures_v1 released");
            }
            _ => {}
        }
    }
}

// ============================================================================
// zwp_pointer_gesture_swipe_v1
// ============================================================================

impl Dispatch<ZwpPointerGestureSwipeV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &ZwpPointerGestureSwipeV1,
        request: zwp_pointer_gesture_swipe_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            zwp_pointer_gesture_swipe_v1::Request::Destroy => {
                tracing::debug!("Swipe gesture destroyed");
            }
            _ => {}
        }
    }
}

// ============================================================================
// zwp_pointer_gesture_pinch_v1
// ============================================================================

impl Dispatch<ZwpPointerGesturePinchV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &ZwpPointerGesturePinchV1,
        request: zwp_pointer_gesture_pinch_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            zwp_pointer_gesture_pinch_v1::Request::Destroy => {
                tracing::debug!("Pinch gesture destroyed");
            }
            _ => {}
        }
    }
}

/// Register zwp_pointer_gestures_v1 global
pub fn register_pointer_gestures(display: &DisplayHandle) -> wayland_server::backend::GlobalId {
    // Version 3 adds hold gesture, but we'll start with v1
    display.create_global::<CompositorState, ZwpPointerGesturesV1, ()>(1, ())
}
