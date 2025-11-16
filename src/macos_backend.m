#import "macos_backend.h"
#import <QuartzCore/QuartzCore.h>
#import <CoreVideo/CoreVideo.h>
#import <libproc.h>
#include <wayland-server-core.h>
#include <wayland-server.h>
#include <dispatch/dispatch.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include "logging.h"
#include "wayland_compositor.h"
#include "wayland_primary_selection.h"
#include "wayland_protocol_stubs.h"
#include "wayland_viewporter.h"
#include "wayland_shell.h"
#include "wayland_screencopy.h"
#include "wayland_idle_inhibit.h"
#include "wayland_pointer_gestures.h"
#include "wayland_gtk_shell.h"
#include "wayland_plasma_shell.h"
#include "wayland_qt_extensions.h"
#include "wayland_relative_pointer.h"
#include "wayland_pointer_constraints.h"
#include "wayland_tablet.h"
#include "wayland_idle_manager.h"
#include "wayland_keyboard_shortcuts.h"
#include "wayland_linux_dmabuf.h"
#include "metal_waypipe.h"

// Custom NSView subclass that accepts first responder status and handles keyboard events
@interface CompositorView : NSView
@property (nonatomic, assign) InputHandler *inputHandler;  // assign for MRC compatibility
@property (nonatomic, assign) SurfaceRenderer *renderer;  // assign for MRC compatibility
@property (nonatomic, strong) MTKView *metalView;  // Metal view for full compositor rendering
@end

@implementation CompositorView
- (BOOL)isFlipped {
    // Return YES to use top-left origin (like Wayland) instead of bottom-left (Cocoa default)
    return YES;
}

- (BOOL)mouseDownCanMoveWindow {
    // Allow window to be moved by dragging the background
    // This ensures window controls remain functional
    return YES;
}

- (BOOL)acceptsMouseMovedEvents {
    // Accept mouse moved events for Wayland client input
    return YES;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (BOOL)becomeFirstResponder {
    NSLog(@"[COMPOSITOR VIEW] Became first responder - ready for keyboard input");
    return [super becomeFirstResponder];
}

- (BOOL)resignFirstResponder {
    NSLog(@"[COMPOSITOR VIEW] Resigned first responder");
    return [super resignFirstResponder];
}

// Override drawRect: to draw Wayland surfaces using Cocoa/Quartz drawing
- (void)drawRect:(NSRect)dirtyRect {
    // If Metal view is active, don't draw here (Metal handles its own rendering)
    // Also ensure Metal view completely covers this view to prevent any Cocoa drawing showing through
    if (self.metalView && self.metalView.superview == self) {
        // Metal view should completely cover this view - no need to draw
        return;
    }
    
    // Draw all Wayland surfaces using Cocoa/Quartz drawing
    if (self.renderer) {
        [self.renderer drawSurfacesInRect:dirtyRect];
    } else {
        // Fallback: draw background if no renderer
        [[NSColor colorWithRed:0.1 green:0.1 blue:0.2 alpha:1.0] setFill];
        NSRectFill(dirtyRect);
    }
}

// Override keyDown to handle keyboard events and prevent macOS keyboard fail sounds
- (void)keyDown:(NSEvent *)event {
    if (self.inputHandler) {
        [self.inputHandler handleKeyboardEvent:event];
    } else {
        [super keyDown:event];
    }
}

// Override keyUp to handle keyboard release events
- (void)keyUp:(NSEvent *)event {
    if (self.inputHandler) {
        [self.inputHandler handleKeyboardEvent:event];
    } else {
        [super keyUp:event];
    }
}

// Override performKeyEquivalent to handle special keys (like Cmd+Q, etc.)
// Return YES to indicate we handled it, NO to let macOS handle it
- (BOOL)performKeyEquivalent:(NSEvent *)event {
    // Only intercept if we have a focused Wayland surface
    // Otherwise let macOS handle system shortcuts
    if (self.inputHandler && self.inputHandler.seat && self.inputHandler.seat->focused_surface) {
        [self.inputHandler handleKeyboardEvent:event];
        return YES; // We handled it, prevent macOS from processing
    }
    return [super performKeyEquivalent:event];
}
@end

// Static reference to compositor instance for C callback
static MacOSCompositor *g_compositor_instance = NULL;

// C function to update window title when focus changes
void macos_compositor_update_title(struct wl_client *client) {
    if (g_compositor_instance) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [g_compositor_instance updateWindowTitleForClient:client];
        });
    }
}

// C function to detect full compositors and switch to Metal backend
// OPTIMIZED: Only switch to Metal for actual nested compositors, not proxies like waypipe
void macos_compositor_detect_full_compositor(struct wl_client *client) {
    if (!g_compositor_instance) {
        NSLog(@"⚠️ g_compositor_instance is NULL, cannot detect compositor");
        return;
    }
    
    // Try to get PID for detection
    pid_t client_pid = 0;
    uid_t client_uid = 0;
    gid_t client_gid = 0;
    wl_client_get_credentials(client, &client_pid, &client_uid, &client_gid);
    
    BOOL shouldSwitchToMetal = NO;
    NSString *processName = nil;
    
    if (client_pid > 0) {
        // Check process name to determine if this is a nested compositor
        char proc_path[PROC_PIDPATHINFO_MAXSIZE] = {0};
        int ret = proc_pidpath(client_pid, proc_path, sizeof(proc_path));
        if (ret > 0) {
            NSString *processPath = [NSString stringWithUTF8String:proc_path];
            processName = [processPath lastPathComponent];
            NSLog(@"🔍 Client binding to wl_compositor: %@ (PID: %d)", processName, client_pid);
            
            // Known nested compositors that should use Metal backend
            // Includes: Weston, wlroots-based (Sway, River, Hyprland), GNOME (Mutter), KDE (KWin)
            NSArray<NSString *> *nestedCompositors = @[
                @"weston", @"weston-desktop-shell",
                @"mutter", @"gnome-shell", @"gnome-session",
                @"kwin_wayland", @"kwin", @"plasmashell",
                @"sway", @"river", @"hyprland", @"niri", @"cage",
                @"wayfire", @"hikari", @"orbital"
            ];
            
            NSString *lowercaseName = [processName lowercaseString];
            for (NSString *compositor in nestedCompositors) {
                if ([lowercaseName containsString:compositor]) {
                    shouldSwitchToMetal = YES;
                    NSLog(@"✅ Detected nested compositor: %@ - switching to Metal backend", processName);
                    break;
                }
            }
            
            // waypipe is a proxy/tunnel, NOT a compositor - don't switch backend
            if ([lowercaseName containsString:@"waypipe"]) {
                shouldSwitchToMetal = NO;
                NSLog(@"ℹ️ Detected waypipe proxy - keeping Cocoa backend for regular clients");
            }
        }
    } else {
        // PID unavailable - likely forwarded through waypipe or similar proxy
        // Don't switch backend automatically - waypipe clients should use Cocoa
        NSLog(@"🔍 Client PID unavailable (likely forwarded through waypipe) - keeping Cocoa backend");
        shouldSwitchToMetal = NO;
    }
    
    // Only switch to Metal if we detected an actual nested compositor
    if (shouldSwitchToMetal) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [g_compositor_instance switchToMetalBackend];
        });
    } else {
        NSLog(@"ℹ️ Client binding to wl_compositor but not a nested compositor - using Cocoa backend");
    }
    
    // Update window title with client name (regardless of backend)
    dispatch_async(dispatch_get_main_queue(), ^{
        [g_compositor_instance updateWindowTitleForClient:client];
    });
}

