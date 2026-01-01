---
id: task-399
title: >-
  Refactor Firebase Auth C++ to match database.h patterns and add GDScript
  service layer
status: To Do
assignee: []
created_date: '2025-12-30 21:26'
updated_date: '2026-01-01 14:08'
labels:
  - firebase
  - auth
  - gdscript
  - testing
dependencies:
  - task-403
  - task-406
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Overview

**REFACTOR existing auth.cpp** to match the production-grade patterns in database.cpp, then extend the GDScript layer. The C++ auth module already exists with working methods - it needs hardening, NOT rewriting.

## Existing Implementation Analysis

### What Already Works (auth.cpp - 11KB, 265 lines):
- ✅ `sign_in_anonymously()` - Direct Firebase call
- ✅ `sign_in_facebook(String token)` - OAuth credential
- ✅ `sign_in_apple(String token, String nonce)` - OAuth with nonce
- ✅ `link_to_facebook()`, `link_to_apple()` - Provider linking
- ✅ `unlink_provider(String provider_name)` - Provider unlinking
- ✅ `providers()` - Returns Array of linked providers
- ✅ `is_logged_in()`, `uid()`, `email()`, `user_name()`, `photo_url()`
- ✅ `sign_out()` - Sign out current user
- ✅ Signals: `logged_in`, `account_linked`, `account_unlinked`

### What's Missing (must add from database.h pattern):
- ❌ Thread-safe singleton with `std::mutex` and `std::atomic`
- ❌ MessageQueue marshalling (callbacks currently emit on wrong thread!)
- ❌ Request ID tracking for concurrent operations
- ❌ Shutdown safety with `is_shutting_down` flag
- ❌ `sign_in_with_email_async()` method
- ❌ `sign_in_with_custom_token_async()` method (required by task-404)
- ❌ `AuthStateListener` for reactive auth state changes

### GDScript Layer (auth.gd already exists):
- ✅ Thin wrapper with `sign_in_facebook()`, `sign_in_apple()`
- ✅ Platform availability checks
- ✅ Sentry integration
- ⚠️ Needs extension for email auth and custom tokens

## Architecture Reference

Follow the 3-layer pattern from RTDB:
1. **C++ Module Layer** - `godot/modules/firebase/auth.h/cpp` (REFACTOR existing)
2. **GDScript Service Layer** - `project/firebase/auth_service.gd` (NEW, uses FirebaseRequest pattern)
3. **Existing Wrapper** - `project/firebase/auth.gd` (EXTEND for new methods)

## Implementation Approach: REFACTOR, NOT REWRITE

### Phase 1: Add Thread-Safe Singleton to Existing auth.h
```cpp
// ADD to existing auth.h - don't replace file
private:
    static std::mutex initialization_mutex;
    static std::atomic<bool> inited;
    static FirebaseAuth* singleton_instance;
    static std::mutex instance_mutex;
    static std::atomic<bool> is_shutting_down;

public:
    static FirebaseAuth& get_instance();
    static void cleanup();
    static void begin_shutdown();
```

### Phase 2: Add MessageQueue Marshalling to Existing Callbacks
```cpp
// MODIFY existing OnCreateUserCallback - don't create new callback
void OnCreateUserCallback(...) {
    // Extract data on worker thread
    int error = result.error();
    String uid = result.result()->user.uid().c_str();
    
    // Marshal to main thread (NEW)
    MessageQueue::get_singleton()->push_callable(
        callable_mp(this, &FirebaseAuth::_handle_sign_in_on_main_thread)
            .bind(req_id, error == 0, uid, error, String(result.error_message()))
    );
}
```

### Phase 3: Add New Methods
- `sign_in_with_email_async(int req_id, String email, String password)`
- `sign_in_with_custom_token_async(int req_id, String token)` - Required for Steam
- `create_user_with_email_async(int req_id, String email, String password)`

### Phase 4: Extend GDScript Layer
- Use existing `FirebaseRequest` pattern from `firebase_request.gd`
- Extend `firebase_service.gd` to expose auth service
- Create `auth_service.gd` following `database_service.gd` pattern

## Reference Files (MUST READ BEFORE IMPLEMENTING)
- `godot/modules/firebase/database.cpp:88-120` - Thread-safe singleton pattern
- `godot/modules/firebase/database.cpp:404-453` - MessageQueue marshalling
- `godot/modules/firebase/database.cpp:814-862` - Main thread callback handler
- `project/firebase/firebase_request.gd` - Async request pattern with ARM64 safety
- `project/firebase/auth.gd` - Existing wrapper to extend

