//! Window management, clipboard/DnD, and decoration methods.
//!
//! Contains `CompositorState` methods for window lifecycle, decoration
//! reconfiguration, clipboard selection, and drag-and-drop operations.

use wayland_server::protocol::wl_data_device_manager::DndAction;

use super::*;

impl CompositorState {
    /// Add a window (Legacy - delegating to register_window)
    pub fn add_window(&mut self, window: Window) -> u32 {
        let surface_id = window.surface_id;
        self.register_window(surface_id, window)
    }
    
    /// Remove a window (Delegating to destroy_window)
    pub fn remove_window(&mut self, window_id: u32) {
        self.destroy_window(window_id);
    }
    
    /// Get window for surface
    pub fn get_window_for_surface(&self, surface_id: u32) -> Option<Arc<RwLock<Window>>> {
        self.get_window_by_surface(surface_id)
    }
    
    /// Re-configure a window to ensure it updates its decoration mode.
    pub fn reconfigure_window_decorations(&mut self, window_id: u32) {
        let mut surface_res = None;
        let mut toplevel_res = None;
        let mut internal_surface_id = 0;
        let mut current_states = Vec::new();
        
        for ((client_id, _), tl) in self.xdg.toplevels.iter() {
            if tl.window_id == window_id {
                internal_surface_id = tl.surface_id;
                toplevel_res = tl.resource.clone();
                
                if tl.activated {
                    use crate::core::wayland::protocol::server::xdg::shell::server::xdg_toplevel::State;
                    current_states.push(State::Activated);
                }
                
                if internal_surface_id != 0 {
                    if let Some(surf) = self.xdg.surfaces.get(&(client_id.clone(), internal_surface_id)) {
                        surface_res = surf.resource.clone();
                    }
                }
                break;
            }
        }
        
        if let Some(tl) = toplevel_res {
            let (width, height) = if let Some(window) = self.windows.get(&window_id) {
                let window = window.read().unwrap();
                (window.width as i32, window.height as i32)
            } else {
                (0, 0)
            };
            
            let mut states_bytes = Vec::new();
            for state in current_states {
                let val = state as u32;
                states_bytes.extend_from_slice(&val.to_ne_bytes());
            }
            tl.configure(width, height, states_bytes);
            
            if let Some(surf) = surface_res {
                let serial = self.next_serial();
                surf.configure(serial);
                crate::wlog!(crate::util::logging::COMPOSITOR, "Sent full configure sequence (serial={}, size={}x{}) to window {} for decoration update", serial, width, height, window_id);
            }
        }
    }

    /// Register a new window for a surface
    pub fn register_window(&mut self, surface_id: u32, window: Window) -> u32 {
        let window_id = window.id;
        self.windows.insert(window_id, Arc::new(RwLock::new(window)));
        self.surface_to_window.insert(surface_id, window_id);
        self.window_tree.insert(window_id);
        
        self.focus.set_keyboard_focus(Some(window_id));
        if let Some(old_focus_wid) = self.focus.pointer_focus {
            if let Some(old_window) = self.windows.get(&old_focus_wid) {
                let (sid, cid) = {
                    let w = old_window.read().unwrap();
                    let sid = w.surface_id;
                    let cid = self.get_surface(sid).and_then(|s| s.read().unwrap().client_id.clone());
                    (sid, cid)
                };
                if let Some(cid) = cid {
                    self.ext.pointer_constraints.deactivate_constraints(cid, sid);
                }
            }
        }
        self.focus.set_pointer_focus(Some(window_id));
        
        let client_id = self.get_surface(surface_id).and_then(|s| s.read().unwrap().client_id.clone());
        if let Some(cid) = client_id {
            self.ext.pointer_constraints.activate_constraints(cid, surface_id);
        }
        self.window_tree.bring_to_front(window_id);
        
        tracing::info!("Registered window {} for surface {}", window_id, surface_id);
        window_id
    }

    /// Get a window by ID
    pub fn get_window(&self, window_id: u32) -> Option<Arc<RwLock<Window>>> {
        self.windows.get(&window_id).cloned()
    }
    
