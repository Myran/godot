---
id: task-429
title: 'Fix Firebase macOS crash: Mutex::Acquire() during RTDB operations'
status: Done
assignee: []
created_date: '2026-01-07 17:42'
updated_date: '2026-01-12 10:50'
labels:
  - cpp
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Firebase C++ SDK crashes on macOS in Mutex::Acquire() during RTDB operations. The crash occurs in firebase::scheduler::Scheduler::Schedule when processing database queries via FirebaseDatabase::get_value_async(). This is a Firebase threading issue on macOS, NOT related to Sentry context capture as initially suspected.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Sentry safely handles early init phase before RenderingServer exists,macOS automated tests pass without Sentry crash,Performance context capture defers until RenderingServer available
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
ROOT CAUSE FOUND (2026-01-12):

The crash was NOT caused by Mutex::Acquire() in Firebase SDK RTDB operations.

Real root cause: The Firestore commit (a3ee581d) added a fixed app name parameter 
to firebase::App::Create() calls in firebase_platform.mm:

BEFORE (working):
  app_ptr = firebase::App::Create();

AFTER (crashing):
  app_ptr = firebase::App::Create(firebase::AppOptions(), "__FIRAPP_DEFAULT");

The App::Create(AppOptions, app_name) overload expects different initialization 
conditions that weren't met during early Firebase initialization on macOS, causing 
a null pointer dereference at offset 0x38 (56 bytes into an object).

FIX APPLIED:
- Reverted to firebase::App::Create() without app name parameter
- macOS tests now pass: 8/8 actions (100% success rate)
- Firebase backend tests: PASSED
- System error handling tests: PASSED

The Firestore module itself was NOT the direct cause. The app_name parameter was 
intended to fix keychain prompt issues on iOS but broke macOS initialization.

Commit: godot submodule 9c0b6ae0ef
<!-- SECTION:NOTES:END -->