## Critical: Do NOT Break Existing Functionality
The current auth.cpp works for Facebook and Apple sign-in. Changes must:
1. Preserve all existing method signatures
2. Add thread safety without changing behavior
3. Add new methods alongside existing ones
4. Keep existing signal names (add new ones for new methods)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 AuthService class implemented with async pattern matching DatabaseService
- [ ] #2 Sign-in methods work: email/password and anonymous
- [ ] #3 Sign-out properly clears auth state
- [ ] #4 Auth state change signals propagate correctly
- [ ] #5 Rate limiting integration through firebase_service.gd
- [ ] #6 AuthBackend implements consistent backend abstraction
- [ ] #7 5+ debug actions covering happy path and error scenarios
- [ ] #8 Test configurations for all platforms (Android, iOS, macOS, Windows)
- [ ] #9 Cross-platform testing passes on at least Android and desktop
- [ ] #10 Error handling tests validate all Firebase Auth error codes

- [ ] #11 #11 signInWithCustomToken() implemented for third-party auth providers (required by task-404)
- [ ] #12 #12 Thread-safe singleton pattern matching database.h with std::mutex and std::atomic
- [ ] #13 #13 Shutdown safety with is_shutting_down flag preventing callbacks during cleanup
- [ ] #14 #14 Request ID tracking for concurrent auth operations (std::map<int, PendingAuthRequest>)
- [ ] #15 #15 AuthStateListener properly cleaned up in destructor
- [ ] #16 #16 Use FirebaseRequest pattern (not raw signal indexing) for type-safe async handling

- [ ] #17 Add firebase-auth-tests to firebase-all.json so tests run with `just test`
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Plan (Based on quickstart-cpp Analysis)

### Key Discovery: Missing Critical Methods
Our auth.cpp is missing methods required for Steam auth and proper integration.

### Current State Analysis (auth.cpp)
**What We Have:**
- ✅ SignInAnonymously()
- ✅ SignInAndRetrieveDataWithCredential()
- ✅ Apple OAuth (OAuthProvider::GetCredential)
- ✅ Facebook (FacebookAuthProvider::GetCredential)
- ✅ LinkWithCredential(), Unlink()
- ✅ User info: uid(), email(), display_name(), photo_url()
- ✅ providers(), is_logged_in()
- ✅ SignOut()

**What's Missing (from quickstart):**
- ❌ **SignInWithCustomToken()** - CRITICAL for Steam auth (task-404 blocker!)
- ❌ **User::GetToken()** - Get ID token for backend verification
- ❌ **AuthStateListener / IdTokenListener** - State change callbacks
- ❌ Thread-safe singleton (uses simple `bool inited`)
- ❌ Shutdown safety (`is_shutting_down` flag)
- ❌ MessageQueue marshalling for callbacks

### Phase 1: Add Thread Safety (copy from database.h)

```cpp
// Replace current:
bool FirebaseAuth::inited = false;

// With:
static std::mutex initialization_mutex;
static std::atomic<bool> inited{false};
static std::atomic<bool> is_shutting_down{false};
static FirebaseAuth* singleton_instance{nullptr};
```

### Phase 2: Add Missing Methods

**SignInWithCustomToken (CRITICAL for Steam):**
```cpp
void FirebaseAuth::sign_in_with_custom_token(String token) {
    firebase::Future<firebase::auth::AuthResult> result = 
        auth->SignInWithCustomToken(token.utf8().get_data());
    result.OnCompletion([](const auto& result, void* user_data) {
        // Marshal to main thread via MessageQueue
    }, this);
}
```

**GetToken (for backend verification):**
```cpp
void FirebaseAuth::get_id_token_async(int request_id, bool force_refresh) {
    firebase::auth::User user = auth->current_user();
    if (!user.is_valid()) {
        emit_signal("token_result", request_id, "", "No user logged in");
        return;
    }
    firebase::Future<std::string> result = user.GetToken(force_refresh);
    result.OnCompletion([request_id](const auto& result, void* user_data) {
        // Marshal to main thread
    }, this);
}
```

**AuthStateListener:**
```cpp
class GameTwoAuthStateListener : public firebase::auth::AuthStateListener {
    void OnAuthStateChanged(Auth* auth) override {
        // Marshal to main thread, emit auth_state_changed signal
    }
};
```

