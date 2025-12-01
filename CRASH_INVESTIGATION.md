# Caelestia Shell Startup Crash Investigation

## Summary
The shell crashed on startup with a segmentation fault in `IpcServerConnection::onReadyRead()`. This appears to be an IPC (Inter-Process Communication) initialization race condition.

## Crash Details
- **Time**: Dec 01 07:44:35 CET
- **Process ID**: 1621
- **Signal**: SIGSEGV (Segmentation Fault)
- **Location**: `IpcServerConnection::onReadyRead()` in quickshell
- **Core dump**: Present at `~/.cache/quickshell/crashes/cy41wk6t`

## Root Cause Analysis

### 1. Multiple IPC Handlers Initialized at Startup
The following components create `IpcHandler` instances during startup:
- `modules/Shortcuts.qml` - 3 handlers (drawers, controlCenter, toaster)
- `services/IdleInhibitor.qml` - 1 handler (idleInhibitor)
- `services/Notifs.qml` - 1 handler (notifs)
- `modules/lock/Lock.qml` - 1 handler (lock)

### 2. Potential Race Conditions
- Multiple `IpcHandler` components may be trying to register with the IPC server simultaneously
- The IPC server connection may not be fully established when handlers try to register
- A previous crash may have left a stale IPC socket

### 3. Zombie Processes
Defunct processes from the crash indicate improper cleanup:
```
vlad  1621  0:08 [qs] <defunct>
vlad  1623  0:01 [quickshell] <defunct>
```

## Additional Issue: Auto-Restart Loses Config

When quickshell crashes and auto-restarts, it loses the config name (`-c caelestia`), resulting in:
- `ERROR: Could not open config file ""`
- `INFO: Launching config: ""`

This creates a crash loop where the initial crash triggers a restart that fails due to missing config.

**Workaround**: Use the provided `start-caelestia.sh` wrapper script which:
- Cleans up crash state before starting
- Always passes the `-c caelestia` argument
- Prevents duplicate instances with `-n` flag

## Recommendations

### Immediate Fixes

1. **Use the wrapper script**:
   ```bash
   ./start-caelestia.sh
   ```
   Or use it instead of `caelestia shell -d` or `qs -c caelestia -d`

2. **Clean up zombie processes and stale sockets**:
   ```bash
   # Kill any remaining quickshell processes
   killall -9 qs quickshell caelestia-shell 2>/dev/null
   
   # Clean up crash directory
   rm -rf ~/.cache/quickshell/crashes/*
   
   # Check for stale IPC sockets (if any)
   find /tmp -name "*quickshell*" -o -name "*caelestia*" 2>/dev/null
   ```

2. **Add startup delay for IPC handlers**:
   Consider adding a small delay or using `Component.onCompleted` with proper sequencing to ensure IPC server is ready before handlers register.

3. **Add error handling**:
   Wrap IPC handler initialization in try-catch blocks or add null checks.

### Long-term Solutions

1. **Implement IPC handler initialization queue**:
   - Ensure IPC handlers register sequentially rather than simultaneously
   - Add a ready signal from the IPC server before allowing handler registration

2. **Add instance locking**:
   - Prevent multiple shell instances from starting simultaneously
   - Use a lock file or systemd service to ensure single instance

3. **Improve error recovery**:
   - Add automatic cleanup of stale sockets on startup
   - Implement graceful degradation if IPC fails

4. **Add logging**:
   - Enable debug logging for IPC initialization
   - Log the order of component initialization

## Testing

To reproduce and test fixes:
1. Restart the system or ensure no quickshell processes are running
2. Start the shell and monitor for crashes
3. Check system logs: `journalctl --user -u quickshell* --since "today"`
4. Monitor IPC socket creation: `watch -n 1 'ls -la /tmp/*quickshell* 2>/dev/null'`

## Related Files
- `shell.qml` - Main entry point
- `modules/Shortcuts.qml` - Contains multiple IPC handlers
- `services/IdleInhibitor.qml` - IPC handler for idle inhibitor
- `services/Notifs.qml` - IPC handler for notifications
- `modules/lock/Lock.qml` - IPC handler for lock screen

