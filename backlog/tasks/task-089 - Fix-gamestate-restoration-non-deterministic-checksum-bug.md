---
id: task-089
title: Fix gamestate restoration non-deterministic checksum bug
status: In Progress
assignee: []
created_date: '2025-08-21 06:58'
updated_date: '2025-08-21 07:45'
labels:
  - bug
  - gamestate
  - checksum-validation
  - deterministic
  - testing
dependencies: []
priority: high
---

## Description

Critical bug in gamestate save/load system where save-load-save cycles produce different checksums for functionally identical game states. This prevents perfect deterministic validation and affects automated testing reliability. Bug discovered during validation testing on August 21, 2025. Save process is deterministic (confirmed working), but load process creates non-deterministic state variations. Functional game state preservation works correctly, but issue blocks perfect automated validation and deterministic testing. Root cause likely in async card recreation order or state transition side effects.

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Save-Load-Save cycle produces identical checksums
- [ ] #2 Restoration preserves exact field-by-field state data
- [ ] #3 Async operations don't affect final state determinism
- [ ] #4 All existing functionality continues to work
- [ ] #5 Investigation identifies root cause of non-deterministic state variations
<!-- AC:END -->

## Implementation Plan

### Investigation Phase (30 minutes)
1. Compare state extraction before/after load using StateExtractor
2. Create test case: save state → load state → save again → compare checksums
3. Log detailed field-by-field comparison to identify varying fields

### Root Cause Analysis (1-2 hours)
1. **Card Recreation Order**: Investigate if cards are recreated in different orders
   - Check `_restore_board_content` method in `project/core/game.gd`
   - Verify card instantiation order determinism
   - Add logging to card deserialization in `project/core/clicker/blocks/block_base_card.gd`

2. **State Transition Effects**: Look for side effects during state loading
   - Check for async operations that complete after load
   - Verify RNG state is properly restored before any operations
   - Investigate signal connections that might trigger during load

3. **Field-Level Analysis**: Identify specific fields causing checksum differences
   - Use StateExtractor to compare pre/post load states
   - Focus on arrays, dictionaries, and object references
   - Check for timestamp or session-specific data leaking into state

### Fix Implementation (1 hour)
1. Ensure deterministic card recreation order (likely sorting by position/id)
2. Add synchronization points for async operations
3. Isolate state loading from side effects

### Validation (30 minutes)
1. Add automated test for save-load-save cycle checksum validation
2. Test multiple scenarios: empty board, complex lineups, mid-battle states
3. Verify fix doesn't break existing functionality

## Files to Investigate
- `project/core/game.gd` (load_state_from_file, _restore_board_content methods)
- `project/misc/state_extractor.gd` (state extraction logic)
- `project/core/clicker/blocks/block_base_card.gd` (card deserialization)
- `project/core/saves/gamestate_save_manager.gd` (save/load coordination)

## Estimated Timeline
- **Total**: 6-8 hours (4-6 hours investigation/fix + 2 hours testing)
- **Priority**: P1-High (blocks automated testing validation)