// C wrapper function for render callback
static void render_surface_callback(struct wl_surface_impl *surface) {
    if (!surface) return;
    
    // CRITICAL: Validate surface is still valid before dispatching async render
    // The surface may be destroyed between commit and async render execution
    if (!surface->resource) return;
    
    // SAFETY: Check user_data FIRST before calling wl_resource_get_client
    // This is safer because user_data access doesn't dereference as many internal fields
    struct wl_surface_impl *surface_check = wl_resource_get_user_data(surface->resource);
    if (!surface_check || surface_check != surface) return;
    
    // Now verify resource is still valid by checking if we can get the client
    struct wl_client *client = wl_resource_get_client(surface->resource);
    if (!client) return;
    
    if (g_compositor_instance && g_compositor_instance.renderingBackend) {
        // Render on main thread using active backend (Cocoa or Metal)
        // Note: renderSurface will validate again, but this prevents unnecessary dispatch
        dispatch_async(dispatch_get_main_queue(), ^{
            // Check if window needs to be shown and sized for first client
            if (!g_compositor_instance.windowShown && surface->buffer_resource) {
                // Get buffer size to size window appropriately
                // buffer_data structure is defined in wayland_shm.c
                struct buffer_data {
                    void *data;
                    int32_t offset;
                    int32_t width;
                    int32_t height;
                    int32_t stride;
                    uint32_t format;
                };
                struct buffer_data *buf_data = wl_resource_get_user_data(surface->buffer_resource);
                if (buf_data && buf_data->width > 0 && buf_data->height > 0) {
                    [g_compositor_instance showAndSizeWindowForFirstClient:buf_data->width height:buf_data->height];
                }
            }
            
            if ([g_compositor_instance.renderingBackend respondsToSelector:@selector(renderSurface:)]) {
                [g_compositor_instance.renderingBackend renderSurface:surface];
            }
            // Trigger redraw after rendering surface
            // For Metal backend with continuous rendering, no need to call setNeedsDisplay:
            if (g_compositor_instance.window && g_compositor_instance.window.contentView) {
                if (g_compositor_instance.backendType == 1) {
                    // Metal backend - continuous rendering handles updates automatically
                    // No need to call setNeedsDisplay: with enableSetNeedsDisplay=NO
                } else {
                    // Cocoa backend - needs explicit redraw
                    [g_compositor_instance.window.contentView setNeedsDisplay:YES];
                }
            }
        });
    }
}

// C wrapper function to remove surface (for cleanup)
void remove_surface_from_renderer(struct wl_surface_impl *surface) {
    if (!g_compositor_instance) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Remove from Cocoa renderer if active
        if (g_compositor_instance.renderer) {
            [g_compositor_instance.renderer removeSurface:surface];
        }
        
        // Remove from Metal renderer if active
        if (g_compositor_instance.renderingBackend && 
            g_compositor_instance.backendType == 1 &&
            [g_compositor_instance.renderingBackend respondsToSelector:@selector(removeSurface:)]) {
            [g_compositor_instance.renderingBackend removeSurface:surface];
        }
    });
}

// C function to check if window should be hidden after client disconnects
// Called from client_destroy_listener after removing all surfaces
void macos_compositor_check_and_hide_window_if_needed(void) {
    if (!g_compositor_instance) {
        return;
    }
    
    // Check if there are any remaining surfaces
    // We need to check the surfaces list from wayland_compositor.c
    // Since we can't directly access it, we'll use a callback mechanism
    // For now, we'll check if the window is shown and hide it
    // The actual surface count check will be done in client_destroy_listener
    dispatch_async(dispatch_get_main_queue(), ^{
        if (g_compositor_instance.windowShown && g_compositor_instance.window) {
            NSLog(@"[WINDOW] All clients disconnected - hiding window");
            [g_compositor_instance.window orderOut:nil];
            g_compositor_instance.windowShown = NO;
        }
    });
}

@implementation MacOSCompositor

