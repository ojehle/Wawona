// WawonaFrameCallbackManager.h - Frame callback timer management
// Extracted from WawonaCompositor.m for better organization

#pragma once

#import <Foundation/Foundation.h>
#include <wayland-server-core.h>

@class WawonaCompositor;

// Public C API for frame callback management
#ifdef __cplusplus
extern "C" {
#endif

// Called when a client requests a frame callback
void wawona_frame_callback_requested(void);

// Force immediate frame callback dispatch
void wawona_send_frame_callbacks_immediately(WawonaCompositor *compositor);

#ifdef __cplusplus
}
#endif

// Internal class for managing frame callback timers
@interface WawonaFrameCallbackManager : NSObject

- (instancetype)initWithCompositor:(WawonaCompositor *)compositor;

// Ensure timer exists and is scheduled (must run on event thread)
- (BOOL)ensureTimerOnEventThreadWithDelay:(uint32_t)delayMs reason:(const char *)reason;

// Send frame callbacks immediately (runs on event thread)
- (void)sendFrameCallbacks;

// Handle pending resize configure events
- (void)processPendingResizeConfigure;

@end

