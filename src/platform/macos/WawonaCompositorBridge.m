//  WawonaCompositorBridge.m
//  Direct C API - calling plain C exports from Rust

#import "WawonaCompositorBridge.h"
#import "../../logging/WawonaLog.h"
#import "WawonaPlatformCallbacks.h"
#import "WawonaWindow.h"
#import <Cocoa/Cocoa.h>
#import <IOSurface/IOSurface.h>
#import <QuartzCore/QuartzCore.h> // For CALayer

// Plain C FFI functions exported from Rust with #[no_mangle]
extern void *wawona_core_new(void);
extern bool wawona_core_start(void *core, const char *socket_name);
extern bool wawona_core_stop(void *core);
extern bool wawona_core_is_running(const void *core);
extern char *wawona_core_get_socket_path(const void *core);
extern char *wawona_core_get_socket_name(const void *core);
extern void wawona_string_free(char *s);
extern bool wawona_core_process_events(void *core);
extern void wawona_core_set_output_size(void *core, uint32_t w, uint32_t h,
                                        float s);
extern void wawona_core_notify_frame_presented(void *core, uint32_t surface_id,
                                               uint64_t buffer_id,
                                               uint32_t timestamp);
extern void wawona_core_free(void *core);
extern void wawona_core_inject_window_resize(void *core, uint64_t window_id,
                                             uint32_t width, uint32_t height);
extern void wawona_core_set_window_activated(void *core, uint64_t window_id,
                                             bool active);

@implementation WawonaCompositorBridge {
  void *_rustCore;
  NSTimer *_eventTimer;
  NSMutableDictionary<NSNumber *, WawonaWindow *> *_windows;
}

+ (instancetype)sharedBridge {
  static WawonaCompositorBridge *sharedInstance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[WawonaCompositorBridge alloc] init];
  });
  return sharedInstance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    WLog(@"BRIDGE", @"Creating WawonaCore via direct C API");
    _rustCore = wawona_core_new();

    if (!_rustCore) {
      WLog(@"BRIDGE", @"Error: Failed to create WawonaCore");
      return nil;
    }

    WLog(@"BRIDGE", @"WawonaCore created successfully via C API!");
    _windows = [NSMutableDictionary dictionary];
  }
  return self;
}

- (void)dealloc {
  if (_rustCore) {
    wawona_core_free(_rustCore);
  }
}

// MARK: - Lifecycle

- (BOOL)startWithSocketName:(NSString *)socketName {
  if (!_rustCore) {
    WLog(@"BRIDGE", @"No Rust core");
    return NO;
  }

  const char *name = socketName ? [socketName UTF8String] : NULL;
  WLog(@"BRIDGE", @"Starting compositor...");

  bool success = wawona_core_start(_rustCore, name);

  if (success) {
    WLog(@"BRIDGE", @"Compositor started successfully!");

    // Start window event polling timer (60fps is fine for UI updates)
    _eventTimer =
        [NSTimer scheduledTimerWithTimeInterval:0.016
                                         target:self
                                       selector:@selector(onTimerTick:)
                                       userInfo:nil
                                        repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:_eventTimer forMode:NSRunLoopCommonModes];

  } else {
    WLog(@"BRIDGE", @"Error: Start failed");
  }

  return success;
}

- (void)stop {
  WLog(@"BRIDGE", @"Stopping compositor bridge...");

  // Stop the event timer first to prevent processing during shutdown
  [_eventTimer invalidate];
  _eventTimer = nil;

  // Close all windows gracefully
  NSUInteger windowCount = [_windows count];
  if (windowCount > 0) {
    WLog(@"BRIDGE", @"Closing %lu window(s)...", (unsigned long)windowCount);
    for (NSNumber *key in [_windows allKeys]) {
      WawonaWindow *window = [_windows objectForKey:key];
      [window orderOut:nil]; // Hide window
      [window close];        // Close window
    }
    [_windows removeAllObjects];
  }

  // Stop the Rust compositor (this will disconnect clients and close sockets)
  if (_rustCore) {
    wawona_core_stop(_rustCore);
    WLog(@"BRIDGE", @"Compositor stopped");
  }
}

- (BOOL)isRunning {
  return _rustCore ? wawona_core_is_running(_rustCore) : NO;
}

- (NSString *)socketPath {
  if (!_rustCore)
    return @"";

  char *path = wawona_core_get_socket_path(_rustCore);
  if (!path)
    return @"";

  NSString *result = [NSString stringWithUTF8String:path];
  wawona_string_free(path);
  return result ?: @"";
}

