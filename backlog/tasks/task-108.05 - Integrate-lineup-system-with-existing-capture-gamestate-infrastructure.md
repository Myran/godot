---
id: task-108.05
title: Integrate lineup system with existing capture-gamestate infrastructure
status: To Do
assignee: []
created_date: '2025-08-30 07:19'
updated_date: '2025-08-30 08:02'
labels:
  - integration
  - infrastructure
dependencies: []
parent_task_id: task-108
---

## Description

Integrate lineup save/load system with existing capture-gamestate infrastructure to leverage existing file management, naming conventions, and cross-platform compatibility

## Acceptance Criteria

- [ ] Lineup system uses same directory structure as existing saved states
- [ ] System leverages existing file management utilities and error handling
- [ ] Integration maintains cross-platform compatibility (desktop/android)
- [ ] Lineup saves work with existing 'just list-saved-states' and 'just clean-saved-states' commands
- [ ] System follows established patterns for save file validation and integrity checks

## Implementation Notes

EXPERT TECHNICAL ANALYSIS - CLI Infrastructure Integration:

Existing Justfile Architecture (Perfect Foundation):
- Current capture-gamestate commands provide complete infrastructure template
- File management, error handling, cross-platform compatibility already implemented
- Android chunking system handles large data automatically
- Log extraction patterns ready for lineup-specific markers

Required CLI Extensions (Minimal Effort):
1. **New Log Markers**: DEBUG_LINEUP_ALLIED_CAPTURE and DEBUG_LINEUP_ENEMY_CAPTURE
2. **New Commands**: capture-lineup-allied NAME and capture-lineup-enemy NAME
3. **Extended Commands**: list-saved-states and clean-saved-states work with 'line-' prefix automatically

Log Extraction Pattern Integration:
- Existing grep patterns for DEBUG_GAMESTATE_CAPTURE work unchanged
- Android chunking and reassembly works for lineup data size
- Log boundaries detection ('=== END GAMESTATE ===') extends to lineup markers
- Error handling for missing/incomplete captures already implemented

Command Implementation (Copy-Paste Ready):


File Management Integration:
- 'line-' prefix integrates seamlessly with existing file discovery
- list-saved-states already scans entire directory - lineup files appear automatically
- clean-saved-states pattern matching includes 'line-*' files by default
- File validation and integrity check patterns work unchanged

Cross-Platform Compatibility (Already Implemented):
- Desktop/Android log extraction patterns identical
- File system operations work across both platforms
- Error handling patterns (missing logs, incomplete captures) ready for reuse
- Command execution patterns (just android/desktop distinction) work unchanged

Workflow Integration:
- Existing replay/testing system compatibility maintained
- Battle testing workflows can integrate lineup switching seamlessly
- Error reporting and debugging patterns work for lineup operations
- Performance and timing characteristics identical to gamestate captures

Log Processing Infrastructure:
- Existing _extract-gamestate-content function works for lineup data
- Grep patterns, chunk detection, file reassembly all ready for reuse
- Android 4KB limit handling works for lineup-specific data
- Temporary file management and cleanup patterns work unchanged

Implementation Effort: ~10 lines of new Justfile commands + 2 new log markers in GDScript

Integration Benefits:
- Zero learning curve for users familiar with capture-gamestate commands
- Identical error handling and troubleshooting patterns
- Same performance characteristics and reliability
- Automatic compatibility with future infrastructure improvements
