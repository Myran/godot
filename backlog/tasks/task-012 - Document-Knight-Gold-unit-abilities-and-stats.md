---
id: task-012
title: Document Knight Gold unit abilities and stats
status: Done
assignee: []
created_date: '2025-08-08 23:09'
updated_date: '2025-12-18 10:37'
labels:
  - creature
  - documentation
  - abilities
  - knight
dependencies: []
ordinal: 240000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Document and validate the Knight Gold unit (ID: 8) with Shield Aura ability that protects all friendly knight units at battle start
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Knight Gold unit has correct base stats (4/4, soldier tribe)
- [ ] #2 Shield Aura ability grants shields to all friendly knights
- [ ] #3 Ability activates at start of battle
- [ ] #4 Implementation for abilities_knight_gold.gd is accurate
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Complexity**: 🟡 Moderate
**Current System**: ✅ Good fit with minor extension for battle events

### Technical Approach
Create `ShieldAuraAbility` that responds to battle start events and grants shields to all knight allies:

```gdscript
class_name ShieldAuraAbility extends Ability

func handle_battle_event(phase: core.Tempus, unit_position: int, is_allied_unit: bool, battle_context: BattleContext, battle_event: Context.Event) -> void:
    if phase == core.Tempus.POST and battle_event is BattleContext.BattleStartEvent:
        grant_knight_shields(battle_context, is_allied_unit, unit_position)

func grant_knight_shields(battle_context: BattleContext, is_allied_unit: bool, knight_gold_position: int) -> void:
    var allied_side: Side = get_allied_side(battle_context, is_allied_unit)
    
    for position: int in allied_side.lineup:
        var unit: UnitData = allied_side.lineup[position]
        if position != knight_gold_position and unit.has_tribe("knight"):
            # Grant shield ability to the knight
            var shield_ability: DamageShieldAbility = DamageShieldAbility.new()
            shield_ability.persistence_type = Ability.PersistenceType.TEMPORARY
            unit.add_ability(shield_ability)
            unit.show_shield()  # Visual feedback
```

### Required Changes
1. **BattleContext Extension**: Add `BattleStartEvent` class
2. **Dynamic Ability Addition**: System to add abilities to units during battle
3. **Shield Visual System**: Ensure shields appear on protected knights
4. **AbilitiesHandler Extension**: Add "shield_aura" case to parser

### Battle Event System Requirements
```gdscript
# In BattleContext:
class BattleStartEvent extends BaseEvent:
    func _init() -> void:
        pass

# In battle system:
func start_battle():
    var battle_start_event: BattleStartEvent = BattleStartEvent.new()
    fire_event(battle_start_event)
    # ... continue with normal battle logic
```

### Dependencies
- Battle start event system (📋 Need to implement `BattleStartEvent`)
- `DamageShieldAbility` class (✅ Already implemented)
- Dynamic ability addition during battle (📋 Need to implement)
- Shield visual system (📋 Need to verify)
- Tribe checking utilities (✅ Available)

### Technical Details
- **Trigger**: At the very start of battle, before any combat actions
- **Target Selection**: All allied units with "knight" tribe, excluding Knight Gold itself
- **Shield Type**: Temporary shields (cleared after battle) using existing `DamageShieldAbility`
- **Self-Exclusion**: Knight Gold does not grant a shield to itself
- **Visual Feedback**: Shield icons appear on all protected knights
- **Persistence**: Shields last for the duration of the battle only

### Edge Cases & Behavior
- **No Other Knights**: If no other knights in lineup, no shields are granted
- **Multiple Knight Golds**: Each would grant shields independently (potential stacking)
- **Knight Dies Before Battle**: Dead knights don't receive shields
- **Timing**: Shields are active immediately when battle damage starts

### Testing Strategy
- Test with lineups containing multiple knights (all should get shields)
- Test with lineup containing only Knight Gold (no shields granted)
- Test with mixed lineups (only knights get shields, others don't)
- Test shield functionality during battle (each blocks one damage)
- Test visual shield indicators appear correctly
- Test interaction with existing shield abilities (stacking behavior)
- Test with multiple Knight Gold units (verify shield stacking or limits)
<!-- SECTION:PLAN:END -->
