/**
 * Android input helpers - keycode mapping and modifier tracking
 *
 * Maps Android KeyEvent keycodes to Linux evdev/XKB keycodes.
 * Android keycodes are similar but not identical to Linux.
 *
 * char_to_linux_keycode() mirrors iOS's charToLinuxKeycode() for virtual
 * keyboard input synthesis — the Rust core handles XKB state internally.
 */

#include "input_android.h"
#include <stdint.h>

/* Android KeyEvent keycodes - same values as in android/view/KeyEvent.java */
#define AKEYCODE_SOFT_LEFT 1
#define AKEYCODE_SOFT_RIGHT 2
#define AKEYCODE_HOME 3
#define AKEYCODE_BACK 4
#define AKEYCODE_CALL 5
#define AKEYCODE_ENDCALL 6
#define AKEYCODE_0 7
#define AKEYCODE_1 8
#define AKEYCODE_2 9
#define AKEYCODE_3 10
#define AKEYCODE_4 11
#define AKEYCODE_5 12
#define AKEYCODE_6 13
#define AKEYCODE_7 14
#define AKEYCODE_8 15
#define AKEYCODE_9 16
#define AKEYCODE_STAR 17
#define AKEYCODE_POUND 18
#define AKEYCODE_DPAD_UP 19
#define AKEYCODE_DPAD_DOWN 20
#define AKEYCODE_DPAD_LEFT 21
#define AKEYCODE_DPAD_RIGHT 22
#define AKEYCODE_DPAD_CENTER 23
#define AKEYCODE_VOLUME_UP 24
#define AKEYCODE_VOLUME_DOWN 25
#define AKEYCODE_POWER 26
#define AKEYCODE_CAMERA 27
#define AKEYCODE_CLEAR 28
#define AKEYCODE_A 29
#define AKEYCODE_B 30
#define AKEYCODE_C 31
#define AKEYCODE_D 32
#define AKEYCODE_E 33
#define AKEYCODE_F 34
#define AKEYCODE_G 35
#define AKEYCODE_H 36
#define AKEYCODE_I 37
#define AKEYCODE_J 38
#define AKEYCODE_K 39
#define AKEYCODE_L 40
#define AKEYCODE_M 41
#define AKEYCODE_N 42
#define AKEYCODE_O 43
#define AKEYCODE_P 44
#define AKEYCODE_Q 45
#define AKEYCODE_R 46
#define AKEYCODE_S 47
#define AKEYCODE_T 48
#define AKEYCODE_U 49
#define AKEYCODE_V 50
#define AKEYCODE_W 51
#define AKEYCODE_X 52
#define AKEYCODE_Y 53
#define AKEYCODE_Z 54
#define AKEYCODE_COMMA 55
#define AKEYCODE_PERIOD 56
#define AKEYCODE_ALT_LEFT 57
#define AKEYCODE_ALT_RIGHT 58
#define AKEYCODE_SHIFT_LEFT 59
#define AKEYCODE_SHIFT_RIGHT 60
#define AKEYCODE_TAB 61
#define AKEYCODE_SPACE 62
#define AKEYCODE_SYMBOL 63
#define AKEYCODE_EXPLORER 64
#define AKEYCODE_ENVELOPE 65
#define AKEYCODE_ENTER 66
#define AKEYCODE_DEL 67
#define AKEYCODE_GRAVE 68
#define AKEYCODE_MINUS 69
#define AKEYCODE_EQUALS 70
#define AKEYCODE_LEFT_BRACKET 71
#define AKEYCODE_RIGHT_BRACKET 72
#define AKEYCODE_BACKSLASH 73
#define AKEYCODE_SEMICOLON 74
#define AKEYCODE_APOSTROPHE 75
#define AKEYCODE_SLASH 76
#define AKEYCODE_AT 77
#define AKEYCODE_NUM 78
#define AKEYCODE_HEADPHONEHOOK 79
#define AKEYCODE_FOCUS 80
#define AKEYCODE_PLUS 81
#define AKEYCODE_MENU 82
#define AKEYCODE_NOTIFICATION 83
#define AKEYCODE_SEARCH 84
#define AKEYCODE_DPAD_UP_2 85 /* same as 19 on many devices */
#define AKEYCODE_DPAD_DOWN_2 86
#define AKEYCODE_DPAD_LEFT_2 87
#define AKEYCODE_DPAD_RIGHT_2 88
#define AKEYCODE_DPAD_CENTER_2 89
#define AKEYCODE_CTRL_LEFT 113
#define AKEYCODE_CTRL_RIGHT 114
#define AKEYCODE_ESCAPE 111
#define AKEYCODE_FORWARD_DEL 112
#define AKEYCODE_META_LEFT 117
#define AKEYCODE_META_RIGHT 118

