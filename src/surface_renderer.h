#pragma once

#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>
#include "wayland_compositor.h"

// Forward declaration
@class SurfaceImage;

// Surface Renderer - Converts Wayland buffers to Cocoa drawing
// Uses NSView drawing (like OWL compositor) instead of CALayer
@interface SurfaceRenderer : NSObject

@property (nonatomic, assign) NSView *compositorView;  // The view we draw into (assign for MRC compatibility)
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, SurfaceImage *> *surfaceImages;

- (instancetype)initWithCompositorView:(NSView *)view;
- (void)renderSurface:(struct wl_surface_impl *)surface;
- (void)removeSurface:(struct wl_surface_impl *)surface;
- (void)drawSurfacesInRect:(NSRect)dirtyRect;  // Called from drawRect:

@end
