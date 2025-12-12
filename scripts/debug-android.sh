#!/usr/bin/env bash
# Debug Wawona Android App using ndk-gdb

# Locate the NDK
if [ -z "$ANDROID_NDK_ROOT" ]; then
    echo "ANDROID_NDK_ROOT is not set."
    
    # Try default location on macOS
    if [ -d "$HOME/Library/Android/sdk/ndk" ]; then
        LATEST_NDK=$(ls -d "$HOME/Library/Android/sdk/ndk/"* | sort -V | tail -n1)
        if [ -n "$LATEST_NDK" ]; then
             export ANDROID_NDK_ROOT="$LATEST_NDK"
             echo "Found NDK at $ANDROID_NDK_ROOT"
        fi
    fi
fi

if [ -z "$ANDROID_NDK_ROOT" ]; then
    echo "Error: Could not find Android NDK."
    echo "Please set ANDROID_NDK_ROOT to your NDK installation."
    echo "Example: export ANDROID_NDK_ROOT=/path/to/android-ndk-r27c"
    exit 1
fi

NDK_GDB="$ANDROID_NDK_ROOT/ndk-gdb"

if [ ! -f "$NDK_GDB" ]; then
    echo "Error: ndk-gdb not found at $NDK_GDB"
    exit 1
fi

echo "Starting ndk-gdb..."

PROJECT_DIR="$(pwd)/src/android"

if [ ! -d "$PROJECT_DIR" ]; then
    echo "Error: Could not find Android project directory at $PROJECT_DIR"
    exit 1
fi

# Note: ndk-gdb requires 'adb' to be in PATH.
if ! command -v adb &> /dev/null; then
    if [ -n "$ANDROID_SDK_ROOT" ]; then
        export PATH="$ANDROID_SDK_ROOT/platform-tools:$PATH"
    elif [ -d "$HOME/Library/Android/sdk/platform-tools" ]; then
        export PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"
    fi
fi

"$NDK_GDB" --project "$PROJECT_DIR" --launch --verbose
