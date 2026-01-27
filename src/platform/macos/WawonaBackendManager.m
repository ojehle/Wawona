// WawonaBackendManager.m - Backend detection and switching implementation
// Extracted from WawonaCompositor.m for better organization

#import "WawonaBackendManager.h"
#import "WawonaCompositor.h"
#import "WawonaSettings.h"
#include "../logging/logging.h"
#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR
#include <libproc.h>
#endif

extern WawonaCompositor *g_wl_compositor_instance;

void wawona_compositor_detect_full_compositor(struct wl_client *client) {
  if (!g_wl_compositor_instance) {
    NSLog(@"⚠️ g_wl_compositor_instance is NULL, cannot detect compositor");
    return;
  }

  // Try to get PID for detection
  pid_t client_pid = 0;
  uid_t client_uid = 0;
  gid_t client_gid = 0;
  wl_client_get_credentials(client, &client_pid, &client_uid, &client_gid);

  BOOL shouldSwitchToMetal = NO;
  NSString *processName = nil;

  // Check backend preference
  // 0 = Automatic (default)
  // 1 = Metal (Vulkan)
  // 2 = Cocoa (Surface)
  NSInteger backendPref =
      [[NSUserDefaults standardUserDefaults] integerForKey:@"RenderingBackend"];

  if (backendPref == 1) {
    // Force Metal
    shouldSwitchToMetal = YES;
    NSLog(@"ℹ️ Rendering Backend preference set to Metal (Vulkan) - forcing "
          @"switch");
  } else if (backendPref == 2) {
    // Force Cocoa
    shouldSwitchToMetal = NO;
    NSLog(@"ℹ️ Rendering Backend preference set to Cocoa (Surface) - preventing "
          @"switch");
  } else {
    // Automatic mode (existing logic)
    if (client_pid > 0) {
      // Check process name to determine if this is a nested compositor
#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR
      char proc_path[PROC_PIDPATHINFO_MAXSIZE] = {0};
      int ret = proc_pidpath(client_pid, proc_path, sizeof(proc_path));
      if (ret > 0) {
        NSString *processPath = [NSString stringWithUTF8String:proc_path];
#else
      // iOS: Process name detection not available
      NSString *processPath = nil;
      if (0) {
#endif
        processName = [processPath lastPathComponent];
        NSLog(@"🔍 Client binding to wl_compositor: %@ (PID: %d)", processName,
              client_pid);

        // Known nested compositors that should use Metal backend
        // Includes: Weston, wlroots-based (Sway, River, Hyprland), GNOME
        // (Mutter), KDE (KWin)
        NSArray<NSString *> *nestedCompositors = @[
          @"weston", @"weston-desktop-shell", @"mutter", @"gnome-shell",
          @"gnome-session", @"kwin_wayland", @"kwin", @"plasmashell", @"sway",
          @"river", @"hyprland", @"niri", @"cage", @"wayfire", @"hikari",
          @"orbital"
        ];

        NSString *lowercaseName = [processName lowercaseString];
        for (NSString *compositor in nestedCompositors) {
          if ([lowercaseName containsString:compositor]) {
            shouldSwitchToMetal = YES;
            NSLog(@"✅ Detected nested compositor: %@ - switching to Metal "
                  @"backend",
                  processName);
            break;
          }
        }

        // waypipe is a proxy/tunnel, NOT a compositor - don't switch backend
        if ([lowercaseName containsString:@"waypipe"]) {
          shouldSwitchToMetal = NO;
          NSLog(@"ℹ️ Detected waypipe proxy - keeping Cocoa backend for regular "
                @"clients");
        }
      }
    } else {
      // PID unavailable - likely forwarded through waypipe or similar proxy
      // On iOS, we assume this is a forwarded session (Weston/etc) and use
      // Metal for performance
#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
      NSLog(@"🔍 Client PID unavailable (likely forwarded through waypipe) - "
            @"switching to Metal backend on iOS");
      shouldSwitchToMetal = YES;
#else
      // On macOS, waypipe might be individual windows, so keep Cocoa
      NSLog(@"🔍 Client PID unavailable (likely forwarded through waypipe) - "
            @"keeping Cocoa backend");
      shouldSwitchToMetal = NO;
#endif
    }
  }

  // Only switch to Metal if we detected an actual nested compositor or forced
  // via prefs
  if (shouldSwitchToMetal) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [g_wl_compositor_instance switchToMetalBackend];
    });
  } else {
    NSLog(@"ℹ️ Client binding to wl_compositor but not a nested compositor - "
          @"using Cocoa backend");
  }

  // Update window title with client name (regardless of backend)
  dispatch_async(dispatch_get_main_queue(), ^{
    [g_wl_compositor_instance updateWindowTitleForClient:client];
  });
}

