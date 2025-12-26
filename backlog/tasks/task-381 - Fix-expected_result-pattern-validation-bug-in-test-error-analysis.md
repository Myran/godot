---
id: task-381
title: Fix expected_result pattern validation bug in test error analysis
status: Done
assignee: []
created_date: '2025-12-26 00:08'
updated_date: '2025-12-26 00:17'
labels:
  - testing
  - bug
  - validation
dependencies:
  - task-380
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

The expected_result pattern validation in the test error analysis incorrectly reports patterns as "Missing" even when they are present in the logs.

## Evidence

When running `just test-windows-physical-target sentry-integration-bridges`:

**Log file contains (verified with grep):**
```
2025-12-26 01:06:49 ERROR [sentry, test, intentional_test_error] Test error for Sentry direct integration validation { "test": true, "integration_test": true }
```

**Test output says:**
```
🎯 Using legacy log pattern validation
🎯 Expected error patterns found:
   ❌ Missing: Test error for Sentry direct integration validation
```

The pattern IS in the log file but the validation reports it as missing.

## Config

From `sentry-integration-bridges.json`:
```json
"expected_result": {
  "type": "expected_errors",
  "description": "Validates intentional test error for Advanced Logger → Sentry integration",
  "patterns": [
    "Test error for Sentry direct integration validation"
  ]
}
```

## Suspected Cause

The legacy log pattern validation may be:
1. Not reading the correct log file
2. Using grep patterns that don't match the log format with JSON metadata appended
3. Parsing the log file incorrectly

## Impact

- False test failures when using `expected_result` validation
- Affects all platforms, not just Windows
- Discovered while adding Windows platform support (task-380)

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Investigate why pattern validation fails when pattern exists
- [x] #2 Fix the validation logic to correctly find patterns in logs
- [x] #3 Verify sentry-integration-bridges passes on all platforms
<!-- SECTION:DESCRIPTION:END -->

<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Fix Applied (2025-12-26)

**Root Cause**: The `RELEVANT_LOGS` filter at line 1280 in `justfile-validation-enhanced-testing.justfile` used the pattern `godot.*ERROR` which only matched Android log format (`12-24 11:09:31.413 30453 30516 E godot   : [ERROR]...`). Windows physical logs use the Advanced Logger format (`2025-12-26 01:06:49 ERROR [tags] message`) which doesn't have `godot` in the line.

**Fix**: Added patterns to match both Android format and Advanced Logger format:
- `[[:space:]]ERROR[[:space:]]` - matches ` ERROR ` (space-surrounded)
- `[[:space:]]CRITICAL[[:space:]]` - matches ` CRITICAL ` (space-surrounded)
- `^ERROR:` - matches Godot internal errors at line start

**Verified on all platforms**:
- ✅ Desktop (editor)
- ✅ Android
- ✅ Windows physical
- ✅ macOS
<!-- SECTION:NOTES:END -->
