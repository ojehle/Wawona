// WawonaEventLoopManager.m - Event loop and TCP accept handling implementation
// Extracted from WawonaCompositor.m for better organization

#import "WawonaEventLoopManager.h"
#import "WawonaCompositor.h"
#import "WawonaClientManager.h"
#include "../logging/logging.h"
#include "WawonaSettings.h"
#include <wayland-server-core.h>
#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <string.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <unistd.h>
#ifdef __APPLE__
#import <CoreFoundation/CoreFoundation.h>
#endif

extern WawonaCompositor *g_wl_compositor_instance;
extern int macos_compositor_get_client_count(void);
extern bool macos_compositor_multiple_clients_enabled(void);

static void waylandEventLoopCallback(CFFileDescriptorRef fdref, CFOptionFlags callBackTypes, void *info) {
  WawonaCompositor *compositor = (__bridge WawonaCompositor *)info;
  
  // Dispatch Wayland events
  // 0 timeout means don't block
  wl_event_loop_dispatch(compositor.eventLoop, 0);
  wl_display_flush_clients(compositor.display);
  
  // Re-enable callback
  CFFileDescriptorEnableCallBacks(fdref, kCFFileDescriptorReadCallBack);
}

static void tcpAcceptCallback(CFFileDescriptorRef fdref, CFOptionFlags callBackTypes, void *info) {
  WawonaCompositor *compositor = (__bridge WawonaCompositor *)info;
  int listen_fd = compositor.tcp_listen_fd;
  
  if (listen_fd < 0) return;
  
  // Accept all pending connections
  struct sockaddr_in client_addr;
  socklen_t client_len = sizeof(client_addr);
  
  while (true) {
    int client_fd = accept(listen_fd, (struct sockaddr *)&client_addr, &client_len);
    if (client_fd < 0) {
      if (errno != EWOULDBLOCK && errno != EAGAIN) {
        log_printf("COMPOSITOR", "⚠️ accept() failed: %s\n", strerror(errno));
      }
      break;
    }
    
    // Configure non-blocking
    int flags = fcntl(client_fd, F_GETFL, 0);
    if (flags >= 0) fcntl(client_fd, F_SETFL, flags | O_NONBLOCK);
    
    // Check multiple clients setting
    BOOL allowMultiple = macos_compositor_multiple_clients_enabled();
    if (!allowMultiple && macos_compositor_get_client_count() > 0) {
        log_printf("COMPOSITOR", "🚫 TCP client rejected: multiple clients disabled\n");
        close(client_fd);
        continue;
    }
    
    struct wl_client *client = wl_client_create(compositor.display, client_fd);
    if (!client) {
        log_printf("COMPOSITOR", "⚠️ Failed to create Wayland client for fd %d\n", client_fd);
        close(client_fd);
    } else {
        log_printf("COMPOSITOR", "✅ Accepted TCP connection (fd=%d), client %p\n", client_fd, client);
        macos_compositor_handle_client_connect();
    }
  }
  
  // Re-enable callback
  CFFileDescriptorEnableCallBacks(fdref, kCFFileDescriptorReadCallBack);
}

@implementation WawonaEventLoopManager {
  WawonaCompositor *_compositor;
  CFFileDescriptorRef _waylandCfFd;
  CFFileDescriptorRef _tcpCfFd;
  NSTimer *_maintenanceTimer;
}

- (instancetype)initWithCompositor:(WawonaCompositor *)compositor {
  self = [super init];
  if (self) {
    _compositor = compositor;
    _waylandCfFd = NULL;
    _tcpCfFd = NULL;
    _maintenanceTimer = nil;
  }
  return self;
}

- (BOOL)setupEventLoop {
  // Event loop is already created by wl_display_create
  _eventLoop = wl_display_get_event_loop(_compositor.display);
  return _eventLoop != NULL;
}

