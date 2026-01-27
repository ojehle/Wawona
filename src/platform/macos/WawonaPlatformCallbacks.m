//  WawonaPlatformCallbacks.m
//  Implementation of platform callbacks for Rust compositor

#import "WawonaPlatformCallbacks.h"
#import "../../logging/WawonaLog.h"
#import "WawonaWindow.h"

@implementation WawonaPlatformCallbacks

+ (instancetype)sharedCallbacks {
  static WawonaPlatformCallbacks *sharedInstance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[WawonaPlatformCallbacks alloc] init];
  });
  return sharedInstance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR
    _windowRegistry = [NSMutableDictionary dictionary];
#else
    _windowRegistry = [NSMutableDictionary dictionary];
#endif
  }
  return self;
}

#pragma mark - Window Management

- (void)createNativeWindowWithId:(uint64_t)windowId
                           width:(int32_t)width
                          height:(int32_t)height
                           title:(NSString *)title
                          useSSD:(BOOL)useSSD {
  dispatch_async(dispatch_get_main_queue(), ^{
#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR
    // macOS window creation
    NSWindowStyleMask styleMask =
        useSSD ? (NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                  NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable)
               : (NSWindowStyleMaskBorderless | NSWindowStyleMaskResizable);

    NSRect contentRect = NSMakeRect(100, 100, width, height);
    NSWindow *window =
        [[WawonaWindow alloc] initWithContentRect:contentRect
                                        styleMask:styleMask
                                          backing:NSBackingStoreBuffered
                                            defer:NO];

    // Create and set WawonaView as content view to handle input
    WawonaView *contentView =
        [[WawonaView alloc] initWithFrame:NSMakeRect(0, 0, width, height)];
    [window setContentView:contentView];

    window.title = title ?: @"Wawona Client";
    window.delegate = (id<NSWindowDelegate>)self; // For window lifecycle events

    [self.windowRegistry setObject:window forKey:@(windowId)];
    [window makeKeyAndOrderFront:nil];

    WLog(@"PLATFORM", @"Created native window %llu: %@", windowId, title);
#else
        // iOS window creation (simplified for now)
        UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, width, height)];
        window.backgroundColor = [UIColor blackColor];
        [self.windowRegistry setObject:window forKey:@(windowId)];
        [window makeKeyAndVisible];
        
        WLog(@"PLATFORM", @"Created native window %llu", windowId);
#endif
  });
}

- (void)destroyNativeWindowWithId:(uint64_t)windowId {
  dispatch_async(dispatch_get_main_queue(), ^{
#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR
    NSWindow *window = [self.windowRegistry objectForKey:@(windowId)];
    if (window) {
      [window close];
      [self.windowRegistry removeObjectForKey:@(windowId)];
      WLog(@"PLATFORM", @"Destroyed native window %llu", windowId);
    }
#else
        UIWindow *window = [self.windowRegistry objectForKey:@(windowId)];
        if (window) {
            window.hidden = YES;
            [self.windowRegistry removeObjectForKey:@(windowId)];
            WLog(@"PLATFORM", @"Destroyed native window %llu", windowId);
        }
#endif
  });
}

- (void)setWindowTitle:(NSString *)title forWindowId:(uint64_t)windowId {
  dispatch_async(dispatch_get_main_queue(), ^{
#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR
    NSWindow *window = [self.windowRegistry objectForKey:@(windowId)];
    if (window) {
      window.title = title;
    }
#endif
  });
}

- (void)setWindowSize:(CGSize)size forWindowId:(uint64_t)windowId {
  dispatch_async(dispatch_get_main_queue(), ^{
#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR
    NSWindow *window = [self.windowRegistry objectForKey:@(windowId)];
    if (window) {
      NSRect frame = window.frame;
      NSRect contentRect =
          NSMakeRect(frame.origin.x, frame.origin.y, size.width, size.height);
      NSRect newFrame = [window frameRectForContentRect:contentRect];
      [window setFrame:newFrame display:YES animate:YES];
    }
#else
        UIWindow *window = [self.windowRegistry objectForKey:@(windowId)];
        if (window) {
            CGRect frame = window.frame;
            frame.size = size;
            window.frame = frame;
        }
#endif
  });
}

- (void)requestRenderForWindowId:(uint64_t)windowId {
  // TODO: Trigger Metal rendering for this window
  // For now, this is a stub
}

@end
