---
id: task-417
title: Fix AuthService _on_sign_in_completed signal arity mismatch
status: To Do
assignee: []
created_date: '2026-01-04 21:38'
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

**Location**: `project/data/backends/auth_service.gd`

## Acceptance Criteria
1. Check the actual signal signature in FirebaseAuth C++ class
2. Update `_on_sign_in_completed` method signature to match signal arity
3. Verify all signal handlers have correct signatures
4. Run `backend.firebase.auth.sign_in_anonymous` test to verify fix
5. Test on Android platform

## Related
- Discovered by: task-399 backend auth service layer tests
- Test config: `backend.firebase.auth.sign_in_anonymous`
<!-- SECTION:DESCRIPTION:END -->
