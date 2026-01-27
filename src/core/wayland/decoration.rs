//! XDG Decoration protocol implementation.
//!
//! This protocol allows clients and compositors to negotiate whether
//! window decorations should be drawn client-side (CSD) or server-side (SSD).

use wayland_server::{
    Dispatch, Resource, DisplayHandle, GlobalDispatch,
};
use wayland_protocols::xdg::decoration::zv1::server::{
    zxdg_decoration_manager_v1::{self, ZxdgDecorationManagerV1},
    zxdg_toplevel_decoration_v1::{self, ZxdgToplevelDecorationV1, Mode},
};


use crate::core::state::{CompositorState, DecorationPolicy, ToplevelDecorationData};
use crate::core::window::DecorationMode;

// ============================================================================
// zxdg_decoration_manager_v1
// ============================================================================

pub struct DecorationManagerGlobal;

impl GlobalDispatch<ZxdgDecorationManagerV1, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &wayland_server::Client,
        resource: wayland_server::New<ZxdgDecorationManagerV1>,
        _global_data: &(),
        data_init: &mut wayland_server::DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
        tracing::debug!("Bound zxdg_decoration_manager_v1");
    }
}

impl Dispatch<ZxdgDecorationManagerV1, ()> for CompositorState {
    fn request(
        state: &mut Self,
        _client: &wayland_server::Client,
        _resource: &ZxdgDecorationManagerV1,
        request: zxdg_decoration_manager_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut wayland_server::DataInit<'_, Self>,
    ) {
        match request {
            zxdg_decoration_manager_v1::Request::GetToplevelDecoration { id, toplevel } => {
                // Get the toplevel data to find the window ID
                // FIXED: data should be &u32, not XdgToplevelData
                let window_id = match toplevel.data::<u32>() {
                    Some(id) => *id,
                    None => {
                        crate::wlog!(crate::util::logging::COMPOSITOR, "zxdg_decoration_manager: xdg_toplevel resource missing window_id data");
                        // We MUST initialize the resource anyway to avoid a panic in wayland-server
                        data_init.init(id, 0);
                        return;
                    }
                };
                
                let decoration_data = ToplevelDecorationData::new(window_id);
                // Initialize decoration resource with its own data
                let decoration = data_init.init(id, window_id);
                
                state.decorations.insert(decoration.id().protocol_id(), decoration_data);
                
                // Send the preferred mode based on compositor policy
                let preferred_mode = match state.decoration_policy {
                    DecorationPolicy::PreferClient => Mode::ClientSide,
                    DecorationPolicy::PreferServer => Mode::ServerSide,
                    DecorationPolicy::ForceServer => Mode::ServerSide,
                };
                
                crate::wlog!(crate::util::logging::COMPOSITOR, "Sending zxdg_toplevel_decoration.configure for window {}: {:?}", window_id, preferred_mode);
                decoration.configure(preferred_mode);
                
                // Update window decoration mode
                if let Some(window) = state.get_window(window_id) {
                    let mut window = window.write().unwrap();
                    window.decoration_mode = match preferred_mode {
                        Mode::ClientSide => DecorationMode::ClientSide,
                        Mode::ServerSide => DecorationMode::ServerSide,
                        _ => DecorationMode::ClientSide,
                    };
                }
                
                tracing::debug!(
                    "Created toplevel decoration for window {}: {:?}",
                    window_id, preferred_mode
                );
            }
            zxdg_decoration_manager_v1::Request::Destroy => {
                tracing::debug!("zxdg_decoration_manager_v1 destroyed");
            }
            _ => {}
        }
    }
}

// ============================================================================
// zxdg_toplevel_decoration_v1
// ============================================================================

impl Dispatch<ZxdgToplevelDecorationV1, u32> for CompositorState {
    fn request(
        state: &mut Self,
        _client: &wayland_server::Client,
        resource: &ZxdgToplevelDecorationV1,
        request: zxdg_toplevel_decoration_v1::Request,
        _data: &u32,
        _dhandle: &DisplayHandle,
        _data_init: &mut wayland_server::DataInit<'_, Self>,
    ) {
        let dec_id = resource.id().protocol_id();
        let window_id = *_data;
        
        match request {
            zxdg_toplevel_decoration_v1::Request::SetMode { mode } => {
                tracing::debug!("Client requests decoration mode: {:?}", mode);
                
                // Convert WEnum<Mode> to Mode
                let requested_mode = match mode {
                    wayland_server::WEnum::Value(m) => m,
                    wayland_server::WEnum::Unknown(_) => Mode::ClientSide,
                };
                
                // Determine the actual mode based on policy
                let actual_mode = match state.decoration_policy {
                    DecorationPolicy::ForceServer => Mode::ServerSide,
                    _ => requested_mode,
                };
                
                // Update window
                if let Some(window) = state.get_window(window_id) {
                    let mut window = window.write().unwrap();
                    window.decoration_mode = match actual_mode {
                        Mode::ClientSide => DecorationMode::ClientSide,
                        Mode::ServerSide => DecorationMode::ServerSide,
                        _ => DecorationMode::ClientSide,
                    };
                }
                
                crate::wlog!(crate::util::logging::COMPOSITOR, 
                    "Set decoration mode for window {}: {:?} (requested {:?})",
                    window_id, actual_mode, requested_mode
                );
                
                // Send configure with actual mode
                resource.configure(actual_mode);
            }
            zxdg_toplevel_decoration_v1::Request::UnsetMode => {
                tracing::debug!("Client unsets decoration mode");
                
                // Revert to compositor preference
                let preferred_mode = match state.decoration_policy {
                    DecorationPolicy::PreferClient => Mode::ClientSide,
                    DecorationPolicy::PreferServer => Mode::ServerSide,
                    DecorationPolicy::ForceServer => Mode::ServerSide,
                };
                
                if let Some(data) = state.decorations.get(&dec_id) {
                    if let Some(window) = state.get_window(data.window_id) {
                        let mut window = window.write().unwrap();
                        window.decoration_mode = match preferred_mode {
                            Mode::ClientSide => DecorationMode::ClientSide,
                            Mode::ServerSide => DecorationMode::ServerSide,
                            _ => DecorationMode::ClientSide,
                        };
                    }
                }
                
                resource.configure(preferred_mode);
            }
            zxdg_toplevel_decoration_v1::Request::Destroy => {
                state.decorations.remove(&dec_id);
                tracing::debug!("zxdg_toplevel_decoration_v1 destroyed");
            }
            _ => {}
        }
    }
}
