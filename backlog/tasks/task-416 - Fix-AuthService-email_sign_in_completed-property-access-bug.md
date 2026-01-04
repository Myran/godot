---
id: task-416
title: Fix AuthService email_sign_in_completed property access bug
status: To Do
assignee: []
created_date: '2026-01-04 21:38'
updated_date: '2026-01-04 23:30'
labels:
  - firebase
  - auth
  - bug
  - gdscript
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Bug Description

Tests revealed that AuthService has invalid access to 'email_sign_in_completed' property on FirebaseAuth base object.

**Test Output**:
```
Invalid access to property or key 'email_sign_in_completed' on a base object of type 'FirebaseAuth'
```

## Root Cause Analysis

**Location**: `project/firebase/auth_service.gd:367`

The code attempts to connect to a signal that doesn't exist in the C++ layer:

```gdscript
err = _cpp_auth.email_sign_in_completed.connect(_on_email_sign_in_completed)
```

**C++ Reality** (godot/modules/firebase/auth.cpp:698-726):
- `sign_in_completed` - ✅ exists (4 params)
- `custom_token_sign_in_completed` - ✅ exists (4 params)
- `id_token_result` - ✅ exists (4 params)
- `link_completed` - ✅ exists (3 params)
- `unlink_completed` - ✅ exists (3 params)
- `email_sign_in_completed` - ❌ **DOES NOT EXIST**

**Design Pattern**: The C++ FirebaseAuth class emits `sign_in_completed` for ALL sign-in operations:
- Anonymous sign-in → `sign_in_completed`
- Email/password → `sign_in_completed`
- Facebook → `sign_in_completed`
- Apple → `sign_in_completed`
- Custom token → `custom_token_sign_in_completed`

See `_handle_sign_in_on_main_thread()` in auth.cpp:107 which emits the same signal for all sign-in types.

## Recommended Fix

1. **Remove** the `_on_email_sign_in_completed` handler (lines 477-503)
2. **Remove** the signal connection attempt at line 367
3. **Route** email sign-ins through the existing `_on_sign_in_completed` handler
4. **Verify** `sign_in_with_email_async` in C++ calls `_handle_sign_in_on_main_thread` (it does)

The existing `_on_sign_in_completed` handler already handles the correct flow - just needs to process email sign-ins.

## Acceptance Criteria
1. Remove `_on_email_sign_in_completed` method (lines 477-503)
2. Remove `email_sign_in_completed` signal connection (line 367)
3. Verify `sign_in_with_email_async()` emits `sign_in_completed` signal
4. Run `backend.firebase.auth.sign_in_anonymous` test to verify fix
5. Test on Android platform

## Related
- Discovered by: task-399 backend auth service layer tests
- Test config: `backend.firebase.auth.sign_in_anonymous`
- Related bug: task-417 (signal arity mismatch)
<!-- SECTION:DESCRIPTION:END -->
