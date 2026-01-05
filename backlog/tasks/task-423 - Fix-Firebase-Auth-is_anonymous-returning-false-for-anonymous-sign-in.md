---
id: task-423
title: Fix Firebase Auth is_anonymous() returning false for anonymous sign-in
status: Done
assignee: []
created_date: '2026-01-05 17:40'
updated_date: '2026-01-05 17:47'
labels:
  - firebase
  - auth
  - cpp
  - bug
  - android
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
After anonymous sign-in, AuthService.is_anonymous() returns false instead of true.

Test: backend.firebase.auth.anonymous_check
Error: "is_anonymous() returned false for anonymous sign in"
Test ID: backend.firebase.auth.anonymous_check_android_1767633477

Platform: Android (likely affects all platforms)
Component: Firebase Auth C++ SDK / GDScript wrapper
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## OODA Root Cause Analysis

**OBSERVE**: Test error `is_anonymous() returned false for anonymous sign in`
Logs showed `providers: [{name: "firebase"}]` after anonymous sign-in.

**ORIENT**: Firebase C++ SDK returns `provider_id = "firebase"` for anonymous users.
GDScript code incorrectly expected empty provider names.

**DECIDE**: Root cause - incorrect assumption that anonymous users have empty provider names.
Reality: Firebase uses "firebase" as provider_id for anonymous users.

**ACT** (Fix):
1. auth_service.gd - Updated is_anonymous() to check for "firebase" provider
2. backend_auth_anonymous_check_action.gd - Updated test validation

**Result**: Test PASSED ✅

**Commit**: a985f9a3
<!-- SECTION:NOTES:END -->
