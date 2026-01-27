

#[derive(Debug, Clone, Default, Copy, PartialEq, Eq)]
pub struct DamageRegion {
    pub x: i32,
    pub y: i32,
    pub width: i32,
    pub height: i32,
}

impl DamageRegion {
    pub fn new(x: i32, y: i32, width: i32, height: i32) -> Self {
        Self { x, y, width, height }
    }

    /// Check if this region intersects with another
    pub fn intersects(&self, other: &DamageRegion) -> bool {
        self.x < other.x + other.width &&
        self.x + self.width > other.x &&
        self.y < other.y + other.height &&
        self.y + self.height > other.y
    }
}

/// Tracks accumulated damage over multiple commits
#[derive(Debug, Clone, Default)]
pub struct DamageHistory {
    pub regions: Vec<DamageRegion>,
}

impl DamageHistory {
    pub fn add(&mut self, region: DamageRegion) {
        self.regions.push(region);
        // In a full implementation, we'd merge overlapping regions 
        // to keep the list short and rendering efficient.
    }

    pub fn clear(&mut self) {
        self.regions.clear();
    }
}
