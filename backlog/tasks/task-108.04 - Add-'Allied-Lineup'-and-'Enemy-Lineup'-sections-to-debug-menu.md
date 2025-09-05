---
id: task-108.04
title: Add 'Allied Lineup' and 'Enemy Lineup' sections to debug menu
status: Done
assignee: []
created_date: '2025-08-30 07:19'
updated_date: '2025-09-04 20:44'
labels:
  - debug
  - ui
  - menu
dependencies: []
parent_task_id: task-108
---

## Description

Add 'Allied Lineup' and 'Enemy Lineup' sections to debug menu that display saved lineups and provide loading functionality for each battle slot independently

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] Debug menu displays 'Allied Lineup' section
- [ ] Debug menu displays 'Enemy Lineup' section  
- [ ] Both sections list all available saved lineups with 'line-' prefix
- [ ] Selecting lineup from Allied section loads into allied slot
- [ ] Selecting lineup from Enemy section loads into enemy slot
- [ ] Same lineup files appear in both sections for maximum flexibility
- [ ] Sections display lineup names in user-friendly format (without technical prefixes)
- [ ] Menu sections integrate with existing debug menu layout and styling
- [ ] Menu sections update dynamically when new lineups are saved
<!-- AC:END -->

## Implementation Notes

EXPERT TECHNICAL ANALYSIS - Menu System Extension:

Debug Menu Architecture (Pattern Reuse):
- Debug menu uses dynamic ViewLevel enum system for navigation
- Current 'Saved States' section provides exact template to follow
- Need 2 new ViewLevel entries: ALLIED_LINEUPS and ENEMY_LINEUPS
- File discovery pattern from _populate_saved_states_view() ready for reuse

Required Enum Extensions:
1. ViewLevel enum: Add ALLIED_LINEUPS and ENEMY_LINEUPS entries
2. ItemType enum: Add ALLIED_LINEUP and ENEMY_LINEUP entries (in MenuListItemData)
3. Navigation handler: Add cases to _on_navigator_item_selected()

UI Implementation Pattern (Copy-Paste Ready):
- Copy _populate_saved_states_view() → _populate_allied_lineups_view()
- Copy _populate_saved_states_view() → _populate_enemy_lineups_view()
- Implement _scan_and_add_lineup_files() with 'line-' prefix filtering
- File discovery uses existing FileManager.scan_saved_states() pattern

File Discovery Strategy:
- Same 'line-' files appear in both Allied and Enemy sections
- User selection determines target slot (allied vs enemy) for surgical replacement
- File names display without 'line-' prefix for clean UI presentation
- Dynamic updates through existing file system monitoring patterns

Navigation Integration:
- Extend _on_navigator_item_selected() switch statement
- Add cases for ViewLevel.ALLIED_LINEUPS and ViewLevel.ENEMY_LINEUPS
- Loading actions triggered with slot parameter (allied/enemy)
- Error handling follows existing menu error patterns

Key Implementation Files:
- Main controller: src/debug/debug_menu_controller.gd
- Menu data: MenuListItemData class extensions
- File operations: Extend existing FileManager scan methods

Menu Layout Integration:
- Add lineup sections after existing 'Saved States' section
- Follow existing menu styling and spacing patterns
- Use consistent iconography and color schemes
- Maintain menu responsiveness and navigation flow

Dynamic Update Strategy:
- Leverage existing file system monitoring for menu updates
- Same refresh patterns as current saved states functionality
- Menu rebuilds automatically when lineup files added/removed
- No manual refresh required for user experience

Implementation Complexity: Low-Medium - mostly copy-paste patterns with filtering modifications
