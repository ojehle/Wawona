// WawonaCompositorView.h - Compositor view for iOS and macOS
// Extracted from WawonaCompositor.m for better organization

#pragma once

#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import <MetalKit/MetalKit.h>

@class InputHandler;
@class WawonaCompositor;
@protocol RenderingBackend;

#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
@interface CompositorView : UIView
@property(nonatomic, assign) InputHandler *inputHandler;
@property(nonatomic, strong) id<RenderingBackend> renderer;
@property(nonatomic, strong) MTKView *metalView;
@property(nonatomic, weak) WawonaCompositor *compositor;
@end
#else
@interface CompositorView : NSView
@property(nonatomic, strong) InputHandler *inputHandler;
@property(nonatomic, strong) id<RenderingBackend> renderer;
@property(nonatomic, strong) MTKView *metalView;
@property(nonatomic, weak) WawonaCompositor *compositor;
@end
#endif

