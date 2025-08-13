---
id: task-004
title: Document Guard unit abilities and stats
status: To Do
assignee: []
created_date: '2025-08-08 23:09'
labels:
  - creature
  - documentation
  - abilities
dependencies: []
---

## Description

Document and validate the Guard unit (ID: 1) with Knight Bonus ability that gains +1/+1 for each friendly knight unit when recruited

## Acceptance Criteria

- [ ] Guard unit has correct base stats (1/2, soldier tribe)
- [ ] Knight Bonus ability is properly documented
- [ ] Implementation details for abilities_guard.gd are accurate
- [ ] Unit behavior is consistent with description

## Implementation Plan

**Complexity**: 🟢 Simple
**Current System**: ✅ Perfect fit for existing event-driven architecture

### Technical Approach
Create `KnightBonusAbility` that extends the base `Ability` class and leverages the existing draft event system:

```gdscript
class_name KnightBonusAbility extends Ability

func handle_draft_event(phase: core.Tempus, unit_position: int, unit: Block, draft_context: DraftContext, draft_event: core.CoreEvent) -> void:
    if phase == core.Tempus.POST and draft_event is core.LineupAddCardFromDraftEvent:
        var knight_count = count_tribe_in_lineup(draft_context.lineup, "knight", unit)
        if knight_count > 0:
            var stat_change = core.CardStatChangeEvent.new(unit, knight_count, knight_count)
            draft_context.add_event(stat_change)
```

### Required Changes
1. **AbilitiesHandler Extension**: Add "knight_bonus" case to parser
2. **Utility Function**: Create `count_tribe_in_lineup()` helper function
3. **Integration**: Works seamlessly with existing `core.LineupAddCardFromDraftEvent` system

### Dependencies
- Existing draft event system (✅ Available)
- Card stat change events (✅ Available)  
- Tribe counting utilities (📋 Need to create)

### Testing Strategy
- Test with lineups containing 0, 1, 2, 3+ knights
- Verify stat bonuses apply correctly on recruitment
- Ensure no bonuses when no knights present
- Validate behavior with mixed tribe lineups
