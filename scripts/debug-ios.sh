#!/usr/bin/env bash
# Attach lldb to the iOS Simulator process for Wawona

# Find the process ID
PID=$(pgrep -f "Wawona.app/Wawona")

if [ -z "$PID" ]; then
    echo "Wawona is not running in the simulator."
    echo "Please launch Wawona in the iOS Simulator first."
    exit 1
fi

echo "Found Wawona process at PID $PID"
echo "Attaching lldb..."

# Attach lldb
lldb -p "$PID"
