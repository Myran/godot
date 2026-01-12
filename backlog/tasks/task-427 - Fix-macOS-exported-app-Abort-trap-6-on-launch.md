---
id: task-427
title: 'Fix macOS exported app Abort trap: 6 on launch'
status: Done
assignee: []
created_date: '2026-01-07 16:41'
updated_date: '2026-01-07 17:41'
labels:
  - macos
  - firebase
  - crash
  - infrastructure
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

macOS exported app crashes immediately on launch with `Abort trap: 6` when running automated tests. The error occurs during Firebase initialization.

## Evidence

```
/var/folders/.../tmp: line 3663: 39889 Abort trap: 6
timeout "$MAX_TIMEOUT" "$MACOS_BINARY_PATH" $MACOS_ARGS
```

Build warnings show:
```
ld: warning: object file (libfirebase_firestore.a) was built for newer 'macOS' version (13.6) than being linked (11.0)
ld: warning: object file (libfirebase_database.a) was built for newer 'macOS' version (13.6) than being linked (11.0)
```

## Impact

Blocks cross-platform Firebase validation on macOS (task-403 criterion #9).

## Investigation Required

1. Verify Firebase initialization order on macOS
2. Check if linking macOS 13.6 SDK to 11.0 target causes incompatibility
3. Test with increased minimum macOS version in export presets
4. May need Firebase SDK update or different linking strategy
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 macOS exported app launches without crash
- [ ] #2 Firebase tests execute on macOS automated
- [ ] #3 build-export-test-macos firebase-all passes
- [ ] #4 Abort trap resolved
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
**ROOT CAUSE ANALYSIS COMPLETE - OODA Loop**

**OBSERVE:**
- App crashed immediately with 'Abort trap: 6'
- Linker warnings: Firebase SDK built for macOS 13.6, but linking against 11.0
- export_presets.cfg set min_macos_version_arm64='11.00'

**INITIAL INCORRECT DIAGNOSIS:**
- Thought the issue was macOS version mismatch
- Updated min_macos_version_arm64 from '11.00' to '13.0' in export_presets.cfg
- This did NOT fix the crash

**CORRECT ROOT CAUSE (discovered later):**
The Firestore commit (a3ee581d) added a fixed app name parameter to
firebase::App::Create() calls in firebase_platform.mm:

BEFORE (working):
  app_ptr = firebase::App::Create();

AFTER (crashing):
  app_ptr = firebase::App::Create(firebase::AppOptions(), "__FIRAPP_DEFAULT");

The App::Create(AppOptions, app_name) overload caused macOS to crash with
Abort trap: 6 at startup due to null pointer dereference.

**ACTUAL FIX:**
- Reverted to firebase::App::Create() without app name parameter
- Commit: godot submodule 9c0b6ae0ef
- macOS tests now pass: 8/8 actions (100% success rate)

**RESOLUTION:**
Firebase SDK crash resolved. App now initializes Firebase properly.
The macOS minimum version change (13.0) remains for SDK compatibility but was
not the primary fix for the Abort trap: 6 crash.

See task-429 (Firebase macOS crash) for full details.
See task-430 (Cherry-pick Firebase commits) for complete fix history.

**Files Changed:**
- godot/modules/firebase/firebase_platform.mm: Reverted __FIRAPP_DEFAULT
- project/export_presets.cfg:815 (min version 13.0 for SDK compatibility)
<!-- SECTION:NOTES:END -->