- (NSString *)socketName {
  if (!_rustCore)
    return @"";

  char *name = wawona_core_get_socket_name(_rustCore);
  if (!name)
    return @"";

  NSString *result = [NSString stringWithUTF8String:name];
  wawona_string_free(name);
  return result ?: @"";
}

// MARK: - Event Processing

- (void)onTimerTick:(NSTimer *)timer {
  if (!_rustCore)
    return;

  // 1. Process Wayland internal events (accept connections, dispatch protocol)
  wawona_core_process_events(_rustCore);

  // 2. Poll for window events (Created, Destroyed, etc.)
  [self pollAndHandleWindowEvents];

  // 3. Poll for buffer updates and render them
  [self pollAndRenderBuffers];
}

- (void)pollAndRenderBuffers {
  CBufferData *buffer;
  while ((buffer = [self popPendingBuffer]) != NULL) {
    WLog(@"BUFFER",
         @"Got buffer: win=%llu surf=%u buf=%llu %ux%u stride=%u size=%zu",
         buffer->window_id, buffer->surface_id, buffer->buffer_id,
         buffer->width, buffer->height, buffer->stride, buffer->size);

    NSNumber *windowId = @(buffer->window_id);
    WawonaWindow *window = [_windows objectForKey:windowId];

    if (window) {
      WLog(@"BUFFER", @"Found window for id %llu, creating image...",
           buffer->window_id);

      if (buffer->iosurface_id != 0) {
        WLog(@"BUFFER", @"Attempting IOSurface lookup for ID %u (window %llu)",
             buffer->iosurface_id, buffer->window_id);
        IOSurfaceRef surf = IOSurfaceLookup(buffer->iosurface_id);
        if (surf) {
          WLog(@"BRIDGE", @"IOSurface lookup SUCCESS for ID %u",
               buffer->iosurface_id);
          size_t w = IOSurfaceGetWidth(surf);
          size_t h = IOSurfaceGetHeight(surf);
          OSType fmt = IOSurfaceGetPixelFormat(surf);
          size_t allocSize = IOSurfaceGetAllocSize(surf);
          WLog(@"BRIDGE",
               @"IOSurface stats: %zux%zu fmt=%08x (DRM fmt=%08x) size=%zu", w,
               h, fmt, buffer->format, allocSize);

          CFDictionaryRef props = IOSurfaceCopyAllValues(surf);
          if (props) {
            WLog(@"BRIDGE", @"IOSurface properties: %@", props);
            CFRelease(props);
          }

          window.contentView.layer.contents = (__bridge id)surf;

          // DRM formats: XRGB8888=0x34325258, BGRX8888=0x34325842
          // If the buffer is X-variant (no alpha), force the layer to be
          // opaque.
          window.contentView.layer.opaque =
              (buffer->format == 0x34325258 || buffer->format == 0x34325842);

          CFRelease(surf); // Layer retains it
          WLog(@"BRIDGE",
               @"Set layer contents to IOSurface %u (fmt=%08x opaque=%d)",
               buffer->iosurface_id, buffer->format,
               window.contentView.layer.opaque);
        } else {
          WLog(@"BRIDGE",
               @"Error: Failed to lookup IOSurface %u in window %llu",
               buffer->iosurface_id, buffer->window_id);
        }
      } else {
        // Create CGImage from buffer
        CFDataRef pixelData =
            CFDataCreate(NULL, buffer->pixels, (CFIndex)buffer->size);
        CGDataProviderRef provider = CGDataProviderCreateWithCFData(pixelData);
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

        // Wayland ARGB8888 is BGRA in Little Endian
        CGBitmapInfo bitmapInfo =
            kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst;

        CGImageRef image =
            CGImageCreate(buffer->width, buffer->height,
                          8,  // bitsPerComponent
                          32, // bitsPerPixel
                          buffer->stride, colorSpace, bitmapInfo, provider,
                          NULL,  // decode
                          false, // shouldInterpolate
                          kCGRenderingIntentDefault);

        if (image) {
          WLog(@"BUFFER",
               @"Image created successfully, setting layer contents");
          // Update layer contents on main thread
          window.contentView.layer.contents = (__bridge id)image;

          CGImageRelease(image);
        } else {
          WLog(@"BUFFER", @"ERROR: CGImageCreate returned NULL!");
        }

        CGColorSpaceRelease(colorSpace);
        CGDataProviderRelease(provider);
        CFRelease(pixelData);
      }
    } else {
      WLog(@"BUFFER",
           @"Warning: No window for buffer win_id=%llu (windows count=%lu)",
           buffer->window_id, (unsigned long)[_windows count]);
      // Log available window IDs
      for (NSNumber *key in _windows) {
        WLog(@"BUFFER", @"  Available window: %@", key);
      }
    }

    // Notify Rust that frame was presented
    uint32_t timestamp =
        (uint32_t)([[NSDate date] timeIntervalSince1970] * 1000.0);
    [self notifyFramePresentedForSurface:buffer->surface_id
                                  buffer:buffer->buffer_id
                               timestamp:timestamp];

    [self freeBufferData:buffer];
  }
}

