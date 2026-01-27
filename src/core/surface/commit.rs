use crate::core::surface::surface::SurfaceState;

/// Performs the atomic update of a surface state.
/// Returns the ID of the buffer that was replaced and should be released, if any.
pub fn apply_commit(pending: &mut SurfaceState, current: &mut SurfaceState) -> Option<u32> {
    // Check if buffer is changing
    let old_buffer = if pending.buffer_id != current.buffer_id {
        current.buffer_id
    } else {
        None
    };

    // 1. Update buffer if pending
    current.buffer = pending.buffer.clone();
    current.buffer_id = pending.buffer_id;
    
    // 2. Update dimensions
    current.width = pending.width;
    current.height = pending.height;
    
    // 3. Accumulate damage
    // Note: In some protocols, damage is relative to the buffer.
    // For now, we just copy it over or merge it.
    current.damage.extend(pending.damage.drain(..));
    
    // 4. Update other attributes
    current.opaque = pending.opaque;
    current.scale = pending.scale;
    current.transform = pending.transform;
    current.offset = pending.offset;
    current.input_region = pending.input_region.clone();
    current.opaque_region = pending.opaque_region.clone();
    
    // Note: pending.buffer remains the same until next attach
    // but damage is cleared by the drain above.
    
    old_buffer
}
