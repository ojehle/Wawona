//! XDG Foreign protocol implementation.
//!
//! This protocol allows clients to embed windows from other clients,
//! enabling cross-client window embedding scenarios.


use wayland_server::{
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New, Resource,
};
use wayland_protocols::xdg::foreign::zv2::server::{
    zxdg_exporter_v2::{self, ZxdgExporterV2},
    zxdg_exported_v2::{self, ZxdgExportedV2},
    zxdg_importer_v2::{self, ZxdgImporterV2},
    zxdg_imported_v2::{self, ZxdgImportedV2},
};

use crate::core::state::{CompositorState, ExportedToplevelData, ImportedToplevelData};

// ============================================================================
// zxdg_exporter_v2
// ============================================================================

impl GlobalDispatch<ZxdgExporterV2, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<ZxdgExporterV2>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
        tracing::debug!("Bound zxdg_exporter_v2");
    }
}

impl Dispatch<ZxdgExporterV2, ()> for CompositorState {
    fn request(
        state: &mut Self,
        _client: &Client,
        _resource: &ZxdgExporterV2,
        request: zxdg_exporter_v2::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            zxdg_exporter_v2::Request::ExportToplevel { id, surface } => {
                // Get the toplevel from the surface
                let toplevel_id = surface.id().protocol_id();
                let handle = format!("wawona:{}", toplevel_id);
                
                let exported_data = ExportedToplevelData {
                    toplevel_id,
                    handle: handle.clone(),
                };
                
                let exported = data_init.init(id, ());
                
                // Send the handle to the client
                exported.handle(handle.clone());
                
                state.exported_toplevels.insert(exported.id().protocol_id(), exported_data);
                
                tracing::debug!("Exported toplevel {} with handle {}", toplevel_id, handle);
            }
            zxdg_exporter_v2::Request::Destroy => {
                tracing::debug!("zxdg_exporter_v2 destroyed");
            }
            _ => {}
        }
    }
}

// ============================================================================
// zxdg_importer_v2
// ============================================================================

impl GlobalDispatch<ZxdgImporterV2, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<ZxdgImporterV2>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
        tracing::debug!("Bound zxdg_importer_v2");
    }
}

impl Dispatch<ZxdgImporterV2, ()> for CompositorState {
    fn request(
        state: &mut Self,
        _client: &Client,
        _resource: &ZxdgImporterV2,
        request: zxdg_importer_v2::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            zxdg_importer_v2::Request::ImportToplevel { id, handle } => {
                let imported_data = ImportedToplevelData {
                    handle: handle.clone(),
                };
                
                let imported = data_init.init(id, ());
                state.imported_toplevels.insert(imported.id().protocol_id(), imported_data);
                
                tracing::debug!("Imported toplevel with handle {}", handle);
            }
            zxdg_importer_v2::Request::Destroy => {
                tracing::debug!("zxdg_importer_v2 destroyed");
            }
            _ => {}
        }
    }
}

// ============================================================================
// zxdg_exported_v2
// ============================================================================

impl Dispatch<ZxdgExportedV2, ()> for CompositorState {
    fn request(
        state: &mut Self,
        _client: &Client,
        resource: &ZxdgExportedV2,
        request: zxdg_exported_v2::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            zxdg_exported_v2::Request::Destroy => {
                state.exported_toplevels.remove(&resource.id().protocol_id());
                tracing::debug!("zxdg_exported_v2 destroyed");
            }
            _ => {}
        }
    }
}

// ============================================================================
// zxdg_imported_v2
// ============================================================================

impl Dispatch<ZxdgImportedV2, ()> for CompositorState {
    fn request(
        state: &mut Self,
        _client: &Client,
        resource: &ZxdgImportedV2,
        request: zxdg_imported_v2::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            zxdg_imported_v2::Request::SetParentOf { surface } => {
                tracing::debug!("Set parent of imported toplevel");
                let _ = surface;
            }
            zxdg_imported_v2::Request::Destroy => {
                state.imported_toplevels.remove(&resource.id().protocol_id());
                tracing::debug!("zxdg_imported_v2 destroyed");
            }
            _ => {}
        }
    }
}

/// Register zxdg_exporter_v2 global
pub fn register_xdg_exporter(display: &DisplayHandle) -> wayland_server::backend::GlobalId {
    display.create_global::<CompositorState, ZxdgExporterV2, ()>(2, ())
}

/// Register zxdg_importer_v2 global
pub fn register_xdg_importer(display: &DisplayHandle) -> wayland_server::backend::GlobalId {
    display.create_global::<CompositorState, ZxdgImporterV2, ()>(2, ())
}
