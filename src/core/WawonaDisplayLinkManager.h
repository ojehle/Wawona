// WawonaDisplayLinkManager.h - Display link and frame rendering setup
// Extracted from WawonaCompositor.m for better organization

#pragma once

#import <Foundation/Foundation.h>

@class WawonaCompositor;

@interface WawonaDisplayLinkManager : NSObject

- (instancetype)initWithCompositor:(WawonaCompositor *)compositor;
- (void)setupDisplayLink;

@end

