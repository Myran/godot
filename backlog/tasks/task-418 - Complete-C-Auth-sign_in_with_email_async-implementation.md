---
id: task-418
title: Complete C++ Auth sign_in_with_email_async implementation
status: Done
assignee: []
created_date: '2026-01-04 21:38'
updated_date: '2026-01-05 08:21'
labels:
  - firebase
  - auth
  - cpp
  - android
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Task Description

Implement the missing `sign_in_with_email_async` method in the C++ FirebaseAuth class.

**From task-399 acceptance criteria**:
- C++ layer: `sign_in_with_email_async` for Firebase email/password authentication

## Acceptance Criteria
1. Implement `sign_in_with_email_async` in `godot/modules/firebase/firebase_auth.cpp`
2. Add GDScript bindings for the method
3. Add C++ layer test: `cpp.firebase.auth.sign_in_with_email_async`
4. Verify signal emissions and error handling
5. Test on Android platform

## Technical Notes
- Reference existing `sign_in_anonymous_async` implementation
- Ensure proper CharString to String conversion for UTF-8
- Emit appropriate signals for success/error cases

## Related
- Parent task: task-399 (Firebase Auth service layer)
- Service layer test: `backend.firebase.auth.sign_in_with_email`
<!-- SECTION:DESCRIPTION:END -->
