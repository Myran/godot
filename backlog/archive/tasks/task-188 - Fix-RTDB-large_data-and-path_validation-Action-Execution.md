---
id: task-188
title: Fix RTDB large_data and path_validation Action Execution
status: To Do
assignee: []
created_date: '2025-09-30 20:48'
updated_date: '2025-10-01 11:37'
labels:
  - testing
  - rtdb
  - firebase
  - action-discovery
  - auto-quit
dependencies: []
priority: medium
---

## Description

## 🚨 CRITICAL - CI Validation Blocker

**Status**: Android CI validation failing, blocking commits

**Evidence**: 
```
just ci-validate → error: Recipe `ci-validate-android` failed with exit code 1
Loading resource: res://debug/actions/firebase_cpp/cpp_error_handling_test_action.gd
❌ Android CI validation failed
```

**Investigation Required**:
1. Run `just show-warnings` to identify GDScript warnings
2. Check Android export warnings with godot export
3. Fix validation issues before proceeding with RTDB investigation

**Original Task Context**: Two RTDB actions fail to execute in firebase-rtdb-layer test (large_data and path_validation), and app does not auto-quit after completing actions, resulting in 10-minute timeout. Core functionality works (17/19 actions = 89.5% success), but need 100% execution for complete test coverage.

**BLOCKED**: Cannot proceed with RTDB testing until CI validation passes.

**Next Steps**:
1. Fix CI validation errors
2. Run `just fastbuild-android` to deploy updated build
3. Verify unified completion event system present in logs
4. Re-test firebase-rtdb-layer config

**Root Cause Hypotheses** (for RTDB issues after CI fixed):
1. large_data action hangs during execution (has auto_continue=false)
2. Actions not discovered by rtdb.* wildcard pattern
3. Auto-quit logic not triggering after queue completes

**Evidence**: Test ID firebase-rtdb-layer_android_1759262212, logs/20250930_215652_test.log lines 2746-2970

**Related**: TASK-187 (RESOLVED), TASK-186 (completed)
## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Identify why large_data action doesn't execute,Identify why path_validation action doesn't execute,Fix or document limitation for both actions,All 19 RTDB actions execute with rtdb.* wildcard,App auto-quits after completing all actions (<30 seconds),firebase-rtdb-layer test completes without 10-minute timeout
<!-- AC:END -->

## Implementation Notes

**Investigation Steps**:
1. Test large_data action in isolation: actions: ["rtdb.testing.large_data"]
2. Test path_validation action in isolation: actions: ["rtdb.testing.path_validation"]
3. Check action discovery/registration in DebugActionRegistry
4. Investigate auto-quit logic in game.gd

**Files to Investigate**:
- project/debug/actions/rtdb/rtdb_large_data_test_action.gd
- project/debug/actions/rtdb/rtdb_path_validation_action.gd
- project/debug/actions/registrations/rtdb_actions.gd
- project/core/game.gd (auto-quit logic)

**Related**: TASK-187 (RESOLVED), TASK-186 (completed)

**Context**: Split from TASK-187 after transaction hang resolved. Lower priority cleanup work for 100% action coverage.
