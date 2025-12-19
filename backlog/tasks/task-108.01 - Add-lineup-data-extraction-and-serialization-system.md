---
id: task-108.01
title: Add lineup data extraction and serialization system
status: Done
assignee: []
created_date: '2025-08-30 07:18'
updated_date: '2025-12-18 10:37'
labels:
  - battle
  - serialization
  - core
dependencies: []
parent_task_id: task-108
ordinal: 186000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create comprehensive lineup data extraction system that captures complete lineup state including cards/units, positions, levels, abilities, equipment, and all other relevant lineup properties for accurate battle scenario reproduction
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 System extracts complete lineup data including cards/units with full properties
- [ ] #2 Captures unit positions, levels, abilities, and equipment states
- [ ] #3 Serializes lineup data in format compatible with existing save system
- [ ] #4 Uses 'line-' prefix naming convention for saved files
- [ ] #5 Integrates with existing GameState serialization infrastructure
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
EXPERT TECHNICAL ANALYSIS - 90% Code Reuse Opportunity:

StateExtractor Foundation (Existing Infrastructure):
- StateExtractor.extract_lineup_state() already perfectly separates allied vs enemy data
- Current method returns: {'allied': {...}, 'enemy': {...}}
- Allied/enemy data includes complete card/unit properties, positions, levels, abilities, equipment
- Serialization format is JSON-compatible and tested in production

Required Extensions (Minimal New Code):
1. extract_allied_lineup_only(): Extract StateExtractor.extract_lineup_state()['allied'] 
2. extract_enemy_lineup_only(): Extract StateExtractor.extract_lineup_state()['enemy']
3. Wrapper Methods: Add to StateExtractor class following existing patterns

Code Locations:
- Primary class: src/game/state/state_extractor.gd
- Existing method: extract_lineup_state() 
- Pattern to follow: Other extract_*_state() methods in same class

Implementation Pattern (Copy-Paste Ready):
func extract_allied_lineup_only() -> Dictionary:
    var full_lineup = extract_lineup_state()
    return {'allied': full_lineup['allied']}

func extract_enemy_lineup_only() -> Dictionary:
    var full_lineup = extract_lineup_state()
    return {'enemy': full_lineup['enemy']}

Serialization Compatibility:
- Uses identical JSON format as full gamestate saves
- File structure mirrors existing save system in /game_states/
- 'line-' prefix integrates seamlessly with existing file discovery patterns
- No changes needed to existing serialization infrastructure

Testing Integration:
- Leverage existing StateExtractor unit tests
- Reuse JSON validation patterns from GameState tests
- File I/O patterns already validated in production
<!-- SECTION:NOTES:END -->