- (instancetype)initWithDisplay:(struct wl_display *)display window:(NSWindow *)window {
    self = [super init];
    if (self) {
        _display = display;
        _window = window;
        _eventLoop = wl_display_get_event_loop(display);
        _shouldStopEventThread = NO;
        _needs_frame_callbacks = NO;
        _frame_callback_source = NULL;
        _pending_resize_width = 0;
        _pending_resize_height = 0;
        _needs_resize_configure = NO;
        _windowShown = NO; // Track if window has been shown (delayed until first client)
        
        // Create custom view that accepts first responder and handles drawing
        NSRect contentRect = NSMakeRect(0, 0, 800, 600);
        CompositorView *compositorView = [[CompositorView alloc] initWithFrame:contentRect];
        
        // Use NSView drawing (like OWL compositor) - no CALayer needed
        // The view will draw using drawRect: and CoreGraphics
        [window setContentView:compositorView];
        
        // Set window delegate to detect resize
        [window setDelegate:self];
        
        // Make window accept key events and become key window
        [window setAcceptsMouseMovedEvents:YES];
        
        // Ensure window can become key and accept keyboard input
        [window setCollectionBehavior:NSWindowCollectionBehaviorDefault];
        
        // Make window resizable and allow focus
        [window setStyleMask:(NSWindowStyleMaskTitled |
                              NSWindowStyleMaskClosable |
                              NSWindowStyleMaskResizable |
                              NSWindowStyleMaskMiniaturizable)];
        
        // Don't show window initially - wait for first client to connect
        // Window will be shown and sized when first surface buffer is committed
        // [window makeKeyAndOrderFront:nil]; // DELAYED - shown when first client connects
        
        // Make compositor view first responder to receive keyboard events
        [window makeFirstResponder:compositorView];
        
        // Don't force window to become key yet - wait for client connection
        // [window becomeKeyWindow]; // DELAYED - done when window is shown
        
        // Create surface renderer with NSView (like OWL compositor)
        // Start with Cocoa renderer, will switch to Metal if full compositor detected
        _renderer = [[SurfaceRenderer alloc] initWithCompositorView:compositorView];
        _renderingBackend = _renderer;
        _backendType = 0; // RENDERING_BACKEND_COCOA
        
        // Set renderer reference in view for drawRect: calls
        compositorView.renderer = _renderer;
        
        // Store global reference for C callbacks (MUST be set before clients connect)
        g_compositor_instance = self;
        NSLog(@"   Global compositor instance set for client detection: %p", (void *)self);
        
        NSLog(@"🚀 macOS Wayland Compositor initialized");
        NSLog(@"   Window: %@", window.title);
        NSLog(@"   Display: %p", (void *)display);
        NSLog(@"   Initial backend: Cocoa (will auto-switch to Metal for full compositors)");
    }
    return self;
}

- (void)setupInputHandling {
    if (_seat && _window) {
        _inputHandler = [[InputHandler alloc] initWithSeat:_seat window:_window compositor:self];
        [_inputHandler setupInputHandling];
        
        // Set input handler reference in compositor view for keyboard event handling
        NSView *contentView = _window.contentView;
        if ([contentView isKindOfClass:[CompositorView class]]) {
            ((CompositorView *)contentView).inputHandler = _inputHandler;
        }
        
        // Set up event monitoring for mouse events only
        // Keyboard events are handled directly in CompositorView keyDown/keyUp methods
        NSEventMask eventMask = NSEventMaskLeftMouseDown | NSEventMaskLeftMouseUp |
                               NSEventMaskRightMouseDown | NSEventMaskRightMouseUp |
                               NSEventMaskOtherMouseDown | NSEventMaskOtherMouseUp |
                               NSEventMaskMouseMoved | NSEventMaskLeftMouseDragged |
                               NSEventMaskRightMouseDragged | NSEventMaskOtherMouseDragged |
                               NSEventMaskScrollWheel;
        
        [NSEvent addLocalMonitorForEventsMatchingMask:eventMask handler:^NSEvent *(NSEvent *event) {
            // CRITICAL: Always return the event to allow normal window processing
            // We just observe events for Wayland clients, but don't consume them
            if ([event window] == self.window) {
                // Check if event is in content area (not title bar)
                NSPoint locationInWindow = [event locationInWindow];
                NSRect contentRect = [self.window.contentView frame];
                
                // Only process events in content area - let window handle title bar events
                if (locationInWindow.y <= contentRect.size.height && locationInWindow.y >= 0 &&
                    locationInWindow.x >= 0 && locationInWindow.x <= contentRect.size.width) {
                    NSEventType type = [event type];
                    if (type == NSEventTypeMouseMoved || type == NSEventTypeLeftMouseDragged ||
                        type == NSEventTypeRightMouseDragged || type == NSEventTypeOtherMouseDragged ||
                        type == NSEventTypeLeftMouseDown || type == NSEventTypeLeftMouseUp ||
                        type == NSEventTypeRightMouseDown || type == NSEventTypeRightMouseUp ||
                        type == NSEventTypeOtherMouseDown || type == NSEventTypeOtherMouseUp ||
                        type == NSEventTypeScrollWheel) {
                        // Forward to Wayland clients but don't consume the event
                        [self.inputHandler handleMouseEvent:event];
                    }
                }
            }
            // ALWAYS return event - never consume it, so window controls work normally
            return event;
        }];
        
        NSLog(@"   ✓ Input handling set up");
    }
}

