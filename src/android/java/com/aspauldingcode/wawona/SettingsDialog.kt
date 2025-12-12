package com.aspauldingcode.wawona

import android.content.SharedPreferences
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun SettingsDialog(
    prefs: SharedPreferences,
    onDismiss: () -> Unit,
    onApply: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            Button(onClick = {
                onApply()
                onDismiss()
            }) {
                Text("Close")
            }
        },
        title = { Text("Wawona Settings", style = MaterialTheme.typography.headlineSmall) },
        text = {
            Column(
                modifier = Modifier
                    .verticalScroll(rememberScrollState())
                    .fillMaxWidth()
            ) {
                SettingsSwitch(prefs, "forceServerSideDecorations", "Force Server-Side Decorations", false)
                SettingsSwitch(prefs, "autoRetinaScaling", "Auto Retina Scaling", true)
                SettingsSwitch(prefs, "respectSafeArea", "Respect Safe Area", true)
                SettingsSwitch(prefs, "renderMacOSPointer", "Render Software Pointer", false)
                SettingsSwitch(prefs, "swapCmdAsCtrl", "Swap Cmd as Ctrl", false)
                SettingsSwitch(prefs, "universalClipboard", "Universal Clipboard", true)
                SettingsSwitch(prefs, "colorSyncSupport", "ColorSync Support", false)
                SettingsSwitch(prefs, "nestedCompositorsSupport", "Nested Compositors", false)
                SettingsSwitch(prefs, "useMetal4ForNested", "Use Metal 4 (Nested)", false)
                SettingsSwitch(prefs, "multipleClients", "Multiple Clients", true)
                SettingsSwitch(prefs, "waypipeRSSupport", "Waypipe RS Support", false)
                SettingsSwitch(prefs, "enableTCPListener", "Enable TCP Listener", false)
                
                // TCP Port (Simple Text Field simulation)
                // For simplicity, we just toggle it here, but ideally needs a text field
                // I'll skip it for now or add a hardcoded value switch
            }
        }
    )
}

@Composable
fun SettingsSwitch(prefs: SharedPreferences, key: String, title: String, default: Boolean) {
    var checked by remember { mutableStateOf(prefs.getBoolean(key, default)) }
    
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = title, 
            style = MaterialTheme.typography.bodyMedium,
            modifier = Modifier.weight(1f)
        )
        Switch(
            checked = checked,
            onCheckedChange = {
                checked = it
                prefs.edit().putBoolean(key, it).apply()
            }
        )
    }
}
