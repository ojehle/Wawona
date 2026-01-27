//! WP Text Input protocol implementation.
//!
//! This protocol provides text input support for IME (Input Method Editor),
//! essential for non-Latin text input (Chinese, Japanese, Korean, etc.).


use wayland_server::{
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New, Resource,
};
use wayland_protocols::wp::text_input::zv3::server::{
    zwp_text_input_manager_v3::{self, ZwpTextInputManagerV3},
    zwp_text_input_v3::{self, ZwpTextInputV3},
};


use crate::core::state::CompositorState;

// ============================================================================
// Data Types
// ============================================================================

/// Data stored with text input
#[derive(Debug, Clone)]
pub struct TextInputData {
    pub seat_id: u32,
    pub surface_id: Option<u32>,
}

impl TextInputData {
    pub fn new(seat_id: u32) -> Self {
        Self {
            seat_id,
            surface_id: None,
        }
    }
}

// ============================================================================
// zwp_text_input_manager_v3
// ============================================================================

impl GlobalDispatch<ZwpTextInputManagerV3, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<ZwpTextInputManagerV3>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
        tracing::debug!("Bound zwp_text_input_manager_v3");
    }
}

impl Dispatch<ZwpTextInputManagerV3, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &ZwpTextInputManagerV3,
        request: zwp_text_input_manager_v3::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            zwp_text_input_manager_v3::Request::GetTextInput { id, seat } => {
                let seat_id = seat.id().protocol_id();
                // let data = TextInputData::new(seat_id);
                let _text_input = data_init.init(id, ());
                tracing::debug!("Created text input for seat {}", seat_id);
            }
            zwp_text_input_manager_v3::Request::Destroy => {
                tracing::debug!("zwp_text_input_manager_v3 destroyed");
            }
            _ => {}
        }
    }
}

// ============================================================================
// zwp_text_input_v3
// ============================================================================

impl Dispatch<ZwpTextInputV3, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _resource: &ZwpTextInputV3,
        request: zwp_text_input_v3::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            zwp_text_input_v3::Request::Enable => {
                // let mut data = data.write().unwrap();
                // In text_input_v3, Enable doesn't take a surface - it's implicit
                tracing::debug!("Text input enabled");
            }
            zwp_text_input_v3::Request::Disable => {
                // let mut data = data.write().unwrap();
                // data.surface_id = None;
                tracing::debug!("Text input disabled");
            }
            zwp_text_input_v3::Request::SetSurroundingText { text, cursor, anchor } => {
                tracing::debug!("Text input surrounding text: cursor={}, anchor={}", cursor, anchor);
                let _ = text;
            }
            zwp_text_input_v3::Request::SetTextChangeCause { cause } => {
                tracing::debug!("Text change cause: {:?}", cause);
            }
            zwp_text_input_v3::Request::SetContentType { hint, purpose } => {
                tracing::debug!("Content type: hint={:?}, purpose={:?}", hint, purpose);
            }
            zwp_text_input_v3::Request::SetCursorRectangle { x, y, width, height } => {
                tracing::debug!("Cursor rectangle: ({}, {}) {}x{}", x, y, width, height);
            }
            zwp_text_input_v3::Request::Commit => {
                tracing::debug!("Text input commit");
            }
            zwp_text_input_v3::Request::Destroy => {
                tracing::debug!("Text input destroyed");
            }
            _ => {}
        }
    }
}

/// Register zwp_text_input_manager_v3 global
pub fn register_text_input_manager(display: &DisplayHandle) -> wayland_server::backend::GlobalId {
    display.create_global::<CompositorState, ZwpTextInputManagerV3, ()>(1, ())
}
