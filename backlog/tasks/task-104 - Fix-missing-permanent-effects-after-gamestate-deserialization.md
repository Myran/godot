---
id: task-104
title: Fix missing permanent effects after gamestate deserialization
status: Done
assignee: []
created_date: '2025-08-27 21:42'
updated_date: '2025-12-18 10:37'
labels:
  - bug
  - critical
  - gamestate
  - serialization
dependencies: []
priority: high
ordinal: 200000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Critical bug where units with permanent effects (MergeBonusAbility, SoldierBonusAbility, etc.) appear with base stats only after loading saved states. The deserialization process correctly restores StatEffect objects but fails to re-apply them to current stats, causing units to appear weaker than they should be.

**Root Cause**: Missing `apply_permanent_effects_to_current_stats()` call after deserialization in `/project/core/clicker/blocks/block_base_card.gd:_restore_unit_data_state()`

## Evidence 
- **Test Case**: test-capture-34 with 3 dwarfs 
- **Issue**: Level 2 dwarf showed 2/2 stats instead of expected 10/10 stats
- **Analysis**: StatEffect objects properly deserialized but not applied to `current_attack`/`current_health`

## Technical Details

**File**: `project/core/clicker/blocks/block_base_card.gd`  
**Function**: `_restore_unit_data_state()`  
**Fix**: Add `unit_data.apply_permanent_effects_to_current_stats()` call after line 370
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Units with permanent effects show correct bonuses after loading saved states
- [x] #2 test-capture-34 dwarfs display their MergeBonusAbility stat bonuses correctly  
- [x] #3 Checksum validation passes after loading states with permanent effects
- [x] #4 Cross-platform consistency verified between Android and Desktop
- [x] #5 All unit types with permanent effects work correctly (dwarfs, guards, etc)
- [x] #6 Enhanced logging added for debugging effect application during deserialization
<!-- AC:END -->