    /// Get a window by Surface ID
    pub fn get_window_by_surface(&self, surface_id: u32) -> Option<Arc<RwLock<Window>>> {
        let wid = self.surface_to_window.get(&surface_id)?;
        self.get_window(*wid)
    }

    /// Destroy a window
    pub fn destroy_window(&mut self, window_id: u32) {
        if let Some(window) = self.windows.remove(&window_id) {
            let surface_id = window.read().unwrap().surface_id;
            self.surface_to_window.remove(&surface_id);
            self.window_tree.remove(window_id);
            
            if self.focus.has_keyboard_focus(window_id) {
                let next = self.focus.focus_history.first().copied();
                self.focus.set_keyboard_focus(next);
            }
            if let Some(old_focus_wid) = self.focus.pointer_focus {
                if old_focus_wid == window_id {
                    let (sid, cid) = {
                        let w = window.read().unwrap(); // window is already removed from map but we have Arc
                        let sid = w.surface_id;
                        let cid = self.get_surface(sid).and_then(|s| s.read().unwrap().client_id.clone());
                        (sid, cid)
                    };
                    if let Some(cid) = cid {
                        self.ext.pointer_constraints.deactivate_constraints(cid, sid);
                    }
                    self.focus.set_pointer_focus(None);
                }
            }
            
            tracing::info!("Destroyed window {}", window_id);
            
            self.pending_compositor_events.push(crate::core::compositor::CompositorEvent::WindowDestroyed {
                window_id,
            });
        }
    }

    // =========================================================================
    // Clipboard & Drag-and-Drop
    // =========================================================================
    
    /// Set the current clipboard source
    pub fn set_clipboard_source(&mut self, dh: &wayland_server::DisplayHandle, source: Option<SelectionSource>) {
        tracing::debug!("Clipboard source set to: {:?}", source);
        self.seat.current_selection = source;
        
        let devices: Vec<wayland_server::protocol::wl_data_device::WlDataDevice> = self.data.devices.values()
            .map(|d| d.resource.clone())
            .collect();
            
        for device in devices {
             if let Some(client) = device.client() {
                 if let Some(src) = &self.seat.current_selection {
                     let version = device.version();
                     let offer = client.create_resource::<wayland_server::protocol::wl_data_offer::WlDataOffer, (), CompositorState>(
                         dh,
                         version,
                         ()
                     ).unwrap();
                     
                     device.data_offer(&offer);
                     
                     let (source_id, source_dnd_actions) = match src {
                         SelectionSource::Wayland(s) => {
                             let id = s.id().protocol_id();
                            let actions = self.data.sources.get(&id)
                                .map(|d| d.dnd_actions).unwrap_or(DndAction::empty());
                             if let Some(data) = self.data.sources.get(&id) {
                                 for mime in &data.mime_types {
                                     offer.offer(mime.clone());
                                 }
                             }
                             (Some(id), actions)
                         }
                         SelectionSource::Wlr(s) => {
                             let id = s.id().protocol_id();
                            let actions = self.wlr.data_control.sources.get(&id)
                                .map(|d| d.dnd_actions)
                                .unwrap_or(DndAction::empty());
                             if let Some(data) = self.wlr.data_control.sources.get(&id) {
                                 for mime in &data.mime_types {
                                     offer.offer(mime.clone());
                                 }
                             }
                             (Some(id), actions)
                         }
                     };
                     if offer.version() >= 3 {
                         offer.source_actions(source_dnd_actions);
                     }
                     let offer_id = offer.id().protocol_id();
                     self.data.offers.insert(offer_id, crate::core::wayland::ext::data_device::DataOfferData {
                         source_id,
                         mime_types: Vec::new(),
                         source_dnd_actions,
                         preferred_action: None,
                     });
                     
                     device.selection(Some(&offer));
                 } else {
                     device.selection(None);
                 }
             }
        }
    }

