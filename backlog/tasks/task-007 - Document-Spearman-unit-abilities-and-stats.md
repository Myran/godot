---
id: task-007
title: Document Spearman unit abilities and stats
status: Done
assignee: []
created_date: '2025-08-08 23:09'
updated_date: '2025-10-29 09:52'
labels:
  - creature
  - documentation
  - abilities
dependencies: []
---

## Description

Document and validate the Spearman unit (ID: 4) with Breakthrough ability that attacks both primary target and unit behind it

## Acceptance Criteria

- [ ] Spearman unit has correct base stats (1/3, soldier tribe)
- [ ] Breakthrough ability mechanics are clearly documented
- [ ] Implementation details for abilities_spearman.gd and battle.gd interaction are accurate
- [ ] Attack pattern targets primary and rear units correctly

## Implementation Plan

**Complexity**: 🟡 Moderate
**Current System**: ⚠️ Needs custom battle action system extension

### Technical Approach
Create `BreakthroughAbility` that modifies attack events to hit multiple targets:

```gdscript
class_name BreakthroughAbility extends Ability

func handle_battle_event(phase: core.Tempus, unit_position: int, is_allied_unit: bool, battle_context: BattleContext, battle_event: Context.Event) -> void:
    if phase == core.Tempus.PRE and battle_event is BattleContext.AttackEvent:
        var attack_event: BattleContext.AttackEvent = battle_event as BattleContext.AttackEvent
        if attack_event.attacker_position == unit_position and attack_event.is_allied_attack == is_allied_unit:
            # Add breakthrough effect to the attack
            attack_event.add_effect({
                "type": "breakthrough",
                "ability": self,
                "primary_target": attack_event.target_position
            })
```

### Required Changes
1. **BattleContext Extension**: Add `AttackEvent` class with effects system
2. **Battle System Integration**: 
   - Add breakthrough logic to damage resolution
   - Add rear-target calculation (same position, opposite line)
   - Handle cases where rear target doesn't exist
3. **AbilitiesHandler Extension**: Add "breakthrough" case to parser

### Battle System Requirements
```gdscript
# In battle system:
func resolve_breakthrough_attack(attack_event: AttackEvent):
    var primary_target = attack_event.target_position
    var rear_target = calculate_rear_position(primary_target, attack_event.target_side)
    
    # Attack primary target
    apply_damage(attack_event.damage, primary_target, attack_event.target_side)
    
    # Attack rear target if exists
    if rear_target != -1 and has_unit_at_position(rear_target, attack_event.target_side):
        apply_damage(attack_event.damage, rear_target, attack_event.target_side)
```

### Dependencies
- Battle event system with attack events (📋 Need to implement)
- Multi-target damage system (📋 Need to implement)
- Position/line calculation utilities (📋 Need to implement)
- Battle effect resolution system (📋 Need to implement)

### Technical Details
- **Timing**: Effect applies during attack resolution, before damage calculation
- **Target Selection**: Primary target (normal), plus unit directly behind in opposite line
- **Damage**: Same damage value applied to both targets
- **Edge Cases**: Rear target may not exist (no unit, out of bounds)
- **Visual Feedback**: Attack animation should show spear piercing through

### Testing Strategy
- Test breakthrough vs front line target (should hit front + rear)
- Test breakthrough vs rear line target (should hit rear only, no "behind rear")
- Test breakthrough when rear position is empty (should hit primary only)
- Test breakthrough damage calculation (same damage to both targets)
- Test with various lineup configurations and positions
