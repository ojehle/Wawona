// WawonaEventLoopManager.h - Event loop and TCP accept handling
// Extracted from WawonaCompositor.m for better organization

#pragma once

#import <Foundation/Foundation.h>
#include <wayland-server-core.h>

@class WawonaCompositor;

@interface WawonaEventLoopManager : NSObject

- (instancetype)initWithCompositor:(WawonaCompositor *)compositor;
- (BOOL)setupEventLoop;
- (void)startEventThread;
- (void)stopEventThread;
- (void)cleanup;

@property(nonatomic, readonly) struct wl_event_loop *eventLoop;
@property(nonatomic, readonly) int tcp_listen_fd;

@end

