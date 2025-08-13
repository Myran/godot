---
id: task-005
title: Document Old Man unit abilities and stats
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

Document and validate the Old Man unit (ID: 2) with Shield and Merge Bonus abilities providing defensive capabilities and growth through merging

## Acceptance Criteria

- [ ] Old Man unit has correct base stats (1/1, villager tribe)
- [ ] Shield ability activates on battle start and recruitment
- [ ] Merge Bonus ability grants +1/+1 when merged
- [ ] Implementation for abilities_oldman.gd is accurate

## Implementation Plan

**Complexity**: 🟢 Simple
**Current System**: ✅ Already has both required abilities implemented

### Technical Approach
The Old Man unit requires a **composite ability approach** - simply assign both existing abilities:

```gdscript
# In unit configuration or parsing:
old_man_abilities = [
    DamageShieldAbility.new(),
    MergeBonusAbility.new(1, 1)  # +1/+1 on merge
]
```

### Required Changes
1. **AbilitiesHandler Extension**: Add "shield_and_merge" composite case
2. **Unit Configuration**: Apply both abilities to Old Man unit template
3. **No New Classes Needed**: Leverage existing `DamageShieldAbility` and `MergeBonusAbility`

### Dependencies
- `DamageShieldAbility` (✅ Already implemented)
- `MergeBonusAbility` (✅ Already implemented)
- Composite ability assignment system (📋 Minor parser update)

### Technical Details
- **Shield Behavior**: Activates on battle start, recruitment, and spawning
- **Merge Behavior**: Triggers when this unit is the target of a merge operation
- **Persistence**: Shield is TEMPLATE type, merge bonus becomes ENHANCEMENT type
- **Integration**: Both abilities use existing event system independently

### Testing Strategy
- Test shield activation on recruitment and battle start
- Test merge bonus application (+1/+1 stats)
- Test shield consumption after taking damage
- Test multiple merge operations (shield + cumulative stat bonuses)
- Verify shield visual indicator appears correctly
