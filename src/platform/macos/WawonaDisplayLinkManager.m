// WawonaDisplayLinkManager.m - Display link and frame rendering setup implementation
// Extracted from WawonaCompositor.m for better organization

#import "WawonaDisplayLinkManager.h"
#import "WawonaCompositor.h"
#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
#import <QuartzCore/QuartzCore.h>
#else
#import <CoreVideo/CoreVideo.h>
#endif

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR
static CVReturn displayLinkCallback(CVDisplayLinkRef displayLink,
                                    const CVTimeStamp *inNow,
                                    const CVTimeStamp *inOutputTime,
                                    CVOptionFlags flagsIn,
                                    CVOptionFlags *flagsOut,
                                    void *displayLinkContext) {
  WawonaCompositor *compositor = (__bridge WawonaCompositor *)displayLinkContext;
  [compositor renderFrame];
  return kCVReturnSuccess;
}
#endif

@implementation WawonaDisplayLinkManager {
  WawonaCompositor *_compositor;
}

- (instancetype)initWithCompositor:(WawonaCompositor *)compositor {
  self = [super init];
  if (self) {
    _compositor = compositor;
  }
  return self;
}

- (void)setupDisplayLink {
  // Set up frame rendering using CVDisplayLink/CADisplayLink - syncs to
  // display refresh rate This automatically matches the display's refresh
  // rate (e.g., 60Hz, 120Hz, etc.)
#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
  CADisplayLink *displayLink =
      [CADisplayLink displayLinkWithTarget:_compositor
                                  selector:@selector(displayLinkCallback:)];
  [displayLink addToRunLoop:[NSRunLoop mainRunLoop]
                    forMode:NSDefaultRunLoopMode];
  _compositor.displayLink = displayLink;
  double refreshRate = displayLink.preferredFramesPerSecond > 0
                           ? (double)displayLink.preferredFramesPerSecond
                           : 60.0;
  NSLog(@"   Frame rendering active (%.0fHz - synced to display)", refreshRate);
#else
  CVDisplayLinkRef displayLink = NULL;
  CVDisplayLinkCreateWithActiveCGDisplays(&displayLink);

  if (displayLink) {
    // Set callback to renderFrame
    CVDisplayLinkSetOutputCallback(displayLink, displayLinkCallback,
                                   (__bridge void *)_compositor);
    // Start display link - it will continue running even when window loses
    // focus This ensures Wayland clients continue to receive frame callbacks
    // and can render
    CVDisplayLinkStart(displayLink);
    _compositor.displayLink = displayLink;

    // Get actual refresh rate for logging
    CVTime time = CVDisplayLinkGetNominalOutputVideoRefreshPeriod(displayLink);
    double refreshRate = 60.0; // Default fallback
    if (!(time.flags & kCVTimeIsIndefinite) && time.timeValue != 0) {
      refreshRate = (double)time.timeScale / (double)time.timeValue;
    }
    NSLog(@"   Frame rendering active (%.0fHz - synced to display)",
          refreshRate);
  } else {
    // Fallback to 60Hz timer if CVDisplayLink fails
    NSTimer *fallbackTimer =
        [NSTimer scheduledTimerWithTimeInterval:1.0 / 60.0
                                         target:_compositor
                                       selector:@selector(renderFrame)
                                       userInfo:nil
                                        repeats:YES];
    (void)fallbackTimer; // Timer is retained by the run loop, no need to
                         // store reference
    _compositor.displayLink = NULL;
    NSLog(@"   Frame rendering active (60Hz - fallback timer)");
  }
#endif
}

@end

