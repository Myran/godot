---
id: task-006
title: Document Mooseman unit abilities and stats
status: Done
assignee: []
created_date: '2025-08-08 23:09'
updated_date: '2025-12-18 10:37'
labels:
  - creature
  - documentation
  - abilities
dependencies: []
ordinal: 246000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Document and validate the Mooseman unit (ID: 3) with Merge Shield ability that provides defensive capability when merged
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Mooseman unit has correct base stats (2/3, evil tribe)
- [ ] #2 Merge Shield ability properly documented
- [ ] #3 Shield activation occurs only when merged
- [ ] #4 Implementation for abilities_mooseman.gd is accurate
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Complexity**: 🟢 Simple
**Current System**: ✅ Perfect fit for existing event-driven architecture

### Technical Approach
Create `MergeShieldAbility` that extends the base `Ability` class and responds to merge events:

```gdscript
class_name MergeShieldAbility extends Ability

func handle_draft_event(phase: core.Tempus, unit_position: int, unit: Block, draft_context: DraftContext, draft_event: core.CoreEvent) -> void:
    if phase == core.Tempus.POST and draft_event is core.MergeEvent:
        var merge_event: core.MergeEvent = draft_event as core.MergeEvent
        if merge_event.target_unit == unit:
            # Grant shield ability to the unit
            var shield_ability: DamageShieldAbility = DamageShieldAbility.new()
            shield_ability.persistence_type = Ability.PersistenceType.ENHANCEMENT
            unit.add_ability(shield_ability)
            unit.show_shield()  # Visual feedback
```

### Required Changes
1. **AbilitiesHandler Extension**: Add "merge_shield" case to parser
2. **MergeEvent Integration**: Ensure merge events are properly fired
3. **Visual System**: Shield display integration
4. **Dynamic Ability Addition**: System to add abilities at runtime

### Dependencies
- Existing merge event system (✅ Available via `core.MergeEvent`)
- `DamageShieldAbility` class (✅ Already implemented)
- Dynamic ability addition system (📋 Need to verify/implement)
- Shield visual system (📋 Need to verify)

### Technical Details
- **Trigger**: Only activates when this unit is the **target** of a merge
- **Shield Type**: Uses existing `DamageShieldAbility` with ENHANCEMENT persistence
- **Visual Feedback**: Shield indicator appears after merge completion
- **Stacking**: Multiple merges could grant multiple shields (design decision needed)

### Testing Strategy
- Test merge with Mooseman as target (should gain shield)
- Test merge with Mooseman as source (should not affect shield)
- Test shield functionality after merge (blocks one damage)
- Test visual shield indicator appears correctly
- Test persistence through battle transitions
<!-- SECTION:PLAN:END -->
