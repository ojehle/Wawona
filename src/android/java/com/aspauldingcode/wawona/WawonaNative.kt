package com.aspauldingcode.wawona

import android.util.Log
import android.view.Surface

object WawonaNative {
    private const val TAG = "WawonaNative"
    
    init {
        try {
            Log.d(TAG, "Loading native library 'wawona'")
            System.loadLibrary("wawona")
            Log.d(TAG, "Native library 'wawona' loaded successfully")
        } catch (e: UnsatisfiedLinkError) {
            Log.e(TAG, "Failed to load native library 'wawona'", e)
            throw e
        } catch (e: Exception) {
            Log.e(TAG, "Unexpected error loading native library", e)
            throw e
        }
    }

    external fun nativeInit()
    external fun nativeSetSurface(surface: Surface)
    external fun nativeDestroySurface()
    external fun nativeUpdateSafeArea(left: Int, top: Int, right: Int, bottom: Int)
    external fun nativeApplySettings(
        forceServerSideDecorations: Boolean,
        autoRetinaScaling: Boolean,
        renderingBackend: Int,
        respectSafeArea: Boolean,
        renderMacOSPointer: Boolean,
        swapCmdAsCtrl: Boolean,
        universalClipboard: Boolean,
        colorSyncSupport: Boolean,
        nestedCompositorsSupport: Boolean,
        useMetal4ForNested: Boolean,
        multipleClients: Boolean,
        waypipeRSSupport: Boolean,
        enableTCPListener: Boolean,
        tcpPort: Int
    )
}
