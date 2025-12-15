#pragma once

#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif

#include <wayland-server-core.h>

// Wayland Client App Launcher
// Handles discovery and launching of Wayland client applications

@interface WawonaAppScanner : NSObject

@property(nonatomic, assign, readonly) struct wl_display *display;
@property(nonatomic, strong, readonly) NSArray *availableApplications;
@property(nonatomic, strong, readonly) NSArray *runningApplications;

- (instancetype)initWithDisplay:(struct wl_display *)display;
- (void)scanForApplications;
- (BOOL)launchApplication:(NSString *)appId;
- (void)terminateApplication:(NSString *)appId;
- (BOOL)isApplicationRunning:(NSString *)appId;
// Environment setup
- (void)setupWaylandEnvironment;
- (NSString *)waylandSocketPath;

@end

// App metadata
@interface WaylandApp : NSObject
@property(nonatomic, strong) NSString *appId;
@property(nonatomic, strong) NSString *name;
@property(nonatomic, strong) NSString *description;
@property(nonatomic, strong) NSString *iconPath;
@property(nonatomic, strong) NSString *executablePath;
@property(nonatomic, strong) NSArray *categories;
@property(nonatomic, assign) BOOL isRunning;
@end
