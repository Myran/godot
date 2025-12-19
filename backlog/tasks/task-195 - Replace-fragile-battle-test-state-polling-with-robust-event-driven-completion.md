---
id: task-195
title: Replace fragile battle test state polling with robust event-driven completion
status: Done
assignee: []
created_date: '2025-10-02 18:32'
updated_date: '2025-12-18 10:37'
labels:
  - testing
  - battle
  - event-driven
  - architecture-refactoring
dependencies:
  - task-193
priority: high
ordinal: 113000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The current test_determinism_animated function uses a fragile while loop to wait for battle completion that creates race conditions and goes against the existing event-driven architecture. This improvement will replace the polling mechanism with a proper event-driven approach using the existing TransitionEvent system for more robust and maintainable test infrastructure.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Replace while loop polling with event-driven TransitionEvent listening
- [x] #2 Battle completion detection no longer relies on brief POSTBATTLE state polling
- [x] #3 Test uses existing event-driven architecture patterns
- [x] #4 Battle animation runs successfully and test completes reliably
- [x] #5 Race conditions with state transitions are eliminated
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Locate the test_determinism_animated function in the codebase
2. Analyze the current while loop polling mechanism for POSTBATTLE state
3. Identify where TransitionEvent is already used for state transitions
4. Replace the polling loop with event-driven await using TransitionEvent
5. Test the new implementation to ensure battle completion is properly detected
6. Verify the test runs reliably without race conditions
7. Validate that the solution follows existing event-driven patterns in the codebase
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
This is a follow-up improvement to task-193 which addressed sequential action completion. While task-193 fixed the immediate issue, the underlying polling mechanism remains fragile and should be replaced with proper event-driven architecture.

## 🔍 Root Cause Investigation (2025-10-02)

### **Actual Problem Discovered**

The issue is NOT a polling mechanism problem. The real root cause is that **sequential actions don't emit completion events** because `auto_continue` flag is being incorrectly set to `true` during dispatch.

### **Evidence from Test Logs**

From `desktop_battle-animated_desktop_1759408705.log`:

1. **Action Dispatch** (debug_startup_coordinator.gd:100):
   ```
   "Dispatching action to idle queue" { "action": "game.lineup.populate_enemy" }
   ```

2. **Queue Addition** (core_event_resolver.gd:387):
   ```
   "Adding action to queue" { "auto_continue": true }  ← WRONG! Should be false
   ```

3. **Action Execution** (game.gd:258):
   ```
   "PROCESSING ONE QUEUE ITEM - EXECUTING ACTION" { "auto_continue": true }
   ```

4. **Action Completion** (debug_action.gd:306):
   ```
   "Completed: game.lineup.populate_enemy"
   "DEBUG_TEST_SUCCESS" { "action": "game.lineup.populate_enemy", "duration_ms": 75 }
   ```

5. **NO Completion Event** - Code at `debug_action.gd:309-321` only emits when `if not auto_continue`:
   ```gdscript
   if not auto_continue:
       Log.info("Sequential action completed - emitting completion event", ...)
       core.action(core.SequentialActionCompleteEvent.new(...))
   ```

6. **Test Framework Timeout** (justfile-validation-enhanced-testing.justfile:765):
   ```bash
   # Searches for completion events that were never emitted
   COMPLETION_EVENTS=$(grep -c "Sequential action completed.*emitting completion event" "$LOG_FILE")
   # Found: 0/1 events → 30s timeout
   ```

### **Technical Analysis**

**Action Registration** (`project/debug/actions/registrations/game_actions.gd:100`):
```gdscript
DebugAction
  .create("game.lineup.populate_enemy", GameActionCore._populate_enemy_lineup)
  .set_auto_continue(false)  // ← Registered correctly
```

**Startup Coordinator Dispatch** (`debug_startup_coordinator.gd:112`):
```gdscript
var action := _get_action_by_name(registry, action_name)
var auto_continue: bool = _should_action_auto_continue(action)
core.action(core.SystemIdleActionEvent.new(callable, auto_continue))
```

**Expected**: `_should_action_auto_continue(action)` should return `false`
**Actual**: Returns `true` (proven by logs)

### **Root Cause Hypotheses**

1. **Registry Clone Issue**: `_get_action_by_name()` returns a copy/clone without preserving `auto_continue` property
2. **Default Value Problem**: `DebugAction.auto_continue` defaults to `true`, and `set_auto_continue(false)` doesn't persist
3. **Reference vs Value**: The action reference is correct but property read returns default value
4. **Timing Issue**: Registration happens after coordinator reads actions (unlikely - would error)

### **Diagnostic Plan**

Add targeted debug logging to trace `auto_continue` value:

1. **In action registration** - Log actual property value after `set_auto_continue(false)`
2. **In `_get_action_by_name()`** - Log action found and its `auto_continue` value
3. **In `_should_action_auto_continue()`** - Log input action and returned value
4. **In dispatcher** - Log final `auto_continue` value being used

