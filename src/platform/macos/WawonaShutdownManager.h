// WawonaShutdownManager.h - Compositor shutdown management
// Extracted from WawonaCompositor.m for better organization

#pragma once

#import <Foundation/Foundation.h>

@class WawonaCompositor;

@interface WawonaShutdownManager : NSObject

- (instancetype)initWithCompositor:(WawonaCompositor *)compositor;
- (void)stop;

@end

