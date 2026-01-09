// WawonaProtocolSetup.h - Wayland protocol initialization
// Extracted from WawonaCompositor.m for better organization

#pragma once

#import <Foundation/Foundation.h>
#include <wayland-server-core.h>

@class WawonaCompositor;

@interface WawonaProtocolSetup : NSObject

- (instancetype)initWithCompositor:(WawonaCompositor *)compositor;
- (BOOL)setupProtocols;

@end

