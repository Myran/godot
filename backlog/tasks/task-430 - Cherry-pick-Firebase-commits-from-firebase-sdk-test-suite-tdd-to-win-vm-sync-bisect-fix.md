---
id: task-430
title: >-
  Cherry-pick Firebase commits from firebase-sdk-test-suite-tdd to
  win-vm-sync-bisect-fix
status: Done
assignee: []
created_date: '2026-01-12 00:28'
updated_date: '2026-01-12 10:50'
labels:
  - firebase
  - cherry-pick
  - macos
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Cherry-pick Firebase-related commits from firebase-sdk-test-suite-tdd branch that are missing from win-vm-sync-bisect-fix. Testing on macOS after each commit.

Commits to apply in order:
1. a985f9a3 - fix: correct is_anonymous() detection for Firebase anonymous users (GDScript only)
2. 4a85bf60 - feat: Implement Firebase RTDB retry logic with exponential backoff (task-424) (GDScript)
3. 8df12d89 - fix: correct firebase-auth-tests config action order (Config)
4. 7fcc0100 - fix: update firebase-auth-tests config to use working tests (Config)

Skip for now (C++ module changes requiring full rebuild):
- 34594394 - Cloud Firestore module
- 3960443c - Firestore validation and Analytics enhancement
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
ROOT CAUSE FOUND (2026-01-12):

The crash was NOT caused by the Firestore module itself but by a change in
firebase_platform.mm that was part of the Firestore commit.

Real root cause: The Firestore commit (a3ee581d) added:
  firebase::App::Create(firebase::AppOptions(), "__FIRAPP_DEFAULT")

This App::Create() overload with app_name parameter caused macOS to crash
with Abort trap: 6 at startup due to null pointer dereference at offset 0x38.

CHERRY-PICK STRATEGY UPDATED:
- Reverted the __FIRAPP_DEFAULT parameter in firebase_platform.mm
- All other Firebase commits from firebase-sdk-test-suite-tdd successfully
  cherry-picked

VERIFICATION:
- macOS tests: 8/8 actions PASSED (100%)
- Firebase backend tests: PASSED
- System error handling tests: PASSED

Commit: godot submodule 9c0b6ae0ef

FIRESTORE MODULE RE-ENABLED (2026-01-12):

The Firestore module has been successfully re-enabled after confirming that
the root cause was in firebase_platform.mm, not the Firestore C++ code.

Re-enabled:
- firestore.cpp compilation (SCsub line 13)
- FirebaseFirestore class registration (register_types.cpp)
- Firestore library linking for macOS arm64 + x86_64 (SCsub)
- SystemConfiguration framework linking for macOS (SCsub)

Commits:
- godot submodule: 92a9bc0a - fix: re-enable Firestore module
- main repo: d4935e76 - fix: update godot submodule to re-enable Firestore

All Firebase features from firebase-sdk-test-suite-tdd are now successfully
cherry-picked and working on macOS.
<!-- SECTION:NOTES:END -->