    /// Start a drag-and-drop operation
    pub fn start_drag(
        &mut self,
        source_id: Option<u32>,
        origin_surface_id: u32,
        icon_surface_id: Option<u32>,
    ) {
        use crate::core::wayland::ext::data_device::DragState;

        let serial = self.serial;
        self.data.drag = Some(DragState {
            source_id,
            origin_surface_id,
            icon_surface_id,
            focus_surface_id: None,
            current_offer_id: None,
            serial,
        });

        tracing::info!(
            "Drag started: source={:?}, origin={}, icon={:?}, serial={}",
            source_id, origin_surface_id, icon_surface_id, serial
        );
    }

    /// Check if a drag-and-drop operation is currently active
    pub fn is_dragging(&self) -> bool {
        self.data.drag.is_some()
    }

    /// End the current drag-and-drop operation
    pub fn end_drag(&mut self, dropped: bool) {
        self.xdg.toplevel_drag.active = None;

        let drag = match self.data.drag.take() {
            Some(d) => d,
            None => return,
        };

        if dropped && drag.focus_surface_id.is_some() {
            for device_data in self.data.devices.values() {
                if device_data.resource.is_alive() {
                    device_data.resource.drop();
                }
            }

            if let Some(source_id) = drag.source_id {
                if let Some(selection) = &self.seat.current_selection {
                    match selection {
                        SelectionSource::Wayland(src) => {
                            if src.id().protocol_id() == source_id && src.is_alive() {
                                src.dnd_drop_performed();
                            }
                        }
                        _ => {}
                    }
                }
            }

            tracing::info!("Drag dropped on surface {:?}", drag.focus_surface_id);
        } else {
            if drag.focus_surface_id.is_some() {
                for device_data in self.data.devices.values() {
                    if device_data.resource.is_alive() {
                        device_data.resource.leave();
                    }
                }
            }

            if let Some(source_id) = drag.source_id {
                if let Some(selection) = &self.seat.current_selection {
                    match selection {
                        SelectionSource::Wayland(src) => {
                            if src.id().protocol_id() == source_id && src.is_alive() {
                                src.cancelled();
                            }
                        }
                        _ => {}
                    }
                }
            }

            tracing::info!("Drag cancelled (dropped={})", dropped);
        }
        // Do not remove the offer here - the destination client may still call
        // Finish(); the offer is removed when the client sends Destroy.
    }

    // =========================================================================
    // DMABUF Export Management
    // =========================================================================

    /// Add a DMABUF export frame
    pub fn add_dmabuf_export_frame(&mut self, resource_id: u32, frame: DmabufExportFrame) {
        self.wlr.export_dmabuf.frames.insert(resource_id, frame);
        tracing::debug!("Added DMABUF export frame for resource {}", resource_id);
    }

    /// Remove a DMABUF export frame
    pub fn remove_dmabuf_export_frame(&mut self, resource_id: u32) {
        self.wlr.export_dmabuf.frames.remove(&resource_id);
        tracing::debug!("Removed DMABUF export frame for resource {}", resource_id);
    }

    // =========================================================================
    // Virtual Pointer Management
    // =========================================================================

    /// Add a virtual pointer
    pub fn add_virtual_pointer(&mut self, client_id: ClientId, resource_id: u32, pointer: VirtualPointerState) {
        self.wlr.virtual_pointers.insert((client_id, resource_id), pointer);
        tracing::debug!("Added virtual pointer device for resource {}", resource_id);
    }

    /// Remove a virtual pointer
    pub fn remove_virtual_pointer(&mut self, client_id: ClientId, resource_id: u32) {
        self.wlr.virtual_pointers.remove(&(client_id, resource_id));
        tracing::debug!("Removed virtual pointer device for resource {}", resource_id);
    }

    // =========================================================================
    // Virtual Keyboard Management
    // =========================================================================

    /// Add a virtual keyboard
    pub fn add_virtual_keyboard(&mut self, client_id: ClientId, resource_id: u32, keyboard: VirtualKeyboardState) {
        self.wlr.virtual_keyboards.insert((client_id, resource_id), keyboard);
        tracing::debug!("Added virtual keyboard device for resource {}", resource_id);
    }

