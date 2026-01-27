//! XDG Toplevel protocol implementation.
//!
//! This implements the xdg_toplevel protocol from the xdg-shell extension.
//! It provides the interface for managing toplevel (window) surfaces.

use wayland_server::{
    Dispatch, DisplayHandle, Resource,
};
use crate::core::wayland::protocol::server::xdg::shell::server::xdg_toplevel;

use crate::core::state::CompositorState;

impl Dispatch<xdg_toplevel::XdgToplevel, u32> for CompositorState {
    fn request(
        state: &mut Self,
        _client: &wayland_server::Client,
        resource: &xdg_toplevel::XdgToplevel,
        request: xdg_toplevel::Request,
        _data: &u32,
        _dhandle: &DisplayHandle,
        _data_init: &mut wayland_server::DataInit<'_, Self>,
    ) {
        let toplevel_id = resource.id().protocol_id();
        let _window_id = *_data;
        let data = state.xdg_toplevels.get(&toplevel_id).cloned();
        
        match request {
            xdg_toplevel::Request::SetTitle { title } => {
                tracing::debug!("xdg_toplevel.set_title: \"{}\"", title);
                if let Some(data) = &data {
                    if let Some(window) = state.get_window(data.window_id) {
                        {
                            let mut window = window.write().unwrap();
                            window.title = title.clone();
                        }
                        
                        // Push event for platform
                        state.pending_compositor_events.push(
                            crate::core::compositor::CompositorEvent::WindowTitleChanged {
                                window_id: data.window_id,
                                title,
                            }
                        );
                    }
                }
            }
            xdg_toplevel::Request::SetAppId { app_id } => {
                tracing::debug!("xdg_toplevel.set_app_id: \"{}\"", app_id);
                // Store app_id - could be used for window grouping
            }
            xdg_toplevel::Request::SetMaxSize { width, height } => {
                tracing::trace!("xdg_toplevel.set_max_size: {}x{}", width, height);
            }
            xdg_toplevel::Request::SetMinSize { width, height } => {
                tracing::trace!("xdg_toplevel.set_min_size: {}x{}", width, height);
            }
            xdg_toplevel::Request::SetMaximized => {
                tracing::debug!("xdg_toplevel.set_maximized");
                if let Some(data) = &data {
                    if let Some(window) = state.get_window(data.window_id) {
                        let mut window = window.write().unwrap();
                        window.maximized = true;
                        // TODO: Send configure with Maximized state
                    }
                }
            }
            xdg_toplevel::Request::UnsetMaximized => {
                tracing::debug!("xdg_toplevel.unset_maximized");
                if let Some(data) = &data {
                    if let Some(window) = state.get_window(data.window_id) {
                        let mut window = window.write().unwrap();
                        window.maximized = false;
                    }
                }
            }
            xdg_toplevel::Request::SetFullscreen { output: _ } => {
                tracing::debug!("xdg_toplevel.set_fullscreen");
                if let Some(data) = &data {
                    if let Some(window) = state.get_window(data.window_id) {
                        let mut window = window.write().unwrap();
                        window.fullscreen = true;
                    }
                }
            }
            xdg_toplevel::Request::UnsetFullscreen => {
                tracing::debug!("xdg_toplevel.unset_fullscreen");
                if let Some(data) = &data {
                    if let Some(window) = state.get_window(data.window_id) {
                        let mut window = window.write().unwrap();
                        window.fullscreen = false;
                    }
                }
            }
            xdg_toplevel::Request::SetMinimized => {
                tracing::debug!("xdg_toplevel.set_minimized");
                if let Some(data) = &data {
                    if let Some(window) = state.get_window(data.window_id) {
                        let mut window = window.write().unwrap();
                        window.minimized = true;
                    }
                }
            }
            xdg_toplevel::Request::Move { seat: _, serial: _ } => {
                tracing::debug!("xdg_toplevel.move requested");
                // TODO: Verify serial and seat
                if let Some(data) = &data {
                    if let Some(_client) = state.focused_pointer_client() {
                         // Check if implicit grab exists and start interactive move
                         // For now, we'll just log it. Actual logic needs pointer focus check.
                         tracing::info!("Starting interactive move for window {}", data.window_id);
                         // state.seat.start_interactive_move(data.window_id); 
                    }
                }
            }
            xdg_toplevel::Request::Resize { seat: _, serial: _, edges } => {
                tracing::debug!("xdg_toplevel.resize requested: edges={:?}", edges);
                if let Some(data) = &data {
                    if let Some(_client) = state.focused_pointer_client() {
                        tracing::info!("Starting interactive resize for window {}", data.window_id);
                         // state.seat.start_interactive_resize(data.window_id, edges);
                    }
                }
            }
            xdg_toplevel::Request::ShowWindowMenu { seat: _, serial: _, x, y } => {
                tracing::debug!("xdg_toplevel.show_window_menu at ({}, {})", x, y);
             }
            xdg_toplevel::Request::Destroy => {
                if let Some(data) = &data {
                    tracing::debug!("xdg_toplevel destroyed: window_id={}", data.window_id);
                    state.remove_window(data.window_id);
                }
                state.xdg_toplevels.remove(&toplevel_id);
            }
            _ => {}
        }
    }
}
