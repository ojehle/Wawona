//! wl_output protocol implementation.
//!
//! Outputs represent physical displays connected to the system.
//! Clients use this to understand display geometry, mode, scale, etc.

use wayland_server::{
    protocol::wl_output::{self, WlOutput, Subpixel, Transform},
    Dispatch, DisplayHandle, GlobalDispatch, Resource,
};

use crate::core::state::{CompositorState, OutputState};

/// Output global data - references an output by ID
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct OutputGlobal {
    pub output_id: u32,
}

impl OutputGlobal {
    pub fn new(output_id: u32) -> Self {
        Self { output_id }
    }
}

// ============================================================================
// wl_output GlobalDispatch
// ============================================================================

impl GlobalDispatch<WlOutput, OutputGlobal> for CompositorState {
    fn bind(
        state: &mut Self,
        _handle: &DisplayHandle,
        _client: &wayland_server::Client,
        resource: wayland_server::New<WlOutput>,
        global_data: &OutputGlobal,
        data_init: &mut wayland_server::DataInit<'_, Self>,
    ) {
        let output = data_init.init(resource, ());
        let object_id = output.id();
        let client = output.client();
        let client_id = client.as_ref().map(|c| c.id());
        
        state.output_resources.insert(object_id.clone(), output.clone());
        state.output_id_by_resource.insert(object_id, global_data.output_id);
        crate::wlog!(crate::util::logging::COMPOSITOR, "Bound wl_output version {} for client {:?}", output.version(), client_id);

        // Find the output state using the global data ID
        if let Some(output_state) = state.outputs.iter().find(|o| o.id == global_data.output_id) {
            send_output_info(&output, output_state);
        } else {
            crate::wlog!(crate::util::logging::COMPOSITOR, "ERROR: OutputGlobal ID {} not found in state!", global_data.output_id);
            if let Some(primary) = state.outputs.first() {
                send_output_info(&output, primary);
            }
        }

        // Retroactively send wl_surface.enter for any existing surfaces owned
        // by this client.  Without this, surfaces attached before the client
        // binds wl_output never receive an enter event, which violates the
        // protocol expectation that surfaces know their output.
        let bind_client_id = _client.id();
        let surfaces_for_client: Vec<_> = state.surfaces.values()
            .filter_map(|s| {
                let s = s.read().unwrap();
                if s.client_id.as_ref() == Some(&bind_client_id) {
                    s.resource.clone()
                } else {
                    None
                }
            })
            .collect();
        for surf_res in &surfaces_for_client {
            surf_res.enter(&output);
        }
        if !surfaces_for_client.is_empty() {
            crate::wlog!(crate::util::logging::COMPOSITOR,
                "Retroactively sent wl_surface.enter to {} surfaces for client {:?}",
                surfaces_for_client.len(), client_id);
        }
    }
}

impl Dispatch<WlOutput, ()> for CompositorState {
    fn request(
        state: &mut Self,
        _client: &wayland_server::Client,
        resource: &WlOutput,
        request: wl_output::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut wayland_server::DataInit<'_, Self>,
    ) {
        match request {
            wl_output::Request::Release => {
                state.output_resources.remove(&resource.id());
                state.output_id_by_resource.remove(&resource.id());
                crate::wlog!(crate::util::logging::COMPOSITOR, "wl_output released for client {:?}", resource.client().map(|c| c.id()));
            }
            _ => {}
        }
    }
}

// ============================================================================
// Helpers
// ============================================================================

/// Send all output information to a newly bound output resource.
fn send_output_info(output: &WlOutput, state: &OutputState) {
    crate::wlog!(crate::util::logging::COMPOSITOR, "Sending wl_output.geometry: {}x{} @ ({},{})", state.physical_width, state.physical_height, state.x, state.y);
    // Send geometry
    output.geometry(
        state.x,
        state.y,
        state.physical_width as i32,
        state.physical_height as i32,
        Subpixel::Unknown,
        state.name.clone(),
        state.name.clone(), // model
        Transform::Normal,
    );
    
    // wl_output.mode reports physical pixel dimensions.
    // OutputState.width/height are logical (points/dp), so multiply by scale.
    let phys_w = (state.width as f32 * state.scale) as i32;
    let phys_h = (state.height as f32 * state.scale) as i32;
    crate::wlog!(crate::util::logging::COMPOSITOR, "Sending wl_output.mode: {}x{} (Current | Preferred)", phys_w, phys_h);
    output.mode(
        wl_output::Mode::Current | wl_output::Mode::Preferred,
        phys_w,
        phys_h,
        state.refresh as i32,
    );
    
    // Send scale (version 2+)
    if output.version() >= 2 {
        output.scale(state.scale as i32);
    }
    
    // Send name (version 4+)
    if output.version() >= 4 {
        output.name(state.name.clone());
        output.description(format!("{} ({}x{})", state.name, state.width, state.height));
    }
    
    // Send done event to signal end of initial configuration
    if output.version() >= 2 {
        output.done();
    }
    
    crate::wlog!(crate::util::logging::COMPOSITOR,
        "Sent output info: {} {}x{} logical ({}x{} physical px, {}x{}mm) @ {}mHz, scale {}, version {}",
        state.name, state.width, state.height, phys_w, phys_h, state.physical_width, state.physical_height, state.refresh, state.scale, output.version()
    );
}

/// Notify all bound output resources of a configuration change.
///
/// Call this when output configuration changes (resolution, scale, position, etc.)
/// to send updated geometry, mode, scale, and done events to all clients.
pub fn notify_output_change(state: &CompositorState, output_id: u32) {
    let output_state = match state.outputs.iter().find(|o| o.id == output_id) {
        Some(o) => o,
        None => {
            tracing::warn!("notify_output_change: output {} not found", output_id);
            return;
        }
    };

    let mut notified = 0;
    for (_obj_id, output_res) in &state.output_resources {
        if !output_res.is_alive() {
            continue;
        }
        send_output_info(output_res, output_state);
        notified += 1;
    }

    tracing::debug!(
        "Notified {} bound wl_output resources of output {} change ({}x{})",
        notified, output_id, output_state.width, output_state.height
    );

    // Also notify xdg_output resources
    crate::core::wayland::xdg::xdg_output::notify_xdg_output_change(state);
}

/// Notify only a single client's bound output resources of a configuration change.
///
/// Used when a per-window resize should only inform the owning client about
/// the output mode change, not all connected clients.
pub fn notify_output_change_for_client(
    state: &CompositorState,
    output_id: u32,
    client_id: &wayland_server::backend::ClientId,
) {
    let output_state = match state.outputs.iter().find(|o| o.id == output_id) {
        Some(o) => o,
        None => {
            tracing::warn!("notify_output_change_for_client: output {} not found", output_id);
            return;
        }
    };

    let mut notified = 0;
    for (_obj_id, output_res) in &state.output_resources {
        if !output_res.is_alive() {
            continue;
        }
        if let Some(client) = output_res.client() {
            if client.id() == *client_id {
                send_output_info(output_res, output_state);
                notified += 1;
            }
        }
    }

    tracing::debug!(
        "Notified {} output resources for client {:?} of output {} change ({}x{})",
        notified, client_id, output_id, output_state.width, output_state.height
    );

    crate::core::wayland::xdg::xdg_output::notify_xdg_output_change_for_client(state, client_id);
}
