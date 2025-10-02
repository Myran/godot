# Task task-191 - Fix Action Completion Race Condition - SequentialActionCompleteEvent Fires Before Action Wait Completes

**Status**: ✅ Completed
**Priority**: High
**Created**: 2025-10-01 20:21
**Resolved**: 2025-10-02
**Labels**: rtdb, firebase, race-condition, sequential-actions, critical

## Problem Statement

**Critical race condition discovered**: Only **3 of 19 RTDB actions executed** before the queue permanently stopped processing. The wildcard expansion fix (commit 98dc9049) successfully expanded `rtdb.*` to all 19 actions and dispatched them to the queue, but a race condition in the action completion sequencing prevented actions 4-19 from executing.

**Test**: `firebase-rtdb-layer` (Android)
**Expected**: All 19 actions execute sequentially with `auto_continue: false`
**Actual**: Only 3 actions execute, then queue stops permanently

## Root Cause Analysis

### The Race Condition (4ms timing window)

**Timeline at 19:20:36.699-703**:

```
19:20:36.699 - SequentialActionCompleteEvent emitted (inside action's callable)
19:20:36.699 - Event handler fires ProcessQueueEvent to continue queue
19:20:36.699 - ProcessQueueEvent blocked: _processing_idle_action = true
19:20:36.703 - Action completes, sets _processing_idle_action = false
19:20:36.703 - Logs "Waiting for natural completion events"
→ Permanent deadlock: completion event already fired but was discarded
```

**The Core Problem**:
1. `SequentialActionCompleteEvent` fires from within the action's execution (before callable returns)
2. `ProcessQueueEvent` handler checks `_processing_idle_action` guard
3. Guard blocks because action is still executing (`_processing_idle_action = true`)
4. Event gets discarded
5. Action finishes 4ms later, but the event already fired
6. Queue enters permanent wait state

## Solution Implemented

**Simple Flag-Based Continuation Pattern**:

Added `_queue_continuation_requested: bool` flag to remember when a completion event arrives while an action is still processing.

### Code Changes

**1. Added flag to `game.gd:30`**:
```gdscript
var _queue_continuation_requested: bool = false
```

**2. Modified `ProcessQueueEvent` handler in `core_event_resolver.gd:404-406`**:
```gdscript
elif event is core.ProcessQueueEvent:
    # If processing an action, remember the continuation request for after completion
    if game._processing_idle_action:
        game._queue_continuation_requested = true
        return
    # Return early if UI not ready - preserves queue for later processing
    if game.ui_state != core.UIState.WAITING:
        return
    game._process_one_queue_item()
```

**3. Updated queue continuation logic in `game.gd:322-346`**:
```gdscript
var should_continue: bool = (auto_continue or _queue_continuation_requested) and not _idle_action_queue.is_empty()

if should_continue:
    var continuation_reason: String = "action_auto_continue" if auto_continue else "completion_event_received"
    # ... logging ...
    _queue_continuation_requested = false
    core.action(core.ProcessQueueEvent.new())
```

**4. Reset flag at start of each action in `game.gd:249`**:
```gdscript
_processing_idle_action = true
_queue_continuation_requested = false
```

## Test Results

### Before Fix
```
🔧 firebase-rtdb-layer
   ├── 📱 android: ⚠️ PARTIAL (3/19 actions)
   │   └── Queue stops permanently after action 3
   │   └── 17 actions remain in queue forever
```

### After Fix
```
🔧 firebase-rtdb-layer
   ├── 📱 android: ✅ PASSED (19/19 actions - 100%)

Full test suite (just test):
   ✅ 36/36 configs passed
   ✅ 115/115 actions passed (100%)
   ✅ 18 desktop configs passed
   ✅ 18 android configs passed
```

**All 19 RTDB Actions Executed**:
- ✅ rtdb.advanced.batch_ops (785ms)
- ✅ rtdb.advanced.concurrent_ops (573ms)
- ✅ rtdb.advanced.transaction (1999ms)
- ✅ rtdb.children.list (771ms)
- ✅ rtdb.children.push (454ms)
- ✅ rtdb.database.get_value (480ms)
- ✅ rtdb.database.remove_value (1509ms)
- ✅ rtdb.database.set_value (534ms)
- ✅ rtdb.database.update_value (582ms)
- ✅ rtdb.listeners.child_added (671ms)
- ✅ rtdb.listeners.child_changed (1446ms)
- ✅ rtdb.listeners.child_removed (1701ms)
- ✅ rtdb.listeners.remove_all (76ms)
- ✅ rtdb.listeners.single_value (1214ms)
- ✅ rtdb.paths.get_nested (1298ms)
- ✅ rtdb.paths.set_nested (682ms)
- ✅ rtdb.testing.error_handling (2115ms)
- ✅ rtdb.testing.path_validation (5784ms)
- ✅ system.debug.replay_complete (3ms)

## Why This Solution Works

**Simple and Robust**:
1. When `ProcessQueueEvent` arrives during action processing, set flag instead of discarding
2. After action completes, check flag to determine if continuation was requested
3. Flag reset at start of each new action for clean state
4. No complex timing dependencies or architectural changes needed

**Advantages**:
- ✅ Minimal code changes (4 locations)
- ✅ No changes to action classes
- ✅ No changes to event system
- ✅ Handles race condition naturally
- ✅ Self-documenting: flag name explains purpose
- ✅ Zero performance impact

## Files Modified

1. `project/core/game.gd:30` - Added `_queue_continuation_requested` flag
2. `project/core/game.gd:249` - Reset flag at action start
3. `project/core/game.gd:322-346` - Check flag for continuation decision
4. `project/core/events/core_event_resolver.gd:404-410` - Set flag when blocked

## Related Tasks

- **task-189**: Fix RTDB Wildcard Regression - RESOLVED (wildcard expansion working)
- **task-187**: Fix RTDB Transaction Action Execution Hang - Indirectly resolved by this fix

## Success Validation

**Acceptance Criteria** - All Met ✅:
- [x] All 19 RTDB actions execute sequentially with `rtdb.*` wildcard pattern
- [x] No race conditions between completion event emission and queue state
- [x] Test `firebase-rtdb-layer` completes with 19/19 actions (not 3/19)
- [x] All actions execute within reasonable time (no 10-minute timeout)
- [x] Full test suite passes (36/36 configs, 115/115 actions)
- [x] No regression in other Firebase tests

**Test Evidence**:
- Standalone test: `just test-android-target firebase-rtdb-layer` - 19/19 actions ✅
- Full test suite: `just test` - 36/36 configs passed ✅
- Log file: `logs/20251002_104515_test.log` - Complete success ✅
