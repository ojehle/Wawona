
use wayland_server::{
    Dispatch, DisplayHandle, GlobalDispatch, Resource,
};

use crate::core::state::CompositorState;
use crate::core::wayland::wlroots::wlr_foreign_toplevel_management_unstable_v1::{
    zwlr_foreign_toplevel_manager_v1,
    zwlr_foreign_toplevel_handle_v1,
};

pub struct ForeignToplevelManagerData;

impl GlobalDispatch<zwlr_foreign_toplevel_manager_v1::ZwlrForeignToplevelManagerV1, ()> for CompositorState {
    fn bind(
        state: &mut Self,
        handle: &DisplayHandle,
        client: &wayland_server::Client,
        resource: wayland_server::New<zwlr_foreign_toplevel_manager_v1::ZwlrForeignToplevelManagerV1>,
        _global_data: &(),
        data_init: &mut wayland_server::DataInit<'_, Self>,
    ) {
        let manager = data_init.init(resource, ());
        
        // Advertise all existing windows
        for (&window_id, window_lock) in state.windows.iter() {
            let window = window_lock.read().unwrap();
            
            let handle_resource = client.create_resource::<zwlr_foreign_toplevel_handle_v1::ZwlrForeignToplevelHandleV1, u32, CompositorState>(
                handle,
                manager.version(),
                window_id,
            ).expect("Failed to create zwlr_foreign_toplevel_handle_v1");
            
            manager.toplevel(&handle_resource);
            
            // Send initial state
            send_toplevel_info(&handle_resource, &window);
        }
    }
}

impl Dispatch<zwlr_foreign_toplevel_manager_v1::ZwlrForeignToplevelManagerV1, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &wayland_server::Client,
        _resource: &zwlr_foreign_toplevel_manager_v1::ZwlrForeignToplevelManagerV1,
        request: zwlr_foreign_toplevel_manager_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut wayland_server::DataInit<'_, Self>,
    ) {
        match request {
            zwlr_foreign_toplevel_manager_v1::Request::Stop => {
                // Client stops receiving events
            }
            _ => {}
        }
    }
}

impl Dispatch<zwlr_foreign_toplevel_handle_v1::ZwlrForeignToplevelHandleV1, u32> for CompositorState {
    fn request(
        state: &mut Self,
        _client: &wayland_server::Client,
        _resource: &zwlr_foreign_toplevel_handle_v1::ZwlrForeignToplevelHandleV1,
        request: zwlr_foreign_toplevel_handle_v1::Request,
        data: &u32,
        _dhandle: &DisplayHandle,
        _data_init: &mut wayland_server::DataInit<'_, Self>,
    ) {
        let window_id = *data;
        match request {
            zwlr_foreign_toplevel_handle_v1::Request::SetMaximized => {
                if let Some(window_lock) = state.windows.get(&window_id) {
                    let mut window = window_lock.write().unwrap();
                    window.maximized = true;
                    // TODO: Send actual configure event to client
                }
            }
            zwlr_foreign_toplevel_handle_v1::Request::UnsetMaximized => {
                if let Some(window_lock) = state.windows.get(&window_id) {
                    let mut window = window_lock.write().unwrap();
                    window.maximized = false;
                }
            }
            zwlr_foreign_toplevel_handle_v1::Request::SetMinimized => {
                if let Some(window_lock) = state.windows.get(&window_id) {
                    let mut window = window_lock.write().unwrap();
                    window.minimized = true;
                }
            }
            zwlr_foreign_toplevel_handle_v1::Request::UnsetMinimized => {
                if let Some(window_lock) = state.windows.get(&window_id) {
                    let mut window = window_lock.write().unwrap();
                    window.minimized = false;
                }
            }
            zwlr_foreign_toplevel_handle_v1::Request::Activate { seat: _ } => {
                if let Some(window_lock) = state.windows.get(&window_id) {
                    let mut window = window_lock.write().unwrap();
                    window.activated = true;
                    // TODO: Update focus in CompositorState
                }
            }
            zwlr_foreign_toplevel_handle_v1::Request::Close => {
                // Request window close
                // We should probably emit an event for the platform to handle
            }
            zwlr_foreign_toplevel_handle_v1::Request::SetRectangle { surface: _, x: _, y: _, width: _, height: _ } => {
                // Informational hint
            }
            zwlr_foreign_toplevel_handle_v1::Request::Destroy => {
                // Destructor
            }
            zwlr_foreign_toplevel_handle_v1::Request::SetFullscreen { output: _ } => {
                if let Some(window_lock) = state.windows.get(&window_id) {
                    let mut window = window_lock.write().unwrap();
                    window.fullscreen = true;
                }
            }
            zwlr_foreign_toplevel_handle_v1::Request::UnsetFullscreen => {
                if let Some(window_lock) = state.windows.get(&window_id) {
                    let mut window = window_lock.write().unwrap();
                    window.fullscreen = false;
                }
            }
            _ => {}
        }
    }
}

/// Helper to send all information about a toplevel
fn send_toplevel_info(handle: &zwlr_foreign_toplevel_handle_v1::ZwlrForeignToplevelHandleV1, window: &crate::core::window::Window) {
    handle.title(window.title.clone());
    handle.app_id(window.app_id.clone());
    
    // States
    let mut states = Vec::new();
    if window.maximized {
        states.push(zwlr_foreign_toplevel_handle_v1::State::Maximized as u32);
    }
    if window.minimized {
        states.push(zwlr_foreign_toplevel_handle_v1::State::Minimized as u32);
    }
    if window.activated {
        states.push(zwlr_foreign_toplevel_handle_v1::State::Activated as u32);
    }
    if window.fullscreen {
        states.push(zwlr_foreign_toplevel_handle_v1::State::Fullscreen as u32);
    }
    
    // Convert Vec<u32> to &[u8] for Wayland array
    let states_bytes: &[u8] = unsafe {
        std::slice::from_raw_parts(
            states.as_ptr() as *const u8,
            states.len() * std::mem::size_of::<u32>(),
        )
    };
    handle.state(states_bytes.to_vec());
    
    // Outputs (TODO: Real output tracking)
    // For now, we don't send any output_enter events here as we don't have the WlOutput resources easily available
    
    handle.done();
}
