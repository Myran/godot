# doc-005: Firebase SDK Test Strategy

**Document ID**: doc-005
**Title**: Firebase SDK Test Strategy for TDD Development
**Status**: Active
**Related Task**: task-406
**Created**: 2025-12-31

---

## Overview

This document defines the testing strategy for Firebase SDK integration in GameTwo using Test-Driven Development (TDD). All Firebase public API methods are tested before implementation, ensuring behavior is validated rather than implementation details.

---

## TDD Workflow

### Red Phase (Current)
- Write failing tests that describe desired behavior
- Tests fail with "not yet implemented" messages
- Tests skip gracefully on unsupported platforms

### Green Phase (Next)
- Implement Firebase SDK methods to pass tests
- Run tests continuously during development
- Tests pass when implementation is correct

### Refactor Phase
- Improve code without changing behavior
- Tests continue to pass
- Code quality improves while behavior stays stable

---

## Test Organization

### Directory Structure
```
project/debug/actions/firebase_tests/
├── firebase_test_action_base.gd    # Base class with assertions
├── analytics/                       # Analytics tests (6)
│   ├── test_log_event_basic.gd
│   ├── test_log_event_params.gd
│   ├── test_set_user_id.gd
│   ├── test_set_user_property.gd
│   ├── test_collection_enabled.gd
│   └── test_reset_data.gd
├── auth/                            # Auth tests (8)
│   ├── test_sign_in_anonymous.gd
│   ├── test_sign_in_custom_token.gd
│   ├── test_sign_in_email.gd
│   ├── test_get_id_token.gd
│   ├── test_sign_out.gd
│   ├── test_get_uid.gd
│   ├── test_is_logged_in.gd
│   └── test_state_changed.gd
├── remote_config/                   # Remote Config tests (8)
│   ├── test_get_boolean.gd
│   ├── test_get_string.gd
│   ├── test_get_int.gd
│   ├── test_fetch_and_activate.gd
│   ├── test_fetch_async.gd
│   ├── test_activate_async.gd
│   ├── test_get_keys.gd
│   └── test_set_defaults.gd
├── firestore/                       # Firestore tests (5)
│   ├── test_document_get.gd
│   ├── test_document_set.gd
│   ├── test_document_update.gd
│   ├── test_document_delete.gd
│   └── test_query.gd
└── steam/                           # Steam tests (4, desktop only)
    ├── test_init.gd
    ├── test_get_ticket.gd
    ├── test_sign_in_flow.gd
    └── test_no_client_error.gd
```

---

## Test Configuration Files

### Debug Configs (in `tests/debug_configs/`)
- `firebase-feature-tests.json` - Master config (all 31 tests)
- `firebase-analytics-tests.json` - Analytics tests (6)
- `firebase-auth-tests.json` - Auth tests (8)
- `firebase-remote-config-tests.json` - Remote Config tests (8)
- `firebase-firestore-tests.json` - Firestore tests (5)
- `firebase-steam-tests.json` - Steam tests (4, desktop only)

### Test Lists (in `tests/test-lists/`)
- `firebase-sdk-tests.json` - Orchestration list for all Firebase tests

---

## Running Tests

### Individual Service Tests
```bash
# Analytics
just test-android-target firebase-analytics-tests
just test-desktop-target firebase-analytics-tests

# Auth
just test-android-target firebase-auth-tests
just test-desktop-target firebase-auth-tests

# Remote Config
just test-android-target firebase-remote-config-tests
just test-desktop-target firebase-remote-config-tests

# Firestore
just test-android-target firebase-firestore-tests
just test-desktop-target firebase-firestore-tests

# Steam (desktop only)
just test-desktop-target firebase-steam-tests
```

### Complete Test Suite
```bash
# All Firebase tests via test list
just test-android-target firebase-sdk-tests
just test-desktop-target firebase-sdk-tests

# All tests via master config
just test-android-target firebase-feature-tests
just test-desktop-target firebase-feature-tests
```

---

## Test Implementation Patterns

### Base Class (FirebaseTestActionBase)

Provides assertion methods and platform gating:

```gdscript
class_name FirebaseTestActionBase
extends DebugAction

# Assertions
assert_true(condition, msg)
assert_false(condition, msg)
assert_equals(expected, actual, msg)
assert_not_null(value, msg)
assert_null(value, msg)
assert_fail(msg)  # Explicitly fail test

# Platform gating
should_run_on_platform(PLATFORM_DESKTOP | PLATFORM_MOBILE | PLATFORM_WEB)

# Test lifecycle
_run_test()  # Override in subclasses
```

### Test Pattern Example

```gdscript
## Test Firestore document_get method
extends FirebaseTestActionBase

func _init() -> void:
    super._init()
    action_name = "test.firestore.document_get"
    group = "CRUD Operations"

func _run_test() -> void:
    var firestore: FirebaseFirestore = FirebaseFirestore.get_instance() if ClassDB.class_exists("FirebaseFirestore") else null

    if firestore == null:
        _skip("FirebaseFirestore class not implemented yet")
        return

    # Get document from collection
    # For TDD red phase: this will fail because class doesn't exist yet
    assert_true(false, "document_get not yet implemented")
```

---

## Platform-Specific Behavior

### Platform Gating
Tests use `should_run_on_platform()` to skip gracefully:

```gdscript
# Desktop-only tests (Steam)
if not should_run_on_platform(PLATFORM_DESKTOP):
    _skip("Steam test is desktop-only")
    return

# Mobile-specific tests
if not should_run_on_platform(PLATFORM_MOBILE):
    _skip("This test is mobile-only")
    return
```

