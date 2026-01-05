---
id: task-421
title: Add Facebook and Apple OAuth regression tests
status: Done
assignee: []
created_date: '2026-01-04 21:38'
updated_date: '2026-01-05 09:04'
labels:
  - firebase
  - auth
  - oauth
  - facebook
  - apple
  - testing
dependencies: []
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Task Description

Add regression tests for Facebook and Apple OAuth authentication flows.

**From task-399 acceptance criteria**:
- Regression tests for Facebook/Apple sign-in

## Acceptance Criteria
1. Add C++ layer test: `cpp.firebase.auth.sign_in_with_facebook`
2. Add C++ layer test: `cpp.firebase.auth.sign_in_with_apple`
3. Add service layer test: `backend.firebase.auth.facebook_sign_in`
4. Add service layer test: `backend.firebase.auth.apple_sign_in`
5. Verify token handling and error cases
6. Add tests to `firebase-all.json` test list
7. Test on physical devices (required for OAuth)

## Technical Notes
- OAuth flows require physical device testing (won't work in emulator)
- May need to handle platform-specific OAuth flows
- Verify credential token passing to Firebase

## Related
- Parent task: task-399 (Firebase Auth service layer)
- Platform-specific: iOS/Android OAuth implementations differ
<!-- SECTION:DESCRIPTION:END -->