- (void)flushClients {
}

// MARK: - Input (Stubs)

// C FFI for input injection
extern void wawona_core_inject_pointer_motion(void *core, uint64_t window_id,
                                              double x, double y,
                                              uint32_t timestamp);
extern void wawona_core_inject_pointer_button(void *core, uint64_t window_id,
                                              uint32_t button, uint32_t state,
                                              uint32_t timestamp);
extern void wawona_core_inject_pointer_enter(void *core, uint64_t window_id,
                                             double x, double y,
                                             uint32_t timestamp);
extern void wawona_core_inject_pointer_leave(void *core, uint64_t window_id,
                                             uint32_t timestamp);
extern void wawona_core_inject_key(void *core, uint32_t keycode, uint32_t state,
                                   uint32_t timestamp);
extern void wawona_core_inject_keyboard_enter(void *core, uint64_t window_id,
                                              const uint32_t *keys,
                                              size_t count);
extern void wawona_core_inject_keyboard_leave(void *core, uint64_t window_id);
extern void wawona_core_inject_modifiers(void *core, uint32_t depressed,
                                         uint32_t latched, uint32_t locked,
                                         uint32_t group);

- (void)injectPointerMotionForWindow:(uint64_t)windowId
                                   x:(double)x
                                   y:(double)y
                           timestamp:(uint32_t)timestampMs {
  if (_rustCore) {
    wawona_core_inject_pointer_motion(_rustCore, windowId, x, y, timestampMs);
  }
}

- (void)injectPointerEnterForWindow:(uint64_t)windowId
                                  x:(double)x
                                  y:(double)y
                          timestamp:(uint32_t)timestampMs {
  if (_rustCore) {
    wawona_core_inject_pointer_enter(_rustCore, windowId, x, y, timestampMs);
  }
}

- (void)injectPointerLeaveForWindow:(uint64_t)windowId
                          timestamp:(uint32_t)timestampMs {
  if (_rustCore) {
    wawona_core_inject_pointer_leave(_rustCore, windowId, timestampMs);
  }
}

- (void)injectPointerButtonForWindow:(uint64_t)windowId
                              button:(uint32_t)button
                             pressed:(BOOL)pressed
                           timestamp:(uint32_t)timestampMs {
  if (_rustCore) {
    // 0 = Released, 1 = Pressed
    uint32_t state = pressed ? 1 : 0;
    wawona_core_inject_pointer_button(_rustCore, windowId, button, state,
                                      timestampMs);
  }
}
- (void)injectPointerAxisForWindow:(uint64_t)windowId
                              axis:(uint32_t)axis
                             value:(double)value
                          discrete:(int32_t)discrete
                         timestamp:(uint32_t)timestampMs {
}
- (void)injectKeyWithKeycode:(uint32_t)keycode
                     pressed:(BOOL)pressed
                   timestamp:(uint32_t)timestampMs {
  if (_rustCore) {
    // 0 = Released, 1 = Pressed
    uint32_t state = pressed ? 1 : 0;
    wawona_core_inject_key(_rustCore, keycode, state, timestampMs);
  }
}

- (void)injectKeyboardEnterForWindow:(uint64_t)windowId
                                keys:(NSArray<NSNumber *> *)keys {
  if (_rustCore) {
    size_t count = keys.count;
    uint32_t *keyArray = malloc(sizeof(uint32_t) * count);
    for (size_t i = 0; i < count; i++) {
      keyArray[i] = [keys[i] unsignedIntValue];
    }
    wawona_core_inject_keyboard_enter(_rustCore, windowId, keyArray, count);
    free(keyArray);
  }
}

- (void)injectKeyboardLeaveForWindow:(uint64_t)windowId {
  if (_rustCore) {
    wawona_core_inject_keyboard_leave(_rustCore, windowId);
  }
}

- (void)injectWindowResize:(uint64_t)windowId
                     width:(uint32_t)width
                    height:(uint32_t)height {
  if (_rustCore) {
    wawona_core_inject_window_resize(_rustCore, windowId, width, height);
  }
}

