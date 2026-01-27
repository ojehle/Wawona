

use std::time::{SystemTime, UNIX_EPOCH};
use wayland_protocols::wp::presentation_time::server::{wp_presentation, wp_presentation_feedback};
use wayland_server::{
    Dispatch, DisplayHandle, GlobalDispatch, Resource,
};

use crate::core::state::CompositorState;

/// Presentation time global
pub struct PresentationTimeGlobal;

/// Presentation feedback callback
#[derive(Debug)]
pub struct PresentationFeedback {
    pub surface_id: u32,
    pub callback: wp_presentation_feedback::WpPresentationFeedback,
    pub committed: bool,
}

impl GlobalDispatch<wp_presentation::WpPresentation, ()> for CompositorState {
    fn bind(
        _state: &mut Self,
        _handle: &DisplayHandle,
        _client: &wayland_server::Client,
        resource: wayland_server::New<wp_presentation::WpPresentation>,
        _global_data: &(),
        data_init: &mut wayland_server::DataInit<'_, Self>,
    ) {
        data_init.init(resource, ());
    }
}

impl Dispatch<wp_presentation::WpPresentation, ()> for CompositorState {
    fn request(
        state: &mut Self,
        _client: &wayland_server::Client,
        _resource: &wp_presentation::WpPresentation,
        request: wp_presentation::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        data_init: &mut wayland_server::DataInit<'_, Self>,
    ) {
        match request {
            wp_presentation::Request::Feedback { surface, callback } => {
                let surface_id = surface.id().protocol_id();
                let feedback_resource = data_init.init(callback, ());
                
                state.presentation_feedbacks.push(PresentationFeedback {
                    surface_id,
                    callback: feedback_resource,
                    committed: false, // Will be marked true on surface commit
                });
            }
            wp_presentation::Request::Destroy => {
                // connection closed
            }
            _ => {}
        }
    }
}

impl Dispatch<wp_presentation_feedback::WpPresentationFeedback, ()> for CompositorState {
    fn request(
        _state: &mut Self,
        _client: &wayland_server::Client,
        _resource: &wp_presentation_feedback::WpPresentationFeedback,
        _request: wp_presentation_feedback::Request,
        _data: &(),
        _dhandle: &DisplayHandle,
        _data_init: &mut wayland_server::DataInit<'_, Self>,
    ) {
    }
}

impl CompositorState {
    /// Fire presentation feedback for committed surfaces
    pub fn fire_presentation_feedback(&mut self) {
        let now = SystemTime::now();
        let duration = now.duration_since(UNIX_EPOCH).unwrap();
        
        // High 32 bits and Low 32 bits of tv_sec
        let tv_sec_hi = (duration.as_secs() >> 32) as u32;
        let tv_sec_lo = (duration.as_secs() & 0xFFFFFFFF) as u32;
        let tv_nsec = duration.subsec_nanos();
        
        let refresh_nsec = 16_666_666; // 60Hz default
        let flags = wp_presentation_feedback::Kind::Vsync;
        
        // Process feedbacks
        // In a real compositor we would wait for the actual scanout.
        // For nested/emulated, we just fire them immediately if they are committed.
        
        // Since we don't track per-frame commit explicitly in this simplifiied storage yet,
        // we'll just fire all of them for now as "presented".
        // functionality.
        
        let remaining = Vec::new();
        
        for feedback in self.presentation_feedbacks.drain(..) {
             // In a real implementation: check if surface was actually updated this frame.
             // Here we assume immediate presentation.
             feedback.callback.presented(
                 tv_sec_hi,
                 tv_sec_lo,
                 tv_nsec,
                 refresh_nsec,
                 0, // seq_hi
                 0, // seq_lo
                 flags
             );
        }
        
        self.presentation_feedbacks = remaining;
    }
}
