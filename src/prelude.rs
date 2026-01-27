//! Common imports and types used throughout Wawona.

pub use std::sync::{Arc, RwLock};
pub use std::collections::HashMap;

// Add common internal types here
pub type Result<T> = std::result::Result<T, crate::core::errors::CoreError>;
