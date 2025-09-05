---
id: task-108.02
title: Add 'Save Allied Lineup' and 'Save Enemy Lineup' buttons to debug menu
status: Done
assignee: []
created_date: '2025-08-30 07:18'
updated_date: '2025-09-04 20:45'
labels:
  - debug
  - ui
  - menu
dependencies: []
parent_task_id: task-108
---

## Description

Add 'Save Allied Lineup' and 'Save Enemy Lineup' buttons to existing debug menu interface using same location and interaction pattern as existing 'Save State' functionality, with both buttons using simple 'line-' naming convention

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] Debug menu displays both 'Save Allied Lineup' and 'Save Enemy Lineup' buttons
- [ ] Both buttons use simple 'line-' prefix naming convention (e.g. 'line-scenario-name')
- [ ] Buttons follow same user interaction pattern as current save system
- [ ] Buttons trigger lineup data extraction and save with user-provided name
- [ ] Save process provides feedback on success/failure for both button types
- [ ] Buttons are located in same menu section as existing 'Save State' button
- [ ] Buttons are available at same times as existing full save functionality
<!-- AC:END -->

## Implementation Notes

EXPERT TECHNICAL ANALYSIS - Debug Action Pattern Reuse:

SaveDebugStateAction Pattern (90% Code Reuse):
- Existing SaveDebugStateAction provides complete save workflow template
- Current implementation handles UI prompts, file naming, error handling, success feedback
- Copy-paste pattern: SaveAlliedLineupAction and SaveEnemyLineupAction classes
- File location: src/debug/actions/save_debug_state_action.gd (pattern to copy)

Required New Action Classes:
1. SaveAlliedLineupAction: Copy SaveDebugStateAction, replace state extraction call
2. SaveEnemyLineupAction: Copy SaveDebugStateAction, replace state extraction call
3. Action Registration: Add to src/debug/system_actions.gd following existing patterns

Debug Menu Integration (Automatic Discovery):
- Debug menu dynamically discovers registered actions through ActionRegistry
- No manual menu changes required - actions auto-appear in menu
- Button placement controlled by action registration order in system_actions.gd
- UI interaction patterns identical to existing Save State button

Key Code Changes (Minimal):
1. Copy SaveDebugStateAction class twice with new names
2. Replace extract_full_state() calls with extract_allied_lineup_only()/extract_enemy_lineup_only()
3. Update action names and descriptions in new classes
4. Register both new actions in system_actions.gd

File Naming Integration:
- 'line-' prefix handled automatically by save action prompt system
- User input validation follows existing patterns in SaveDebugStateAction
- File collision detection works unchanged
- Error handling patterns ready for reuse

Success/Failure Feedback:
- Message display system identical to existing save functionality
- Error handling patterns from SaveDebugStateAction work unchanged
- Progress indicators and user feedback already implemented

Implementation Effort: ~20 lines of new code (mostly copy-paste with method name changes)
