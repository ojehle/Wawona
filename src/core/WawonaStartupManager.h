// WawonaStartupManager.h - Compositor startup management
// Extracted from WawonaCompositor.m for better organization

#pragma once

#import <Foundation/Foundation.h>

@class WawonaCompositor;

@interface WawonaStartupManager : NSObject

- (instancetype)initWithCompositor:(WawonaCompositor *)compositor;
- (BOOL)start;

@end

