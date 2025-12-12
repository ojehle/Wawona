#pragma once
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Universal Clipboard
bool WawonaSettings_GetUniversalClipboardEnabled(void);

// Window Decorations
bool WawonaSettings_GetForceServerSideDecorations(void);

// Display
bool WawonaSettings_GetAutoRetinaScalingEnabled(void);
bool WawonaSettings_GetRespectSafeArea(void);

// Color Management
bool WawonaSettings_GetColorSyncSupportEnabled(void);

// Nested Compositors
bool WawonaSettings_GetNestedCompositorsSupportEnabled(void);
bool WawonaSettings_GetUseMetal4ForNested(void);

// Input
bool WawonaSettings_GetRenderMacOSPointer(void);
bool WawonaSettings_GetSwapCmdAsCtrl(void);

// Client Management
bool WawonaSettings_GetMultipleClientsEnabled(void);

// Waypipe
bool WawonaSettings_GetWaypipeRSSupportEnabled(void);

// Network / Remote Access
bool WawonaSettings_GetEnableTCPListener(void);
int WawonaSettings_GetTCPListenerPort(void);

// Rendering Backend Flags
int WawonaSettings_GetRenderingBackend(void);
bool WawonaSettings_GetVulkanDriversEnabled(void);
bool WawonaSettings_GetEGLDriversEnabled(void);

// Dmabuf Support
bool WawonaSettings_GetDmabufEnabled(void);

// Configuration update (mainly for Android/Linux where settings are pushed from platform layer)
#ifndef __APPLE__
typedef struct {
    bool universalClipboard;
    bool forceServerSideDecorations;
    bool autoRetinaScaling;
    bool respectSafeArea;
    bool colorSyncSupport;
    bool nestedCompositorsSupport;
    bool useMetal4ForNested;
    bool renderMacOSPointer;
    bool swapCmdAsCtrl;
    bool multipleClients;
    bool waypipeRSSupport;
    bool enableTCPListener;
    int tcpPort;
    // Rendering backend is handled separately or via separate flags
    int renderingBackend; // 0=Automatic, 1=Metal(Vulkan), 2=Cocoa(Surface)
    bool vulkanDrivers; // derived from backend choice
    bool eglDrivers;    // derived from backend choice
} WawonaSettingsConfig;

void WawonaSettings_UpdateConfig(const WawonaSettingsConfig *config);
#endif

#ifdef __cplusplus
}
#endif
