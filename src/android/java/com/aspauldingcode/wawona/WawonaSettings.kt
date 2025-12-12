package com.aspauldingcode.wawona

import android.content.SharedPreferences

object WawonaSettings {
    fun apply(prefs: SharedPreferences) {
        WawonaNative.nativeApplySettings(
            prefs.getBoolean("forceServerSideDecorations", false),
            prefs.getBoolean("autoRetinaScaling", true),
            prefs.getInt("renderingBackend", 0),
            prefs.getBoolean("respectSafeArea", true),
            prefs.getBoolean("renderMacOSPointer", false),
            prefs.getBoolean("swapCmdAsCtrl", false),
            prefs.getBoolean("universalClipboard", true),
            prefs.getBoolean("colorSyncSupport", false),
            prefs.getBoolean("nestedCompositorsSupport", false),
            prefs.getBoolean("useMetal4ForNested", false),
            prefs.getBoolean("multipleClients", true),
            prefs.getBoolean("waypipeRSSupport", false),
            prefs.getBoolean("enableTCPListener", false),
            try { prefs.getString("tcpPort", "1234")?.toInt() ?: 1234 } catch (e: Exception) { 1234 }
        )
    }
}