### Supported Platforms
- **Android** - All tests except Steam
- **iOS** - All tests except Steam
- **macOS** - All tests including Steam
- **Desktop** - All tests including Steam
- **Windows** - All tests including Steam

---

## Test Result Interpretation

### Test States
- **PENDING** - Test not yet run
- **PASSED** - Test assertions succeeded
- **FAILED** - Test assertions failed
- **SKIPPED** - Test skipped (platform gating or class not implemented)

### Expected Behavior (Red Phase)
All tests currently fail with "not yet implemented" messages. This is **expected and correct** for TDD red phase.

### Success Criteria (Green Phase)
Tests pass when:
1. Firebase SDK classes are implemented
2. Public API methods work correctly
3. Error handling is proper
4. Platform-specific code is gated correctly

---

## Integration with Firebase C Module

### C Module Structure
```
godot/modules/firebase/
├── firebase.cpp          # Initialization
├── firebase_auth.cpp     # Auth C API (to be implemented)
├── firebase_analytics.cpp     # Analytics C API (to be implemented)
├── firebase_remote_config.cpp # Remote Config C API (to be implemented)
├── firebase_firestore.cpp     # Firestore C API (to be implemented)
└── godot/cpp/library/    # Generated GDScript bindings
```

### Thread-Safe Singleton Pattern
Follow `database.h` pattern:
```cpp
// Thread-safe singleton
static FirebaseFirestore* get_instance();
static void set_instance(FirebaseFirestore* instance);

// Initialize on app startup
FirebaseFirestore* FirebaseFirestore::get_instance() {
    if (!instance) {
        instance = new FirebaseFirestore();
    }
    return instance;
}
```

---

## Async Operation Testing

### Signal-Based Testing
```gdscript
func _run_test() -> void:
    var firestore: FirebaseFirestore = FirebaseFirestore.get_instance()
    var completed: bool = false

    firestore.document_get("collection", "doc_id").then(
        func(result):
            completed = true
            assert_true(result.success, "Document fetch succeeded")
            assert_not_null(result.data, "Document data exists")
    )

    # Wait for async completion
    await wait_for_timeout(5.0)
    assert_true(completed, "Async operation completed")
```

### Error Testing
```gdscript
func _run_test() -> void:
    var firestore: FirebaseFirestore = FirebaseFirestore.get_instance()

    # Test error handling for non-existent document
    firestore.document_get("collection", "nonexistent").then(
        func(result):
            assert_false(result.success, "Expected failure for non-existent doc")
            assert_not_null(result.error, "Error message present")
    )
```

---

## Fire-and-Forget Pattern (Analytics)

Analytics operations don't require awaiting:

```gdscript
func _run_test() -> void:
    var analytics: FirebaseAnalytics = FirebaseAnalytics.get_instance()

    # Fire-and-forget - no callback
    analytics.log_event("game_start", {"level": 1})

    # Test passes if no crash occurs
    assert_true(true, "log_event completed without error")
```

---

## Steam Integration Testing

### Desktop-Only Tests
Steam tests run on desktop platforms only:

```gdscript
func _run_test() -> void:
    if not should_run_on_platform(PLATFORM_DESKTOP):
        _skip("Steam test is desktop-only")
        return

    var steam: FirebaseSteam = FirebaseSteam.get_instance()
    if steam == null:
        _skip("Steam integration not available")
        return

    # Test Steam initialization
    var result: Dictionary = steam.init()
    assert_true(result.success, "Steam initialized successfully")
```

### Auth Ticket Flow
Steam → Firebase custom token → sign_in:

```gdscript
func _run_test() -> void:
    var steam: FirebaseSteam = FirebaseSteam.get_instance()
    var auth: FirebaseAuth = FirebaseAuth.get_instance()

    # Get Steam auth ticket
    var ticket_result: Dictionary = steam.get_auth_ticket()
    assert_true(ticket_result.success, "Got Steam ticket")

    # Exchange for Firebase custom token
    var custom_token: String = await auth.get_custom_token_for_steam(ticket_result.ticket)
    assert_not_null(custom_token, "Got Firebase custom token")

    # Sign in with custom token
    var sign_in_result: Dictionary = await auth.sign_in_with_custom_token(custom_token)
    assert_true(sign_in_result.success, "Signed in with Steam token")
```

---

## Test Data Management

### Test Collections
- Use test-specific collection names: `test_firebase_sdk`
- Use test-specific document IDs: `test_doc_{random}`

### Cleanup
Tests should clean up after themselves:

```gdscript
func _cleanup() -> void:
    var test_doc_id: String = _test_data.get("doc_id", "")
    if test_doc_id != "":
        await firestore.document_delete("test_firebase_sdk", test_doc_id)
```

---

## Continuous Integration

### Pre-Commit Testing
```bash
# Run all Firebase tests before commit
just test-desktop-target firebase-sdk-tests
just fastbuild-android
just test-android-target firebase-sdk-tests
```

### CI Pipeline
```bash
# CI runs Firebase tests on all platforms
just ci-validate
just test-android firebase-sdk-tests
just test-desktop firebase-sdk-tests
```

---

## Success Metrics

### Code Coverage
- Target: 100% of public API methods
- Current: 31/31 tests written (100%)

### Test Status
- Red Phase: All tests fail with "not yet implemented"
- Green Phase: Tests pass as implementations are completed
- Regression: Tests catch breaking changes

---

## Related Documentation

- `task-406` - Firebase SDK Test Suite implementation task
- `task-403` - Firebase Services Integration Epic
- `godot/modules/firebase/CLAUDE.md` - Firebase C module implementation guide
- `project/CLAUDE.md` - GDScript patterns and Firebase integration

---

*Last Updated: 2025-12-31*
