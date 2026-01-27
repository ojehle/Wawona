// WawonaCompositorView.m - Compositor view implementation
// Extracted from WawonaCompositor.m for better organization

#import "WawonaCompositorView.h"
#import "WawonaCompositor.h"
#import "../input/input_handler.h"
#import "../rendering/RenderingBackend.h"
#import "../compositor_implementations/xdg_shell.h"
#import <MetalKit/MetalKit.h>

// Forward declaration
extern WawonaCompositor *g_wl_compositor_instance;

#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
// iOS: Use UIView instead of NSView
@implementation CompositorView

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    // Ensure background is transparent so window's black background shows
    // through in unsafe areas
    self.backgroundColor = [UIColor clearColor];
    self.opaque = NO;

    // Listen for settings changes
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(defaultsChanged:)
               name:NSUserDefaultsDidChangeNotification
             object:nil];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)defaultsChanged:(NSNotification *)note {
  // Trigger layout update when settings change
  [self setNeedsLayout];
}

- (void)safeAreaInsetsDidChange {
  [super safeAreaInsetsDidChange];
  [self setNeedsLayout];
  if (self.compositor) {
    // Force update when safe area changes (e.g. startup, rotation)
    [self.compositor updateOutputSize:self.bounds.size];
  }
}

- (void)layoutSubviews {
  [super layoutSubviews];

  BOOL respectSafeArea =
      [[NSUserDefaults standardUserDefaults] boolForKey:@"RespectSafeArea"];
  if ([[NSUserDefaults standardUserDefaults] objectForKey:@"RespectSafeArea"] ==
      nil) {
    respectSafeArea = YES;
  }

  if (respectSafeArea) {
    // Respect Safe Area: manually constrain frame
    CGRect targetFrame = self.superview.bounds;
    if (self.window) {
      UIEdgeInsets insets = self.window.safeAreaInsets;
      if (insets.top != 0 || insets.left != 0 || insets.bottom != 0 ||
          insets.right != 0) {
        targetFrame = UIEdgeInsetsInsetRect(self.superview.bounds, insets);
      }
    } else {
      // Fallback if window not available
      UIEdgeInsets insets = self.safeAreaInsets;
      if (insets.top != 0 || insets.left != 0 || insets.bottom != 0 ||
          insets.right != 0) {
        targetFrame = UIEdgeInsetsInsetRect(self.superview.bounds, insets);
      }
    }

    if (!CGRectEqualToRect(self.frame, targetFrame)) {
      self.autoresizingMask = UIViewAutoresizingNone;
      self.frame = targetFrame;
      NSLog(@"🔵 CompositorView constrained to safe area: (%.0f, %.0f) "
            @"%.0fx%.0f",
            targetFrame.origin.x, targetFrame.origin.y, targetFrame.size.width,
            targetFrame.size.height);
    }
  } else {
    // Full Screen: match superview
    CGRect targetFrame = self.superview.bounds;
    if (!CGRectEqualToRect(self.frame, targetFrame)) {
      self.frame = targetFrame;
      self.autoresizingMask =
          UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
      NSLog(@"🔵 CompositorView expanded to full screen: (%.0f, %.0f) "
            @"%.0fx%.0f",
            targetFrame.origin.x, targetFrame.origin.y, targetFrame.size.width,
            targetFrame.size.height);
    } else if (self.autoresizingMask != (UIViewAutoresizingFlexibleWidth |
                                         UIViewAutoresizingFlexibleHeight)) {
      self.autoresizingMask =
          UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
  }

  if (self.compositor) {
    [self.compositor updateOutputSize:self.bounds.size];
  }
}

- (void)drawRect:(CGRect)rect {
  if (self.metalView && self.metalView.superview == self) {
    return;
  }
  if (self.renderer) {
    [self.renderer drawSurfacesInRect:rect];
  } else {
    [[UIColor colorWithRed:0.1 green:0.1 blue:0.2 alpha:1.0] setFill];
    UIRectFill(rect);
  }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  if (self.inputHandler) {
    [self.inputHandler handleTouchEvent:event];
  }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  if (self.inputHandler) {
    [self.inputHandler handleTouchEvent:event];
  }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  if (self.inputHandler) {
    [self.inputHandler handleTouchEvent:event];
  }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches
               withEvent:(UIEvent *)event {
  if (self.inputHandler) {
    [self.inputHandler handleTouchEvent:event];
  }
}

@end
#else
// macOS: Use NSView
@implementation CompositorView

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    self.wantsLayer = YES;
    self.layer.opaque = NO;
    self.layer.backgroundColor = [NSColor clearColor].CGColor;
    self.layer.masksToBounds = NO; // Allow CSD shadows to bleed out
  }
  return self;
}