/**
 * Map Android KeyEvent keycode to Linux evdev keycode.
 * Returns 0 if unmapped (caller may pass through or skip).
 */
uint32_t android_keycode_to_linux(uint32_t android_keycode) {
  switch (android_keycode) {
  /* Letters A-Z */
  case AKEYCODE_A: return KEY_A;
  case AKEYCODE_B: return KEY_B;
  case AKEYCODE_C: return KEY_C;
  case AKEYCODE_D: return KEY_D;
  case AKEYCODE_E: return KEY_E;
  case AKEYCODE_F: return KEY_F;
  case AKEYCODE_G: return KEY_G;
  case AKEYCODE_H: return KEY_H;
  case AKEYCODE_I: return KEY_I;
  case AKEYCODE_J: return KEY_J;
  case AKEYCODE_K: return KEY_K;
  case AKEYCODE_L: return KEY_L;
  case AKEYCODE_M: return KEY_M;
  case AKEYCODE_N: return KEY_N;
  case AKEYCODE_O: return KEY_O;
  case AKEYCODE_P: return KEY_P;
  case AKEYCODE_Q: return KEY_Q;
  case AKEYCODE_R: return KEY_R;
  case AKEYCODE_S: return KEY_S;
  case AKEYCODE_T: return KEY_T;
  case AKEYCODE_U: return KEY_U;
  case AKEYCODE_V: return KEY_V;
  case AKEYCODE_W: return KEY_W;
  case AKEYCODE_X: return KEY_X;
  case AKEYCODE_Y: return KEY_Y;
  case AKEYCODE_Z: return KEY_Z;
  /* Numbers */
  case AKEYCODE_0: return KEY_0;
  case AKEYCODE_1: return KEY_1;
  case AKEYCODE_2: return KEY_2;
  case AKEYCODE_3: return KEY_3;
  case AKEYCODE_4: return KEY_4;
  case AKEYCODE_5: return KEY_5;
  case AKEYCODE_6: return KEY_6;
  case AKEYCODE_7: return KEY_7;
  case AKEYCODE_8: return KEY_8;
  case AKEYCODE_9: return KEY_9;
  /* Modifiers */
  case AKEYCODE_CTRL_LEFT: return KEY_LEFTCTRL;
  case AKEYCODE_CTRL_RIGHT: return KEY_RIGHTCTRL;
  case AKEYCODE_SHIFT_LEFT: return KEY_LEFTSHIFT;
  case AKEYCODE_SHIFT_RIGHT: return KEY_RIGHTSHIFT;
  case AKEYCODE_ALT_LEFT: return KEY_LEFTALT;
  case AKEYCODE_ALT_RIGHT: return KEY_RIGHTALT;
  case AKEYCODE_META_LEFT: return KEY_LEFTMETA;
  case AKEYCODE_META_RIGHT: return KEY_RIGHTMETA;
  /* Navigation */
  case AKEYCODE_DPAD_UP:
  case AKEYCODE_DPAD_UP_2: return KEY_UP;
  case AKEYCODE_DPAD_DOWN:
  case AKEYCODE_DPAD_DOWN_2: return KEY_DOWN;
  case AKEYCODE_DPAD_LEFT:
  case AKEYCODE_DPAD_LEFT_2: return KEY_LEFT;
  case AKEYCODE_DPAD_RIGHT:
  case AKEYCODE_DPAD_RIGHT_2: return KEY_RIGHT;
  /* Special */
  case AKEYCODE_ENTER:
  case AKEYCODE_DPAD_CENTER:
  case AKEYCODE_DPAD_CENTER_2: return KEY_ENTER;
  case AKEYCODE_TAB: return KEY_TAB;
  case AKEYCODE_SPACE: return KEY_SPACE;
  case AKEYCODE_ESCAPE: return KEY_ESC;
  case AKEYCODE_DEL: return KEY_BACKSPACE;
  case AKEYCODE_FORWARD_DEL: return KEY_DELETE;
  case AKEYCODE_HOME: return KEY_HOME;
  case AKEYCODE_ENDCALL: return KEY_END;
  /* Punctuation */
  case AKEYCODE_COMMA: return KEY_COMMA;
  case AKEYCODE_PERIOD: return KEY_DOT;
  case AKEYCODE_SLASH: return KEY_SLASH;
  case AKEYCODE_MINUS: return KEY_MINUS;
  case AKEYCODE_EQUALS: return KEY_EQUAL;
  case AKEYCODE_LEFT_BRACKET: return KEY_LEFTBRACE;
  case AKEYCODE_RIGHT_BRACKET: return KEY_RIGHTBRACE;
  case AKEYCODE_BACKSLASH: return KEY_BACKSLASH;
  case AKEYCODE_SEMICOLON: return KEY_SEMICOLON;
  case AKEYCODE_APOSTROPHE: return KEY_APOSTROPHE;
  case AKEYCODE_GRAVE: return KEY_GRAVE;
  default:
    return android_keycode;
  }
}

