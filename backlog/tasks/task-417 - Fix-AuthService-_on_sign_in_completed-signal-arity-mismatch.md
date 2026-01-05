---
id: task-417
title: Fix AuthService _on_sign_in_completed signal arity mismatch
status: Done
assignee: []
created_date: '2026-01-04 21:38'
updated_date: '2026-01-05 00:12'
labels:
  - firebase
  - auth
  - bug
  - gdscript
  - signals
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Bug Description

Tests revealed signal arity mismatch in AuthService._on_sign_in_completed.

**Test Output**:
```
Error calling from signal 'sign_in_completed' to callable: 'RefCounted(auth_service.gd)::_on_sign_in_completed': Method expected 5 argument(s), but called with 4
```

## Root Cause Analysis

**Location**: `project/firebase/auth_service.gd:416-418`

**C++ Signal Definition** (godot/modules/firebase/auth.cpp:699-703) - **4 parameters**:
```cpp
ADD_SIGNAL(MethodInfo("sign_in_completed",
    PropertyInfo(Variant::INT, "request_id"),      // param 1
    PropertyInfo(Variant::BOOL, "success"),         // param 2
    PropertyInfo(Variant::STRING, "uid"),           // param 3
    PropertyInfo(Variant::STRING, "error_message"))); // param 4
```

**C++ Emission** (auth.cpp:107):
```cpp
emit_signal("sign_in_completed", req_id, success, uid, error_msg);
```

**GDScript Handler** (auth_service.gd:416-418) - **5 parameters** (WRONG):
```gdscript
func _on_sign_in_completed(
    request_id: int, success: bool, uid: String, error_code: int, error_message: String
) -> void:
```

**Mismatch**: The handler expects `error_code: int` as the 4th parameter, but the C++ signal only emits 4 parameters total (request_id, success, uid, error_message).

**Design Note**: The C++ layer does NOT emit integer error codes. Error codes are converted to strings (via `_firebase_error_code_to_string()`) before being emitted. The signal uses string error messages throughout.

## Recommended Fix

Change the handler signature from 5 to 4 parameters - remove `error_code: int`:

```gdscript
# BEFORE (wrong - 5 params)
func _on_sign_in_completed(
    request_id: int, success: bool, uid: String, error_code: int, error_message: String
) -> void:

# AFTER (correct - 4 params)
func _on_sign_in_completed(
    request_id: int, success: bool, uid: String, error_message: String
) -> void:
```

Also update the handler body to remove references to `error_code` parameter. Use `error_message` string directly for error cases.

## Acceptance Criteria
1. Update `_on_sign_in_completed` signature to 4 parameters (remove error_code)
2. Update handler body to remove error_code references
3. Check `_on_custom_token_sign_in_completed` (same issue at line 448)
4. Run `backend.firebase.auth.sign_in_anonymous` test to verify fix
5. Test on Android platform

## Related
- Discovered by: task-399 backend auth service layer tests
- Test config: `backend.firebase.auth.sign_in_anonymous`
- Related bug: task-416 (non-existent email_sign_in_completed signal)
<!-- SECTION:DESCRIPTION:END -->
