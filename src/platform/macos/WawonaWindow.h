#pragma once

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR
#import <Cocoa/Cocoa.h>

@interface WawonaWindow : NSWindow <NSWindowDelegate>
@property(nonatomic, assign) uint64_t wawonaWindowId;
@end

@interface WawonaView : NSView
@end
#endif
