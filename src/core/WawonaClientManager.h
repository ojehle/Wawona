// WawonaClientManager.h - Client connection/disconnection and title management
// Extracted from WawonaCompositor.m for better organization

#pragma once

#import <Foundation/Foundation.h>

// Client lifecycle functions
void macos_compositor_handle_client_connect(void);
void macos_compositor_handle_client_disconnect(void);
void macos_compositor_check_and_hide_window_if_needed(void);
void macos_compositor_update_title_no_clients(void);

