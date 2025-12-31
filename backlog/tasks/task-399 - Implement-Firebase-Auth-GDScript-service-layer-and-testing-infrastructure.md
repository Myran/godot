---
id: task-399
title: Implement Firebase Auth GDScript service layer and testing infrastructure
status: To Do
assignee: []
created_date: '2025-12-30 21:26'
updated_date: '2025-12-30 22:42'
labels:
  - firebase
  - auth
  - gdscript
  - testing
dependencies:
  - task-403
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Overview

Implement complete Firebase Authentication integration following the established RTDB architecture patterns. The C++ auth.h/cpp already exists but needs full GDScript service layer, backend abstraction, and comprehensive testing.

## Architecture Reference

Follow the 3-layer pattern from RTDB:
1. **C++ Module Layer** - `godot/modules/firebase/auth.h/cpp` (exists, may need enhancements)
2. **GDScript Service Layer** - `project/firebase/auth_service.gd` (NEW)
3. **Backend Abstraction** - `project/data/backends/auth_backend.gd` (NEW)

## Implementation Scope

### GDScript Service Layer (`project/firebase/auth_service.gd`)
- AuthService class wrapping C++ FirebaseAuth
- Async pattern with FirebaseRequest-style completion tracking
- Rate limiting integration through firebase_service.gd
- Methods: `sign_in_with_email()`, `sign_in_anonymous()`, `sign_out()`, `get_current_user()`
- Signals: `auth_state_changed`, `sign_in_completed`, `sign_out_completed`

### Backend Abstraction (`project/data/backends/auth_backend.gd`)
- AuthBackend class for unified auth access
- Integration with existing backend factory pattern
- Session management support

### Debug Actions (`project/debug/actions/firebase_auth/`)
- `auth_sign_in_email_test_action.gd` - Email/password sign-in
- `auth_sign_in_anonymous_test_action.gd` - Anonymous auth
- `auth_sign_out_test_action.gd` - Sign-out flow
- `auth_error_handling_test_action.gd` - Error scenarios
- `auth_state_change_test_action.gd` - Auth state transitions

### Test Configurations (`tests/debug_configs/`)
- `firebase-auth-layer.json` - All auth tests
- `firebase-auth-sign-in.json` - Sign-in specific
- `firebase-auth-error-handling.json` - Error scenarios

## Reference Files
- `godot/modules/firebase/database.cpp` - C++ async pattern
- `project/firebase/database_service.gd` - GDScript service pattern
- `project/data/backends/firebase_service_backend.gd` - Backend pattern
- `project/debug/actions/firebase_backend/` - Debug action pattern
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
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Plan - Firebase Auth

### Phase 1: C++ Layer Enhancement (auth.h/cpp)

**Current State Analysis:**
- Basic auth exists with: sign_in_anonymously, sign_in_facebook, sign_in_apple, link_to_*, providers, sign_out
- **Missing**: Thread-safe singleton, email/password auth, AuthStateListener, request IDs, MessageQueue marshalling

**1.1 Add Thread-Safe Singleton Pattern (Follow database.h)**
```cpp
// auth.h additions
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
    static bool is_app_shutting_down();
```

**1.2 Add Email/Password Authentication**
```cpp
// Firebase SDK pattern from documentation
void sign_in_with_email_async(int p_request_id, String email, String password);
void create_user_with_email_async(int p_request_id, String email, String password);

// Implementation pattern:
firebase::Future<firebase::auth::AuthResult> result = 
    auth->SignInWithEmailAndPassword(email.utf8().get_data(), password.utf8().get_data());
result.OnCompletion([this, p_request_id](const firebase::Future<firebase::auth::AuthResult>& result) {
    // Worker thread - extract data
    // Marshal to main thread via MessageQueue
});
```

