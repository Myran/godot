---
id: task-200
title: >-
  Fix firebase-backend-batch-2 sequential action completion event detection (2/3
  timeout)
status: To Do
assignee: []
created_date: '2025-10-06 16:33'
updated_date: '2025-10-06 16:33'
labels: [testing, firebase, sequential-actions, android, logging]
dependencies: []
priority: medium
---

## Description

Test framework experiences 30-second timeout waiting for sequential action completion events in `firebase-backend-batch-2` Android test. All 5 actions execute successfully (100% pass rate), but only 2 of 3 expected completion events are detected in logs.

**Status**: Cosmetic issue - does NOT affect functionality. All actions complete successfully.

## Problem Statement

**Test Config**: `firebase-backend-batch-2` (Android only)
**Actions**: 5 total (backend.firebase.performance x2, backend.firebase.request_tracking x1)
**Sequential Actions**: 3 expected
**Completion Events Detected**: 2/3
**Result**: Test PASSED with 30s timeout warning

**From logs/20251006_154537_test.log**:
```
⚠️  Timeout waiting for sequential actions (after 30s)
   Completed: 2/3
   Proceeding with available logs (timeout safety)
📊 Log lines captured: 2028
🎯 DEBUG_TEST_SUCCESS entries: 5
⚡ Sequential action successes: 4
```

## Root Cause

Similar to task-192 resolution, this appears to be a test framework logging pattern detection issue:

**Possible causes**:
1. One action doesn't emit the expected completion log pattern
2. Sequential action detection counting internal operations instead of queue dispatches
3. Action with `set_use_auto_success_logging(false)` or custom logging
4. Async timing - log extracted before 3rd event fully written

## Investigation Steps

1. Check which specific action is missing completion event:
```bash
just logs-text firebase-backend-batch-2_android_1759758337 "Sequential action completed"
just logs-pattern firebase-backend-batch-2_android_1759758337 "completion"
```

2. Verify sequential action detection pattern:
```bash
# Check what framework counts as sequential
just logs-text firebase-backend-batch-2_android_1759758337 "auto_continue.*false"
```

3. Check if completion events use different format:
```bash
just android-logs-search "backend.firebase.request_tracking"
```

## Expected Outcome

Either:
- **Option A**: Fix event emission - ensure all sequential actions emit completion events
- **Option B**: Fix detection pattern - adjust framework to match actual log format
- **Option C**: Document as expected - if action intentionally uses custom logging

## Related Tasks

- **task-192**: Sequential action completion event timeouts (14 configs) - RESOLVED
  - Reduced 14 timeouts to 6 by fixing detection pattern
  - Documented remaining 6 as expected for custom logging actions
- **task-191**: Fix action completion race condition - Related to queue continuation

## Context

- Test log: `logs/20251006_154537_test.log`
- Android log: `android_firebase-backend-batch-2_android_1759758337.log`
- Config: `tests/debug_configs/firebase-backend-batch-2.json`
