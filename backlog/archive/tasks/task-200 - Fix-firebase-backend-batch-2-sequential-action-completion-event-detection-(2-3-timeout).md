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

## Root Cause (IDENTIFIED - 2025-10-06)

**Critical Finding**: Race condition in action queue dispatch violates sequential execution contract.

### Evidence from Android logs (firebase-backend-batch-2_android_1759758337):

**Timeline of `backend.firebase.error_handling` execution:**
1. **15:49:03.438** - First execution (autoload/startup phase) - COMPLETED at 15:49:03.564
2. **15:49:03.619** - Second execution (actual test) - **NEVER COMPLETED**
3. **15:49:03.628** - `backend.firebase.performance` started (only **9ms** after error_handling test execution)

### Root Cause Analysis:

**1. Duplicate Execution Pattern**:
- `error_handling` executed **twice**: once during autoload initialization, once in test queue
- First execution (autoload) completed but wasn't part of test (no test_id logging)
- Second execution (actual test) **interrupted before completion**

**2. Sequential Action Contract Violation**:
- All 3 actions have `auto_continue = false` (requires sequential execution)
- Action queue dispatched `performance` only 9ms after `error_handling` started
- `error_handling` never reached completion code path
- **Violates sequential execution guarantee**

**3. Missing Logs Explained**:
- ❌ No DEBUG_TEST_SUCCESS → action never completed execution path
- ❌ No SequentialActionCompleteEvent → completion code never reached
- ✅ Test infrastructure correctly detected "3 sequential actions" (from config)
- ✅ Only observed 2 completion events (performance + request_tracking)

**4. Why Other Actions Work**:
- `performance` and `request_tracking` completed successfully
- Both logged DEBUG_TEST_SUCCESS (with duplicates indicating similar issue)
- Both emitted SequentialActionCompleteEvent

### Architectural Issue:

**CORRECTED ANALYSIS** (After deep investigation):

The action queue system is **correctly implemented**:
- `ProcessQueueEvent` properly sets `_queue_continuation_requested = true` when action is processing
- `SequentialActionCompleteEvent` triggers `ProcessQueueEvent` to continue queue
- Queue only continues when `auto_continue = true` OR `_queue_continuation_requested = true`

**THE REAL BUG: Double Config Parsing During Startup**

Config is being **read and actions dispatched TWICE** during the same startup sequence:
1. **15:49:03.617** - Config parsed (first time): 3 actions dispatched
2. **15:49:03.618** - Config parsed (second time, 1ms later): 3 actions dispatched again
3. This creates **6 total queue items** from 3 config actions
4. First batch and second batch execute concurrently, causing race conditions

**Timeline Evidence**:
- `15:49:03.438` - First `error_handling` execution (from first batch)
- `15:49:03.564` - First `error_handling` completes (autoload phase)
- `15:49:03.619` - Second `error_handling` execution starts (from second batch)
- `15:49:03.628` - `performance` starts (only **9ms** after second error_handling)
- Second `error_handling` **never completes** - interrupted by concurrent batch

**Root Cause**: Config reader or startup coordinator is parsing `user://debug_startup_actions.json` twice, creating duplicate action dispatches that violate sequential execution guarantees.

## Investigation Plan (Following OODA Loop)

### Phase 1: Autoload Execution Investigation ✅ COMPLETED
**Question**: Why is autoload executing test actions during initialization?

**Findings**:
- `main.gd` calls `DebugStartupCoordinator.startDebugCoordinator()` during game initialization
- `startDebugCoordinator()` reads config from `user://debug_startup_actions.json`
- Actions are **batch dispatched** to idle queue via `core.action(core.SystemIdleActionEvent.new(callable, auto_continue))`
- All actions dispatched immediately (lines 84-114 in `debug_startup_coordinator.gd`)
- This is **correct behavior** for single config parse

### Phase 2: Action Queue Dispatch Logic Investigation ✅ COMPLETED
**Question**: Why does queue dispatch next action before current completes?

**Findings - Queue Logic is CORRECT**:
- `game.gd:202-349` - `_process_one_queue_item()` implementation
- Line 220: Only processes if `ui_state == WAITING` AND NOT `_processing_idle_action` AND queue not empty
- Line 248: Sets `_processing_idle_action = true` before action execution
- Line 272: `await action.call()` - properly waits for action completion
- Line 303: Sets `_processing_idle_action = false` after completion
- Line 324: Only continues if `auto_continue = true` OR `_queue_continuation_requested = true`

**SequentialActionCompleteEvent Flow**:
1. Action completes → emits `SequentialActionCompleteEvent` (`debug_action.gd:231`)
2. Event handled in `core_event_resolver.gd` → triggers `core.action(core.ProcessQueueEvent.new())`
3. `ProcessQueueEvent` handler checks if action is processing:
   - If YES: Sets `_queue_continuation_requested = true` and returns
   - If NO: Directly calls `_process_one_queue_item()`
4. Queue processes next item only when `_queue_continuation_requested = true`

**Conclusion**: Sequential action handling is correctly implemented. The issue is **external** to queue logic.

### Phase 3: Config Parsing Investigation ✅ COMPLETED
**Question**: Why is config parsed twice?

