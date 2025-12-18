---
id: task-108.03
title: Implement lineup loading system with allied/enemy slot assignment
status: Done
assignee: []
created_date: '2025-08-30 07:18'
updated_date: '2025-12-18 10:37'
labels:
  - battle
  - loading
  - core
dependencies: []
parent_task_id: task-108
ordinal: 188000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement lineup loading system that can restore saved lineups to specific battle slots (allied or enemy) independently, allowing battle scenario testing with mixed lineup configurations
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 System can load saved lineups with 'line-' prefix from existing save directory
- [ ] #2 Loading system can target specific battle slots (allied or enemy)
- [ ] #3 Any lineup file can be loaded into either allied or enemy slot
- [ ] #4 Loading lineup to allied slot does not affect enemy lineup
- [ ] #5 Loading lineup to enemy slot does not affect allied lineup
- [ ] #6 Loaded lineups maintain all original properties (cards, positions, levels, abilities, equipment)
- [ ] #7 Loading integrates with existing file management and validation systems
- [ ] #8 System enables flexible testing by allowing same lineup in either battle slot
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
EXPERT TECHNICAL ANALYSIS - Surgical State Replacement:

LoadDebugStateAction Extension Pattern:
- Existing LoadDebugStateAction provides file loading, validation, error handling infrastructure
- Current implementation loads full gamestate with complete replacement
- Need surgical replacement logic that targets specific lineup slots only
- Core loading mechanics (file I/O, JSON parsing, validation) ready for reuse

Required Implementation Approaches:
1. **Extend LoadDebugStateAction**: Add surgical replacement mode parameter
2. **New LineupRestorer Utility**: Standalone class for surgical lineup operations
3. **Game Class Extensions**: Direct lineup replacement methods in Game class

Surgical Replacement Logic (Key Technical Challenge):
- Load lineup file containing {'allied': {...}} or {'enemy': {...}}
- Identify target slot (allied or enemy) from user selection
- Extract lineup data from appropriate key in loaded file
- Replace target lineup slot in current game state without affecting other slot
- Preserve all other game state (resources, turn state, battle phase, etc.)

File Compatibility Strategy:
- 'line-' prefix files contain both allied and enemy data from original save
- Loading system extracts appropriate portion based on target slot selection
- Same file can load allied lineup to enemy slot or vice versa for flexible testing
- File structure: {'allied': {...}, 'enemy': {...}} - use target key for replacement

Integration Points:
- Game class has existing lineup management methods for battle setup
- Current battle initialization can be leveraged for lineup replacement
- State validation systems work unchanged for surgical replacements
- Error handling patterns from full state loading apply directly

Key Implementation Decisions:
- Preserve turn order and battle phase during lineup replacement
- Handle unit references and relationships properly during replacement
- Maintain deterministic behavior for testing consistency
- Validate lineup data compatibility with current game version

Complexity Assessment: Medium - requires careful state management but leverages existing infrastructure extensively
<!-- SECTION:NOTES:END -->