### Phase 3: Fix Callback Safety

Replace raw `this` pointer pattern:
```cpp
// Current (unsafe):
result.OnCompletion([](const auto& result, void* user_data) {
    ((FirebaseAuth*)user_data)->OnCreateUserCallback(result, user_data);
}, this);

// Fixed (safe):
result.OnCompletion([](const auto& result, void* user_data) {
    if (is_shutting_down) return;
    auto* self = static_cast<FirebaseAuth*>(user_data);
    MessageQueue::get_singleton()->push_callable(
        callable_mp(self, &FirebaseAuth::_handle_auth_on_main_thread)
            .bind(result.error(), String(result.error_message()))
    );
}, this);
```

### Phase 4: New Signals
```cpp
ADD_SIGNAL(MethodInfo("auth_state_changed", PropertyInfo(Variant::BOOL, "signed_in")));
ADD_SIGNAL(MethodInfo("token_result", PropertyInfo(Variant::INT, "request_id"), 
                      PropertyInfo(Variant::STRING, "token"),
                      PropertyInfo(Variant::STRING, "error")));
```

### Dependency Note
task-404 (Steam Auth) REQUIRES `sign_in_with_custom_token()` from this task.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## CTO Review Notes (2025-12-31)

### Critical Corrections Required

**1. signInWithCustomToken Required**
Task-404 (Steam Auth) depends on this method for custom token authentication. Must be included in C++ layer.

**2. Signal Result Indexing is Fragile**
The implementation plan shows:
```gdscript
var result = await _cpp_auth.sign_in_completed
return {"success": result[1], "user": result[2], "error": result[3]}
```
This breaks if signal parameters change. Use the existing `FirebaseRequest` pattern from `project/firebase/firebase_request.gd` instead.

**3. AuthStateListener Cleanup Missing**
The plan adds AuthStateListener but doesn't show cleanup:
```cpp
~FirebaseAuth() {
    if (auth && auth_state_listener) {
        auth->RemoveAuthStateListener(auth_state_listener);
        delete auth_state_listener;
    }
}
```

**4. Request ID Tracking for Concurrent Operations**
Unlike database.h, auth plan doesn't handle multiple simultaneous sign-in attempts. Need:
```cpp
std::map<int, PendingAuthRequest> pending_requests;
```

### Scope Clarification
This is a **significant C++ enhancement**, not just a GDScript wrapper. Current auth.h lacks:
- Thread-safe singleton (database.h has it)
- Email/password auth
- AuthStateListener
- Request ID tracking
- MessageQueue marshalling

Estimate accordingly - this is essentially bringing auth.h up to database.h quality level.

## Revised Scope (2025-12-31)

### Key Discovery: Auth C++ Already Exists!

Exploration revealed that `auth.cpp` (11KB, 265 lines) already has:
- All social auth methods (Facebook, Apple, anonymous)
- Provider linking/unlinking
- User data accessors
- Basic async callbacks

### What's Actually Needed:

**C++ Refactoring (not rewriting):**
1. Add thread-safe singleton pattern (copy from database.h)
2. Add MessageQueue marshalling to existing callbacks
3. Add request ID parameter to existing methods
4. Add `is_shutting_down` flag for cleanup safety
5. Add `sign_in_with_email_async()` new method
6. Add `sign_in_with_custom_token_async()` new method
7. Add `AuthStateListener` class

**GDScript Extension (not replacement):**
1. Create `auth_service.gd` using `FirebaseRequest` pattern
2. Extend `firebase_service.gd` to expose auth service
3. Keep `auth.gd` for backward compatibility

### Risk Reduction:
- **Before**: Estimated as "new implementation" - HIGH risk
- **After**: Refactor existing working code - MEDIUM risk
- Existing Facebook/Apple auth MUST keep working

### Files to Modify:
- `godot/modules/firebase/auth.h` - Add singleton, new methods
- `godot/modules/firebase/auth.cpp` - Add MessageQueue, new implementations
- `project/firebase/auth.gd` - Extend with new method wrappers
- `project/firebase/firebase_service.gd` - Add auth service accessor

### Files to Create:
- `project/firebase/auth_service.gd` - New service layer
- Debug actions in `project/debug/actions/firebase_auth/`
- Test configs in `tests/debug_configs/`
<!-- SECTION:NOTES:END -->