**Evidence from Android logs**:
```
10-06 15:49:03.617 [DEBUG] Parsed actions from config { "actions": [...], "count": 3 }
10-06 15:49:03.618 [DEBUG] Parsed actions from config { "actions": [...], "count": 3 }
```

**Dispatch logs show duplicate action registration**:
- First dispatch: Actions queued for first batch
- Second dispatch (1ms later): Same actions queued again

**Location to investigate**:
- `debug_startup_coordinator.gd:145-175` - `_get_action_names()` function
- Check if config file is read multiple times
- Check if `startDebugCoordinator()` is called twice

### Phase 4: Fix Implementation ⏸️ PENDING

Based on investigation findings:
- **Option A** ✅ RECOMMENDED: Prevent double config parsing
  - Add guard to ensure config is only read once per startup
  - Check if `startDebugCoordinator()` can be called multiple times
  - Add singleton pattern or initialization flag

- **Option B**: Deduplicate action dispatch
  - Check action queue for duplicates before adding
  - Clear queue before new dispatch

- **Option C**: Investigate why there are TWO separate execution phases
  - First execution at 15:49:03.438 (early autoload)
  - Second execution at 15:49:03.617-619 (config parsing)
  - Understand if this is intentional design

## Technical Details for Continuation

### Key Files to Investigate:
1. **`project/addons/debug_startup/debug_startup_coordinator.gd`**
   - Line 31: `startDebugCoordinator()` function
   - Line 145: `_get_action_names()` - reads config
   - Line 84-114: Batch dispatch loop

2. **`project/main.gd`**
   - Search for `startDebugCoordinator()` call
   - Check if called multiple times

3. **`project/debug/utilities/debug_config_reader.gd`**
   - Config file reading logic
   - Check for caching or duplicate reads

### Log Patterns to Search For:
```bash
# Find all config parsing instances
rg "Parsed actions from config" logs/android_*.log

# Find all dispatch instances
rg "Dispatching action to idle queue" logs/android_*.log

# Find startDebugCoordinator calls
rg "DebugStartupCoordinator initializing" logs/android_*.log

# Check for duplicate action executions
rg "Executing backend.firebase.error_handling" logs/android_*.log
```

### Action Results Analysis:
From `test_action_results_firebase-backend-batch-2_android_1759758337.json`:
- **5 total actions collected** (should be 3)
- Sequence 3: `backend.firebase.performance` (373ms)
- Sequence 4: `backend.firebase.performance` (635ms) - **DUPLICATE**
- Sequence 5: `backend.firebase.request_tracking` (0ms)
- Sequence 6: `system.debug.replay_complete` (2ms)
- Sequence 7: `backend.firebase.request_tracking` (2892ms) - **DUPLICATE**
- **Missing**: `backend.firebase.error_handling` (never logged DEBUG_TEST_SUCCESS)

### Queue System Architecture (VERIFIED CORRECT):
```
SystemIdleActionEvent(callable, auto_continue)
    ↓
core_event_resolver.gd: Adds to _idle_action_queue
    ↓
ProcessQueueEvent triggered
    ↓
game.gd:_process_one_queue_item()
    ↓
Sets _processing_idle_action = true
    ↓
await action.call()
    ↓
Action executes and emits SequentialActionCompleteEvent (if auto_continue=false)
    ↓
core_event_resolver.gd: Handles SequentialActionCompleteEvent
    ↓
Triggers ProcessQueueEvent
    ↓
If _processing_idle_action: sets _queue_continuation_requested = true
    ↓
After action completes: checks (auto_continue OR _queue_continuation_requested)
    ↓
If true: Processes next queue item
```

## Expected Outcome

**Correct Behavior**:
1. Config should only be parsed **once** during startup
2. Each action should execute **exactly once** (no duplicates)
3. Sequential actions (`auto_continue = false`) complete before next action starts
4. All 3 actions emit completion events: error_handling, performance, request_tracking
5. No 30s timeout warnings
6. Test framework detects 3/3 completion events

## Next Steps for Resolution

1. **Immediate Fix** (Option A - Recommended):
   - Add initialization guard to `startDebugCoordinator()` to prevent double execution
   - Example: `static var _already_initialized: bool = false`

2. **Root Cause Investigation**:
   - Determine why config is parsed twice at 15:49:03.617 and 15:49:03.618
   - Check if `_get_action_names()` is called multiple times
   - Verify if `startDebugCoordinator()` can be called concurrently

3. **Verification**:
   - Run `just test-android-target firebase-backend-batch-2`
   - Check logs for "Parsed actions from config" - should appear only once
   - Verify all 3 actions execute once and emit completion events
   - No 30s timeout warning

## Investigation Session Summary

**Time Investment**: ~4 hours
**Token Usage**: ~125k tokens
**Status**: Root cause identified, ready for implementation
**Confidence**: High - Queue system verified correct, config parsing duplication confirmed

## Related Tasks

- **task-192**: Sequential action completion event timeouts (14 configs) - RESOLVED
  - Reduced 14 timeouts to 6 by fixing detection pattern
  - Documented remaining 6 as expected for custom logging actions
- **task-191**: Fix action completion race condition - Related to queue continuation

## Context

- Test log: `logs/20251006_154537_test.log`
- Android log: `android_firebase-backend-batch-2_android_1759758337.log`
- Config: `tests/debug_configs/firebase-backend-batch-2.json`
