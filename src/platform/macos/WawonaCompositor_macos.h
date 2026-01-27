// WawonaCompositor_macos.h - macOS-specific compositor extensions
// Extracted from WawonaCompositor.m for better organization

#pragma once

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR

#import "WawonaCompositor.h"
#import <Cocoa/Cocoa.h>

// NSWindowDelegate functionality has been moved to WawonaWindowContainer
// in WawonaSurfaceManager.m

#endif // !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR
