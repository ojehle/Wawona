// WawonaCompositorView_macos.h - macOS compositor view
// Extracted from WawonaCompositorView.m for platform separation

#pragma once

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR

#import <Cocoa/Cocoa.h>
#import <MetalKit/MetalKit.h>

@class InputHandler;
@class WawonaCompositor;
@protocol RenderingBackend;

@interface CompositorView : NSView
@property(nonatomic, strong) InputHandler *inputHandler;
@property(nonatomic, strong) id<RenderingBackend> renderer;
@property(nonatomic, strong) MTKView *metalView;
@property(nonatomic, weak) WawonaCompositor *compositor;
@end

#endif // !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR

