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


use crate::core::state::CompositorState;
use std::collections::HashMap;

#[derive(Debug, Clone)]
pub struct XdgOutputData {
    pub output_id: u32,
}

impl XdgOutputData {
    pub fn new(output_id: u32) -> Self {
        Self { output_id }
    }
}

/// Tracks all bound xdg_output resources for update notifications.
#[derive(Debug, Default)]
pub struct XdgOutputState {
    pub outputs: HashMap<(wayland_server::backend::ClientId, u32), XdgOutputData>,
    /// All active xdg_output resources, keyed by client and xdg_output protocol ID.
    /// Used to send updates when output configuration changes.
    pub resources: HashMap<(wayland_server::backend::ClientId, u32), ZxdgOutputV1>,
}


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

                let xdg_output_id = xdg_output.id().protocol_id();
                state.xdg.output.outputs.insert((_client.id().clone(), xdg_output_id), xdg_output_data);
                state.xdg.output.resources.insert((_client.id().clone(), xdg_output_id), xdg_output.clone());

                
                // Send output information
                let output_state = state.primary_output();
                
                xdg_output.logical_position(output_state.x, output_state.y);
                
                // OutputState.width/height are already logical (points/dp).
                let lw = output_state.width as i32;
                let lh = output_state.height as i32;
                xdg_output.logical_size(lw, lh);
                
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
                
                if xdg_output.version() >= 3 {
                    xdg_output.done();
                }
                
                tracing::debug!(
                    "Created xdg_output for output {}: logical {}x{} at ({}, {})",
                    output_id, lw, lh, output_state.x, output_state.y
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
                let id = resource.id().protocol_id();
                state.xdg.output.outputs.remove(&(_client.id().clone(), id));
                state.xdg.output.resources.remove(&(_client.id().clone(), id));
                tracing::debug!("zxdg_output_v1 destroyed");
            }

            _ => {}
        }
    }
}

/// Notify all xdg_output resources about output configuration changes.
/// Called when output geometry, mode, or scale changes.
pub fn notify_xdg_output_change(state: &CompositorState) {
    let output_state = state.primary_output();
    // OutputState.width/height are already logical (points/dp).
    let lw = output_state.width as i32;
    let lh = output_state.height as i32;

    for (_, xdg_output) in &state.xdg.output.resources {
        if !xdg_output.is_alive() {
            continue;
        }
        xdg_output.logical_position(output_state.x, output_state.y);
        xdg_output.logical_size(lw, lh);

        if xdg_output.version() >= 3 {
            xdg_output.done();
        }
    }

    if !state.xdg.output.resources.is_empty() {
        tracing::debug!(
            "Notified {} xdg_output resources of change: logical {}x{} at ({}, {})",
            state.xdg.output.resources.len(),
            lw, lh, output_state.x, output_state.y
        );
    }
}

/// Notify only a single client's xdg_output resources of a change.
pub fn notify_xdg_output_change_for_client(
    state: &CompositorState,
    client_id: &wayland_server::backend::ClientId,
) {
    let output_state = state.primary_output();
    let lw = output_state.width as i32;
    let lh = output_state.height as i32;

    for ((cid, _), xdg_output) in &state.xdg.output.resources {
        if cid != client_id || !xdg_output.is_alive() {
            continue;
        }
        xdg_output.logical_position(output_state.x, output_state.y);
        xdg_output.logical_size(lw, lh);
        if xdg_output.version() >= 3 {
            xdg_output.done();
        }
    }
}

/// Register zxdg_output_manager_v1 global
pub fn register_xdg_output_manager(display: &DisplayHandle) -> wayland_server::backend::GlobalId {
    display.create_global::<CompositorState, ZxdgOutputManagerV1, ()>(3, ())
}
