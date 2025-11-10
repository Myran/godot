---
id: task-265
title: Implement SentryManager.setup_firebase_context() bridge
status: Open
assignee: []
created_date: '2025-11-10 09:52'
updated_date: '2025-11-10 09:53'
labels:
  - sentry
  - firebase
  - integration
  - user-context
dependencies:
  - task-263
priority: high
---

## Description

Implement **`setup_firebase_context()`** method in SentryManager to enrich Sentry events with Firebase user and session context for better error tracking and debugging.

## Context

**Integration Point:** FirebaseService autoload
**Test Location:** `project/debug/actions/sentry/sentry_integration_bridges_action.gd:110-130`

**Current Behavior:**
- Firebase manages user authentication and session data
- Sentry events lack user/session context
- Difficult to correlate errors with specific users or sessions

**Target Behavior:**
- Sentry events automatically include Firebase user context
- User ID, authentication state, and session metadata attached to all events
- Easy correlation between errors and users/sessions

## Method Signature

```gdscript
func setup_firebase_context() -> void
```

**No parameters required** - pulls context directly from FirebaseService autoload

## Implementation Requirements

1. **Firebase Context Extraction:**
   - Query FirebaseService for current user
   - Extract user ID (Firebase UID)
   - Get authentication state (signed in/anonymous/guest)
   - Capture relevant session metadata

2. **Sentry Context Setup:**
   - Set Sentry user context with Firebase UID
   - Add authentication state as tag or extra
   - Include session metadata as context
   - Update context when user state changes

3. **Dynamic Context Updates:**
   - Listen for Firebase auth state changes
   - Update Sentry context on sign in/out
   - Handle user switching scenarios
   - Clear context on sign out

4. **Context Fields:**
   - **User ID:** Firebase UID (primary identifier)
   - **Username:** Display name or email (if available)
   - **Email:** User email (if authenticated)
   - **Auth State:** signed_in, anonymous, guest
   - **Session ID:** Firebase session identifier
   - **Custom Properties:** Any game-specific user metadata

## Test Validation

**Test Method:** `_test_firebase_context_integration()` in `sentry_integration_bridges_action.gd`

**Test Flow:**
1. Validates FirebaseService autoload exists and is valid
2. Checks SentryManager has `setup_firebase_context()` method
3. Expects return: `true` (bridge structure validated)

## Success Criteria

- [ ] Method `setup_firebase_context()` exists in SentryManager
- [ ] Method takes no parameters
- [ ] Pulls user context from FirebaseService autoload
- [ ] Sets Sentry user context with Firebase UID
- [ ] Includes authentication state as tag/extra
- [ ] Updates context dynamically on auth changes
- [ ] Test `_test_firebase_context_integration()` returns true
- [ ] Integration test shows 2/3 bridges working (with task-264)
- [ ] Works on both desktop and Android platforms

## Technical Considerations

**FirebaseService Integration:**
- Access via `FirebaseService` autoload singleton
- Query current user: `FirebaseService.get_current_user()`
- Listen for auth changes: Connect to auth signals
- Handle null/missing user gracefully

**Sentry SDK User Context:**
- Use Sentry SDK's set_user() method
- Set user ID: `sentry_sdk.set_user({"id": firebase_uid})`
- Add email: `sentry_sdk.set_user({"id": uid, "email": email})`
- Add username: `sentry_sdk.set_user({"username": display_name})`
- Add custom properties via set_context() or set_extra()

**Auth State Changes:**
- Connect to FirebaseService auth signals
- Update Sentry context on user_signed_in signal
- Clear context on user_signed_out signal
- Handle user switching edge cases

**Privacy Considerations:**
- Don't expose sensitive user data unnecessarily
- Consider GDPR/privacy requirements
- Allow opt-out if required by privacy policy

## Example Implementation (Pseudocode)

```gdscript
func setup_firebase_context() -> void:
    if not FirebaseService or not sentry_sdk:
        return  # Gracefully fail if either unavailable

    # Connect to auth change signals
    if not FirebaseService.user_signed_in.is_connected(_on_firebase_user_signed_in):
        FirebaseService.user_signed_in.connect(_on_firebase_user_signed_in)
    if not FirebaseService.user_signed_out.is_connected(_on_firebase_user_signed_out):
        FirebaseService.user_signed_out.connect(_on_firebase_user_signed_out)

    # Set initial context
    _update_sentry_user_context()


func _update_sentry_user_context() -> void:
    var current_user = FirebaseService.get_current_user()
    if current_user:
        var user_data = {
            "id": current_user.uid,
            "email": current_user.email if current_user.email else null,
            "username": current_user.display_name if current_user.display_name else null
        }
        sentry_sdk.set_user(user_data)

        # Add auth state as tag
        sentry_sdk.set_tag("auth_state", "signed_in")
    else:
        # Clear or set anonymous context
        sentry_sdk.set_user({"id": "anonymous"})
        sentry_sdk.set_tag("auth_state", "guest")


func _on_firebase_user_signed_in(_user) -> void:
    _update_sentry_user_context()


func _on_firebase_user_signed_out() -> void:
    # Clear user context on sign out
    sentry_sdk.set_user(null)
    sentry_sdk.set_tag("auth_state", "signed_out")
```

## Related Tasks

- **Parent:** task-263 - Implement SentryManager Engine singleton
- **Related:** task-264 - Advanced Logger error bridge
- **Related:** task-266 - Debug Coordinator compatibility

## Related Files

**Test:** `project/debug/actions/sentry/sentry_integration_bridges_action.gd:110-130`
**Firebase Service:** `autoloads/firebase/`
**Sentry SDK:** `addons/sentry/`