- (NSView *)hitTest:(NSPoint)point {
  // NSView hitTest: expects point in the superview's coordinate system.
  // Convert it to local coordinates for pickSurfaceAt:
  // This ensures robust coordinate handling for macOS
  NSPoint localPoint = [self convertPoint:point fromView:self.superview];

  if (self.inputHandler) {
    // pickSurfaceAt: returns NULL if the point is in the shadow region
    // (outside the window geometry but inside the surface buffer)
    if ([self.inputHandler pickSurfaceAt:localPoint] == NULL) {
      // If we are over a shadow area (no surface picked), return nil to allow
      // click passthrough to underlying macOS windows.
      return nil;
    }
  }
  return [super hitTest:point];
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event {
  return YES;
}

- (BOOL)isFlipped {
  return YES;
}

- (BOOL)mouseDownCanMoveWindow {
  // For CSD windows, let the client handle window movement/resizing
  // For SSD windows, allow macOS to move the window
  NSWindow *window = self.window;
  if (window) {
    NSValue *toplevelValue = [g_wl_compositor_instance.windowToToplevelMap
        objectForKey:[NSValue valueWithPointer:(__bridge void *)window]];
    
    if (toplevelValue) {
      struct xdg_toplevel_impl *toplevel = [toplevelValue pointerValue];
      if (toplevel->decoration_mode == 1) { // CLIENT_SIDE
        return NO; // Let CSD client handle window movement/resizing
      }
    }
  }
  return YES; // Allow macOS to move SSD windows
}

- (BOOL)acceptsFirstResponder {
  return YES;
}

- (BOOL)becomeFirstResponder {
  NSLog(@"[COMPOSITOR VIEW] Became first responder - ready for keyboard input");
  BOOL result = [super becomeFirstResponder];
  // TODO: Send keyboard enter to focused surface when view becomes first
  // responder For now, skip this to avoid crashes during client window setup
  return result;
}

- (void)mouseMoved:(NSEvent *)event {
  if (self.inputHandler) {
    [self.inputHandler handleMouseEvent:event];
  }
}

- (void)mouseDown:(NSEvent *)event {
  if (self.inputHandler) {
    [self.inputHandler handleMouseEvent:event];
  }
}

- (void)mouseUp:(NSEvent *)event {
  if (self.inputHandler) {
    [self.inputHandler handleMouseEvent:event];
  }
}

- (void)rightMouseDown:(NSEvent *)event {
  if (self.inputHandler) {
    [self.inputHandler handleMouseEvent:event];
  }
}

- (void)rightMouseUp:(NSEvent *)event {
  if (self.inputHandler) {
    [self.inputHandler handleMouseEvent:event];
  }
}

- (void)otherMouseDown:(NSEvent *)event {
  if (self.inputHandler) {
    [self.inputHandler handleMouseEvent:event];
  }
}

- (void)otherMouseUp:(NSEvent *)event {
  if (self.inputHandler) {
    [self.inputHandler handleMouseEvent:event];
  }
}

- (void)mouseDragged:(NSEvent *)event {
  if (self.inputHandler) {
    [self.inputHandler handleMouseEvent:event];
  }
}

- (void)rightMouseDragged:(NSEvent *)event {
  if (self.inputHandler) {
    [self.inputHandler handleMouseEvent:event];
  }
}

- (void)otherMouseDragged:(NSEvent *)event {
  if (self.inputHandler) {
    [self.inputHandler handleMouseEvent:event];
  }
}

- (void)scrollWheel:(NSEvent *)event {
  if (self.inputHandler) {
    [self.inputHandler handleMouseEvent:event];
  }
}

- (BOOL)resignFirstResponder {
  NSLog(@"[COMPOSITOR VIEW] Resigned first responder");
  return [super resignFirstResponder];
}

- (void)drawRect:(NSRect)dirtyRect {
  if (self.metalView && self.metalView.superview == self) {
    return;
  }
  if (self.renderer) {
    [self.renderer drawSurfacesInRect:dirtyRect];
  } else {
    [[NSColor colorWithRed:0.1 green:0.1 blue:0.2 alpha:1.0] setFill];
    NSRectFill(dirtyRect);
  }
}

- (void)keyDown:(NSEvent *)event {
  if (self.inputHandler) {
    [self.inputHandler handleKeyboardEvent:event];
  } else {
    [super keyDown:event];
  }
}

- (void)keyUp:(NSEvent *)event {
  if (self.inputHandler) {
    [self.inputHandler handleKeyboardEvent:event];
  } else {
    [super keyUp:event];
  }
}

- (BOOL)performKeyEquivalent:(NSEvent *)event {
  if (self.inputHandler && self.inputHandler.seat &&
      self.inputHandler.seat->focused_surface) {
    [self.inputHandler handleKeyboardEvent:event];
    return YES;
  }
  return [super performKeyEquivalent:event];
}

@end
#endif

