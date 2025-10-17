---
id: task-227
title: Fix backend.firebase.performance action failure in firebase-three-actions-test
status: To Do
priority: high
assignee: []
created_date: '2025-10-17 14:03'
updated_date: '2025-10-17 14:03'
labels:
  - firebase
  - performance
  - android
  - test-suite
  - regression
dependencies: []
---

## Description

**TEST SUITE REGRESSION**: The `backend.firebase.performance` action fails in `firebase-three-actions-test` when run as part of comprehensive test suite, despite passing individually.

### Failure Pattern

**Test**: `firebase-three-actions-test` (5 actions total)
**Failed Action**: `backend.firebase.performance` (1/5 actions, 20% failure rate)
**Duration**: 27,606ms (27.6 seconds) - significantly slower than typical performance
**Test Run**: `logs/20251017_134504_test.log` (comprehensive test suite)

### Test Execution Status

```
firebase-three-actions-test_android_1760701504:
✅ 4/5 actions PASSED (80%)
❌ 1/5 actions FAILED (20%)
❌ backend.firebase.performance: FAILED (27606ms)
```

### Historical Context

**Previous Success Evidence**:
- task-154: Performance action completed successfully (1085ms typical duration)
- task-145: Performance test passed with 0 errors after timeout optimization
- task-155: Performance action consistently 909-980ms (100% success)

**Key Observation**: ~27x slower than typical duration (27.6s vs 1s), suggesting timeout or blocking issue.

### Test Suite vs Individual Execution

**Critical Pattern**: Config likely passes when run individually but fails in comprehensive suite due to:
1. **Resource Exhaustion** - Multiple Firebase operations accumulating state
2. **Test Isolation Issues** - App state bleeding from previous configs (task-216.01, task-215)
3. **Firebase SDK State** - Backend state accumulation across multiple test cycles

### Related Tasks

- **task-216.01**: Test suite isolation - app state bleeds between configs
- **task-215**: Configs work individually but fail in comprehensive tests
- **task-197**: Firebase backend sequential action timeout on Android

## Investigation Steps

```bash
# 1. Run individual test to confirm it passes
just test-android-target firebase-three-actions-test

# 2. Check logs from comprehensive suite run
just logs-errors firebase-three-actions-test_android_1760701504
just logs-text firebase-three-actions-test_android_1760701504 "backend.firebase.performance"

# 3. Compare timing between individual and suite execution
just test-android-target firebase-three-actions-test  # Note duration
just test  # Run full suite, compare performance action timing

# 4. Check for state accumulation issues
just android-logs-search "firebase-three-actions-test" | rg -i "performance|timeout"
```

## Acceptance Criteria

- [ ] `firebase-three-actions-test` passes consistently in comprehensive test suite (10/10 runs)
- [ ] `backend.firebase.performance` action completes in <3 seconds (not 27 seconds)
- [ ] All 5 actions in config pass (100% success rate)
- [ ] Performance metrics match individual run timings (909-1085ms range)
- [ ] No regression in other Firebase test configurations
- [ ] Test suite isolation improvements prevent state accumulation

## Debug Commands

```bash
# Latest comprehensive test logs
cat logs/20251017_134504_test.log | rg "firebase-three-actions-test" -A 20

# Extract action results
just logs-pattern firebase-three-actions-test_android_1760701504 "backend.firebase.*"
```
