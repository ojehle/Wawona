

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DecorationMode {
    ClientSide,
    ServerSide,
}

/// Represents a top-level window (XDG Toplevel).
///
/// Corresponds to `WawonaWindowContainer`.
pub struct Window {
    pub id: u32,
    pub title: String,
    pub width: i32,
    pub height: i32,
    pub decoration_mode: DecorationMode,
    pub surface_id: u32,
    pub app_id: String,
    
    // Window state
    pub maximized: bool,
    pub minimized: bool,
    pub fullscreen: bool,
    pub activated: bool,
    pub resizing: bool,
    
    /// IDs of outputs this window is visible on
    pub outputs: Vec<u32>,
}

impl Window {
    pub fn new(id: u32, surface_id: u32) -> Self {
        Self {
            id,
            title: "Wawona Window".to_string(),
            width: 800,
            height: 600,
            decoration_mode: DecorationMode::ClientSide,
            surface_id,
            app_id: "".to_string(),
            maximized: false,
            minimized: false,
            fullscreen: false,
            activated: false,
            resizing: false,
            outputs: Vec::new(),
        }
    }

    pub fn geometry(&self) -> crate::util::geometry::Rect {
        crate::util::geometry::Rect {
            x: 0, // TODO: Window position management
            y: 0,
            width: self.width as u32,
            height: self.height as u32,
        }
    }
}
