#import "WawonaUIHelpers.h"

#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR

@interface NSObject (UIGlassEffectPrivate)
+ (UIVisualEffect *)effectWithStyle:(NSInteger)style;
@end

@implementation WawonaUIHelpers

+ (UIButton *)createLiquidGlassButtonWithImage:(UIImage *)image
                                        target:(id)target
                                        action:(SEL)action {
  UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
  button.translatesAutoresizingMaskIntoConstraints = NO;

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
  if (@available(iOS 26.0, *)) {
    if ([UIButtonConfiguration
            respondsToSelector:@selector(glassButtonConfiguration)]) {
      UIButtonConfiguration *config = [UIButtonConfiguration
          performSelector:@selector(glassButtonConfiguration)];
      config.image = image;
      config.baseForegroundColor = [UIColor whiteColor];
      config.preferredSymbolConfigurationForImage = [UIImageSymbolConfiguration
          configurationWithScale:UIImageSymbolScaleLarge];
      button.configuration = config;
    } else {
      Class glassEffectClass = NSClassFromString(@"UIGlassEffect");
      if (glassEffectClass) {
        UIVisualEffect *glassEffect = [glassEffectClass effectWithStyle:1];
        UIVisualEffectView *glassView =
            [[UIVisualEffectView alloc] initWithEffect:glassEffect];
        glassView.userInteractionEnabled = NO;
        glassView.layer.cornerRadius = 25.0;
        glassView.clipsToBounds = YES;
        glassView.frame = CGRectMake(0, 0, 50, 50);
        glassView.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [button insertSubview:glassView atIndex:0];
      } else {
        [self applyFallbackBlurToButton:button];
      }
    }
  } else {
    [self applyFallbackBlurToButton:button];
  }
#else
  [self applyFallbackBlurToButton:button];
#endif

  [button setImage:image forState:UIControlStateNormal];
  button.tintColor = [UIColor whiteColor];

  button.layer.shadowColor = [UIColor blackColor].CGColor;
  button.layer.shadowOffset = CGSizeMake(0, 4);
  button.layer.shadowOpacity = 0.3;
  button.layer.shadowRadius = 8.0;

  [button addTarget:target
                action:action
      forControlEvents:UIControlEventTouchUpInside];
  return button;
}

+ (void)applyFallbackBlurToButton:(UIButton *)button {
  UIBlurEffectStyle style = UIBlurEffectStyleRegular;
  if (@available(iOS 13.0, *)) {
    style = UIBlurEffectStyleSystemThinMaterialDark;
  }

  UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:style];
  UIVisualEffectView *blurView =
      [[UIVisualEffectView alloc] initWithEffect:blurEffect];
  blurView.userInteractionEnabled = NO;
  blurView.layer.cornerRadius = 25.0;
  blurView.clipsToBounds = YES;
  blurView.autoresizingMask =
      UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  blurView.frame = CGRectMake(0, 0, 50, 50);

  blurView.layer.borderWidth = 1.0;
  blurView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.2].CGColor;

  [button insertSubview:blurView atIndex:0];
}

@end

#else // macOS Implementation

@implementation WawonaUIHelpers

// Factory method for macOS Liquid Glass-styled buttons
+ (NSButton *)createGlassButtonWithTitle:(NSString *)title
                                  target:(id)target
                                  action:(SEL)action {
  NSButton *button = [[NSButton alloc] init];
  button.title = title;
  button.target = target;
  button.action = action;
  button.translatesAutoresizingMaskIntoConstraints = NO;

  // Use rounded bezel style (closest to glass on pre-Tahoe)
  button.bezelStyle = NSBezelStyleRounded;
  button.wantsLayer = YES;

  // Style for glass-like appearance
  button.layer.cornerRadius = 8.0;

  return button;
}

// Factory method for glass visual effect view (background)
+ (NSVisualEffectView *)createGlassBackgroundView {
  NSVisualEffectView *glassView = [[NSVisualEffectView alloc] init];
  glassView.translatesAutoresizingMaskIntoConstraints = NO;
  
  if (@available(macOS 15.0, *)) {
    // macOS Tahoe: Use ContentBackground material for Liquid Glass effect
    glassView.material = NSVisualEffectMaterialContentBackground;
  } else {
    // Fallback for older macOS: use HUD window material
    glassView.material = NSVisualEffectMaterialHUDWindow;
  }
  
  glassView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
  glassView.state = NSVisualEffectStateActive;
  glassView.wantsLayer = YES;
  glassView.layer.cornerRadius = 12.0;
  glassView.layer.masksToBounds = YES;

  return glassView;
}

// Factory method for glass-styled text field
+ (NSTextField *)createGlassTextFieldWithPlaceholder:(NSString *)placeholder {
  NSTextField *textField = [[NSTextField alloc] init];
  textField.translatesAutoresizingMaskIntoConstraints = NO;
  textField.placeholderString = placeholder;
  textField.wantsLayer = YES;
  textField.layer.cornerRadius = 6.0;
  textField.backgroundColor = [NSColor colorWithWhite:1.0 alpha:0.1];
  textField.textColor = [NSColor labelColor];
  textField.font = [NSFont systemFontOfSize:13];

  return textField;
}

// Configure a window for glass appearance (Tahoe styling)
+ (void)configureWindowForGlassAppearance:(NSWindow *)window {
  window.styleMask |= NSWindowStyleMaskFullSizeContentView;
  window.titlebarAppearsTransparent = YES;
  window.backgroundColor = [NSColor clearColor];
  window.appearance =
      [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];

  // Add glass background
  NSVisualEffectView *glassView = [self createGlassBackgroundView];
  glassView.frame = window.contentView.bounds;
  glassView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  [window.contentView addSubview:glassView
                      positioned:NSWindowBelow
                      relativeTo:nil];
}

@end

#endif
