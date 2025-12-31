---
id: task-380
title: Add Windows platform support to Sentry test configurations
status: Done
assignee: []
created_date: '2025-12-25 23:59'
updated_date: '2025-12-29 00:07'
labels:
  - sentry
  - windows
  - testing
  - platform-parity
dependencies: []
priority: high
ordinal: 260000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

Sentry tests cannot run on Windows physical machine because none of the sentry test configurations include Windows platform support.

When running `just test-windows-physical-target sentry-all`, all 6 configs are skipped:
- `sentry-addon-validation` → requires: editor, android, ios
- `sentry-android-file-validation` → requires: android
- `sentry-integration-test` → requires: editor
- `sentry-android-integration-test` → requires: android
- `sentry-crash-scenarios` → requires: editor, android
- `sentry-integration-bridges` → requires: editor, android

## User Report

User attempted to run Sentry tests manually on Windows physical machine and experienced test failures. This suggests:
1. Windows platform needs to be added to appropriate sentry test configs
2. There may be Windows-specific Sentry issues that need investigation

## Current State

Sentry on Windows uses:
- GDExtension with crashpad backend (out-of-process crash handling)
- Native MSVC builds
- Same GDScript integration layer as other platforms

## Required Changes

### Phase 1: Enable Windows Platform Support

Add `"windows-physical"` (and/or `"windows"`) to appropriate configs:

1. **`sentry-addon-validation.json`** - Validate addon presence on Windows
2. **`sentry-integration-test.json`** - Test SDK functionality  
3. **`sentry-crash-scenarios.json`** - Test crash handling (if applicable)
4. **`sentry-integration-bridges.json`** - Test bridges

### Phase 2: Investigate Windows-Specific Issues

1. Run sentry tests on Windows physical after enabling platform
2. Analyze failures
3. Create follow-up tasks for any Windows-specific Sentry bugs

### Phase 3: Create Windows-Specific Tests (if needed)

Consider creating:
- `sentry-windows-file-validation.json` - Windows crashpad file validation
- `sentry-windows-integration-test.json` - Windows-specific SDK tests

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Windows platform added to applicable sentry test configs
- [x] #2 `just test-windows-physical-target sentry-all` executes tests (not skipped)
- [x] #3 Test results documented
- [x] #4 Follow-up tasks created for any Windows-specific failures
<!-- SECTION:DESCRIPTION:END -->

<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Implementation Notes

### Completed Work

1. **Added Windows platform to 4 sentry test configs:**
   - `sentry-addon-validation.json` (added: macos, windows-physical)
   - `sentry-integration-test.json` (added: macos, windows-physical)
   - `sentry-crash-scenarios.json` (added: ios, macos, windows-physical)
   - `sentry-integration-bridges.json` (added: ios, macos, windows-physical)

2. **Fixed Windows binary validation in `sentry_addon_validation_action.gd`:**
   - Added Windows platform check for native binaries at `res://addons/sentry/bin/windows/x86_64/*.dll`
   - Added Windows to functional validation fallback (like Android)

### Test Results After Fix

```
sentry-addon-validation:    ✅ PASSED (was failing)
sentry-integration-test:    ✅ PASSED
sentry-crash-scenarios:     ✅ PASSED
sentry-integration-bridges: ❌ FAILED (pre-existing validation bug)
```

### Issue Found: Expected Result Validation Bug

The `sentry-integration-bridges` failure is NOT a Windows-specific issue. The error message "Test error for Sentry direct integration validation" IS present in the logs, but the validation logic incorrectly reports it as missing.

This appears to be a bug in the legacy log pattern validation that affects all platforms using `expected_result` config. Created follow-up task-381 for this.
<!-- SECTION:NOTES:END -->
