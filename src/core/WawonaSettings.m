#include "WawonaSettings.h"

#ifdef __APPLE__
#import "WawonaPreferencesManager.h"

bool WawonaSettings_GetUniversalClipboardEnabled(void) {
    return [[WawonaPreferencesManager sharedManager] universalClipboardEnabled];
}

bool WawonaSettings_GetForceServerSideDecorations(void) {
    return [[WawonaPreferencesManager sharedManager] forceServerSideDecorations];
}

bool WawonaSettings_GetAutoRetinaScalingEnabled(void) {
    return [[WawonaPreferencesManager sharedManager] autoRetinaScalingEnabled];
}

bool WawonaSettings_GetRespectSafeArea(void) {
    // Default to true for now, or add to WawonaPreferencesManager if needed
    return true;
}

bool WawonaSettings_GetColorSyncSupportEnabled(void) {
    return [[WawonaPreferencesManager sharedManager] colorSyncSupportEnabled];
}

bool WawonaSettings_GetNestedCompositorsSupportEnabled(void) {
    return [[WawonaPreferencesManager sharedManager] nestedCompositorsSupportEnabled];
}

bool WawonaSettings_GetUseMetal4ForNested(void) {
    return [[WawonaPreferencesManager sharedManager] useMetal4ForNested];
}

bool WawonaSettings_GetRenderMacOSPointer(void) {
    return [[WawonaPreferencesManager sharedManager] renderMacOSPointer];
}

bool WawonaSettings_GetSwapCmdAsCtrl(void) {
    return [[WawonaPreferencesManager sharedManager] swapCmdAsCtrl];
}

bool WawonaSettings_GetMultipleClientsEnabled(void) {
    return [[WawonaPreferencesManager sharedManager] multipleClientsEnabled];
}

bool WawonaSettings_GetWaypipeRSSupportEnabled(void) {
    return [[WawonaPreferencesManager sharedManager] waypipeRSSupportEnabled];
}

bool WawonaSettings_GetEnableTCPListener(void) {
    return [[WawonaPreferencesManager sharedManager] enableTCPListener];
}

int WawonaSettings_GetTCPListenerPort(void) {
    return (int)[[WawonaPreferencesManager sharedManager] tcpListenerPort];
}

bool WawonaSettings_GetVulkanDriversEnabled(void) {
    return [[WawonaPreferencesManager sharedManager] vulkanDriversEnabled];
}

bool WawonaSettings_GetEGLDriversEnabled(void) {
    return [[WawonaPreferencesManager sharedManager] eglDriversEnabled];
}

bool WawonaSettings_GetDmabufEnabled(void) {
    return [[WawonaPreferencesManager sharedManager] dmabufEnabled];
}

#endif
