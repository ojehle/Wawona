//! wl_seat protocol implementation.
//!
//! The seat is the primary abstraction for input devices. It represents
//! a collection of input devices (keyboard, pointer, touch) that are
//! logically grouped together.

use wayland_server::{
    protocol::{wl_seat, wl_pointer, wl_keyboard, wl_touch},
    Dispatch, Resource, DisplayHandle, GlobalDispatch,
};

use crate::core::state::CompositorState;

/// Seat global data
pub struct SeatGlobal {
    pub name: String,
}

impl Default for SeatGlobal {
    fn default() -> Self {
        Self {
            name: "seat0".to_string(),
        }
    }
}

// ============================================================================
// wl_seat
// ============================================================================

impl GlobalDispatch<wl_seat::WlSeat, SeatGlobal> for CompositorState {
    fn bind(
        state: &mut Self,
        _handle: &DisplayHandle,
        _client: &wayland_server::Client,
        resource: wayland_server::New<wl_seat::WlSeat>,
        global_data: &SeatGlobal,
        data_init: &mut wayland_server::DataInit<'_, Self>,
    ) {
        let seat = data_init.init(resource, ());
        crate::wlog!(crate::util::logging::SEAT, "DEBUG: Seat Bind Called for client {:?}", _client.id());
        state.seat_resources.insert(seat.id().protocol_id(), seat.clone());
        
        // Send capabilities
        seat.capabilities(
            wl_seat::Capability::Pointer | 
            wl_seat::Capability::Keyboard
        );
        
        // Send name (version 2+)
        if seat.version() >= 2 {
            seat.name(global_data.name.clone());
        }
        
        tracing::debug!("Bound wl_seat with pointer+keyboard capabilities");
    }
}

impl Dispatch<wl_seat::WlSeat, ()> for CompositorState {
    fn request(
        state: &mut Self,
        _client: &wayland_server::Client,
        _resource: &wl_seat::WlSeat,
        request: wl_seat::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut wayland_server::DataInit<'_, Self>,
    ) {
        match request {
            wl_seat::Request::GetPointer { id } => {
                let pointer = data_init.init(id, ());
                tracing::debug!("Created wl_pointer");
                
                state.seat.add_pointer(pointer);
            }
            wl_seat::Request::GetKeyboard { id } => {
                let keyboard = data_init.init(id, ());
                crate::wlog!(crate::util::logging::SEAT, "Created wl_keyboard resource");
                
                // Send keymap
                // For now, send a minimal "no keymap" response
                // In a full implementation, we'd use xkbcommon to create a proper keymap
                send_keymap(&keyboard);
                crate::wlog!(crate::util::logging::SEAT, "Sent keymap to client");
                
                state.seat.add_keyboard(keyboard);
                crate::wlog!(crate::util::logging::SEAT, "Added keyboard to seat (total: {})", 
                    state.seat.keyboards.len());
            }
            wl_seat::Request::GetTouch { id } => {
                let touch = data_init.init(id, ());
                tracing::debug!("Created wl_touch");
                state.seat.add_touch(touch);
            }
            wl_seat::Request::Release => {
                tracing::debug!("wl_seat released");
            }
            _ => {}
        }
    }
}

// ============================================================================
// wl_pointer
// ============================================================================

impl Dispatch<wl_pointer::WlPointer, ()> for CompositorState {
    fn request(
        state: &mut Self,
        _client: &wayland_server::Client,
        _resource: &wl_pointer::WlPointer,
        request: wl_pointer::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut wayland_server::DataInit<'_, Self>,
    ) {
        match request {
            wl_pointer::Request::SetCursor { serial: _, surface, hotspot_x, hotspot_y } => {
                let surface_id = surface.as_ref().map(|s| s.id().protocol_id());
                state.seat.cursor_surface = surface_id;
                state.seat.cursor_hotspot_x = hotspot_x as f64;
                state.seat.cursor_hotspot_y = hotspot_y as f64;
                
                tracing::debug!(
                    "wl_pointer.set_cursor: surface={:?}, hotspot=({}, {})",
                    surface_id, hotspot_x, hotspot_y
                );
            }
            wl_pointer::Request::Release => {
                tracing::debug!("wl_pointer released");
            }
            _ => {}
        }
    }
}

// ============================================================================
// wl_keyboard
// ============================================================================

impl Dispatch<wl_keyboard::WlKeyboard, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &wayland_server::Client,
        _resource: &wl_keyboard::WlKeyboard,
        request: wl_keyboard::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut wayland_server::DataInit<'_, Self>,
    ) {
        match request {
            wl_keyboard::Request::Release => {
                tracing::debug!("wl_keyboard released");
            }
            _ => {}
        }
    }
}

// ============================================================================
// wl_touch
// ============================================================================