**1.3 Add AuthStateListener (Firebase SDK pattern)**
```cpp
class AuthStateListenerImpl : public firebase::auth::AuthStateListener {
    FirebaseAuth* singleton;
public:
    void OnAuthStateChanged(firebase::auth::Auth* auth) override {
        firebase::auth::User user = auth->current_user();
        if (user.is_valid()) {
            // Marshal user data to main thread
        } else {
            // User signed out
        }
    }
};
```

**1.4 Add Main Thread Callback Handlers**
```cpp
void _handle_sign_in_on_main_thread(int req_id, bool success, String uid, String email, String display_name, int error, String error_msg);
void _handle_create_user_on_main_thread(int req_id, bool success, String uid, int error, String error_msg);
```

**1.5 Update Signal Bindings**
```cpp
ADD_SIGNAL(MethodInfo("sign_in_completed", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::BOOL, "success"), PropertyInfo(Variant::DICTIONARY, "user_data"), PropertyInfo(Variant::STRING, "error_message")));
ADD_SIGNAL(MethodInfo("sign_out_completed", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::BOOL, "success")));
ADD_SIGNAL(MethodInfo("auth_state_changed", PropertyInfo(Variant::BOOL, "signed_in"), PropertyInfo(Variant::DICTIONARY, "user_data")));
ADD_SIGNAL(MethodInfo("create_user_completed", PropertyInfo(Variant::INT, "request_id"), PropertyInfo(Variant::BOOL, "success"), PropertyInfo(Variant::STRING, "uid"), PropertyInfo(Variant::STRING, "error_message")));
```

### Phase 2: GDScript Service Layer

**2.1 Create auth_service.gd**
```gdscript
class_name AuthService
extends RefCounted

signal sign_in_completed(success: bool, user_data: Dictionary, error: String)
signal sign_out_completed(success: bool)
signal auth_state_changed(signed_in: bool, user_data: Dictionary)

var _firebase_service: Node
var _cpp_auth: Object
var _request_id_counter: int = 0

func _init(firebase_service: Node) -> void:
    _firebase_service = firebase_service
    _initialize_cpp_auth()

func sign_in_with_email(email: String, password: String) -> Dictionary:
    var request_id = _get_next_request_id()
    _cpp_auth.sign_in_with_email_async(request_id, email, password)
    var result = await _cpp_auth.sign_in_completed
    return {"success": result[1], "user": result[2], "error": result[3]}

func sign_in_anonymous() -> Dictionary:
    var request_id = _get_next_request_id()
    _cpp_auth.sign_in_anonymously_async(request_id)
    var result = await _cpp_auth.sign_in_completed
    return {"success": result[1], "user": result[2], "error": result[3]}

func sign_out() -> bool:
    _cpp_auth.sign_out()
    return true

func get_current_user() -> Dictionary:
    if not _cpp_auth.is_logged_in():
        return {}
    return {
        "uid": _cpp_auth.uid(),
        "email": _cpp_auth.email(),
        "display_name": _cpp_auth.user_name(),
        "photo_url": _cpp_auth.photo_url()
    }
```

### Phase 3: Debug Actions

**3.1 Create project/debug/actions/firebase_auth/**
- `auth_sign_in_email_test_action.gd` - Test email/password flow
- `auth_sign_in_anonymous_test_action.gd` - Test anonymous auth
- `auth_sign_out_test_action.gd` - Test sign-out flow
- `auth_error_handling_test_action.gd` - Test invalid credentials, network errors
- `auth_state_change_test_action.gd` - Test AuthStateListener

### Phase 4: Test Configurations

**4.1 Create tests/debug_configs/**
- `firebase-auth-layer.json` - All auth tests
- `firebase-auth-sign-in.json` - Sign-in specific tests
- `firebase-auth-error-handling.json` - Error scenarios

### Key Reference Files
- `godot/modules/firebase/database.cpp:216-253` - Thread-safe singleton pattern
- `godot/modules/firebase/database.cpp:404-453` - Async with MessageQueue marshalling
- `godot/modules/firebase/database.cpp:814-862` - Main thread callback handler
<!-- SECTION:PLAN:END -->
