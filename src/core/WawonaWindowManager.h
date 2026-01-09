// WawonaWindowManager.h - Window sizing and display management
// Extracted from WawonaCompositor.m for better organization

#pragma once

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@class WawonaCompositor;

@interface WawonaWindowManager : NSObject

- (instancetype)initWithCompositor:(WawonaCompositor *)compositor;
- (void)showAndSizeWindowForFirstClient:(int32_t)width height:(int32_t)height;
- (void)updateOutputSize:(CGSize)size;

@end

