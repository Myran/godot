---
id: task-233
title: Fix Firebase parameter null and method argument mismatch in battle tests
status: Open
assignee: []
created_date: '2025-10-21 17:44'
labels:
  - firebase
  - android
  - testing
  - critical
dependencies: []
priority: high
---

## Description

Android battle tests (battle-animated, battle-logic-only) are failing due to Firebase-related errors that occur during test execution. While the sequential action completion events now work correctly (fixed in task-193), the tests fail due to Firebase parameter and method call issues.

**Impact**: Prevents Android battle test validation despite core sequential action logic being fixed.

## Error Analysis

**Source**: Android test `battle-animated_android_1761064465` (from test run 2025-10-21 18:37)

### Error 1: Null Parameter
```
10-21 18:37:57.571 E godot: ERROR: Parameter "obj" is null.
```

**Context**: Occurs early in test execution, likely during Firebase initialization or listener setup.

### Error 2: Method Argument Mismatch
```
10-21 18:38:07.571 E godot: ERROR: Error calling method from 'callv':
'FirebaseDatabase::remove_listener_at_path': Method expected 1 arguments, but called with 0.
```

**Context**: Firebase cleanup/teardown attempting to remove listener without providing required path argument.

### Error 3: Test Restart Triggered
```
10-21 18:38:07.603 I godot: DEBUG_TEST_RESTART_NEEDED
{ "test_id": "battle-animated_android_1761064465", "reason": "config_updated",
  "phase": "validation_needed", "seed": 55555 }
```

**Context**: Config validation issue triggering restart, suggests battle test completes but fails validation.

### Error 4: Resource Leak
```
10-21 18:38:07.680 E godot: ERROR: 1 resources still in use at exit.
```

**Context**: Cleanup incomplete, likely Firebase listener or database connection not properly released.

## Evidence

**Sequential Actions Work Correctly:**
```
✅ game.lineup.populate_enemy - completion event emitted
✅ game.battle.test_determinism_animated - completion event emitted
```

**Test Execution:**
- Test ID: `battle-animated_android_1761064465`
- Platform: Android
- Log file: `android_battle-animated_android_1761064465.log`
- Debug command: `just logs-errors battle-animated_android_1761064465`

## Root Cause Hypothesis

1. **Null Parameter**: Firebase object not initialized before use, or destroyed before cleanup
2. **Argument Mismatch**: `remove_listener_at_path()` called without path parameter during teardown
3. **Config Validation**: Battle test completes successfully but triggers validation restart
4. **Resource Leak**: Firebase listener not properly cleaned up due to argument mismatch error

## Investigation Steps

- [ ] Check Firebase initialization in battle test setup
- [ ] Review `remove_listener_at_path()` call sites for missing arguments
- [ ] Examine test teardown sequence for proper cleanup order
- [ ] Verify config validation logic for battle tests
- [ ] Check if Desktop has same cleanup code (Desktop tests pass)

## Affected Tests

- `battle-animated` (Android) - ✅ Sequential actions work, ❌ Firebase errors
- `battle-logic-only` (Android) - Likely same Firebase issues

## Related Tasks

- **task-193** (Done): Fixed sequential action completion events - unblocked this issue
- Tests now properly emit completion events, revealing underlying Firebase cleanup issues

## Acceptance Criteria

- [ ] Android battle tests pass without Firebase parameter errors
- [ ] `remove_listener_at_path()` called with correct arguments
- [ ] No resource leaks at test exit
- [ ] Config validation passes without triggering restart
- [ ] Both `battle-animated` and `battle-logic-only` pass on Android
