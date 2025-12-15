#import "WawonaAppScanner.h"
#import "../input/input_handler.h"
#include <signal.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

@implementation WaylandApp
@end

@interface WawonaAppScanner ()
@property(nonatomic, strong) NSMutableArray *availableApps;
@property(nonatomic, strong) NSMutableDictionary *runningProcesses;
@end

@implementation WawonaAppScanner

- (instancetype)initWithDisplay:(struct wl_display *)display {
  self = [super init];
  if (self) {
    _display = display;
    self.availableApps = [NSMutableArray array];
    self.runningProcesses = [NSMutableDictionary dictionary];

    [self setupWaylandEnvironment];
    [self scanForApplications];
  }
  return self;
}

- (void)setupWaylandEnvironment {
  // Set up WAYLAND_DISPLAY environment variable
  const char *socket_name = wl_display_add_socket_auto(_display);
  if (socket_name) {
    setenv("WAYLAND_DISPLAY", socket_name, 1);
    NSLog(@"🎯 Wayland socket: %s", socket_name);
  } else {
    NSLog(@"❌ Failed to add Wayland socket");
  }

  // Set up XDG_RUNTIME_DIR if not set
  if (!getenv("XDG_RUNTIME_DIR")) {
#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
    NSString *runtimeDir = NSTemporaryDirectory();
    if (runtimeDir) {
      // iOS sandbox path
      [[NSFileManager defaultManager] createDirectoryAtPath:runtimeDir
                                withIntermediateDirectories:YES
                                                 attributes:nil
                                                      error:nil];
      setenv("XDG_RUNTIME_DIR", [runtimeDir UTF8String], 1);
    } else {
      NSLog(@"❌ Failed to get NSTemporaryDirectory");
    }
#else
    // macOS: Use /tmp for less limiting access (e.g. waypipe)
    NSString *runtimeDir =
        [NSString stringWithFormat:@"/tmp/wawona-%d", getuid()];
    [[NSFileManager defaultManager] createDirectoryAtPath:runtimeDir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    setenv("XDG_RUNTIME_DIR", [runtimeDir UTF8String], 1);
#endif
  }
}

- (NSString *)waylandSocketPath {
  const char *runtime_dir = getenv("XDG_RUNTIME_DIR");
  const char *socket_name = getenv("WAYLAND_DISPLAY");

  if (runtime_dir && socket_name) {
    return [NSString stringWithFormat:@"%s/%s", runtime_dir, socket_name];
  }
  return nil;
}

- (void)scanForApplications {
  [self.availableApps removeAllObjects];

  // Scan standard application directories
  NSArray *appDirs = @[
    @"/Applications", @"/System/Applications",
    [NSString stringWithFormat:@"%@/Applications", NSHomeDirectory()]
  ];

  for (NSString *appDir in appDirs) {
    [self scanDirectory:appDir forApplications:self.availableApps];
  }

  NSLog(@"🎯 Found %lu Wayland-compatible applications",
        (unsigned long)self.availableApps.count);
}

- (void)scanDirectory:(NSString *)directory
      forApplications:(NSMutableArray *)apps {
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSError *error = nil;

  NSArray *contents =
      [fileManager contentsOfDirectoryAtPath:directory error:&error];
  if (error) {
    return;
  }

  for (NSString *item in contents) {
    NSString *fullPath = [directory stringByAppendingPathComponent:item];

    // Check if it's an app bundle
    if ([item hasSuffix:@".app"]) {
      [self processAppBundle:fullPath apps:apps];
    }
    // Recursively scan subdirectories (but avoid infinite loops)
    else if ([item hasPrefix:@"."] == NO) {
      BOOL isDirectory = NO;
      if ([fileManager fileExistsAtPath:fullPath isDirectory:&isDirectory] &&
          isDirectory) {
        [self scanDirectory:fullPath forApplications:apps];
      }
    }
  }
}

- (void)processAppBundle:(NSString *)appPath apps:(NSMutableArray *)apps {
  NSString *infoPlistPath =
      [appPath stringByAppendingPathComponent:@"Contents/Info.plist"];
  NSFileManager *fileManager = [NSFileManager defaultManager];

  if (![fileManager fileExistsAtPath:infoPlistPath]) {
    return;
  }

  NSDictionary *infoPlist =
      [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
  if (!infoPlist) {
    return;
  }

  // Check if it's a Wayland-compatible app (has Wayland in environment or is a
  // terminal app)
  NSString *bundleIdentifier = infoPlist[@"CFBundleIdentifier"];
  NSString *bundleName = infoPlist[@"CFBundleName"];

  if (!bundleIdentifier || !bundleName) {
    return;
  }

  // For now, include terminal apps and known Wayland apps
  BOOL isWaylandCompatible = NO;

  // Check for Wayland-specific keys
  NSDictionary *environment = infoPlist[@"LSEnvironment"];
  if (environment && environment[@"WAYLAND_DISPLAY"]) {
    isWaylandCompatible = YES;
  }

  // Check if it's a terminal emulator (likely to support Wayland)
  NSArray *terminalApps =
      @[ @"com.apple.Terminal", @"com.googlecode.iterm2", @"org.alacritty" ];
  if ([terminalApps containsObject:bundleIdentifier]) {
    isWaylandCompatible = YES;
  }

  if (isWaylandCompatible) {
    WaylandApp *app = [[WaylandApp alloc] init];
    app.appId = bundleIdentifier;
    app.name = bundleName;
    app.description = infoPlist[@"CFBundleShortVersionString"] ?: @"";
    app.executablePath = [appPath
        stringByAppendingPathComponent:infoPlist[@"CFBundleExecutable"] ?: @""];
    app.iconPath = [appPath
        stringByAppendingPathComponent:infoPlist[@"CFBundleIconFile"] ?: @""];
    app.categories = infoPlist[@"LSApplicationCategoryType"]
                         ? @[ infoPlist[@"LSApplicationCategoryType"] ]
                         : @[];

    [apps addObject:app];
  }
}

- (NSArray *)availableApplications {
  return [self.availableApps copy];
}

- (BOOL)launchApplication:(NSString *)appId {
  for (WaylandApp *app in self.availableApps) {
    if ([app.appId isEqualToString:appId]) {
      return [self launchApplicationWithPath:app.executablePath];
    }
  }
  return NO;
}

- (BOOL)launchApplicationWithPath:(NSString *)appPath {
    if (!appPath || ![[NSFileManager defaultManager] fileExistsAtPath:appPath]) {
      NSLog(@"❌ Application not found: %@", appPath);
      return NO;
    }

    pid_t pid = fork();
    if (pid == 0) {
      // Child process

      // Set up environment
      [self setupWaylandEnvironment];

      // Execute the application
      NSString *appName = [appPath lastPathComponent];
      execl([appPath UTF8String], [appName UTF8String], NULL);

      // If we get here, execl failed
      exit(1);
    } else if (pid > 0) {
      // Parent process
      NSString *processKey = [NSString stringWithFormat:@"%d", pid];
      self.runningProcesses[processKey] =
          @{@"pid" : @(pid), @"path" : appPath, @"startTime" : [NSDate date]};

      NSLog(@"🚀 Launched application: %@ (PID: %d)", appPath, pid);
      return YES;
    } else {
      NSLog(@"❌ Failed to fork process for application: %@", appPath);
      return NO;
    }
}

- (void)terminateApplication:(NSString *)appId {
  // Find running process by app ID
  for (NSString *processKey in self.runningProcesses) {
    NSDictionary *processInfo = self.runningProcesses[processKey];
    NSString *appPath = processInfo[@"path"];

    if ([appPath containsString:appId]) {
      pid_t pid = [processInfo[@"pid"] intValue];
      kill(pid, SIGTERM);

      [self.runningProcesses removeObjectForKey:processKey];
      NSLog(@"🛑 Terminated application: %@ (PID: %d)", appId, pid);
      return;
    }
  }
}

- (BOOL)isApplicationRunning:(NSString *)appId {
  // Check if any running process matches the app ID
  for (NSString *processKey in self.runningProcesses) {
    NSDictionary *processInfo = self.runningProcesses[processKey];
    NSString *appPath = processInfo[@"path"];

    if ([appPath containsString:appId]) {
      pid_t pid = [processInfo[@"pid"] intValue];
      if (kill(pid, 0) == 0) {
        return YES; // Process is still running
      } else {
        // Process is no longer running, clean up
        [self.runningProcesses removeObjectForKey:processKey];
      }
    }
  }
  return NO;
}

- (NSArray *)runningApplications {
  NSMutableArray *runningApps = [NSMutableArray array];

  for (NSString *processKey in self.runningProcesses) {
    NSDictionary *processInfo = self.runningProcesses[processKey];
    pid_t pid = [processInfo[@"pid"] intValue];

    if (kill(pid, 0) == 0) {
      [runningApps addObject:processInfo];
    } else {
      // Process is no longer running, clean up
      [self.runningProcesses removeObjectForKey:processKey];
    }
  }

  return runningApps;
}

@end