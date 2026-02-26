package com.aspauldingcode.wawona

import androidx.compose.foundation.border
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Linux evdev keycodes for accessory bar (matches input_android.h).
 * 1:1 with iOS charToLinuxKeycode / input-accessory key mapping.
 */
internal object LinuxKey {
    const val ESC = 1
    const val GRAVE = 41
    const val TAB = 15
    const val SLASH = 53
    const val MINUS = 12
    const val HOME = 102
    const val UP = 103
    const val END = 107
    const val PAGEUP = 104
    const val LEFTSHIFT = 42
    const val LEFTCTRL = 29
    const val LEFTALT = 56
    const val LEFTMETA = 125
    const val LEFT = 105
    const val DOWN = 108
    const val RIGHT = 106
    const val PAGEDOWN = 109
    const val ENTER = 28
    const val SPACE = 57
    const val BACKSPACE = 14
}

/** XKB modifier bits (matches iOS / input_android.h). */
internal object XkbMod {
    const val SHIFT = 1 shl 0
    const val CTRL = 1 shl 2
    const val ALT = 1 shl 3
    const val LOGO = 1 shl 6
}

/**
 * Shared modifier state — accessible from ModifierAccessoryBar, WawonaInputConnection,
 * and WawonaSurfaceView. Implements the iOS-matching three-state cycle:
 *   Inactive → (tap) → Sticky (one-shot, applies to next key then auto-clears)
 *   Sticky → (double-tap within 400ms) → Locked (persistent until tapped again)
 *   Locked → (tap) → Inactive
 *
 * Uses Compose mutableStateOf so the accessory bar UI recomposes automatically,
 * while remaining readable from non-Compose contexts (InputConnection, SurfaceView).
 */
object ModifierState {
    var shiftActive by mutableStateOf(false)
    var shiftLocked by mutableStateOf(false)
    var ctrlActive by mutableStateOf(false)
    var ctrlLocked by mutableStateOf(false)
    var altActive by mutableStateOf(false)
    var altLocked by mutableStateOf(false)
    var superActive by mutableStateOf(false)
    var superLocked by mutableStateOf(false)

    @Volatile var lastShiftTap = 0L
    @Volatile var lastCtrlTap = 0L
    @Volatile var lastAltTap = 0L
    @Volatile var lastSuperTap = 0L

    private const val DOUBLE_TAP_THRESHOLD_MS = 400L

    fun tapShift() = doTap(
        shiftActive, shiftLocked, lastShiftTap,
        { shiftActive = it }, { shiftLocked = it }, { lastShiftTap = it }
    )
    fun tapCtrl() = doTap(
        ctrlActive, ctrlLocked, lastCtrlTap,
        { ctrlActive = it }, { ctrlLocked = it }, { lastCtrlTap = it }
    )
    fun tapAlt() = doTap(
        altActive, altLocked, lastAltTap,
        { altActive = it }, { altLocked = it }, { lastAltTap = it }
    )
    fun tapSuper() = doTap(
        superActive, superLocked, lastSuperTap,
        { superActive = it }, { superLocked = it }, { lastSuperTap = it }
    )

    private fun doTap(
        active: Boolean, locked: Boolean, lastTap: Long,
        setActive: (Boolean) -> Unit, setLocked: (Boolean) -> Unit, setLastTap: (Long) -> Unit
    ) {
        val now = System.currentTimeMillis()
        val elapsed = now - lastTap
        setLastTap(now)
        when {
            locked -> { setActive(false); setLocked(false) }
            active && elapsed < DOUBLE_TAP_THRESHOLD_MS -> setLocked(true)
            active -> { setActive(false); setLocked(false) }
            else -> { setActive(true); setLocked(false) }
        }
    }

    fun clearStickyModifiers() {
        if (shiftActive && !shiftLocked) shiftActive = false
        if (ctrlActive && !ctrlLocked) ctrlActive = false
        if (altActive && !altLocked) altActive = false
        if (superActive && !superLocked) superActive = false
    }

    fun hasActiveModifiers(): Boolean =
        shiftActive || ctrlActive || altActive || superActive

    fun getXkbModMask(): Int {
        var mods = 0
        if (shiftActive) mods = mods or XkbMod.SHIFT
        if (ctrlActive) mods = mods or XkbMod.CTRL
        if (altActive) mods = mods or XkbMod.ALT
        if (superActive) mods = mods or XkbMod.LOGO
        return mods
    }
}

/**
 * Map a single character to a Linux evdev keycode + shift flag.
 * Mirrors iOS charToLinuxKeycode() and native char_to_linux_keycode().
 * Returns null for unmapped characters (emoji, CJK, etc.).
 */
internal data class KeyMapping(val keycode: Int, val needsShift: Boolean)

