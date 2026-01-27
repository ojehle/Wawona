//! Cursor Shape protocol implementation.
//!
//! This protocol allows clients to set the cursor shape using predefined shapes
//! instead of providing a surface with a cursor image.

use wayland_server::{
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New, Resource,
};
use wayland_protocols::wp::cursor_shape::v1::server::{
    wp_cursor_shape_manager_v1::{self, WpCursorShapeManagerV1},
    wp_cursor_shape_device_v1::{self, WpCursorShapeDeviceV1},
};

use crate::core::state::CompositorState;

// ============================================================================
// Data Types
// ============================================================================

#[derive(Debug, Clone, Default)]
pub struct CursorShapeDeviceData {
    pub pointer_id: u32,
}

// ============================================================================
// wp_cursor_shape_manager_v1
// ============================================================================

impl GlobalDispatch<WpCursorShapeManagerV1, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<WpCursorShapeManagerV1>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
        tracing::debug!("Bound wp_cursor_shape_manager_v1");
    }
}

impl Dispatch<WpCursorShapeManagerV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &WpCursorShapeManagerV1,
        request: wp_cursor_shape_manager_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            wp_cursor_shape_manager_v1::Request::GetPointer { cursor_shape_device, pointer } => {
                let pointer_id = pointer.id().protocol_id();
                // let data = CursorShapeDeviceData { pointer_id };
                let _device = data_init.init(cursor_shape_device, ());
                tracing::debug!("Created cursor shape device for pointer {}", pointer_id);
            }
            wp_cursor_shape_manager_v1::Request::GetTabletToolV2 { cursor_shape_device, tablet_tool } => {
                let tool_id = tablet_tool.id().protocol_id();
                // let data = CursorShapeDeviceData { pointer_id: tool_id };
                let _device = data_init.init(cursor_shape_device, ());
                tracing::debug!("Created cursor shape device for tablet tool {}", tool_id);
            }
            wp_cursor_shape_manager_v1::Request::Destroy => {
                tracing::debug!("wp_cursor_shape_manager_v1 destroyed");
            }
            _ => {}
        }
    }
}

// ============================================================================
// wp_cursor_shape_device_v1
// ============================================================================

impl Dispatch<WpCursorShapeDeviceV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &WpCursorShapeDeviceV1,
        request: wp_cursor_shape_device_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            wp_cursor_shape_device_v1::Request::SetShape { serial, shape } => {
                tracing::debug!("Set cursor shape: serial={}, shape={:?}", serial, shape);
                // TODO: Store and apply cursor shape
            }
            wp_cursor_shape_device_v1::Request::Destroy => {
                tracing::debug!("wp_cursor_shape_device_v1 destroyed");
            }
            _ => {}
        }
    }
}

/// Register wp_cursor_shape_manager_v1 global
pub fn register_cursor_shape(display: &DisplayHandle) -> wayland_server::backend::GlobalId {
    display.create_global::<CompositorState, WpCursorShapeManagerV1, ()>(1, ())
}
