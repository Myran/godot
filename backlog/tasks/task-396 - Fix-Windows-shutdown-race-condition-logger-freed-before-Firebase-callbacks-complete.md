---
id: task-396
title: >-
  Fix Windows shutdown race condition - logger freed before Firebase callbacks
  complete
status: Done
assignee: []
created_date: '2025-12-29 15:48'
updated_date: '2025-12-30 14:05'
labels:
  - bug
  - windows
  - firebase
  - shutdown
  - race-condition
dependencies: []
priority: high
ordinal: 295000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

On Windows physical machine, the `firebase-cpp-layer` test shows 5 critical errors during shutdown:

```
SCRIPT ERROR: Invalid call. Nonexistent function 'info' in base 'previously freed'.
   at: <anonymous lambda> (res://debug/actions/firebase_cpp/cpp_firebase_debug_action.gd:151)
```

## Root Cause Analysis (OODA)

**Shutdown sequence race condition:**
1. App initiates shutdown → Logger/DebugAction objects get freed
2. Firebase C++ SDK destructor runs (`FirebaseDatabase complete cleanup`)
3. Pending async callback (e.g., `SetValue ReqID:3709`) completes on main thread
4. Callback lambda tries to call `logger.info()` or `_update_status()`
5. Logger already freed → "previously freed" error

**Evidence from log:**
```
[RTDB C++] FirebaseDatabase Destructor called.
[RTDB C++] FirebaseDatabase complete cleanup completed (Task-213 fix).
[RTDB C++] SetValue ReqID:3709 Main thread handler - Success.
SCRIPT ERROR: Invalid call. Nonexistent function 'info' in base 'previously freed'.
```

## Affected Files

- `res://debug/actions/firebase_cpp/cpp_firebase_debug_action.gd:151` - Lambda callback
- `res://addons/debug_framework/output/debug_output_service.gd:92` - `_log_to_system()`
- `res://addons/debug_framework/core/debug_action.gd:498,502` - `_update_status()`
- `res://debug/actions/firebase_cpp/cpp_signal_integrity_test_action.gd:45`

## Platform

- ❌ **Windows Physical** - Affected
- ✅ Android - Not affected (tests pass)
- ✅ iOS/macOS - Unknown (needs verification)

## Potential Solutions

1. **Guard callbacks with `is_instance_valid()`** before logging
2. **Cancel pending callbacks** before freeing logger
3. **Use WeakRef** for logger references in lambdas
4. **Extend logger lifetime** until all callbacks complete

## Related

- Task-213: FirebaseDatabase cleanup (mentioned in log)
- ObjectDB leaks also detected at exit (secondary issue)
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Implementation Notes (2025-12-29)

### Root Cause
Firebase C++ SDK async callbacks complete after Logger autoload is freed during Godot shutdown sequence. This causes "Invalid call. Nonexistent function 'info' in base 'previously freed'" errors.

### Solution Applied
Added `is_instance_valid(Log)` guards throughout the codebase:

1. **`cpp_firebase_debug_action.gd`**: Added `_safe_log_*` helper methods and guarded all Log calls
2. **`cpp_signal_integrity_test_action.gd`**: Converted to use safe helpers
3. **`cpp_database_availability_action.gd`**: Added guard
4. **`cpp_large_data_test_action.gd`**: Added guard
5. **`test_validation.gd`**: Added guards to all static validation functions
6. **`debug_action.gd`**: Added guards to `_execute_core` and `_evaluate_action_result`
7. **`debug_output_service.gd`**: Added guard to `_log_to_system`
8. **`logger.gd`**: Added `_shutting_down` flag (additional protection layer)

### Testing
- 3 consecutive tests passed on Windows physical machine
- No "previously freed" errors in logs
- All 7 Firebase C++ layer actions pass with 100% success rate

## Root Cause Fix (2025-12-29)

### True Root Cause
Firebase cleanup was only enabled for Android and macOS, NOT Windows. This meant `begin_shutdown()` (which sets `is_shutting_down = true`) was never called on Windows, so C++ callbacks continued firing during shutdown.

### Fix Applied
Modified `quit_application_event.gd:137` to include Windows in the supported platforms:
```gdscript
var supported_platforms: Array[String] = ["Android", "macOS", "Windows"]
if not supported_platforms.has(OS.get_name()):
    return
```

This ensures Firebase cleanup (including `begin_shutdown()`) is called on Windows before shutdown.

### Architecture Flow (After Fix)
1. Test completes → `QuitApplicationEvent.execute()` called
2. `_perform_firebase_cleanup()` runs on Windows (now included)
3. `cleanup_firebase()` calls `FirebaseDatabase::begin_shutdown()`
4. `begin_shutdown()` sets `is_shutting_down = true`
5. Any pending callbacks check `is_app_shutting_down()` and return early
6. Logger isn't accessed by shutdown-time callbacks → no crash

### Defense in Depth
The `is_instance_valid(Log)` guards added earlier remain as backup protection for edge cases.

### Verification
- 3 consecutive Windows physical tests passed
- 0 "previously freed" errors
- Firebase cleanup logs confirm proper shutdown sequence

### Completion Summary (2025-12-29)

**Root Cause Fix (commit 9d9bd201)**: Fixed `quit_application_event.gd` to include Windows in Firebase cleanup, enabling `begin_shutdown()` to prevent callbacks during shutdown.

**Guard Removal (commit 42880872)**: Removed scattered `is_instance_valid(Log)` guards and `_safe_log_*` helpers after root cause fix validated. Simplified to direct `Log.*` calls.

**Cross-Platform Validation**: Windows 13/13 configs passed, Android Firebase actions 100% passed. 0 "previously freed" errors.

**Modified Files**: quit_application_event.gd, cpp_firebase_debug_action.gd, cpp_signal_integrity_test_action.gd, cpp_database_availability_action.gd, cpp_large_data_test_action.gd, test_validation.gd, debug_action.gd, debug_output_service.gd
<!-- SECTION:NOTES:END -->
