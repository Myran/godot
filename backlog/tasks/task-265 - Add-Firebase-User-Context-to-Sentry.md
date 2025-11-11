---
id: task-265
title: Add Firebase User Context to Sentry
status: Done
assignee: []
created_date: '2025-11-10 09:52'
updated_date: '2025-11-11 20:57'
labels:
  - sentry
  - firebase
  - integration
  - user-context
dependencies: []
priority: medium
---

## Description

Enrich Sentry events with Firebase user and session context by adding **direct SentrySDK calls** to FirebaseService authentication flow. No intermediate bridge layer needed.

## Context

**Expert Panel Decision (2025-11-10):**
- Simplified from SentryManager bridge to direct integration
- FirebaseService owns user context, so it should directly set Sentry user context
- Reduces implementation time from 8-12h to 1-2h (83% reduction)

**Current Behavior:**
- Firebase manages user authentication and session data
- Sentry events lack user/session context
- Difficult to correlate errors with specific users or sessions

**Target Behavior:**
- Sentry events automatically include Firebase user context
- User ID, authentication state, and session metadata attached to all events
- Easy correlation between errors and users/sessions

## Required Implementation

### **Add Direct SentrySDK Calls to FirebaseService**

Modify `firebase/firebase_service.gd` to set Sentry user context on authentication changes:

```gdscript
# In firebase/firebase_service.gd

func _on_user_authenticated(user_data: Dictionary) -> void:
	# Existing Firebase logic
	_current_user = user_data
	_emit_auth_signals(user_data)

	# Direct Sentry user context - no bridge needed
	_update_sentry_user_context(user_data)


func _on_user_signed_out() -> void:
	# Existing Firebase logic
	_current_user = null
	_emit_signout_signals()

	# Clear Sentry user context
	_clear_sentry_user_context()


func _update_sentry_user_context(user_data: Dictionary) -> void:
	# Only update if Sentry is available
	if not Engine.has_singleton("SentrySDK"):
		return

	var sentry: Variant = Engine.get_singleton("SentrySDK")
	if not sentry or not sentry.has_method("set_user"):
		return

	# Set user context with Firebase data
	var sentry_user: Dictionary = {
		"id": user_data.get("uid", ""),
		"email": user_data.get("email", ""),
		"username": user_data.get("display_name", "")
	}

	sentry.set_user(sentry_user)

	# Add authentication state as tag
	if sentry.has_method("set_tag"):
		var auth_state: String = "signed_in" if user_data.get("is_anonymous", false) == false else "anonymous"
		sentry.set_tag("auth_state", auth_state)
		sentry.set_tag("firebase_provider", user_data.get("provider_id", "unknown"))


func _clear_sentry_user_context() -> void:
	if not Engine.has_singleton("SentrySDK"):
		return

	var sentry: Variant = Engine.get_singleton("SentrySDK")
	if not sentry or not sentry.has_method("set_user"):
		return

	# Clear user context on sign out
	sentry.set_user({})

	# Update auth state tag
	if sentry.has_method("set_tag"):
		sentry.set_tag("auth_state", "signed_out")
```

## Success Criteria

- [ ] User context set on Firebase authentication success
- [ ] Sentry receives Firebase UID as user ID
- [ ] Email and username included when available
- [ ] Authentication state tracked as Sentry tag
- [ ] User context cleared on Firebase sign out
- [ ] Graceful handling if SentrySDK not available
- [ ] No Firebase authentication flow disruption
- [ ] Works on both desktop and Android platforms

## Technical Considerations

**Integration Point:**
- Modify existing auth callback methods in FirebaseService
- Natural integration point where user data is already available
- No cross-system coupling required

**Sentry SDK API:**
- `SentrySDK.set_user(user_dict)` - Set user context
- `SentrySDK.set_tag(key, value)` - Set authentication tags
- User dict fields: `id`, `email`, `username`

**Error Handling:**
- Sentry context update failures must not break authentication
- Use `has_method()` checks before calling SDK methods
- Silent failure if Sentry unavailable

**Privacy Considerations:**
- Only include user data that's necessary for debugging
- Consider GDPR/privacy requirements
- User ID is anonymized Firebase UID (not PII)
- Email only included if user provided during auth

## Context Fields

**User Context:**
- **id**: Firebase UID (primary identifier)
- **email**: User email (if authenticated, not anonymous)
- **username**: Display name (if available)

**Tags:**
- **auth_state**: `signed_in`, `anonymous`, `signed_out`
- **firebase_provider**: `password`, `google.com`, `apple.com`, etc.

## Estimated Effort

**1-2 hours** (vs 8-12 hours for SentryManager bridge approach)

- Implementation: 0.5-1 hour
- Testing: 0.5 hour
- Documentation: 0.25 hour

## Related Work

**Modified Files:**
- `project/firebase/firebase_service.gd` - Add Sentry context updates

**Test Files:**
- `project/debug/actions/sentry/sentry_integration_bridges_action.gd` - Update to validate direct integration

**Reference:**
- task-263 - Direct SentrySDK Integration in Advanced Logger (same pattern)

## Expert Panel Recommendation

**Benefits of Direct Integration:**
- ✅ FirebaseService owns user context naturally
- ✅ No cross-system coupling via SentryManager
- ✅ Zero additional runtime overhead
- ✅ Consistent with GameTwo's direct-access pattern
- ✅ Simpler to maintain and test

**Previous Approach Rejected:**
- ❌ SentryManager bridge added unnecessary layer
- ❌ Required SentryManager to know about Firebase
- ❌ Required Firebase to know about SentryManager
- ❌ Additional GDExtension compilation and maintenance

See `/tmp/task-263-expert-panel-evaluation.md` for complete analysis.

## Dependencies

**Independent task** - no dependencies on SentryManager (task-263/264 obsolete)

Can be implemented in parallel with:
- task-263: Direct Advanced Logger integration
- task-266: Sentry debug actions