### **Impact Analysis**

**Affected Configs** (17 total from test summary):
- `battle-animated` (desktop & android) - populate_enemy action
- `firebase-backend-batch-1/2/3` (android) - Firebase backend actions
- `firebase-backend-layer` (android) - Firebase lifecycle actions
- `firebase-rtdb-layer` (android) - RTDB transaction/batch operations
- `system-performance` (android) - Performance test actions

**Common Pattern**: All use actions registered with `set_auto_continue(false)` for sequential processing.

### **Why Tests Pass Despite Timeout**

Critical insight: **Tests succeed functionally but timeout waiting for completion events**

- Actions execute correctly (100% pass rate)
- Business logic works (battle animation runs, Firebase operations succeed)
- Only the test framework's completion event detection times out
- This is a **logging/coordination issue**, not a functional bug

**Test Framework Safety**: 30s timeout is safety mechanism - proceeds after timeout with warning.

### **Revised Implementation Strategy**

~~1. Replace while loop polling~~ ← Original plan, but wrong problem
~~2. Use TransitionEvent system~~ ← Not the actual issue

**Correct Approach**:
1. **Fix auto_continue property propagation** - Ensure actions retain correct flag through registry
2. **Add debug logging** - Trace exact point where flag becomes incorrect
3. **Verify completion events** - Confirm events emit after fix
4. **Remove timeout warnings** - Clean test output once events work

### **Success Criteria (Updated)**

- [x] `auto_continue` property correctly propagates from registration to dispatch
- [x] Sequential actions emit "Sequential action completed - emitting completion event" log
- [x] Test framework detects completion events (no 30s timeout)
- [x] All 17 affected configs complete without timeout warnings
- [x] 100% action pass rate maintained (currently working)

---

## ✅ Resolution (2025-10-03)

### **Actual Root Cause**

The investigation revealed the real issue was NOT `auto_continue` flag propagation (which was correct). The problem was **GDScript async function behavior with polling loops**:

```gdscript
# PROBLEMATIC CODE (game_action_core.gd:856-857)
while game.game_handler.current_gamestate != core.GameState.POSTBATTLE:
    await Engine.get_main_loop().process_frame  # Function returns immediately!
```

When a GDScript function contains `await`, it becomes asynchronous and **returns immediately** before the loop completes. The completion event emission code in `debug_action.gd:321` never executes because the function has already returned.

### **Solution: Event-Driven Architecture**

Replaced fragile polling loops with robust event-driven waiting using existing `SignalAwaiter` utility:

**Files Modified:**
- `project/debug/actions/registrations/game_action_core.gd:853-857` - Replaced polling loops
- `project/debug/actions/registrations/game_action_core.gd:285-310` - Added helper functions

**Implementation:**
```gdscript
# Event-driven: Wait for state to change from initial state
await _await_state_transition_away_from(initial_state)

# Event-driven: Wait for POSTBATTLE state
await _await_state_transition_to(core.GameState.POSTBATTLE)
```

**Helper Functions:**
```gdscript
static func _await_state_transition_to(target_state: core.GameState) -> void:
    var state_awaiter: SignalAwaiter.Any = SignalAwaiter.Any.new()

    var transition_handler: Callable = func(event_data: core.CoreEvent) -> void:
        if event_data is core.TransitionEvent:
            var transition: core.TransitionEvent = event_data as core.TransitionEvent
            if transition.new_state == target_state:
                state_awaiter.finished.emit()

    core.event.connect(transition_handler, CONNECT_ONE_SHOT)
    await state_awaiter.finished
```

### **Test Results**

**Before:**
- 17 configs with 30s timeout warnings
- `game.battle.test_determinism_animated` - 1/1 sequential actions, 0/1 completion events

**After:**
- ✅ **36/36 configs passed** (100% success rate)
- ✅ **All sequential actions emit completion events**
- ✅ **No timeout warnings**
- ✅ Clean event-driven architecture using existing patterns

**Evidence:**
```
battle-animated_desktop_1759442808:
✅ All sequential actions completed (2/2)
  - game.lineup.populate_enemy - ✅ emitted
  - game.battle.test_determinism_animated - ✅ emitted
```

### **Key Learnings**

1. **Investigation-First Methodology Works**: Initial investigation of `auto_continue` flag was a detour, but systematic evidence gathering revealed the true async behavior issue
2. **Use Existing Patterns**: `SignalAwaiter` utility was already available and designed for this exact use case
3. **Event-Driven > Polling**: TransitionEvent listening is more robust than frame-by-frame state polling
4. **GDScript Async Behavior**: Functions with `await` return immediately - critical for understanding completion event emission

### **Related Commits**
- Event-driven battle completion using SignalAwaiter (this implementation)
- Closes: task-195
- Related: task-193 (sequential action completion events)
<!-- SECTION:NOTES:END -->
