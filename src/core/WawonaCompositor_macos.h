// WawonaCompositor_macos.h - macOS-specific compositor extensions
// Extracted from WawonaCompositor.m for better organization

#pragma once

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR

#import <Cocoa/Cocoa.h>
#import "WawonaCompositor.h"

// NSWindowDelegate category for macOS window management
@interface WawonaCompositor (WindowDelegate) <NSWindowDelegate>

// Window lifecycle
- (NSRect)windowWillUseStandardFrame:(NSWindow *)window defaultFrame:(NSRect)newFrame;
- (void)windowWillStartLiveResize:(NSNotification *)notification;
- (void)windowDidEndLiveResize:(NSNotification *)notification;
- (void)windowDidResize:(NSNotification *)notification;
- (void)windowWillClose:(NSNotification *)notification;

// Window focus
- (void)windowDidBecomeKey:(NSNotification *)notification;
- (void)windowDidResignKey:(NSNotification *)notification;

// Window state changes
- (void)windowDidMiniaturize:(NSNotification *)notification;
- (void)windowDidDeminiaturize:(NSNotification *)notification;
- (void)windowDidZoom:(NSNotification *)notification;
- (BOOL)windowShouldZoom:(NSWindow *)window toFrame:(NSRect)newFrame;

// CSD window management
- (void)fixCSDWindowResizing:(NSWindow *)window;

@end

#endif // !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR

