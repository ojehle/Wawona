#pragma once

#import <Foundation/Foundation.h>
#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
#import <UIKit/UIKit.h>
#endif

struct wl_surface_impl;

// Platform-specific renderer interface
#import "../core/RenderingBackend.h"

@interface WawonaRendererIOS : NSObject <RenderingBackend>

#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
- (instancetype)initWithView:(UIView *)view;
- (void)drawSurfacesInRect:(CGRect)dirtyRect;
#endif

- (void)renderSurface:(struct wl_surface_impl *)surface;
- (void)removeSurface:(struct wl_surface_impl *)surface;
- (void)setNeedsDisplay;

@end
