#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SurfaceRole {
    None,
    Toplevel,
    Popup,
    Subsurface,
    Cursor,
    Layer,
}

impl Default for SurfaceRole {
    fn default() -> Self {
        Self::None
    }
}

impl SurfaceRole {
    pub fn is_none(&self) -> bool {
        matches!(self, SurfaceRole::None)
    }

    pub fn name(&self) -> &'static str {
        match self {
            SurfaceRole::None => "none",
            SurfaceRole::Toplevel => "toplevel",
            SurfaceRole::Popup => "popup",
            SurfaceRole::Subsurface => "subsurface",
            SurfaceRole::Cursor => "cursor",
            SurfaceRole::Layer => "layer",
        }
    }
}
