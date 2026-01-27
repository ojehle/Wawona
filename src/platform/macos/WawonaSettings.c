#include "WawonaSettings.h"
#include <string.h>

#ifndef __APPLE__

static WawonaSettingsConfig g_config = {
    .forceServerSideDecorations = true,
    .autoRetinaScaling = true,
    .respectSafeArea = true,
    .renderMacOSPointer = true,
    .universalClipboard = true,
    .colorSyncSupport = true,
    .nestedCompositorsSupport = true,
    .multipleClients = true,
    .waypipeRSSupport = true,
    .enableTCPListener = false,
    .tcpPort = 0,
    .renderingBackend = 0,
    .vulkanDrivers = false,
    .eglDrivers = false
};

void WawonaSettings_UpdateConfig(const WawonaSettingsConfig *config) {
    if (config) {
        g_config = *config;
    }
}

// Universal Clipboard
bool WawonaSettings_GetUniversalClipboardEnabled(void) {
    return g_config.universalClipboard;
}

// Window Decorations
bool WawonaSettings_GetForceServerSideDecorations(void) {
    return g_config.forceServerSideDecorations;
}

// Display
bool WawonaSettings_GetAutoRetinaScalingEnabled(void) {
    return g_config.autoRetinaScaling;
}

bool WawonaSettings_GetRespectSafeArea(void) {
    return g_config.respectSafeArea;
}

// Color Management
bool WawonaSettings_GetColorSyncSupportEnabled(void) {
    return g_config.colorSyncSupport;
}

// Nested Compositors
bool WawonaSettings_GetNestedCompositorsSupportEnabled(void) {
    return g_config.nestedCompositorsSupport;
}

bool WawonaSettings_GetUseMetal4ForNested(void) {
    return g_config.useMetal4ForNested;
}

// Input
bool WawonaSettings_GetRenderMacOSPointer(void) {
    return g_config.renderMacOSPointer;
}

bool WawonaSettings_GetSwapCmdAsCtrl(void) {
    return g_config.swapCmdAsCtrl;
}

// Client Management
bool WawonaSettings_GetMultipleClientsEnabled(void) {
    return g_config.multipleClients;
}

// Waypipe
bool WawonaSettings_GetWaypipeRSSupportEnabled(void) {
    return g_config.waypipeRSSupport;
}

// Network / Remote Access
bool WawonaSettings_GetEnableTCPListener(void) {
    return g_config.enableTCPListener;
}

int WawonaSettings_GetTCPListenerPort(void) {
    return g_config.tcpPort;
}

// Rendering Backend Flags
int WawonaSettings_GetRenderingBackend(void) {
    return g_config.renderingBackend;
}

bool WawonaSettings_GetVulkanDriversEnabled(void) {
    return g_config.vulkanDrivers;
}

bool WawonaSettings_GetEGLDriversEnabled(void) {
    // EGL disabled - Vulkan only mode
    return false;
}

// Dmabuf Support
bool WawonaSettings_GetDmabufEnabled(void) {
    // Usually enabled if Vulkan is enabled, or based on platform
    return true; 
}

#endif
