---
id: task-188
title: Fix RTDB large_data and path_validation Action Execution
status: To Do
assignee: []
created_date: '2025-09-30 20:48'
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

## 🚨 CRITICAL INSIGHT - Build Status Issue

**Discovery**: Current live test shows SAME behavior as before unified event fix:
- Only 2/19 actions executing (batch_ops, concurrent_ops)
- No "Sequential action completed" messages in logs
- No completion events being emitted
- App still running after 6+ minutes

**Root Cause**: Android device may be running OLD BUILD without unified SequentialActionCompleteEvent system

**Evidence**:
- Commits are in git (2bea89cc - unified events committed)
- Previous test at 19:16 showed 17/19 actions (SUCCESS with that build)
- Current test at 22:49 shows 2/19 actions (REGRESSION - suggesting old build)
- No completion event logs in current Android logcat (unified system not present)

**Hypothesis**: The previous successful test run (logs/20250930_215652_test.log) used a different build that had the unified completion event system. Current device may have:
1. Cached old APK from before unified event commits
2. Not rebuilt since last commits
3. Running pre-unified-event code

**REQUIRED ACTION BEFORE INVESTIGATION**:
1. Run `just fastbuild-android` to deploy unified event system to device
2. Verify "Sequential action completed" appears in logs
3. Re-test firebase-rtdb-layer to confirm 17/19 actions still execute
4. If regression confirmed, investigate what changed between builds

**This changes investigation priority**:
- First: Verify current build has unified completion events
- Second: Reproduce 17/19 success rate with current codebase
- Third: Investigate remaining 2 actions (only after confirming build is correct)

---

Two RTDB actions fail to execute in firebase-rtdb-layer test (large_data and path_validation), and app doesn't auto-quit after completing actions, resulting in 10-minute timeout. Core functionality works (17/19 actions = 89.5% success), but need 100% execution for complete test coverage.

**Current State**: Test completes with 36/36 configs passing despite missing 2 actions because 17 actions execute with zero errors.

**Root Cause Hypotheses**:
1. large_data action hangs during execution (has auto_continue=false)
2. Actions not discovered by rtdb.* wildcard pattern
3. Auto-quit logic not triggering after queue completes

**Evidence**: Test ID firebase-rtdb-layer_android_1759262212, logs/20250930_215652_test.log lines 2746-2970

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
