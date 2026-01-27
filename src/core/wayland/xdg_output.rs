//! XDG Output protocol implementation.
//!
//! This protocol provides additional output information beyond wl_output,
//! including logical position and size (accounting for scaling and transforms).


use wayland_server::{
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New, Resource,
};
use wayland_protocols::xdg::xdg_output::zv1::server::{
    zxdg_output_manager_v1::{self, ZxdgOutputManagerV1},
    zxdg_output_v1::{self, ZxdgOutputV1},
};


use crate::core::state::{CompositorState, XdgOutputData};

// ============================================================================
// zxdg_output_manager_v1
// ============================================================================

impl GlobalDispatch<ZxdgOutputManagerV1, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<ZxdgOutputManagerV1>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
        tracing::debug!("Bound zxdg_output_manager_v1");
    }
}

impl Dispatch<ZxdgOutputManagerV1, ()> for CompositorState {
    fn request(
        state: &mut Self,
        _client: &Client,
        _resource: &ZxdgOutputManagerV1,
        request: zxdg_output_manager_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            zxdg_output_manager_v1::Request::GetXdgOutput { id, output } => {
                let output_id = output.id().protocol_id();
                let xdg_output_data = XdgOutputData::new(output_id);
                let xdg_output = data_init.init(id, ());
                state.xdg_outputs.insert(xdg_output.id().protocol_id(), xdg_output_data);
                
                // Send output information
                let output_state = state.primary_output();
                
                // Logical position (in compositor coordinates)
                xdg_output.logical_position(output_state.x, output_state.y);
                
                // Logical size (may differ from physical due to scaling)
                let logical_width = (output_state.width as f32 / output_state.scale) as i32;
                let logical_height = (output_state.height as f32 / output_state.scale) as i32;
                xdg_output.logical_size(logical_width, logical_height);
                
                // Name and description (v2+)
                if xdg_output.version() >= 2 {
                    xdg_output.name(output_state.name.clone());
                    xdg_output.description(format!(
                        "{} ({}x{} @ {}Hz)",
                        output_state.name,
                        output_state.width,
                        output_state.height,
                        output_state.refresh / 1000
                    ));
                }
                
                // Done event (v3+)
                if xdg_output.version() >= 3 {
                    xdg_output.done();
                }
                
                tracing::debug!(
                    "Created xdg_output for output {}: logical {}x{} at ({}, {})",
                    output_id, logical_width, logical_height, output_state.x, output_state.y
                );
            }
            zxdg_output_manager_v1::Request::Destroy => {
                tracing::debug!("zxdg_output_manager_v1 destroyed");
            }
            _ => {}
        }
    }
}

// ============================================================================
// zxdg_output_v1
// ============================================================================

impl Dispatch<ZxdgOutputV1, ()> for CompositorState {
    fn request(
        state: &mut Self,
        _client: &Client,
        resource: &ZxdgOutputV1,
        request: zxdg_output_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            zxdg_output_v1::Request::Destroy => {
                state.xdg_outputs.remove(&resource.id().protocol_id());
                tracing::debug!("zxdg_output_v1 destroyed");
            }
            _ => {}
        }
    }
}

/// Register zxdg_output_manager_v1 global
pub fn register_xdg_output_manager(display: &DisplayHandle) -> wayland_server::backend::GlobalId {
    display.create_global::<CompositorState, ZxdgOutputManagerV1, ()>(3, ())
}
