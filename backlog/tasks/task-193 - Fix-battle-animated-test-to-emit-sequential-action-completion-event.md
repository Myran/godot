---
id: task-193
title: Fix battle-animated test to emit sequential action completion event
status: Done
assignee: []
created_date: '2025-10-02 13:49'
updated_date: '2025-10-21'
labels:
  - testing
  - battle
  - sequential-actions
  - timeout
dependencies: []
priority: medium
---

## Description

The `game.battle.test_determinism_animated` action triggers a battle and waits for it to complete, but doesn't emit a sequential action completion event. This causes a 30-second timeout in the test framework.

**⚠️ CRITICAL DISCOVERY (2025-10-02):**
The timeout was masking a deeper issue - **the test configuration itself is broken**. The `populate_enemy` action succeeds but doesn't actually add enemy cards to the lineup, so the battle never starts and the test hangs forever waiting for POSTBATTLE gamestate.

**⚠️ REOPENED (2025-10-21):**
Task was marked as Done but the issue persists. Desktop test logs from 2025-10-21 show:
- Test still hanging waiting for sequential action completion
- Found 2 sequential actions, only 1/2 completion events received
- Test times out after 30 seconds waiting for missing completion event
- Source: `logs/20251021_133024_test.log` - battle-animated test still failing

**✅ RESOLVED (2025-10-21):**
Root cause identified and fixed:
- **Problem**: `CONNECT_ONE_SHOT` flag on signal handler caused handler to disconnect after receiving the first non-TransitionEvent
- **Impact**: Handler fired on first Resource event (grid blocks, etc.), failed TransitionEvent check, disconnected before actual TransitionEvent arrived
- **Solution**: Removed `CONNECT_ONE_SHOT`, manually disconnect only when correct TransitionEvent received
- **Files Changed**: `project/debug/actions/registrations/game_action_core.gd:542-545` (removed ONE_SHOT), added manual disconnect logic
- **Test Results**: ✅ ALL 4 actions pass, completion event properly emitted, test completes in ~10s

## Root Cause Analysis

### Initial Analysis (Incorrect)
Originally thought the issue was just missing `auto_continue: false` flag on the action registration.

### Actual Root Cause (Discovered via Investigation)
1. **Action Architecture**: `_battle_test_determinism()` dispatches internal `_trigger_start_battle` callable with `auto_continue: false` (default)
2. **Dual Sequential Actions**: Creates TWO sequential actions - parent test + internal battle start
3. **Missing Completion Events**: Neither emits completion events because:
   - Internal callable isn't a full DebugAction → never emits events
   - Parent action never completes → stuck in await loop
4. **Test Configuration Broken**: `populate_enemy` reports SUCCESS but lineup empty:
   ```
   "allies": {},
   "enemies": {}
   ```
5. **Battle Never Starts**: No enemy cards → can't transition to BATTLE/POSTBATTLE
6. **Infinite Wait**: Hangs in `while game.game_handler.current_gamestate != core.GameState.POSTBATTLE`

## Evidence (Log Analysis)

From `desktop_battle-animated_desktop_1759417840.log`:
- ✅ `populate_enemy` shows DEBUG_TEST_SUCCESS (59ms)
- ❌ Checksum shows empty lineups: `"lineup_allies_count": 0`, `"enemies": {}`
- ❌ Stuck at: `"current_state": "PREBATTLE"`
- ❌ Session end: `"enemy_lineup_count": 0`, `"enemy_cards": []`
- ⏱️ "Found 1 sequential action(s), 00 completion event(s)" → 30s timeout

## Partial Implementation (Completed)

### Changes Made:

**1. Added `set_auto_continue()` method** (`project/debug/actions/debug_action.gd:67-69`):
```gdscript
func set_auto_continue(p_auto_continue: bool) -> DebugAction:
    auto_continue = p_auto_continue
    return self
```

**2. Configured action as sequential** (`project/debug/actions/registrations/game_actions.gd:253`):
```gdscript
. set_auto_continue(false)  // ADDED
```

**3. Fixed internal battle dispatch** (`project/debug/actions/registrations/game_action_core.gd:851`):
```gdscript
core.SystemIdleActionEvent.new(Callable(GameActionCore, "_trigger_start_battle"), true)
```
Changed from default `false` to `true` to prevent internal action being sequential.

## 🚫 Blocking Issue

**The test configuration is fundamentally broken.** Completion event emission won't help because the action never completes - it's stuck waiting for a battle that never starts.

## Next Steps (Required to Unblock)

### Option 1: Fix populate_enemy Action ⭐ Recommended
Investigate why `game.lineup.populate_enemy` succeeds but doesn't populate:
- Card creation in `_populate_enemy_lineup()` (game_action_core.gd)
- EnemyLineupAddCardEvent handling
- Lineup state management during PREPARE phase

### Option 2: Use Different Action
Replace with action that properly sets up battle:
- `game.battle.populate_enemy_and_start` - combines populate + start
- Manual lineup setup sequence

### Option 3: Historical Investigation
Check **task-162** (Done) - test WAS working before. What changed?

## Related Tasks

- **task-162** (Done): "Fix battle-animated test infrastructure failure" - may contain clues
- **task-190**: Test infrastructure timeout handling
- **task-194**: Firebase batch operation completion events

## Files Modified

- `project/debug/actions/debug_action.gd:67-69` - Added set_auto_continue()
- `project/debug/actions/registrations/game_actions.gd:253` - Added .set_auto_continue(false)
- `project/debug/actions/registrations/game_action_core.gd:851` - Internal battle auto_continue: true

## Testing Status

✅ **Test now passes completely (2025-10-21)**
- ✅ All 4 actions execute successfully
- ✅ Completion events emitted properly
- ✅ Test completes in ~10 seconds
- ✅ No timeouts or errors

**Test Results:**
```
✅ Total Actions: 4/4 (100%)
- game.debug.hide_debug_menu: ✅ 6ms
- game.lineup.populate_enemy: ✅ 63ms
- game.battle.test_determinism_animated: ✅ 9943ms
- system.debug.replay_complete: ✅ 2ms
```

## Resolution Summary

**Root Cause:** Signal handler with `CONNECT_ONE_SHOT` disconnected after receiving first non-TransitionEvent, missing the actual TransitionEvent that arrived later.

**Solution:** Removed `CONNECT_ONE_SHOT` flag, added manual disconnect logic that only triggers when the correct TransitionEvent is detected.

**Impact:** Battle-animated test now fully functional for regression testing and determinism validation.
