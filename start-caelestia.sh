#!/usr/bin/env bash
# Wrapper script to start Caelestia shell with proper config
# This ensures the config name is always passed, even after crashes

# Kill any existing instances and wait for them to fully terminate
killall -9 qs quickshell caelestia-shell 2>/dev/null
sleep 1

# Remove entire crashes directory to prevent quickshell from detecting old crashes
rm -rf ~/.cache/quickshell/crashes 2>/dev/null
mkdir -p ~/.cache/quickshell/crashes

# Clean up stale sockets
find /tmp -name "*quickshell*" -o -name "*qs*" 2>/dev/null | xargs rm -f 2>/dev/null

# Wait a moment to ensure cleanup is complete
sleep 0.5

# Unset quickshell crash environment variables that cause auto-restart
# These are set by quickshell when it detects a previous crash
unset __QUICKSHELL_CRASH_DUMP_PID
unset __QUICKSHELL_CRASH_INFO_FD

# Start quickshell with caelestia config
# The -n flag prevents duplicate instances
exec qs -c caelestia -n -d "$@"