/**
 * Map an ASCII character to its Linux evdev keycode.
 * Mirrors iOS charToLinuxKeycode() — the Rust core handles XKB state
 * internally, so both platforms just inject Linux keycodes.
 * Returns 0 for non-ASCII / unmapped characters.
 */
uint32_t char_to_linux_keycode(char c, int *needs_shift) {
  *needs_shift = 0;

  /* Letters — evdev layout is NOT contiguous */
  /* clang-format off */
  static const uint32_t letter_map[26] = {
    KEY_A, KEY_B, KEY_C, KEY_D, KEY_E, KEY_F, KEY_G, KEY_H, KEY_I,
    KEY_J, KEY_K, KEY_L, KEY_M, KEY_N, KEY_O, KEY_P, KEY_Q, KEY_R,
    KEY_S, KEY_T, KEY_U, KEY_V, KEY_W, KEY_X, KEY_Y, KEY_Z,
  };
  /* clang-format on */

  if (c >= 'a' && c <= 'z')
    return letter_map[c - 'a'];
  if (c >= 'A' && c <= 'Z') {
    *needs_shift = 1;
    return letter_map[c - 'A'];
  }

  /* Numbers 1-9, 0 */
  if (c >= '1' && c <= '9')
    return KEY_1 + (uint32_t)(c - '1');
  if (c == '0')
    return KEY_0;

  switch (c) {
  case ' ':  return KEY_SPACE;
  case '\n':
  case '\r': return KEY_ENTER;
  case '\t': return KEY_TAB;
  case '-':  return KEY_MINUS;
  case '=':  return KEY_EQUAL;
  case '[':  return KEY_LEFTBRACE;
  case ']':  return KEY_RIGHTBRACE;
  case '\\': return KEY_BACKSLASH;
  case ';':  return KEY_SEMICOLON;
  case '\'': return KEY_APOSTROPHE;
  case '`':  return KEY_GRAVE;
  case ',':  return KEY_COMMA;
  case '.':  return KEY_DOT;
  case '/':  return KEY_SLASH;
  /* Shifted symbols */
  case '!':  *needs_shift = 1; return KEY_1;
  case '@':  *needs_shift = 1; return KEY_2;
  case '#':  *needs_shift = 1; return KEY_3;
  case '$':  *needs_shift = 1; return KEY_4;
  case '%':  *needs_shift = 1; return KEY_5;
  case '^':  *needs_shift = 1; return KEY_6;
  case '&':  *needs_shift = 1; return KEY_7;
  case '*':  *needs_shift = 1; return KEY_8;
  case '(':  *needs_shift = 1; return KEY_9;
  case ')':  *needs_shift = 1; return KEY_0;
  case '_':  *needs_shift = 1; return KEY_MINUS;
  case '+':  *needs_shift = 1; return KEY_EQUAL;
  case '{':  *needs_shift = 1; return KEY_LEFTBRACE;
  case '}':  *needs_shift = 1; return KEY_RIGHTBRACE;
  case '|':  *needs_shift = 1; return KEY_BACKSLASH;
  case ':':  *needs_shift = 1; return KEY_SEMICOLON;
  case '"':  *needs_shift = 1; return KEY_APOSTROPHE;
  case '~':  *needs_shift = 1; return KEY_GRAVE;
  case '<':  *needs_shift = 1; return KEY_COMMA;
  case '>':  *needs_shift = 1; return KEY_DOT;
  case '?':  *needs_shift = 1; return KEY_SLASH;
  default:   return 0;
  }
}
