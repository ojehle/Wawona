pub mod surface;
pub mod buffer;
pub mod role;
pub mod commit;
pub mod damage;

pub use surface::{Surface, SurfaceState};
pub use buffer::{Buffer, BufferType, ShmBufferData, DmaBufData};
pub use role::SurfaceRole;
pub use damage::DamageRegion;

#[cfg(test)]
pub mod tests;