internal fun charToLinuxKeycode(ch: Char): KeyMapping? {
    @Suppress("KotlinConstantConditions")
    val letterKeycodes = intArrayOf(
        30, 48, 46, 32, 18, 33, 34, 35, 23,   // A-I
        36, 37, 38, 50, 49, 24, 25, 16, 19,   // J-R
        31, 20, 22, 47, 17, 45, 21, 44        // S-Z
    )

    if (ch in 'a'..'z') return KeyMapping(letterKeycodes[ch - 'a'], false)
    if (ch in 'A'..'Z') return KeyMapping(letterKeycodes[ch - 'A'], true)
    if (ch in '1'..'9') return KeyMapping(2 + (ch - '1'), false)
    if (ch == '0') return KeyMapping(11, false)

    return when (ch) {
        ' '       -> KeyMapping(LinuxKey.SPACE, false)
        '\n', '\r'-> KeyMapping(LinuxKey.ENTER, false)
        '\t'      -> KeyMapping(LinuxKey.TAB, false)
        '-'       -> KeyMapping(LinuxKey.MINUS, false)
        '='       -> KeyMapping(13, false)
        '['       -> KeyMapping(26, false)
        ']'       -> KeyMapping(27, false)
        '\\'      -> KeyMapping(43, false)
        ';'       -> KeyMapping(39, false)
        '\''      -> KeyMapping(40, false)
        '`'       -> KeyMapping(LinuxKey.GRAVE, false)
        ','       -> KeyMapping(51, false)
        '.'       -> KeyMapping(52, false)
        '/'       -> KeyMapping(LinuxKey.SLASH, false)
        '!'       -> KeyMapping(2, true)
        '@'       -> KeyMapping(3, true)
        '#'       -> KeyMapping(4, true)
        '$'       -> KeyMapping(5, true)
        '%'       -> KeyMapping(6, true)
        '^'       -> KeyMapping(7, true)
        '&'       -> KeyMapping(8, true)
        '*'       -> KeyMapping(9, true)
        '('       -> KeyMapping(10, true)
        ')'       -> KeyMapping(11, true)
        '_'       -> KeyMapping(LinuxKey.MINUS, true)
        '+'       -> KeyMapping(13, true)
        '{'       -> KeyMapping(26, true)
        '}'       -> KeyMapping(27, true)
        '|'       -> KeyMapping(43, true)
        ':'       -> KeyMapping(39, true)
        '"'       -> KeyMapping(40, true)
        '~'       -> KeyMapping(LinuxKey.GRAVE, true)
        '<'       -> KeyMapping(51, true)
        '>'       -> KeyMapping(52, true)
        '?'       -> KeyMapping(LinuxKey.SLASH, true)
        else      -> null
    }
}

/**
 * Modifier accessory bar — 1:1 functionality and button order with iOS.
 *
 * Row 1: ESC  `  TAB  /  —  HOME  ↑  END  PGUP
 * Row 2: ⇧  CTRL  ALT  ◇  ←  ↓  →  PGDN  ⌨↓
 *
 * Modifier behavior (delegated to [ModifierState]):
 * - Inactive → (tap) → Sticky (one-shot, applies to next key then auto-clears)
 * - Sticky → (tap within 0.4s) → Locked (persistent until tapped again)
 * - Sticky → (tap after 0.4s) → Inactive
 * - Locked → (tap) → Inactive
 */
