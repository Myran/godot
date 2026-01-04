---
id: task-416
title: Fix AuthService email_sign_in_completed property access bug
status: To Do
assignee: []
created_date: '2026-01-04 21:38'
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

**Location**: `project/data/backends/auth_service.gd`

## Acceptance Criteria
1. Identify where `email_sign_in_completed` is being accessed
2. Verify the correct property name in FirebaseAuth C++ class
3. Fix the property access
4. Run `backend.firebase.auth.sign_in_anonymous` test to verify fix
5. Test on Android platform

## Related
- Discovered by: task-399 backend auth service layer tests
- Test config: `backend.firebase.auth.sign_in_anonymous`
<!-- SECTION:DESCRIPTION:END -->
