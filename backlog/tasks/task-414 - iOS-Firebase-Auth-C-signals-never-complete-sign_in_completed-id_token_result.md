---
id: task-414
title: >-
  iOS: Firebase Auth C++ signals never complete (sign_in_completed,
  id_token_result)
status: Done
assignee: []
created_date: '2026-01-03 16:12'
updated_date: '2026-01-04 17:59'
labels:
  - ios
  - firebase
  - auth
  - cpp
  - signals
  - blocking
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Root Cause Analysis (OODA - OBSERVE)

**Platform**: iOS
**Module**: Firebase Auth C++ (godot/modules/firebase/auth.cpp)
**Signals Affected**:
- `sign_in_completed` - Never fires after `sign_in_anonymous()` call
- `id_token_result` - Never fires after `get_id_token()` call

### Evidence

**iOS Test Results** (`cpp.firebase.auth.tests`):
- Expected 5 actions, only 4 executed
- `sign_in_anonymous` and `get_id_token` actions silently skipped
- Test shows 4/4 PASSED but should be 5/5

**iOS Log Evidence** (`/tmp/ios_test_cpp.firebase.auth.tests_ios_1767454582.log`):
```
[Auth] Start async anonymous sign in. ReqID: 6077
[Auth] Start async anonymous sign in. ReqID: 6158
# Missing: "Sign in completed on main thread" - callback never fires
```

**macOS Comparison** (Working correctly):
- Same tests pass fully on macOS (5/5 actions)
- All C++ Auth signals fire and complete properly
- `sign_in_anonymous` takes 799ms and completes

### Current Behavior

The C++ `auth.cpp` starts the async Firebase Auth operation:
```cpp
// auth.cpp - sign_in_anonymous starts the operation
firebase::auth::Auth::SignInAnonymously()
```

But the callback that should emit the Godot signal never completes on iOS:
```cpp
// Callback should fire but doesn't on iOS
void OnSignInComplete(...) {
    // Emit sign_in_completed signal
}
```

## Impact

- Firebase Auth tests appear to pass but skip key actions
- Any feature depending on Auth C++ signals will fail silently on iOS
- Users cannot sign in anonymously on iOS

## Next Steps (ORIENT/DECIDE/ACT)

1. Investigate iOS-specific Firebase SDK callback threading
2. Check if iOS main thread dispatch is required for callbacks
3. Verify Firebase Auth C++ SDK iOS framework linkage
4. Add logging to trace callback invocation on iOS

## Related Files

- `godot/modules/firebase/auth.cpp` - C++ Auth implementation
- `project/debug/actions/firebase_auth/auth_sign_in_anonymous_action.gd` - GDScript action
- `godot/modules/firebase/GodotFirebase.h` - iOS bridge definitions
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Root Cause CONFIRMED

**Evidence**:

- macOS: `[Auth] Sign in completed on main thread` ✅ prints

- iOS: `sign_in_completed` signal NEVER fires ❌

**Technical Details**:

- `firebase::auth::Auth::GetAuth(app)` succeeds on both platforms

- `auth->SignInAnonymously()` is called successfully on iOS

- `result.OnCompletion()` lambda is registered

- **Lambda NEVER executes on iOS**

**Root Cause**: Firebase Auth C++ SDK callbacks don't fire on iOS due to threading/app lifecycle issues.

**Fix Strategy**: Add explicit timeout and fallback to polling for iOS

## Completed 2026-01-04

**Fix committed**: `253a79bb`

**Root causes fixed:**
1. SignalAwaiter variadic args - extended to 8 params
2. Integer overflow in request ID - masked to 31-bit positive
3. NSRunLoop pumping for iOS callbacks

**Cross-platform verification:**
- iOS: ✅ 4101ms
- Android: ✅ 1002ms
- macOS: ✅ 706ms
- Windows: ✅ 758ms
<!-- SECTION:NOTES:END -->
