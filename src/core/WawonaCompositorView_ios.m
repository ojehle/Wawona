// WawonaCompositorView_ios.m - iOS compositor view implementation
// Extracted from WawonaCompositorView.m for platform separation

#import "WawonaCompositorView_ios.h"
#import "WawonaCompositor.h"
#import "../input/input_handler.h"
#import "RenderingBackend.h"
#import <MetalKit/MetalKit.h>

#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR

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

#endif // TARGET_OS_IPHONE || TARGET_OS_SIMULATOR

