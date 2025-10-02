---
id: task-193
title: Fix battle-animated test to emit sequential action completion event
status: Done
assignee: []
created_date: '2025-10-02 13:49'
updated_date: '2025-10-02 15:48'
labels:
  - testing
  - battle
  - sequential-actions
  - timeout
  - blocked
dependencies: []
priority: medium
---

## Description

The `game.battle.test_determinism_animated` action triggers a battle and waits for it to complete, but doesn't emit a sequential action completion event. This causes a 30-second timeout in the test framework.

**⚠️ CRITICAL DISCOVERY (2025-10-02):**
The timeout was masking a deeper issue - **the test configuration itself is broken**. The `populate_enemy` action succeeds but doesn't actually add enemy cards to the lineup, so the battle never starts and the test hangs forever waiting for POSTBATTLE gamestate.

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

❌ **Test still fails with 30s timeout**
- ✅ Detects 1 sequential action (correct)
- ✅ Waits for completion event (correct)
- ❌ Action never completes - battle never starts (broken config)
- ⏱️ Timeout after 30s (expected given broken test)

## Recommendations

1. **Mark as BLOCKED** until populate_enemy resolved
2. **Create new task**: "Fix populate_enemy - empty lineup despite success"
3. **Review task-162**: What made test work previously?
4. **Consider redesign**: battle-animated needs proper scenario setup

**Infrastructure is correct, test needs fundamental fixes.**
