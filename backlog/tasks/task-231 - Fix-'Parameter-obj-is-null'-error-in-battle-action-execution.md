---
id: task-231
title: Fix 'Parameter obj is null' error in battle action execution
status: Done
assignee: []
created_date: '2025-10-20 17:03'
updated_date: '2025-10-23 07:25'
labels:
  - critical
  - android
  - battle
  - bug
  - action-execution
  - sequential-events
dependencies: []
---

## Description

This error appeared in Android logs after fixing the compilation error in game_action_core.gd:493. The error 'ERROR: Parameter 'obj' is null.' occurs during battle action execution and causes test error analysis to fail, though the test passes functionally. This may be related to SequentialActionCompleteEvent handling or the battle action execution flow that was recently modified.

## Resolution

**Status**: ✅ RESOLVED (2025-10-21)

**Root Cause**: Android-specific issue where `Signal()` constructor creates invalid/null signal objects, causing null parameter errors when connecting to SignalAwaiter.

**Fix Commit**: `12e52bbc` (2025-10-21 22:33)
- Created StateTransitionEmitter helper class with proper signal definition
- Fixed SignalAwaiter timeout race condition
- Removed CONNECT_DEFERRED flag for immediate handler execution

**Test Results**:
- battle-animated: ✅ PASSED (4/4 actions, 0 errors)
- battle-logic-only: ✅ PASSED (4/4 actions, 0 errors)

**Evidence**: Error NOT present in logs since Oct 21, 2025.

**Closes**: task-231

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Identify the source of the null 'obj' parameter error,Fix the null parameter issue without breaking existing functionality,Ensure error analysis passes for Android tests,Verify the fix works across different battle scenarios
<!-- AC:END -->