impl Dispatch<wl_touch::WlTouch, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &wayland_server::Client,
        _resource: &wl_touch::WlTouch,
        request: wl_touch::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut wayland_server::DataInit<'_, Self>,
    ) {
        match request {
            wl_touch::Request::Release => {
                tracing::debug!("wl_touch released");
            }
            _ => {}
        }
    }
}

// ============================================================================
// Helpers
// ============================================================================

/// Send a minimal keymap to the keyboard.
/// 
/// A real implementation would use xkbcommon to create a proper keymap,
/// but for now we send a minimal XKB keymap that clients can parse.
fn send_keymap(keyboard: &wl_keyboard::WlKeyboard) {
    use std::os::unix::io::AsFd;
    use xkbcommon::xkb;
    
    crate::wlog!(crate::util::logging::SEAT, "Generating XKB keymap using xkbcommon...");
    
    // Create XKB context
    let context = xkb::Context::new(xkb::CONTEXT_NO_FLAGS);
    
    // Generate keymap from RMLVO (same as C implementation)
    let keymap = xkb::Keymap::new_from_names(
        &context,
        "",           // rules (use defaults)
        "pc105",      // model (standard 105-key PC keyboard)
        "us",         // layout (US QWERTY)
        "",           // variant (none)
        None,         // options (none)
        xkb::KEYMAP_COMPILE_NO_FLAGS,
    );
    
    if let Some(keymap) = keymap {
        // Serialize keymap to string
        let keymap_str = keymap.get_as_string(xkb::KEYMAP_FORMAT_TEXT_V1);
        
        crate::wlog!(crate::util::logging::SEAT, "Generated keymap: {} bytes", 
            keymap_str.len());
        
        // Create memfd for keymap
        match create_keymap_fd(&keymap_str) {
            Ok(fd) => {
                keyboard.keymap(
                    wl_keyboard::KeymapFormat::XkbV1,
                    fd.as_fd(),
                    keymap_str.len() as u32,
                );
                crate::wlog!(crate::util::logging::SEAT, "Sent xkbcommon keymap to client");
            }
            Err(e) => {
                crate::wlog!(crate::util::logging::SEAT, "ERROR: Failed to create keymap fd: {}", e);
            }
        }
    } else {
        crate::wlog!(crate::util::logging::SEAT, "ERROR: Failed to generate XKB keymap from xkbcommon");
    }
}

/// Create a file descriptor containing the keymap string.
fn create_keymap_fd(keymap: &str) -> std::io::Result<std::os::unix::io::OwnedFd> {
    use std::os::unix::io::{FromRawFd, IntoRawFd};
    use std::io::{Write, Seek};
    
    #[cfg(target_os = "linux")]
    {
        use std::ffi::CString;
        let name = CString::new("wawona-keymap").unwrap();
        let fd = unsafe { libc::memfd_create(name.as_ptr(), libc::MFD_CLOEXEC) };
        if fd < 0 {
            return Err(std::io::Error::last_os_error());
        }
        
        let mut file = unsafe { std::fs::File::from_raw_fd(fd) };
        file.write_all(keymap.as_bytes())?;
        file.write_all(&[0])?; // Null terminator
        
        // Return owned fd
        Ok(unsafe { std::os::unix::io::OwnedFd::from_raw_fd(file.into_raw_fd()) })
    }
    
    #[cfg(target_os = "macos")]
    {
        // macOS doesn't have memfd_create. Use temp file + unlink (same as C implementation)
        // This creates an anonymous fd that persists until all fd refs are closed

        use std::os::unix::fs::OpenOptionsExt;
        
        let tmp_path = format!("/tmp/wawona-keymap.{}.{}", 
                              std::process::id(),
                              chrono::Local::now().timestamp_nanos_opt().unwrap_or(0));
        
        // Create temporary file
        let mut file = std::fs::OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .truncate(true)
            .mode(0o600)
            .open(&tmp_path)?;
        
        // Write keymap
        file.write_all(keymap.as_bytes())?;
        file.write_all(&[0])?; // Null terminator
        
        // Immediately unlink so file is anonymous (deleted when fd closes)
        std::fs::remove_file(&tmp_path)?;
        
        // Seek to start for client to read
        file.seek(std::io::SeekFrom::Start(0))?;
        
        crate::wlog!(crate::util::logging::SEAT, "Created temp keymap file (anonymous fd)");
        
        // Return owned fd
        Ok(unsafe { std::os::unix::io::OwnedFd::from_raw_fd(file.into_raw_fd()) })
    }
    
    #[cfg(not(any(target_os = "linux", target_os = "macos")))]
    {
        Err(std::io::Error::new(
            std::io::ErrorKind::Unsupported,
            "Platform not supported for keymap fd",
        ))
    }
}
