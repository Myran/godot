---
id: task-386
title: Fix iOS log filtering missing Sentry ERROR logs in integration-bridges test
status: Done
assignee: []
created_date: '2025-12-26 11:48'
updated_date: '2025-12-26 12:16'
labels:
  - ios
  - logging
  - sentry
  - testing
  - filtering
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

The `sentry-integration-bridges` test fails on iOS with:
```
❌ Missing: Test error for Sentry direct integration validation
```

The test action executes successfully (3/3 integrations working), but the **expected result validation fails** because the intentional test ERROR log is being filtered out during iOS log capture.

## Root Cause

iOS logs are captured via device log capture with this filter:
```bash
grep -E "($TEST_ID|SEMANTIC_ACTION|gametwo|com.primaryhive|godot.*:)"
```

The intentional ERROR log has format:
```
ERROR [sentry, test, intentional_test_error] Test error for Sentry direct integration validation
```

This doesn't contain any of the filter patterns, so it's **filtered out**.

## Comparison

| Platform | Result |
|----------|--------|
| macOS | ✅ Captures ERROR logs (local app, no filtering) |
| Android | ✅ Captures ERROR logs (different filter pattern) |
| iOS | ❌ Filters out ERROR logs (strict filter) |

## Evidence

From test run `20251226_120909_test-all_sentry-all.log`:
- iOS raw logs: 1070 lines captured
- After filtering: 28 lines
- ERROR log missing from filtered output

macOS shows the ERROR correctly:
```
ERROR [sentry, test, intentional_test_error] Test error for Sentry direct integration validation { "test": true, "integration_test": true } (sentry_integration_bridges_action.gd:108)
```

## Fix Location

`justfiles/justfile-validation-enhanced-testing.justfile` - iOS log filtering section

Add Sentry ERROR pattern to the iOS log filter:
```bash
grep -E "($TEST_ID|SEMANTIC_ACTION|gametwo|com.primaryhive|godot.*:|sentry.*intentional_test_error|Test error for Sentry)"
```
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented: Added `intentional_test_error` to `CROSS_PLATFORM_TEST_BASE` filter pattern in `justfile-filter-configs.justfile:20`

Tested: iOS sentry-integration-bridges test now captures the intentional ERROR log correctly.
<!-- SECTION:NOTES:END -->