- (void)setWindowActivated:(uint64_t)windowId active:(BOOL)active {
  if (_rustCore) {
    wawona_core_set_window_activated(_rustCore, windowId, active);
  }
}
- (void)injectModifiersWithDepressed:(uint32_t)depressed
                             latched:(uint32_t)latched
                              locked:(uint32_t)locked
                               group:(uint32_t)group {
}

// MARK: - Configuration

- (void)setOutputWidth:(uint32_t)w height:(uint32_t)h scale:(float)s {
  if (_rustCore) {
    wawona_core_set_output_size(_rustCore, w, h, s);
    WLog(@"BRIDGE", @"Output: %ux%u @ %.1fx", w, h, s);
  }
}

- (void)setForceSSD:(BOOL)enabled {
}
- (void)setKeyboardRepeatRate:(int32_t)rate delay:(int32_t)delay {
}
- (void)notifyFrameComplete {
}
- (void)notifyFramePresentedForSurface:(uint32_t)surfaceId
                                buffer:(uint64_t)bufferId
                             timestamp:(uint32_t)timestamp {
  if (_rustCore) {
    wawona_core_notify_frame_presented(_rustCore, surfaceId, bufferId,
                                       timestamp);
  }
}
- (void)flushFrameCallbacks {
}
- (NSArray<NSNumber *> *)pollRedrawRequests {
  return @[];
}

// MARK: - Window Event Polling

// C FFI for window events
typedef enum : uint32_t {
  CWindowEventTypeCreated = 0,
  CWindowEventTypeDestroyed = 1,
  CWindowEventTypeTitleChanged = 2,
  CWindowEventTypeSizeChanged = 3,
  CWindowEventTypePopupCreated = 4,
} CWindowEventType;

typedef struct CWindowEvent {
  uint64_t event_type;
  uint64_t window_id;
  char *title;
  uint32_t width;
  uint32_t height;
  uint64_t parent_id;
  int32_t x;
  int32_t y;
  uint32_t padding;
} CWindowEvent;

extern CWindowEvent *wawona_core_pop_window_event(void *core);
extern void wawona_window_event_free(CWindowEvent *event);

// Legacy struct for compatibility if needed
typedef struct CWindowInfo {
  uint64_t window_id;
  uint32_t width;
  uint32_t height;
  char *title;
} CWindowInfo;

extern uint32_t wawona_core_pending_window_count(const void *core);
extern CWindowInfo *wawona_core_pop_pending_window(void *core);
extern void wawona_window_info_free(CWindowInfo *info);

- (void)pollAndHandleWindowEvents {
  if (!_rustCore)
    return;

  while (true) {
    CWindowEvent *event = wawona_core_pop_window_event(_rustCore);
    if (!event)
      break;

    switch (event->event_type) {
    case CWindowEventTypeCreated:
      [self handleWindowCreated:event];
      break;
    case CWindowEventTypeDestroyed:
      [self handleWindowDestroyed:event];
      break;
    case CWindowEventTypeTitleChanged:
      [self handleWindowTitleChanged:event];
      break;
    case CWindowEventTypeSizeChanged:
      [self handleWindowSizeChanged:event];
      break;
    case CWindowEventTypePopupCreated:
      [self handlePopupCreated:event];
      break;
    }

    wawona_window_event_free(event);
  }
}

// Window Management
- (NSMutableDictionary<NSNumber *, WawonaWindow *> *)windows {
  return _windows;
}

- (void)handleWindowCreated:(CWindowEvent *)event {
  WLog(@"BRIDGE", @"handleWindowCreated: id=%llu size=%ux%u", event->window_id,
       event->width, event->height);

  NSRect contentRect = NSMakeRect(100, 100, event->width, event->height);
  NSWindowStyleMask styleMask =
      NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
      NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;

  WawonaWindow *window =
      [[WawonaWindow alloc] initWithContentRect:contentRect
                                      styleMask:styleMask
                                        backing:NSBackingStoreBuffered
                                          defer:NO];

  window.wawonaWindowId = event->window_id;

  NSString *title = event->title ? [NSString stringWithUTF8String:event->title]
                                 : @"Wawona Window";
  [window setTitle:title];

  // Create content view
  WawonaView *contentView = [[WawonaView alloc] initWithFrame:contentRect];
  contentView.wantsLayer = YES;
  contentView.layer.backgroundColor = [[NSColor blackColor] CGColor];
  contentView.layer.contentsGravity = kCAGravityResize;

  [window setContentView:contentView];
  [window makeFirstResponder:contentView];

  [window center];
  [window makeKeyAndOrderFront:nil];

  [_windows setObject:window forKey:@(event->window_id)];
  WLog(@"BRIDGE", @"Created window %llu: %@ (total windows: %lu)",
       event->window_id, title, (unsigned long)[_windows count]);
}

