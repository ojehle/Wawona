#import "renderer_ios.h"

@implementation WawonaRendererIOS

#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
- (instancetype)initWithView:(UIView *)view {
    self = [super init];
    return self;
}
#endif

- (void)renderSurface:(struct wl_surface_impl *)surface {
    // TODO: Implement iOS rendering
}

- (void)removeSurface:(struct wl_surface_impl *)surface {
    // TODO: Implement iOS cleanup
}

- (void)setNeedsDisplay {
    // TODO
}

#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
- (void)drawSurfacesInRect:(CGRect)dirtyRect {
    // TODO
}
#endif

@end
