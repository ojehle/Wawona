#import "RenderingBackend.h"
#if TARGET_OS_OSX
#import "../rendering/renderer_macos.h"
#elif TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
#import "../rendering/renderer_ios.h"
#endif

@implementation RenderingBackendFactory

+ (id<RenderingBackend>)createBackend:(RenderingBackendType)type
#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
                         withView:(UIView *)view
#else
                         withView:(NSView *)view
#endif
{
    // Map requests to platform-specific renderers
    // The legacy Surface/Metal distinction is replaced by platform-native renderers
    
#if TARGET_OS_OSX
    return [[WawonaRendererMacOS alloc] initWithView:view];
#elif TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
    return [[WawonaRendererIOS alloc] initWithView:view];
#else
    return nil;
#endif
}

@end