@Composable
fun ModifierAccessoryBar(
    modifier: Modifier = Modifier,
    onDismissKeyboard: () -> Unit
) {
    fun sendAccessoryKey(keycode: Int) {
        val ts = (System.currentTimeMillis() % Int.MAX_VALUE).toInt()
        if (ModifierState.shiftActive)
            WawonaNative.nativeInjectKey(LinuxKey.LEFTSHIFT, true, ts)
        if (ModifierState.ctrlActive)
            WawonaNative.nativeInjectKey(LinuxKey.LEFTCTRL, true, ts)
        if (ModifierState.altActive)
            WawonaNative.nativeInjectKey(LinuxKey.LEFTALT, true, ts)
        if (ModifierState.superActive)
            WawonaNative.nativeInjectKey(LinuxKey.LEFTMETA, true, ts)

        WawonaNative.nativeInjectKey(keycode, true, ts)
        WawonaNative.nativeInjectKey(keycode, false, ts)

        if (ModifierState.shiftActive)
            WawonaNative.nativeInjectKey(LinuxKey.LEFTSHIFT, false, ts)
        if (ModifierState.ctrlActive)
            WawonaNative.nativeInjectKey(LinuxKey.LEFTCTRL, false, ts)
        if (ModifierState.altActive)
            WawonaNative.nativeInjectKey(LinuxKey.LEFTALT, false, ts)
        if (ModifierState.superActive)
            WawonaNative.nativeInjectKey(LinuxKey.LEFTMETA, false, ts)

        ModifierState.clearStickyModifiers()
    }

    val barBg = Color(0xFF1C1C1E)
    val keyInactive = Color(0xFF3A3A3C)
    val keySticky = Color(0xFF0A84FF).copy(alpha = 0.6f)
    val keyLocked = Color(0xFF0A84FF).copy(alpha = 0.85f)
    val keyText = Color.White

    Surface(
        modifier = modifier.fillMaxWidth(),
        color = barBg,
        contentColor = keyText
    ) {
        val rowMod = Modifier
            .fillMaxWidth()
            .padding(horizontal = 4.dp, vertical = 2.dp)
            .height(36.dp)

        Column(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = rowMod,
            horizontalArrangement = Arrangement.spacedBy(3.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            listOf(
                "ESC" to { sendAccessoryKey(LinuxKey.ESC) },
                "`" to { sendAccessoryKey(LinuxKey.GRAVE) },
                "TAB" to { sendAccessoryKey(LinuxKey.TAB) },
                "/" to { sendAccessoryKey(LinuxKey.SLASH) },
                "—" to { sendAccessoryKey(LinuxKey.MINUS) },
                "HOME" to { sendAccessoryKey(LinuxKey.HOME) },
                "↑" to { sendAccessoryKey(LinuxKey.UP) },
                "END" to { sendAccessoryKey(LinuxKey.END) },
                "PGUP" to { sendAccessoryKey(LinuxKey.PAGEUP) }
            ).forEach { (label, action) ->
                AccessoryKey(
                    label, keyInactive, keyText,
                    onClick = { action() },
                    modifier = Modifier.weight(1f)
                )
            }
        }

        Row(
            modifier = rowMod,
            horizontalArrangement = Arrangement.spacedBy(3.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            AccessoryModKey(
                label = "⇧",
                active = ModifierState.shiftActive,
                locked = ModifierState.shiftLocked,
                inactiveColor = keyInactive,
                stickyColor = keySticky,
                lockedColor = keyLocked
            ) { ModifierState.tapShift() }

            AccessoryModKey(
                label = "CTRL",
                active = ModifierState.ctrlActive,
                locked = ModifierState.ctrlLocked,
                inactiveColor = keyInactive,
                stickyColor = keySticky,
                lockedColor = keyLocked
            ) { ModifierState.tapCtrl() }

            AccessoryModKey(
                label = "ALT",
                active = ModifierState.altActive,
                locked = ModifierState.altLocked,
                inactiveColor = keyInactive,
                stickyColor = keySticky,
                lockedColor = keyLocked
            ) { ModifierState.tapAlt() }

            AccessoryModKey(
                label = "◇",
                active = ModifierState.superActive,
                locked = ModifierState.superLocked,
                inactiveColor = keyInactive,
                stickyColor = keySticky,
                lockedColor = keyLocked
            ) { ModifierState.tapSuper() }

            listOf(
                "←" to LinuxKey.LEFT,
                "↓" to LinuxKey.DOWN,
                "→" to LinuxKey.RIGHT,
                "PGDN" to LinuxKey.PAGEDOWN
            ).forEach { (label, keycode) ->
                AccessoryKey(
                    label, keyInactive, keyText,
                    onClick = { sendAccessoryKey(keycode) },
                    modifier = Modifier.weight(1f)
                )
            }
            AccessoryKey(
                "⌨↓", keyInactive, keyText,
                onClick = onDismissKeyboard,
                modifier = Modifier.weight(1f)
            )
        }
        }
    }
}

@Composable
private fun AccessoryKey(
    label: String,
    bgColor: Color,
    textColor: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    TextButton(
        onClick = onClick,
        modifier = modifier.height(32.dp).padding(0.dp),
        colors = ButtonDefaults.textButtonColors(
            containerColor = bgColor,
            contentColor = textColor
        ),
        contentPadding = PaddingValues(0.dp),
        shape = RoundedCornerShape(6.dp)
    ) {
        Text(
            text = label,
            fontSize = 12.sp,
            maxLines = 1
        )
    }
}

@Composable
private fun RowScope.AccessoryModKey(
    label: String,
    active: Boolean,
    locked: Boolean,
    inactiveColor: Color,
    stickyColor: Color,
    lockedColor: Color,
    onClick: () -> Unit
) {
    val bg = when {
        locked -> lockedColor
        active -> stickyColor
        else -> inactiveColor
    }
    val borderMod = if (locked) {
        Modifier.border(2.dp, Color(0xFF0A84FF), RoundedCornerShape(6.dp))
    } else {
        Modifier
    }
    Box(modifier = Modifier.weight(1f).then(borderMod)) {
        AccessoryKey(
            label, bg, Color.White,
            onClick = onClick,
            modifier = Modifier.fillMaxWidth()
        )
    }
}
