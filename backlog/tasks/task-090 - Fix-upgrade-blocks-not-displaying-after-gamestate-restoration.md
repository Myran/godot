---
id: task-090
title: Fix upgrade blocks not displaying after gamestate restoration
status: Done
assignee: []
created_date: '2025-08-22 06:24'
completed_date: '2025-08-22 10:26'
labels:
  - gamestate
  - ui
  - clicker
  - bugs
dependencies: []
priority: high
---

## Description

Upgrade blocks are correctly instantiated and added to the scene tree during gamestate restoration but do not display in the clicker UI due to duplicate addition conflicts. All data layer operations work correctly - blocks have proper levels, positions, and visibility properties. Root cause identified as upgrade blocks being added twice (during initialization and restoration) while other block types work fine.

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Upgrade blocks display properly in clicker UI after gamestate restoration,Debug logs show upgrade blocks are added only once during restoration process,All existing upgrade block functionality remains intact,Other block types continue to work without regression
<!-- AC:END -->

## Implementation Summary

**Root Cause**: Duplicate block creation - upgrade blocks were created twice during gamestate loading:
1. Once during normal startup from tilemap (9 blocks)
2. Again during gamestate deserialization (9 more blocks at same positions)
3. Result: 18 blocks with visual conflicts, preventing proper UI display

**Solution**: Implemented gamestate loading mode detection system to conditionally skip tilemap block creation when loading from saved state.

### Key Changes

1. **Early Detection System** (`DebugConfigReader.has_gamestate_loading_action()`)
   - Detects `"system.debug.load_gamestate"` action during initialization
   - Enables gamestate loading mode before any setup occurs

2. **Conditional Block Creation** (`LevelController._gamestate_loading_mode`)
   - Skips `create_blocks_from_level()` when gamestate loading mode is active
   - Allows blocks to be restored from saved state instead

3. **Silent Cleanup Methods**
   - `Block.block_force_destroy_silent()` - Event-free block destruction
   - `Holder.force_clear_silent()` - Event-free holder cleanup
   - Prevents gameplay events during state reset

4. **Clean Startup** (`just run-desktop` config clearing)
   - Removes leftover debug configs to ensure predictable behavior
   - Prevents gamestate mode from persisting after testing

5. **Comprehensive State Reset**
   - Resets all handlers (GameHandler, InputHandler, DraftHandler, etc.)
   - Clears action queues and UI state during gamestate loading

### Results
- ✅ **Exactly 9 upgrade blocks** created (no duplicates)
- ✅ **Proper UI display** after gamestate restoration
- ✅ **Clean separation** between normal startup and gamestate loading
- ✅ **All block types work correctly** without regression

## Completion Summary

**Completed 2025-08-22**: Successfully resolved upgrade blocks display issue after gamestate restoration.

**Commit**: `732f800` - [fix: resolve upgrade blocks display issue after gamestate restoration](../../commit/732f800)
