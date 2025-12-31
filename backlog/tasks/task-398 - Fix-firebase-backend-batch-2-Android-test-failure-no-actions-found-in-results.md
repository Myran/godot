---
id: task-398
title: >-
  Fix firebase-backend-batch-2 Android test failure - no actions found in
  results
status: Done
assignee: []
created_date: '2025-12-30 13:57'
updated_date: '2025-12-30 14:05'
labels:
  - android
  - test-failure
  - firebase
  - pipeline-blocker
dependencies: []
priority: high
ordinal: 15.625
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Issue:**
During pipeline-rebuild-ship test run, the `firebase-backend-batch-2` config failed on Android with a critical error.

**Error:**
```
❌ CRITICAL TEST FAILURE: No actions found in results file
❌ OVERALL RESULT: FAILED
```

**Context:**
- Test ID: firebase-backend-batch-2_android_1767100052
- Platform: Android only
- This indicates the test framework didn't capture any action results, suggesting:
  - App crashed before actions executed
  - Config wasn't loaded properly
  - Results file wasn't written

**Investigation needed:**
1. Check if app started and loaded config
2. Look for crashes or early termination
3. Verify firebase-backend-batch-2.json config is valid
4. Compare with firebase-backend-batch-1 and batch-3 (both passed)

**Commands:**
```bash
just logs-errors firebase-backend-batch-2_android_1767100052
just logs-android firebase-backend-batch-2_android_1767100052
just logs-android-device "firebase-backend-batch-2"
```
<!-- SECTION:DESCRIPTION:END -->