- (BOOL)start {
    init_compositor_logging();
    NSLog(@"✅ Starting compositor backend...");
    log_printf("[COMPOSITOR] ", "Starting compositor backend...\n");
    
    // Create Wayland protocol implementations
    // These globals are advertised to clients and enable EGL platform extension support
    // Clients querying the registry will see wl_compositor, which allows them to create
    // EGL surfaces using eglCreatePlatformWindowSurfaceEXT with Wayland surfaces
    _compositor = wl_compositor_create(_display);
    if (!_compositor) {
        NSLog(@"❌ Failed to create wl_compositor");
        return NO;
    }
    NSLog(@"   ✓ wl_compositor created (supports EGL platform extensions)");
    
    // Set up render callback for immediate rendering on commit
    g_compositor_instance = self;
    wl_compositor_set_render_callback(_compositor, render_surface_callback);
    
    // Set up title update callback to update window title when focus changes
    wl_compositor_set_title_update_callback(_compositor, macos_compositor_update_title);
    
    // Get window size for output
    NSRect frame = [_window.contentView bounds];
    _output = wl_output_create(_display, (int32_t)frame.size.width, (int32_t)frame.size.height, "macOS");
    if (!_output) {
        NSLog(@"❌ Failed to create wl_output");
        return NO;
    }
    NSLog(@"   ✓ wl_output created (%dx%d)", (int)frame.size.width, (int)frame.size.height);
    
    _seat = wl_seat_create(_display);
    if (!_seat) {
        NSLog(@"❌ Failed to create wl_seat");
        return NO;
    }
    NSLog(@"   ✓ wl_seat created");
    
    // Set seat in compositor for focus management
    wl_compositor_set_seat(_seat);
    
    _shm = wl_shm_create(_display);
    if (!_shm) {
        NSLog(@"❌ Failed to create wl_shm");
        return NO;
    }
    NSLog(@"   ✓ wl_shm created");
    
    _subcompositor = wl_subcompositor_create(_display);
    if (!_subcompositor) {
        NSLog(@"❌ Failed to create wl_subcompositor");
        return NO;
    }
    NSLog(@"   ✓ wl_subcompositor created");
    
    _data_device_manager = wl_data_device_manager_create(_display);
    if (!_data_device_manager) {
        NSLog(@"❌ Failed to create wl_data_device_manager");
        return NO;
    }
    NSLog(@"   ✓ wl_data_device_manager created");
    
    _xdg_wm_base = xdg_wm_base_create(_display);
    if (!_xdg_wm_base) {
        NSLog(@"❌ Failed to create xdg_wm_base");
        return NO;
    }
    // Set initial output size
    NSRect initialFrame = [_window.contentView bounds];
    xdg_wm_base_set_output_size(_xdg_wm_base, (int32_t)initialFrame.size.width, (int32_t)initialFrame.size.height);
    NSLog(@"   ✓ xdg_wm_base created");
    
    // Create optional protocol implementations to satisfy client requirements
    // These are minimal stubs - full implementations can be added later
    
    // Primary selection protocol
    struct wl_primary_selection_manager_impl *primary_selection = wl_primary_selection_create(_display);
    if (primary_selection) {
        NSLog(@"   ✓ Primary selection protocol created");
    }
    
    // Decoration manager protocol
    struct wl_decoration_manager_impl *decoration = wl_decoration_create(_display);
    if (decoration) {
        NSLog(@"   ✓ Decoration manager protocol created");
    }
    
    // Toplevel icon protocol
    struct wl_toplevel_icon_manager_impl *toplevel_icon = wl_toplevel_icon_create(_display);
    if (toplevel_icon) {
        NSLog(@"   ✓ Toplevel icon protocol created");
    }
    
    // XDG activation protocol
    struct wl_activation_manager_impl *activation = wl_activation_create(_display);
    if (activation) {
        NSLog(@"   ✓ XDG activation protocol created");
    }
    
    // Fractional scale protocol
    struct wl_fractional_scale_manager_impl *fractional_scale = wl_fractional_scale_create(_display);
    if (fractional_scale) {
        NSLog(@"   ✓ Fractional scale protocol created");
    }
    
    // Cursor shape protocol
    struct wl_cursor_shape_manager_impl *cursor_shape = wl_cursor_shape_create(_display);
    if (cursor_shape) {
        NSLog(@"   ✓ Cursor shape protocol created");
    }
    
    // Text input protocol
    struct wl_text_input_manager_impl *text_input = wl_text_input_create(_display);
    if (text_input) {
        NSLog(@"   ✓ Text input protocol created");
    }
    
    // Viewporter protocol (critical for Weston compatibility)
    struct wl_viewporter_impl *viewporter = wl_viewporter_create(_display);
    if (viewporter) {
        NSLog(@"   ✓ Viewporter protocol created");
    }
    
    // Shell protocol (legacy compatibility)
    struct wl_shell_impl *shell = wl_shell_create(_display);
    if (shell) {
        NSLog(@"   ✓ Shell protocol created");
    }
    
    // Screencopy protocol (screen capture)
    struct wl_screencopy_manager_impl *screencopy = wl_screencopy_manager_create(_display);
    if (screencopy) {
        NSLog(@"   ✓ Screencopy protocol created");
    }
    
    // Linux DMA-BUF protocol (critical for wlroots and hardware-accelerated clients)
    struct wl_linux_dmabuf_manager_impl *linux_dmabuf = wl_linux_dmabuf_create(_display);
    if (linux_dmabuf) {
        NSLog(@"   ✓ Linux DMA-BUF protocol created");
    }
    
    // Idle inhibit protocol (prevent screensaver)
    struct wl_idle_inhibit_manager_impl *idle_inhibit = wl_idle_inhibit_manager_create(_display);
    if (idle_inhibit) {
        NSLog(@"   ✓ Idle inhibit protocol created");
    }
    
    // Pointer gestures protocol (trackpad gestures)
    struct wl_pointer_gestures_impl *pointer_gestures = wl_pointer_gestures_create(_display);
    if (pointer_gestures) {
        NSLog(@"   ✓ Pointer gestures protocol created");
    }
    
    // Relative pointer protocol (relative motion for games)
    struct wl_relative_pointer_manager_impl *relative_pointer = wl_relative_pointer_manager_create(_display);
    if (relative_pointer) {
        NSLog(@"   ✓ Relative pointer protocol created");
    }
    
    // Pointer constraints protocol (pointer locking/confining for games)
    struct wl_pointer_constraints_impl *pointer_constraints = wl_pointer_constraints_create(_display);
    if (pointer_constraints) {
        NSLog(@"   ✓ Pointer constraints protocol created");
    }
    
    // Register additional protocols
    struct wl_tablet_manager_impl *tablet = wl_tablet_create(_display);
    if (tablet) {
        NSLog(@"   ✓ Tablet protocol created");
    }
    
    struct wl_idle_manager_impl *idle_manager = wl_idle_manager_create(_display);
    if (idle_manager) {
        NSLog(@"   ✓ Idle manager protocol created");
    }
    
    struct wl_keyboard_shortcuts_inhibit_manager_impl *keyboard_shortcuts = wl_keyboard_shortcuts_create(_display);
    if (keyboard_shortcuts) {
        NSLog(@"   ✓ Keyboard shortcuts inhibit protocol created");
    }
    
    // GTK Shell protocol (for GTK applications)
    struct wl_gtk_shell_manager_impl *gtk_shell = wl_gtk_shell_create(_display);
    if (gtk_shell) {
        NSLog(@"   ✓ GTK Shell protocol created");
    }
    
    // Plasma Shell protocol (for KDE applications)
    struct wl_plasma_shell_manager_impl *plasma_shell = wl_plasma_shell_create(_display);
    if (plasma_shell) {
        NSLog(@"   ✓ Plasma Shell protocol created");
    }
    
    // Qt Wayland Extensions (for QtWayland applications)
    struct wl_qt_surface_extension_impl *qt_surface = wl_qt_surface_extension_create(_display);
    if (qt_surface) {
        NSLog(@"   ✓ Qt Surface Extension protocol created");
    }
    struct wl_qt_windowmanager_impl *qt_wm = wl_qt_windowmanager_create(_display);
    if (qt_wm) {
        NSLog(@"   ✓ Qt Window Manager protocol created");
    } else {
        NSLog(@"   ✗ Qt Window Manager protocol creation failed");
    }
    
    // Start dedicated Wayland event processing thread
    NSLog(@"   ✓ Starting Wayland event processing thread");
    _shouldStopEventThread = NO;
    __unsafe_unretained MacOSCompositor *unsafeSelf = self;
    _eventThread = [[NSThread alloc] initWithBlock:^{
        MacOSCompositor *compositor = unsafeSelf;
        if (!compositor) return;
        
        log_printf("[COMPOSITOR] ", "🚀 Wayland event thread started\n");
        
        // Set up proper error handling for client connections
        // wl_display_run() handles client connections internally
        // Errors like "failed to read client connection" are normal when clients disconnect
        // and are handled gracefully by libwayland-server
        
        @try {
            wl_display_run(compositor.display);
        } @catch (NSException *exception) {
            log_printf("[COMPOSITOR] ", "⚠️ Exception in Wayland event thread: %s\n", 
                       [exception.reason UTF8String]);
        }
        
        log_printf("[COMPOSITOR] ", "🛑 Wayland event thread stopped\n");
    }];
    _eventThread.name = @"WaylandEventThread";
    [_eventThread start];
    
    // Set up frame rendering using CVDisplayLink - syncs to display refresh rate
    // This automatically matches the display's refresh rate (e.g., 60Hz, 120Hz, etc.)
    CVDisplayLinkRef displayLink = NULL;
    CVDisplayLinkCreateWithActiveCGDisplays(&displayLink);
    
    if (displayLink) {
        // Set callback to renderFrame
        CVDisplayLinkSetOutputCallback(displayLink, displayLinkCallback, (__bridge void *)self);
        // Start display link - it will continue running even when window loses focus
        // This ensures Wayland clients continue to receive frame callbacks and can render
        CVDisplayLinkStart(displayLink);
        _displayLink = displayLink;
        
        // Get actual refresh rate for logging
        CVTime time = CVDisplayLinkGetNominalOutputVideoRefreshPeriod(displayLink);
        double refreshRate = 60.0; // Default fallback
        if (!(time.flags & kCVTimeIsIndefinite) && time.timeValue != 0) {
            refreshRate = (double)time.timeScale / (double)time.timeValue;
        }
        NSLog(@"   Frame rendering active (%.0fHz - synced to display)", refreshRate);
    } else {
        // Fallback to 60Hz timer if CVDisplayLink fails
        NSTimer *fallbackTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/60.0
                                                                  target:self
                                                                selector:@selector(renderFrame)
                                                                userInfo:nil
                                                                 repeats:YES];
        (void)fallbackTimer; // Timer is retained by the run loop, no need to store reference
        _displayLink = NULL;
        NSLog(@"   Frame rendering active (60Hz - fallback timer)");
    }
    
    // Add a heartbeat timer to show compositor is alive (every 5 seconds)
    static int heartbeat_count = 0;
    [NSTimer scheduledTimerWithTimeInterval:5.0
                                     repeats:YES
                                       block:^(NSTimer *timer) {
        heartbeat_count++;
        log_printf("[COMPOSITOR] ", "💓 Compositor heartbeat #%d - window visible, event thread running\n", heartbeat_count);
        // Stop after 12 heartbeats (1 minute) to reduce log spam
        if (heartbeat_count >= 12) {
            [timer invalidate];
            log_printf("[COMPOSITOR] ", "💓 Heartbeat logging stopped (compositor still running)\n");
        }
    }];
    
    // Set up input handling
    [self setupInputHandling];
    
    NSLog(@"✅ Compositor backend started");
    NSLog(@"   Wayland event processing thread active");
    NSLog(@"   Input handling active");
    
    return YES;
}


