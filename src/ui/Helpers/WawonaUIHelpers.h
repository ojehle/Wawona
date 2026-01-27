#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface WawonaUIHelpers : NSObject
#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
+ (UIButton *)createLiquidGlassButtonWithImage:(UIImage *)image
                                        target:(id)target
                                        action:(SEL)action;
#else
// macOS Tahoe Liquid Glass factory methods
+ (NSButton *)createGlassButtonWithTitle:(NSString *)title
                                  target:(id)target
                                  action:(SEL)action;
+ (NSVisualEffectView *)createGlassBackgroundView;
+ (NSTextField *)createGlassTextFieldWithPlaceholder:(NSString *)placeholder;
+ (void)configureWindowForGlassAppearance:(NSWindow *)window;
#endif
@end

NS_ASSUME_NONNULL_END
