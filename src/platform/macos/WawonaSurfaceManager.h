#pragma once

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#include <wayland-server-protocol.h>

// Forward declarations
struct wl_surface_impl;
struct xdg_toplevel_impl;

typedef NS_ENUM(NSUInteger, WawonaDecorationMode) {
  WawonaDecorationModeUnset = 0,
  WawonaDecorationModeCSD = 1,
  WawonaDecorationModeSSD = 2
};

// Surface layer representation
@interface WawonaSurfaceLayer : NSObject
@property(nonatomic, readonly) struct wl_surface_impl *surface;
@property(nonatomic, strong) CALayer *rootLayer;
@property(nonatomic, strong) CAMetalLayer *contentLayer;
@property(nonatomic, strong) NSMutableArray<CALayer *> *subsurfaceLayers;

- (instancetype)initWithSurface:(struct wl_surface_impl *)surface;
- (void)updateContentWithSize:(CGSize)size;
- (void)addSubsurfaceLayer:(CALayer *)sublayer atIndex:(NSInteger)index;
- (void)removeSubsurfaceLayer:(CALayer *)sublayer;
- (void)setNeedsRedisplay;
@end

// Window representation
@interface WawonaWindowContainer : NSObject
@property(nonatomic, readonly) struct xdg_toplevel_impl *toplevel;
#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
@property(nonatomic, strong) UIWindow *window;
@property(nonatomic, strong) UIView *contentView;
#else
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) NSView *contentView;
#endif
@property(nonatomic, strong) WawonaSurfaceLayer *surfaceLayer;
@property(nonatomic, assign) WawonaDecorationMode decorationMode;

// CSD state
@property(nonatomic, assign) BOOL isResizing;
#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR
@property(nonatomic, assign) NSRectEdge resizeEdge;
#endif
@property(nonatomic, assign) CGPoint resizeStartPoint;
@property(nonatomic, assign) CGRect resizeStartFrame;

- (instancetype)initWithToplevel:(struct xdg_toplevel_impl *)toplevel
                  decorationMode:(WawonaDecorationMode)mode
                            size:(CGSize)size;
#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
- (void)replaceContentView:(UIView *)newView;
#else
- (void)replaceContentView:(NSView *)newView;
#endif
- (void)show;
- (void)hide;
- (void)close;
- (void)updateDecorationMode:(WawonaDecorationMode)mode;
- (void)setTitle:(NSString *)title;

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR
// CSD logic
- (NSRectEdge)detectResizeEdgeAtPoint:(CGPoint)point;
- (void)beginResizeWithEdge:(NSRectEdge)edge atPoint:(CGPoint)point;
#endif
- (void)continueResizeToPoint:(CGPoint)point;
- (void)endResize;

@end

// Manager
@interface WawonaSurfaceManager : NSObject
@property(nonatomic, strong, readonly) id<MTLDevice> metalDevice;

+ (instancetype)sharedManager;

- (WawonaSurfaceLayer *)createSurfaceLayerForSurface:
    (struct wl_surface_impl *)surface;
- (void)destroySurfaceLayer:(struct wl_surface_impl *)surface;
- (WawonaSurfaceLayer *)layerForSurface:(struct wl_surface_impl *)surface;

- (WawonaWindowContainer *)createWindowForToplevel:
                               (struct xdg_toplevel_impl *)toplevel
                                    decorationMode:(WawonaDecorationMode)mode
                                              size:(CGSize)size;
- (void)destroyWindowForToplevel:(struct xdg_toplevel_impl *)toplevel;
- (WawonaWindowContainer *)windowForToplevel:
    (struct xdg_toplevel_impl *)toplevel;

@end

// C Helpers
#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR
void macos_create_window_for_toplevel(struct xdg_toplevel_impl *toplevel);
void macos_update_toplevel_decoration_mode(struct xdg_toplevel_impl *toplevel);
void macos_update_toplevel_title(struct xdg_toplevel_impl *toplevel);
void macos_toplevel_set_maximized(struct xdg_toplevel_impl *t);
void macos_toplevel_set_minimized(struct xdg_toplevel_impl *t);
#endif