- (void)handleWindowDestroyed:(CWindowEvent *)event {
  NSWindow *window = [self.windows objectForKey:@(event->window_id)];
  if (window) {
    [window close];
    [self.windows removeObjectForKey:@(event->window_id)];
    WLog(@"BRIDGE", @"Destroyed window %llu", event->window_id);
  }
}

- (void)handleWindowTitleChanged:(CWindowEvent *)event {
  if (!event->title)
    return;
  NSString *newTitle = [NSString stringWithUTF8String:event->title];

  NSWindow *window = [self.windows objectForKey:@(event->window_id)];
  if (window) {
    [window setTitle:newTitle];
    WLog(@"BRIDGE", @"Updated title for window %llu to '%@'", event->window_id,
         newTitle);
  } else {
    WLog(@"BRIDGE",
         @"Warning: handleWindowTitleChanged for unknown window %llu",
         event->window_id);
  }
}

- (void)handleWindowSizeChanged:(CWindowEvent *)event {
  NSWindow *window = [self.windows objectForKey:@(event->window_id)];
  if (window) {
    // Check if size actually changed to avoid loop
    if (window.contentView.bounds.size.width != event->width ||
        window.contentView.bounds.size.height != event->height) {
      NSRect frame =
          [window frameRectForContentRect:NSMakeRect(0, 0, event->width,
                                                     event->height)];
      frame.origin = window.frame.origin; // Keep origin
      [window setFrame:frame display:YES];
    }
  }
}

- (void)handlePopupCreated:(CWindowEvent *)event {
  NSWindow *parentWindow = [self.windows objectForKey:@(event->parent_id)];
  if (!parentWindow) {
    WLog(@"BRIDGE", @"Warning: Popup created for unknown parent %llu",
         event->parent_id);
    // Fallback: use key window?
    parentWindow = [NSApp keyWindow];
  }

  if (parentWindow) {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Popup"];
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Popup Content"
                                                  action:nil
                                           keyEquivalent:@""];
    [menu addItem:item];

    // Calculate location in screen coordinates
    // event->x, y are relative to parent window content view usually
    NSRect contentRect =
        [parentWindow contentRectForFrameRect:parentWindow.frame];
    NSPoint locationInWindow =
        NSMakePoint(event->x, contentRect.size.height - event->y); // Flip Y?

    // Wawona/Wayland coords: usually top-left. AppKit: bottom-left.
    // Converting...

    WLog(@"BRIDGE", @"Showing Popup Menu for window %llu at %d,%d",
         event->parent_id, event->x, event->y);

    // Pop up the menu
    // Note: popUpMenuPositioningItem blocks. Doing this on main thread might
    // block UI updates? Usually menus are modal in local loop. Using a darker
    // view or custom view in menu item would be better.

    NSEvent *mouseEvent = [NSEvent mouseEventWithType:NSEventTypeRightMouseDown
                                             location:locationInWindow
                                        modifierFlags:0
                                            timestamp:0
                                         windowNumber:parentWindow.windowNumber
                                              context:nil
                                          eventNumber:0
                                           clickCount:1
                                             pressure:0];

    [NSMenu popUpContextMenu:menu
                   withEvent:mouseEvent
                     forView:parentWindow.contentView];
  }
}

- (NSUInteger)pendingWindowCount {
  if (!_rustCore)
    return 0;
  return wawona_core_pending_window_count(_rustCore);
}

- (NSDictionary *)popPendingWindow {
  // Legacy support: We might want to just return nil or implement using new API
  // if needed. But since we are handling events internally now, we should
  // probably return nil to stop external pollers from interfering, OR map the
  // first Created event. For now, let's return nil and rely on our internal
  // poller.
  return nil;
}

// MARK: - Buffer updates

extern CBufferData *wawona_core_pop_pending_buffer(void *core);
extern void wawona_buffer_data_free(CBufferData *data);

- (nullable CBufferData *)popPendingBuffer {
  if (!_rustCore)
    return NULL;
  return wawona_core_pop_pending_buffer(_rustCore);
}

- (void)freeBufferData:(CBufferData *)data {
  wawona_buffer_data_free(data);
}

@end