    /// Remove a virtual keyboard
    pub fn remove_virtual_keyboard(&mut self, client_id: ClientId, resource_id: u32) {
        self.wlr.virtual_keyboards.remove(&(client_id, resource_id));
        tracing::debug!("Removed virtual keyboard device for resource {}", resource_id);
    }

    // =========================================================================
    // Presentation Time
    // =========================================================================
    
    /// Get next presentation sequence number
    pub fn next_presentation_seq(&mut self) -> u64 {
        let seq = self.ext.presentation.next_seq;
        self.ext.presentation.next_seq = self.ext.presentation.next_seq.wrapping_add(1);
        seq
    }

    // =========================================================================
    // Output Management
    // =========================================================================

    /// Update output configuration and notify all bound clients.
    pub fn update_output_configuration(
        &mut self,
        output_id: u32,
        width: Option<u32>,
        height: Option<u32>,
        refresh: Option<u32>,
        scale: Option<f32>,
        x: Option<i32>,
        y: Option<i32>,
    ) -> bool {
        let idx = match self.outputs.iter().position(|o| o.id == output_id) {
            Some(i) => i,
            None => return false,
        };

        let mut changed = false;
        {
            let output = &mut self.outputs[idx];
            if let Some(w) = width {
                if output.width != w { output.width = w; changed = true; }
            }
            if let Some(h) = height {
                if output.height != h { output.height = h; changed = true; }
            }
            if let Some(r) = refresh {
                if output.refresh != r { output.refresh = r; changed = true; }
            }
            if let Some(s) = scale {
                if (output.scale - s).abs() > 0.001 { output.scale = s; changed = true; }
            }
            if let Some(px) = x {
                if output.x != px { output.x = px; changed = true; }
            }
            if let Some(py) = y {
                if output.y != py { output.y = py; changed = true; }
            }

            if changed {
                if let Some(mode) = output.modes.iter_mut().find(|m| m.preferred) {
                    mode.width = output.width;
                    mode.height = output.height;
                    mode.refresh = output.refresh;
                }
                output.usable_area = crate::util::geometry::Rect::new(
                    output.x, output.y, output.width, output.height
                );
                tracing::info!(
                    "Output {} updated: {}x{} @ {}mHz, scale {}",
                    output_id, output.width, output.height, output.refresh, output.scale
                );
            }
        }

        if changed {
            crate::core::wayland::wayland::output::notify_output_change(self, output_id);
        }

        true
    }
    
    // =========================================================================
    // Idle Inhibition
    // =========================================================================
    
    // =========================================================================
    // Layer Surface Management
    // =========================================================================
    
    /// Add a layer surface
    pub fn add_layer_surface(&mut self, client_id: ClientId, surface: LayerSurface) -> u32 {
        let id = surface.surface_id;
        self.wlr.layer_surfaces.insert((client_id.clone(), id), Arc::new(RwLock::new(surface)));
        tracing::debug!("Added layer surface {}", id);
        id
    }
    
    /// Remove a layer surface
    pub fn remove_layer_surface(&mut self, client_id: ClientId, surface_id: u32) {
        self.wlr.layer_surfaces.remove(&(client_id, surface_id));
        tracing::debug!("Removed layer surface {}", surface_id);
    }
    
    /// Get a layer surface
    pub fn get_layer_surface(&self, client_id: ClientId, surface_id: u32) -> Option<Arc<RwLock<LayerSurface>>> {
        self.wlr.layer_surfaces.get(&(client_id, surface_id)).cloned()
    }
    
    /// Get all layer surfaces for an output
    pub fn layer_surfaces_for_output(&self, output_id: u32) -> Vec<Arc<RwLock<LayerSurface>>> {
        self.wlr.layer_surfaces.values()
            .filter(|ls| ls.read().unwrap().output_id == output_id)
            .cloned()
            .collect()
    }
}
