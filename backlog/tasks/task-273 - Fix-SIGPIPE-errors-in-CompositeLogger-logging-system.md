---
id: task-273
title: Fix SIGPIPE errors in CompositeLogger logging system
status: Done
assignee: []
created_date: '2025-11-11 08:40'
updated_date: '2025-11-11 21:08'
labels:
  - stability
  - logging
  - sigpipe
  - mobile-app
dependencies: []
priority: high
---

## Description

**🚨 HIGH PRIORITY STABILITY ISSUE** - Logging system experiencing SIGPIPE errors causing potential app crashes.

**Sentry Issue**: [GODOT-S](https://primary-hive.sentry.io/issues/GODOT-S)
**Error**: `SIGPIPE: Signal 13, Code 0`
**Component**: `CompositeLogger::logv`
**Timeline**: 3 occurrences over 2 days (Nov 9-10)
**Severity**: Fatal level errors

**Root Cause**: Broken pipe in logging system - occurring when writing to closed file descriptor, likely during app backgrounding/termination.

**Impact**:
- App crashes during normal operation
- Logging system instability
- Potential data loss during critical operations
- Poor user experience on mobile platforms

## Root Cause Analysis

**SIGPIPE Technical Details**:
- **Signal 13**: Broken pipe (writing to closed file descriptor)
- **Common Cause**: Process termination during write operation
- **Mobile Pattern**: App backgrounding kills file handles
- **Fatal Level**: Causes immediate app termination

**Likely Scenarios**:
1. **App Backgrounding**: Android/iOS closes file descriptors when app goes to background
2. **Log Rotation**: Log file being rotated/moved during write operation
3. **External Termination**: OS kills process while logger is writing
4. **Network Logging**: Remote logging connection drops during write

**Evidence from Sentry**:
- All 3 occurrences in `CompositeLogger::logv` function
- Fatal level errors (app crashes)
- Consistent timing: Nov 9 (17:42, 15:58) and Nov 10 (10:06)
- Pattern suggests mobile app lifecycle events

## Proposed Solutions

### Option 1: SIGPIPE Signal Handling (Recommended)
```cpp
// In CompositeLogger initialization:
signal(SIGPIPE, SIG_IGN);  // Ignore SIGPIPE signal

// Or use modern signal handling:
struct sigaction sa;
sa.sa_handler = SIG_IGN;
sigemptyset(&sa.sa_mask);
sa.sa_flags = 0;
sigaction(SIGPIPE, &sa, NULL);
```

### Option 2: Safe Write Operations
```cpp
// Check file descriptor validity before writing:
bool CompositeLogger::logv(const char* format, va_list args) {
    if (!is_file_descriptor_valid(log_file_fd)) {
        return false;  // Skip write if FD invalid
    }

    // Original logging logic
    return vfprintf(log_file_fd, format, args) >= 0;
}
```

### Option 3: Buffered Logging with Flush Control
```cpp
class SafeCompositeLogger {
private:
    std::stringstream buffer;
    bool write_enabled = true;

public:
    void log(const std::string& message) {
        if (!write_enabled) {
            buffer << message << std::endl;  // Buffer for later
            return;
        }

        try {
            write_to_file(message);
        } catch (const std::exception& e) {
            write_enabled = false;  // Disable writes on error
            buffer << message << std::endl;  // Start buffering
        }
    }
};
```

### Option 4: Mobile-Aware Logging
```cpp
// Detect app lifecycle state and adjust logging:
class LifecycleAwareLogger {
    void on_app_backgrounded() {
        pause_file_logging();  // Stop file writes
        switch_to_memory_logging();  // Buffer in memory
    }

    void on_app_foregrounded() {
        resume_file_logging();  // Resume normal operation
        flush_memory_buffer();  // Write buffered logs
    }
};
```

## Acceptance Criteria

- [x] **Issue Identification**: SIGPIPE errors identified via Sentry MCP integration
- [ ] **SIGPIPE Handling**: Implement proper SIGPIPE signal handling to prevent crashes
- [ ] **Graceful Degradation**: Logging system handles broken pipes without app termination
- [ ] **Mobile Stability**: Fix works reliably on Android/iOS platforms
- [ ] **Preserve Logging**: Core logging functionality remains intact when app is active
- [ ] **Sentry Validation**: No more GODOT-S SIGPIPE errors after fix deployment
- [ ] **Performance**: Minimal performance impact from signal handling
- [ ] **Testing**: Validate fix with app backgrounding/foregrounding scenarios

## Testing Requirements

1. **App Lifecycle Tests**: Background/foreground app during active logging
2. **Log Rotation Tests**: Rotate/move log files while app is running
3. **Network Logging Tests**: Test remote logging connection drops
4. **Stress Tests**: High-volume logging during app state changes
5. **Platform Tests**: Validate on both Android and iOS platforms
6. **Production Monitoring**: Monitor Sentry for regression after deployment

## Implementation Strategy

### Phase 1: Signal Handling (Immediate)
- Implement SIGPIPE signal ignoring/handling
- Add safe write checks
- Deploy to production to stop crashes

### Phase 2: Enhanced Resilience (Follow-up)
- Implement buffered logging during app backgrounding
- Add app lifecycle awareness
- Enhanced error recovery mechanisms

### Phase 3: Optimization (Future)
- Performance optimization for mobile scenarios
- Advanced buffering strategies
- Analytics on logging patterns

## Related Issues

- **Sentry**: GODOT-S - Primary stability issue
- **Backlog**: task-166 (SIGPIPE in test pipeline - similar pattern)
- **Code Location**: `CompositeLogger::logv` (C++ logging infrastructure)
- **Related Systems**: App lifecycle management, logging infrastructure

## Implementation Notes

**Investigation Method**: Discovered through Sentry MCP server integration showing real-time production stability issues.

**Priority**: High - causes app crashes and poor user experience, though not blocking core functionality.

**Platform Considerations**: SIGPIPE handling is critical for mobile apps where OS frequently terminates backgrounded processes.

**Estimated Complexity**: Medium - requires C++ signal handling and mobile lifecycle awareness.

**Safety**: Signal handling must be carefully implemented to avoid side effects.
