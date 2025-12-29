---
id: task-396
title: >-
  Fix Windows shutdown race condition - logger freed before Firebase callbacks
  complete
status: Done
assignee: []
created_date: '2025-12-29 15:48'
updated_date: '2025-12-29 19:15'
labels:
  - bug
  - windows
  - firebase
  - shutdown
  - race-condition
dependencies: []
priority: high
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
<!-- SECTION:NOTES:END -->