- (BOOL)processWaylandEvents {
    // DEPRECATED: Event processing is now handled by the dedicated event thread
    // This method is kept for compatibility but should not be used
    // The event thread handles all Wayland event processing with blocking dispatch
    return NO;
}

// CVDisplayLink callback - called at display refresh rate
static CVReturn displayLinkCallback(CVDisplayLinkRef displayLink,
                                   const CVTimeStamp *inNow,
                                   const CVTimeStamp *inOutputTime,
                                   CVOptionFlags flagsIn,
                                   CVOptionFlags *flagsOut,
                                   void *displayLinkContext) {
    (void)displayLink;
    (void)inNow;
    (void)inOutputTime;
    (void)flagsIn;
    (void)flagsOut;
    MacOSCompositor *compositor = (__bridge MacOSCompositor *)displayLinkContext;
    if (compositor) {
        // Render on main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [compositor renderFrame];
        });
    }
    return kCVReturnSuccess;
}

// Show and size window when first client connects
- (void)showAndSizeWindowForFirstClient:(int32_t)width height:(int32_t)height {
    if (_windowShown) {
        return; // Already shown
    }
    
    NSLog(@"[WINDOW] First client connected - showing window with size %dx%d", width, height);
    
    // Resize window to match client surface size
    // frameRectForContentRect automatically accounts for window frame (titlebar, borders)
    NSRect contentRect = NSMakeRect(0, 0, width, height);
    NSRect windowFrame = [_window frameRectForContentRect:contentRect];
    
    // Center window on screen
    NSScreen *screen = [NSScreen mainScreen];
    NSRect screenFrame = screen ? screen.visibleFrame : NSMakeRect(0, 0, 1920, 1080);
    CGFloat x = screenFrame.origin.x + (screenFrame.size.width - windowFrame.size.width) / 2;
    CGFloat y = screenFrame.origin.y + (screenFrame.size.height - windowFrame.size.height) / 2;
    windowFrame.origin = NSMakePoint(x, y);
    
    // Set window frame
    [_window setFrame:windowFrame display:YES];  // Use display:YES to ensure immediate update
    
    // CRITICAL: Ensure content view frame matches window content rect
    // The content view might have been initialized with a different size (800x600)
    NSView *contentView = _window.contentView;
    NSRect contentViewFrame = [_window contentRectForFrameRect:windowFrame];
    contentViewFrame.origin = NSMakePoint(0, 0);  // Content view origin is always (0,0)
    contentView.frame = contentViewFrame;
    NSLog(@"[WINDOW] Content view resized to: %.0fx%.0f", 
          contentViewFrame.size.width, contentViewFrame.size.height);
    
    // Ensure Metal view (if exists) matches window size before showing
    if ([contentView isKindOfClass:[CompositorView class]]) {
        CompositorView *compositorView = (CompositorView *)contentView;
        
        // If Metal view exists, ensure it matches the window content size
        if (_backendType == 1 && compositorView.metalView) {
            // Metal view frame should match content view bounds (in points)
            // CRITICAL: Do NOT manually set bounds - MTKView handles this automatically
            // Setting bounds manually interferes with MTKView's Retina scaling logic
            NSRect contentBounds = compositorView.bounds;
            compositorView.metalView.frame = contentBounds;
            // MTKView automatically sets bounds to match frame - don't override!
            // The drawableSize will be automatically calculated based on frame size and Retina scale
            [compositorView.metalView setNeedsDisplay:YES];
            NSLog(@"[WINDOW] Metal view sized to match window content: frame=%.0fx%.0f (MTKView handles bounds/drawable automatically)", 
                  contentBounds.size.width, contentBounds.size.height);
        }
    }
    
    // Update output size to match client
    if (_output) {
        wl_output_update_size(_output, width, height);
    }
    if (_xdg_wm_base) {
        xdg_wm_base_set_output_size(_xdg_wm_base, width, height);
    }
    
    // Show window and make it key
    [_window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    [_window becomeKeyWindow];
    
    _windowShown = YES;
    
    NSLog(@"[WINDOW] Window shown and sized to %dx%d", width, height);
}

// NSWindowDelegate method - called when window becomes key
- (void)windowDidBecomeKey:(NSNotification *)notification {
    (void)notification;
    NSLog(@"[WINDOW] Window became key - accepting keyboard input");
    
    // Ensure compositor view is first responder when window becomes key
    NSView *contentView = _window.contentView;
    if ([contentView isKindOfClass:[CompositorView class]] && _window.firstResponder != contentView) {
        [_window makeFirstResponder:contentView];
    }
}

// NSWindowDelegate method - called when window is resized
- (void)windowDidResize:(NSNotification *)notification {
    NSWindow *window = notification.object;
    NSRect frame = [window.contentView bounds];
    int32_t width = (int32_t)frame.size.width;
    int32_t height = (int32_t)frame.size.height;
    
    NSLog(@"[WINDOW] Window resized to %dx%d", width, height);
    
    // Update Metal view frame to match window size if Metal backend is active
    NSView *contentView = window.contentView;
    if ([contentView isKindOfClass:[CompositorView class]]) {
        CompositorView *compositorView = (CompositorView *)contentView;
        
        // If Metal view exists, ensure it matches the window size
        if (_backendType == 1 && compositorView.metalView) {
            NSRect metalFrame = compositorView.bounds;
            compositorView.metalView.frame = metalFrame;
            // CRITICAL: Do NOT manually set bounds - MTKView handles this automatically
            // MTKView automatically sets bounds to match frame and calculates drawableSize
            // Manually setting bounds interferes with Retina scaling
            NSLog(@"[WINDOW] Metal view resized to match window: frame=%.0fx%.0f (MTKView handles bounds/drawable automatically)", 
                  metalFrame.size.width, metalFrame.size.height);
            
            // Trigger Metal view to update its drawable size
            [compositorView.metalView setNeedsDisplay:YES];
        } else {
            // Cocoa backend - trigger redraw
            [contentView setNeedsDisplay:YES];
        }
    }
    
    // Update output size
    if (_output) {
        wl_output_update_size(_output, width, height);
    }
    
    // Update xdg_wm_base output size immediately
    if (_xdg_wm_base) {
        xdg_wm_base_set_output_size(_xdg_wm_base, width, height);
    }
    
    // Schedule configure events to be sent from the Wayland event thread
    // Wayland server functions must be called from the event thread
    _pending_resize_width = width;
    _pending_resize_height = height;
    _needs_resize_configure = YES;
    
    // Trigger the idle callback immediately to send configure events
    if (_eventLoop) {
        // Remove existing callback if any
        if (_frame_callback_source) {
            wl_event_source_remove(_frame_callback_source);
            _frame_callback_source = NULL;
        }
        // Add new idle callback to send configure events immediately
        _needs_frame_callbacks = YES;
        _frame_callback_source = wl_event_loop_add_idle(_eventLoop, send_frame_callbacks_idle, (__bridge void *)self);
    }
}

// Idle callback to send frame callbacks from Wayland event thread
static void send_frame_callbacks_idle(void *data) {
    MacOSCompositor *compositor = (__bridge MacOSCompositor *)data;
    if (compositor) {
        // This runs on the Wayland event thread - safe to call Wayland server functions
        
        // Handle pending resize configure events first
        if (compositor.needs_resize_configure) {
            if (compositor.xdg_wm_base) {
                xdg_wm_base_send_configure_to_all_toplevels(compositor.xdg_wm_base, 
                                                             compositor.pending_resize_width, 
                                                             compositor.pending_resize_height);
            }
            compositor.needs_resize_configure = NO;
        }
        
        // Send frame callbacks
        wl_send_frame_callbacks();
        // Clear the source pointer since idle callbacks are automatically removed after firing
        compositor.frame_callback_source = NULL;
        compositor.needs_frame_callbacks = NO;
    }
}

- (void)sendFrameCallbacksImmediately {
    // Force immediate frame callback dispatch - used after input events
    // This allows clients to render updates immediately in response to input
    // NOTE: Must be called from main thread, but the idle callback will run on event thread
    if (_eventLoop && wl_has_pending_frame_callbacks()) {
        // Remove any existing idle callback and schedule a new one
        // The idle callback will be processed by the event thread on its next iteration
        if (_frame_callback_source) {
            wl_event_source_remove(_frame_callback_source);
            _frame_callback_source = NULL;
        }
        // Schedule idle callback - event thread will process it very quickly
        // Do NOT call wl_event_loop_dispatch here - event loop runs in separate thread!
        _needs_frame_callbacks = YES;
        _frame_callback_source = wl_event_loop_add_idle(_eventLoop, send_frame_callbacks_idle, (__bridge void *)self);
    }
}

- (void)renderFrame {
    // Render callback - called at display refresh rate (via CVDisplayLink)
    // Event processing is handled by the dedicated Wayland event thread
    // This ensures smooth rendering updates synced to display refresh
    // NOTE: This continues to run even when the window loses focus, ensuring
    // Wayland clients continue to receive frame callbacks and can render updates

    // Schedule frame callback sending if there are pending frame callbacks
    // This ensures nested compositors (like Weston) receive frame callbacks continuously
    // Frame callbacks are critical for nested compositors to know when to render
    if (_eventLoop && wl_has_pending_frame_callbacks()) {
        // Always schedule frame callbacks if pending, even if one is already scheduled
        // This ensures frame callbacks are sent at display refresh rate for smooth updates
        if (!_frame_callback_source) {
            _needs_frame_callbacks = YES;
            _frame_callback_source = wl_event_loop_add_idle(_eventLoop, send_frame_callbacks_idle, (__bridge void *)self);
        }
    }
    
    // Check for any committed surfaces and render them
    // Note: The event thread also triggers rendering, but this ensures
    // we catch any surfaces that might have been committed between thread dispatches
    // Continue rendering even when window isn't focused - clients need frame callbacks
    struct wl_surface_impl *surface = wl_get_all_surfaces();
    while (surface) {
        // Store next pointer before potentially accessing surface (may be freed)
        struct wl_surface_impl *next = surface->next;
        
        // Only render if surface is still valid and has committed buffer
        if (surface->committed && surface->buffer_resource && surface->resource) {
            // Verify resource is still valid before rendering
            struct wl_client *client = wl_resource_get_client(surface->resource);
            if (client) {
                // Use active rendering backend (Cocoa or Metal)
                // Render regardless of window focus state - clients need updates
                if (self->_renderingBackend) {
                    if ([self->_renderingBackend respondsToSelector:@selector(renderSurface:)]) {
                        [self->_renderingBackend renderSurface:surface];
                    } else if (self->_renderer) {
                        // Fallback to Cocoa renderer
                        [self->_renderer renderSurface:surface];
                    }
                }
            }
            surface->committed = false;
        }
        surface = next;
    }
    
    // Trigger view redraw at display refresh rate for smooth updates
    // For Metal backend with continuous rendering enabled, the view draws automatically
    // but we ensure frame callbacks are sent so nested compositors can render
    if (_window && _window.contentView) {
        if (_backendType == 1) {
            // Metal backend - continuous rendering is enabled via enableSetNeedsDisplay=NO
            // The Metal view will automatically call drawInMTKView: at display refresh rate
            // No need to call setNeedsDisplay: - it's handled by MTKView's internal display link
        } else {
            // Cocoa backend - needs explicit redraw
            [_window.contentView setNeedsDisplay:YES];
        }
    }
}


- (void)stop {
    NSLog(@"🛑 Stopping compositor backend...");
    
    // Clear global reference
    if (g_compositor_instance == self) {
        g_compositor_instance = NULL;
    }
    
    // Signal event thread to stop
    _shouldStopEventThread = YES;
    if (_display) {
        wl_display_terminate(_display);
    }
    
    // Wait for event thread to finish (with timeout)
    if (_eventThread && [_eventThread isExecuting]) {
        // Give thread up to 1 second to finish
        NSDate *timeout = [NSDate dateWithTimeIntervalSinceNow:1.0];
        while ([_eventThread isExecuting] && [timeout timeIntervalSinceNow] > 0) {
            [NSThread sleepForTimeInterval:0.01];
        }
        
        if ([_eventThread isExecuting]) {
            NSLog(@"⚠️ Event thread did not stop gracefully, forcing termination");
        }
    }
    _eventThread = nil;
    
    // Stop display link
    if (_displayLink) {
        CVDisplayLinkStop(_displayLink);
        CVDisplayLinkRelease(_displayLink);
        _displayLink = NULL;
    }
    
    // Frame callback idle source will be automatically cleaned up when event loop stops
    // No need to manually remove it
    _frame_callback_source = NULL;
    
    // Clean up Wayland resources
    if (_xdg_wm_base) {
        xdg_wm_base_destroy(_xdg_wm_base);
        _xdg_wm_base = NULL;
    }
    
    if (_shm) {
        wl_shm_destroy(_shm);
        _shm = NULL;
    }
    
    if (_seat) {
        wl_seat_destroy(_seat);
        _seat = NULL;
    }
    
    if (_output) {
        wl_output_destroy(_output);
        _output = NULL;
    }
    
    if (_compositor) {
        wl_compositor_destroy(_compositor);
        _compositor = NULL;
    }
    
    cleanup_logging();
    NSLog(@"🛑 Compositor backend stopped");
}

- (void)switchToMetalBackend {
    // Switch from Cocoa to Metal rendering backend for full compositors
    if (_backendType == 1) { // Already using Metal
        return;
    }
    
    NSLog(@"🔄 Switching to Metal rendering backend for full compositor support");
    
    // Get the compositor view
    NSView *contentView = _window.contentView;
    if (![contentView isKindOfClass:[CompositorView class]]) {
        NSLog(@"⚠️ Content view is not CompositorView, cannot switch to Metal");
        return;
    }
    
    CompositorView *compositorView = (CompositorView *)contentView;
    
    // Get current window size for Metal view
    NSRect windowBounds = compositorView.bounds;
    
    // Create Metal view with exact window size
    // Use a custom class that allows window dragging for proper window controls
    Class CompositorMTKViewClass = NSClassFromString(@"CompositorMTKView");
    MTKView *metalView = nil;
    if (CompositorMTKViewClass) {
        metalView = [[CompositorMTKViewClass alloc] initWithFrame:windowBounds];
    } else {
        // Fallback to regular MTKView if custom class not available
        metalView = [[MTKView alloc] initWithFrame:windowBounds];
    }
    metalView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    metalView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    metalView.clearColor = MTLClearColorMake(0.1, 0.1, 0.2, 1.0);
    
    // Ensure Metal view is opaque and properly configured
    metalView.wantsLayer = YES;
    metalView.layer.opaque = YES;
    metalView.layerContentsRedrawPolicy = NSViewLayerContentsRedrawDuringViewResize;
    
    // CRITICAL: Don't block mouse events - allow window controls to work
    // The Metal view should not intercept mouse events meant for window controls
    // Note: mouseDownCanMoveWindow is a method, not a property - handled in CompositorView
    // Don't set ignoresMouseEvents - we need to receive events for Wayland clients
    // But ensure the view doesn't block window controls
    
    // Ensure Metal view matches window size exactly
    metalView.frame = windowBounds;
    
    NSLog(@"   Creating Metal view with frame: %.0fx%.0f at (%.0f, %.0f)",
          windowBounds.size.width, windowBounds.size.height,
          windowBounds.origin.x, windowBounds.origin.y);
    
    // Create Metal renderer
    MetalRenderer *metalRenderer = [[MetalRenderer alloc] initWithMetalView:metalView];
    if (!metalRenderer) {
        NSLog(@"❌ Failed to create Metal renderer");
        return;
    }
    
    // Add Metal view as subview (on top of Cocoa view for rendering)
    // The Metal view renders content but allows events to pass through to CompositorView
    [compositorView addSubview:metalView positioned:NSWindowAbove relativeTo:nil];
    compositorView.metalView = metalView;
    
    // Ensure CompositorView remains the responder chain - Metal view just renders
    // This allows CompositorView to handle events while Metal view displays content
    [metalView setNextResponder:compositorView];
    
    // CRITICAL: Ensure mouse events pass through to CompositorView for tracking areas
    // The Metal view should not block mouse events - they need to reach the tracking area
    // Don't set ignoresMouseEvents - we need events for Wayland clients
    // But ensure the view hierarchy allows events to reach CompositorView's tracking area
    
    // Update input handler's tracking area to cover the full view including Metal view
    if (_inputHandler) {
        // Remove old tracking area and create new one covering full bounds
        NSView *inputContentView = _window.contentView;
        for (NSTrackingArea *area in [inputContentView trackingAreas]) {
            [inputContentView removeTrackingArea:area];
        }
        // Re-setup input handling with updated tracking area
        [_inputHandler setupInputHandling];
    }
    
    // Switch rendering backend
    _renderingBackend = metalRenderer;
    _backendType = 1; // RENDERING_BACKEND_METAL
    
    // Update render callback to use Metal backend
    // The render_surface_callback will now use the Metal backend
    
    NSLog(@"✅ Switched to Metal rendering backend");
    NSLog(@"   Metal view frame: %.0fx%.0f", metalView.frame.size.width, metalView.frame.size.height);
    NSLog(@"   Window bounds: %.0fx%.0f", windowBounds.size.width, windowBounds.size.height);
    NSLog(@"   Metal renderer: %@", metalRenderer);
}

- (void)updateWindowTitleForClient:(struct wl_client *)client {
    if (!_window || !client) return;
    
    // Try to get client process name
    pid_t client_pid = 0;
    uid_t client_uid = 0;
    gid_t client_gid = 0;
    wl_client_get_credentials(client, &client_pid, &client_uid, &client_gid);
    
    NSString *windowTitle = @"Wawona"; // Default title
    
    if (client_pid > 0) {
        char proc_path[PROC_PIDPATHINFO_MAXSIZE] = {0};
        int ret = proc_pidpath(client_pid, proc_path, sizeof(proc_path));
        if (ret > 0) {
            NSString *processPath = [NSString stringWithUTF8String:proc_path];
            NSString *processName = [processPath lastPathComponent];
            // Remove common suffixes and make it look nice
            processName = [processName stringByReplacingOccurrencesOfString:@".exe" withString:@""];
            windowTitle = [NSString stringWithFormat:@"%@ - Wawona", processName];
        }
    } else {
        // For waypipe connections, try to detect based on focused surface
        // Check if we have a focused surface and try to infer the client name
        if (_seat && _seat->focused_surface) {
            struct wl_surface_impl *surface = (struct wl_surface_impl *)_seat->focused_surface;
            if (surface && surface->resource) {
                struct wl_client *surface_client = wl_resource_get_client(surface->resource);
                if (surface_client == client) {
                    // This is the focused client - use a generic name
                    windowTitle = @"Wayland Client - Wawona";
                }
            }
        }
    }
    
    // Update window title
    [_window setTitle:windowTitle];
    NSLog(@"[WINDOW] Updated title to: %@", windowTitle);
}

// C function to set CSD mode for a toplevel (hide/show macOS window decorations)
void macos_compositor_set_csd_mode_for_toplevel(struct xdg_toplevel_impl *toplevel, bool csd) {
    if (!g_compositor_instance || !toplevel) {
        return;
    }
    
    // Dispatch to main thread to update UI
    dispatch_async(dispatch_get_main_queue(), ^{
        NSWindow *window = g_compositor_instance.window;
        if (!window) {
            return;
        }
        
        // Get current style mask
        NSWindowStyleMask currentStyle = window.styleMask;
        
        if (csd) {
            // CLIENT_SIDE decorations - hide macOS window decorations
            // Remove titlebar, close button, etc. - client will draw its own decorations
            NSWindowStyleMask csdStyle = NSWindowStyleMaskBorderless | NSWindowStyleMaskResizable;
            if (currentStyle != csdStyle) {
                window.styleMask = csdStyle;
                NSLog(@"[CSD] Window decorations hidden for CLIENT_SIDE decoration mode");
            }
        } else {
            // SERVER_SIDE decorations - show macOS window decorations
            // Show titlebar, close button, resize controls, etc.
            NSWindowStyleMask gsdStyle = (NSWindowStyleMaskTitled |
                                         NSWindowStyleMaskClosable |
                                         NSWindowStyleMaskResizable |
                                         NSWindowStyleMaskMiniaturizable);
            if (currentStyle != gsdStyle) {
                window.styleMask = gsdStyle;
                NSLog(@"[CSD] Window decorations shown for SERVER_SIDE decoration mode");
            }
        }
    });
}

// C function to activate/raise the window (called from activation protocol)
void macos_compositor_activate_window(void) {
    if (!g_compositor_instance) {
        return;
    }
    
    // Dispatch to main thread to raise window
    dispatch_async(dispatch_get_main_queue(), ^{
        NSWindow *window = g_compositor_instance.window;
        if (!window) {
            return;
        }
        
        // Raise window to front and make it key
        [window makeKeyAndOrderFront:nil];
        [NSApp activateIgnoringOtherApps:YES];
        [window becomeKeyWindow];
        
        NSLog(@"[ACTIVATION] Window activated and raised to front");
    });
}

- (void)dealloc {
    [self stop];
    [super dealloc];
}

@end

