//! WP Pointer Constraints protocol implementation.
//!
//! This protocol allows clients to lock or confine the pointer:
//! - Lock: Pointer is hidden and all motion is relative
//! - Confine: Pointer is constrained to a region


use wayland_server::{
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New, Resource,
};
use wayland_protocols::wp::pointer_constraints::zv1::server::{
    zwp_pointer_constraints_v1::{self, ZwpPointerConstraintsV1, Lifetime},
    zwp_locked_pointer_v1::{self, ZwpLockedPointerV1},
    zwp_confined_pointer_v1::{self, ZwpConfinedPointerV1},
};


use crate::core::state::{CompositorState, LockedPointerData, ConfinedPointerData, ConstraintLifetime};

// ============================================================================
// Data Types
// ============================================================================

impl From<Lifetime> for ConstraintLifetime {
    fn from(l: Lifetime) -> Self {
        match l {
            Lifetime::Persistent => Self::Persistent,
            Lifetime::Oneshot => Self::Oneshot,
            _ => Self::Oneshot,
        }
    }
}

impl From<wayland_server::WEnum<Lifetime>> for ConstraintLifetime {
    fn from(l: wayland_server::WEnum<Lifetime>) -> Self {
        match l {
            wayland_server::WEnum::Value(Lifetime::Persistent) => Self::Persistent,
            wayland_server::WEnum::Value(Lifetime::Oneshot) => Self::Oneshot,
            _ => Self::Oneshot,
        }
    }
}

// ============================================================================
// zwp_pointer_constraints_v1
// ============================================================================

impl GlobalDispatch<ZwpPointerConstraintsV1, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<ZwpPointerConstraintsV1>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
        tracing::debug!("Bound zwp_pointer_constraints_v1");
    }
}

impl Dispatch<ZwpPointerConstraintsV1, ()> for CompositorState {
    fn request(
        state: &mut Self,
        _client: &Client,
        resource: &ZwpPointerConstraintsV1,
        request: zwp_pointer_constraints_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            zwp_pointer_constraints_v1::Request::LockPointer {
                id,
                surface,
                pointer,
                region,
                lifetime,
            } => {
                let surface_id = surface.id().protocol_id();
                let pointer_id = pointer.id().protocol_id();
                
                let data = LockedPointerData {
                    surface_id,
                    pointer_id,
                    lifetime: lifetime.into(),
                    active: false,
                };
                
                let locked = data_init.init(id, ());
                let locked_id = locked.id().protocol_id();
                state.locked_pointers.insert(locked_id, data);
                
                // In a real implementation, we'd check if the surface has focus
                // and activate the lock immediately if so
                
                tracing::debug!(
                    "Created locked pointer for surface {} (lifetime={:?})",
                    surface_id,
                    lifetime
                );
                
                let _ = region; // TODO: Use region for constraint area
            }
            zwp_pointer_constraints_v1::Request::ConfinePointer {
                id,
                surface,
                pointer,
                region,
                lifetime,
            } => {
                let surface_id = surface.id().protocol_id();
                let pointer_id = pointer.id().protocol_id();
                
                let data = ConfinedPointerData {
                    surface_id,
                    pointer_id,
                    lifetime: lifetime.into(),
                    active: false,
                };
                
                let confined = data_init.init(id, ());
                let confined_id = confined.id().protocol_id();
                state.confined_pointers.insert(confined_id, data);
                
                tracing::debug!(
                    "Created confined pointer for surface {} (lifetime={:?})",
                    surface_id,
                    lifetime
                );
                
                let _ = region; // TODO: Use region for constraint area
            }
            zwp_pointer_constraints_v1::Request::Destroy => {
                tracing::debug!("zwp_pointer_constraints_v1 destroyed");
            }
            _ => {}
        }
        let _ = resource;
    }
}

// ============================================================================
// zwp_locked_pointer_v1
// ============================================================================

impl Dispatch<ZwpLockedPointerV1, ()> for CompositorState {
    fn request(
        state: &mut Self,
        _client: &Client,
        resource: &ZwpLockedPointerV1,
        request: zwp_locked_pointer_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            zwp_locked_pointer_v1::Request::SetCursorPositionHint { surface_x, surface_y } => {
                tracing::debug!(
                    "Locked pointer cursor hint: ({}, {})",
                    surface_x, surface_y
                );
            }
            zwp_locked_pointer_v1::Request::SetRegion { region } => {
                tracing::debug!("Locked pointer region updated");
                let _ = region;
            }
            zwp_locked_pointer_v1::Request::Destroy => {
                state.locked_pointers.remove(&resource.id().protocol_id());
                tracing::debug!("Locked pointer destroyed");
            }
            _ => {}
        }
        let _ = resource;
    }
}

// ============================================================================
// zwp_confined_pointer_v1
// ============================================================================

impl Dispatch<ZwpConfinedPointerV1, ()> for CompositorState {
    fn request(
        state: &mut Self,
        _client: &Client,
        resource: &ZwpConfinedPointerV1,
        request: zwp_confined_pointer_v1::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            zwp_confined_pointer_v1::Request::SetRegion { region } => {
                tracing::debug!("Confined pointer region updated");
                let _ = region;
            }
            zwp_confined_pointer_v1::Request::Destroy => {
                state.confined_pointers.remove(&resource.id().protocol_id());
                tracing::debug!("Confined pointer destroyed");
            }
            _ => {}
        }
        let _ = resource;
    }
}

/// Register zwp_pointer_constraints_v1 global
pub fn register_pointer_constraints(display: &DisplayHandle) -> wayland_server::backend::GlobalId {
    display.create_global::<CompositorState, ZwpPointerConstraintsV1, ()>(1, ())
}