- (void)startEventThread {
  if (!_compositor) {
    return;
  }

  NSLog(@"   ✓ Starting Wayland event processing thread");
  _compositor.shouldStopEventThread = NO;
  __unsafe_unretained WawonaCompositor *unsafeSelf = _compositor;
  _compositor.eventThread = [[NSThread alloc] initWithBlock:^{
    WawonaCompositor *compositor = unsafeSelf;
    if (!compositor)
      return;

    log_printf("COMPOSITOR", "🚀 Wayland event thread started\n");

    // Set up proper error handling for client connections
    // wl_display_run() handles client connections internally
    // NOTE: You may see "failed to read client connection (pid 0)" errors
    // from libwayland-server. These are NORMAL and EXPECTED when:
    // - waypipe clients test/check the socket connection (happens during
    // colima-client startup)
    // - Clients connect then immediately disconnect to verify connectivity
    // - "pid 0" means PID unavailable (normal for waypipe forwarded
    // connections)
    // - These are transient connection attempts, not real errors
    // - libwayland-server handles them gracefully and continues accepting
    // connections
    // - The actual connection will succeed on retry
    // This error is printed by libwayland-server to stderr and cannot be
    // suppressed from our code.
    log_printf("COMPOSITOR",
               "ℹ️  Note: Transient 'failed to read client connection' errors "
               "during client setup are normal and harmless\n");

    @try {
      // Setup NSRunLoop integration for Wayland event loop
      struct wl_event_loop *eventLoop = wl_display_get_event_loop(compositor.display);
      int wayland_fd = wl_event_loop_get_fd(eventLoop);
      
      CFFileDescriptorContext ctx = {0, (__bridge void *)compositor, NULL, NULL, NULL};
      CFFileDescriptorRef waylandCfFd = CFFileDescriptorCreate(kCFAllocatorDefault, wayland_fd, true, waylandEventLoopCallback, &ctx);
      if (waylandCfFd) {
          CFRunLoopSourceRef source = CFFileDescriptorCreateRunLoopSource(kCFAllocatorDefault, waylandCfFd, 0);
          CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
          CFRelease(source);
          CFFileDescriptorEnableCallBacks(waylandCfFd, kCFFileDescriptorReadCallBack);
          log_printf("COMPOSITOR", "✅ Added Wayland fd %d to NSRunLoop\n", wayland_fd);
      } else {
          log_printf("COMPOSITOR", "⚠️ Failed to create CFFileDescriptor for Wayland fd\n");
      }

      // Setup NSRunLoop integration for TCP listen socket
      CFFileDescriptorRef tcpCfFd = NULL;
      if (compositor.tcp_listen_fd >= 0) {
          tcpCfFd = CFFileDescriptorCreate(kCFAllocatorDefault, compositor.tcp_listen_fd, true, tcpAcceptCallback, &ctx);
          if (tcpCfFd) {
              CFRunLoopSourceRef source = CFFileDescriptorCreateRunLoopSource(kCFAllocatorDefault, tcpCfFd, 0);
              CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
              CFRelease(source);
              CFFileDescriptorEnableCallBacks(tcpCfFd, kCFFileDescriptorReadCallBack);
              log_printf("COMPOSITOR", "✅ Added TCP listen fd %d to NSRunLoop\n", compositor.tcp_listen_fd);
          } else {
              log_printf("COMPOSITOR", "⚠️ Failed to create CFFileDescriptor for TCP listen fd\n");
          }
      }

      // Add a timer to ensure Wayland timers are processed and clients flushed
      // This mimics the previous 16ms timeout loop
      NSTimer *maintenanceTimer = [NSTimer scheduledTimerWithTimeInterval:0.016 repeats:YES block:^(NSTimer * _Nonnull timer) {
          // Process any pending timers in Wayland loop
          wl_event_loop_dispatch(eventLoop, 0);
          wl_display_flush_clients(compositor.display);
      }];
      [[NSRunLoop currentRunLoop] addTimer:maintenanceTimer forMode:NSDefaultRunLoopMode];

      log_printf("COMPOSITOR", "🔄 Entering NSRunLoop for event processing\n");
      
      while (!compositor.shouldStopEventThread) {
          // Run loop in default mode
          // We use runMode:beforeDate: to allow checking shouldStopEventThread
          [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
      }

      // Cleanup
      if (waylandCfFd) {
          CFFileDescriptorInvalidate(waylandCfFd);
          CFRelease(waylandCfFd);
      }
      if (tcpCfFd) {
          CFFileDescriptorInvalidate(tcpCfFd);
          CFRelease(tcpCfFd);
      }
      [maintenanceTimer invalidate];
      
    } @catch (NSException *exception) {
      log_printf("COMPOSITOR", "⚠️ Exception in Wayland event thread: %s\n",
                 [exception.reason UTF8String]);
    }

    log_printf("COMPOSITOR", "🛑 Wayland event thread stopped\n");
  }];
  _compositor.eventThread.name = @"WaylandEventThread";
  [_compositor.eventThread start];
}

- (void)stopEventThread {
  if (_compositor) {
    _compositor.shouldStopEventThread = YES;
  }
}

- (void)cleanup {
  if (_waylandCfFd) {
    CFFileDescriptorInvalidate(_waylandCfFd);
    CFRelease(_waylandCfFd);
    _waylandCfFd = NULL;
  }
  if (_tcpCfFd) {
    CFFileDescriptorInvalidate(_tcpCfFd);
    CFRelease(_tcpCfFd);
    _tcpCfFd = NULL;
  }
  if (_maintenanceTimer) {
    [_maintenanceTimer invalidate];
    _maintenanceTimer = nil;
  }
}

@end

