use crate::core::surface::*;
use crate::core::surface::role::SurfaceRole;

#[test]
fn test_surface_init() {
    let surface = Surface::new(1, None);
    assert_eq!(surface.id, 1);
    assert!(surface.role.is_none());
}

#[test]
fn test_surface_commit() {
    let mut surface = Surface::new(1, None);
    
    // Initial state
    assert_eq!(surface.current.width, 0);
    assert_eq!(surface.current.height, 0);
    assert_eq!(surface.pending.width, 0);
    
    // Modify pending
    surface.pending.width = 100;
    surface.pending.height = 200;
    surface.pending.opaque = true;
    
    // Commit
    surface.commit();
    
    // Check current
    assert_eq!(surface.current.width, 100);
    assert_eq!(surface.current.height, 200);
    assert_eq!(surface.current.opaque, true);
    
    // Only damage should be drained, pending values persist until changed
    assert_eq!(surface.pending.width, 100); 
}

#[test]
fn test_surface_damage() {
    let mut surface = Surface::new(2, None);
    
    // Add damage to pending
    let region = DamageRegion::new(0, 0, 10, 10);
    surface.pending.damage.push(region);
    
    // Commit
    surface.commit();
    
    // Check current damage
    assert_eq!(surface.current.damage.len(), 1);
    assert_eq!(surface.current.damage[0], region);
    
    // Pending damage should be cleared (drained)
    assert!(surface.pending.damage.is_empty());
    
    // Second commit
    let region2 = DamageRegion::new(10, 10, 20, 20);
    surface.pending.damage.push(region2);
    surface.commit();
    
    // Current damage should accumulate
    assert_eq!(surface.current.damage.len(), 2);
    assert_eq!(surface.current.damage[1], region2);
}

#[test]
fn test_surface_role() {
    let mut surface = Surface::new(3, None);
    assert!(surface.role.is_none());
    
    assert!(surface.set_role(SurfaceRole::Toplevel).is_ok());
    assert_eq!(surface.role, SurfaceRole::Toplevel);
    
    assert!(surface.set_role(SurfaceRole::Toplevel).is_ok()); // Same role ok
    
    assert!(surface.set_role(SurfaceRole::Cursor).is_err()); // Change role err
}
