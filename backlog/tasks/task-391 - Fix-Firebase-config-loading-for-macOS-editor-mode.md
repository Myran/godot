---
id: task-391
title: Fix Firebase config loading for macOS editor mode
status: Done
assignee: []
created_date: '2025-12-28 09:59'
updated_date: '2025-12-28 10:07'
labels:
  - firebase
  - macos
  - editor
  - test-infrastructure
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

All editor tests (6 configs) fail with:
```
ERROR: Unable to load Firebase app options ([google-services-desktop.json, google-services.json] are missing or malformed)
```

## Root Cause

In `godot/modules/firebase/firebase_platform.mm` (lines 50-74), macOS Firebase initialization only looks for config in the app bundle Resources:
```cpp
NSBundle* mainBundle = [NSBundle mainBundle];
NSString* resourcePath = [mainBundle resourcePath];
NSString* configPath = [resourcePath stringByAppendingString:@"/google-services-desktop.json"];
```

- **For exported apps**: Works correctly (config bundled in Resources)
- **For editor mode**: `[NSBundle mainBundle]` returns Godot editor's bundle, NOT project directory

## Affected Tests (6 configs)

- battle-animated
- battle-combat-only-validation
- battle-logic-only
- gamestate-complete-save-load-cycle-test
- gamestate-save-load-test
- system-layer-all

## Solution Options

1. **Add editor-mode fallback**: Check project directory if bundle path fails
2. **Exclude editor platform**: Add `platforms` field to exclude `editor` for these tests
3. **Accept as expected behavior**: Editor tests don't need Firebase (tests pass, just log errors)

## Evidence

Log file: `logs/20251227_232355_pipeline-rebuild.log`
- Tests PASS (actions execute correctly)
- Error analysis FAILS (detects Firebase init errors)

## Related

Windows implementation handles this correctly (uses current directory):
```cpp
// firebase_windows.cpp
// Firebase C++ SDK automatically looks for google-services-desktop.json in current directory
```
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Resolution

**Root cause**: Firebase C++ SDK looks for config at `[NSBundle mainBundle] resourcePath` which for the Godot editor resolves to `editor/` directory, not where the config file was stored (`firebase/`).

**Fix applied**: Created symlink `editor/google-services-desktop.json -> ../firebase/google-services-desktop.json`

**Verification**:
- `system-layer-all` test: ✅ PASSED (was FAILED)
- `battle-animated` test: ✅ PASSED (was FAILED)
- Firebase init logs: `[Firebase] Config file found, loading...` → `[Firebase] Success creating app`

**Commit**: Added symlink to git tracking
<!-- SECTION:NOTES:END -->
