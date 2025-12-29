---
id: task-395
title: Fix action results file pattern matching in trust-based validation
status: Done
assignee: []
created_date: '2025-12-29 11:14'
updated_date: '2025-12-29 11:17'
labels:
  - bug
  - test-framework
  - validation
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

The `system-error-handling` test shows "ACTION RESULT VALIDATION FAILED" across all platforms (Android, iOS, macOS, Windows, Windows Physical) even though:
1. All actions pass (4/4 on Android, 2/2 on other platforms)
2. The action results files **do exist** in the expected location

## Root Cause

In `justfiles/justfile-validation-enhanced-testing.justfile`, the trust-based validation uses `find` with patterns that don't match the actual filename:

```bash
# Current code (line ~100):
RESULTS_FILE=$(find "$RESULTS_DIR" -name "test_action_results_${TEST_ID}_*.json" -o -name "test_action_results_*_${TEST_ID}.json" | head -1)
```

**Pattern mismatch:**
- Actual file: `test_action_results_system-error-handling_android_1767003574.json`
- Pattern 1: `test_action_results_${TEST_ID}_*.json` → expects suffix AFTER TEST_ID
- Pattern 2: `test_action_results_*_${TEST_ID}.json` → expects prefix BEFORE TEST_ID
- **Neither matches** the actual filename format

## Solution

Add exact match pattern to the find command:

```bash
RESULTS_FILE=$(find "$RESULTS_DIR" -name "test_action_results_${TEST_ID}.json" -o -name "test_action_results_${TEST_ID}_*.json" -o -name "test_action_results_*_${TEST_ID}.json" | head -1)
```

## Impact

- All `system-error-handling` tests incorrectly show validation failure warnings
- Falls back to error analysis (works but loses trust-based validation benefits)
- Affects: Android, iOS, macOS, Windows VM, Windows Physical

## Files to Modify

- `justfiles/justfile-validation-enhanced-testing.justfile` - line ~100 in trust-based validation section
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Fix Applied (2025-12-29)

Added exact match pattern `test_action_results_${TEST_ID}.json` as the first option in the find command:

```bash
# Before:
find ... -name "test_action_results_${TEST_ID}_*.json" -o -name "test_action_results_*_${TEST_ID}.json"

# After:
find ... -name "test_action_results_${TEST_ID}.json" -o -name "test_action_results_${TEST_ID}_*.json" -o -name "test_action_results_*_${TEST_ID}.json"
```

Also updated the error message to reflect all patterns searched.
<!-- SECTION:NOTES:END -->
