// WawonaRenderManager.h - Rendering management
// Extracted from WawonaCompositor.m for better organization

#pragma once

#import <Foundation/Foundation.h>

@class WawonaCompositor;

@interface WawonaRenderManager : NSObject

- (instancetype)initWithCompositor:(WawonaCompositor *)compositor;
- (void)renderFrame;

@end

