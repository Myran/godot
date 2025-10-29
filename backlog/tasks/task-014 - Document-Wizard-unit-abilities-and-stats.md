---
id: task-014
title: Document Wizard unit abilities and stats
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

Document and validate the Wizard unit (ID: 16) with Zap ability that attacks one enemy per level instead of normal attack

**Updated 2025-10-26**: Corrected unit ID from 10 to 16 based on current game data. Wizard has "alternateattack:zap;1" ability for multi-target damage.

## Acceptance Criteria

- [ ] Wizard unit has correct base stats (2/6, no tribe)
- [ ] Zap ability attacks one enemy per level instead of normal attack
- [ ] Each zap deals 2 damage (matches ability string "alternateattack:zap;1")
- [ ] Implementation matches alternateattack:zap;1 ability string

## Implementation Plan

**Complexity**: 🔴 Complex
**Current System**: ⚠️ Needs instant-kill mechanics and projectile system

### Technical Approach
Create `ZapAbility` that triggers special attack action with multiple instant-kill projectiles:

```gdscript
class_name ZapAbility extends Ability

func handle_battle_event(phase: core.Tempus, unit_position: int, is_allied_unit: bool, battle_context: BattleContext, battle_event: Context.Event) -> void:
    if phase == core.Tempus.PRE and battle_event is BattleContext.AttackEvent:
        var attack_event: BattleContext.AttackEvent = battle_event as BattleContext.AttackEvent
        if attack_event.attacker_position == unit_position and attack_event.is_allied_attack == is_allied_unit:
            # Replace normal attack with zap action
            attack_event.replace_with_special_action({
                "type": "zap_attack",
                "ability": self,
                "zap_count": get_unit_level(battle_context, unit_position),
                "target_side": get_enemy_side(is_allied_unit)
            })
```

### Required Changes
1. **Battle System Extension**:
   - Add instant-kill damage type/mechanics
   - Add special action system (replaces normal attacks)
   - Add random enemy selection utilities
   - Add projectile animation system

2. **Battle Context Extension**:
   - Add `AttackEvent.replace_with_special_action()`
   - Add unit level access from battle context
   - Add enemy side targeting utilities

3. **Visual Effects System**:
   - Lightning/zap projectile animations
   - Instant death visual feedback
   - Multiple projectile sequencing

### Battle System Requirements
```gdscript
# In battle system:
func resolve_zap_attack(zap_data: Dictionary):
    var zap_count: int = zap_data.zap_count
    var enemy_side: Side = zap_data.target_side
    
    for i in zap_count:
        var random_enemy = select_random_living_unit(enemy_side)
        if random_enemy:
            play_zap_animation(unit_position, random_enemy.position)
            await animation_complete
            apply_instant_kill(random_enemy)
```

### New Systems Required
1. **Instant Kill System**:
   - Bypass normal damage calculation
   - Set unit health to 0 or mark for removal
   - Trigger death events properly
   - Handle death animations/effects

2. **Random Selection System**:
   - Filter living units on enemy side
   - Weighted or uniform random selection
   - Handle edge cases (no valid targets)

3. **Projectile/Animation System**:
   - Lightning bolt visual effects
   - Source-to-target trajectory
   - Sequential animation timing
   - Audio/visual feedback integration

### Dependencies
- Special attack action system (📋 Major new system)
- Instant kill mechanics (📋 Major new system)
- Random enemy selection (📋 New utility system)
- Projectile animation system (📋 Major new system)
- Unit level access in battle (📋 Need to verify)

### Technical Details
- **Timing**: Replaces normal attack entirely during attack resolution
- **Target Selection**: Completely random among living enemies
- **Scaling**: Number of zaps = wizard level (1-3+ typically)
- **Animation**: Sequential zap animations, not simultaneous
- **Edge Cases**: No valid targets, all enemies already dead
- **Balance**: Potentially very powerful, may need level caps or restrictions

### Testing Strategy
- Test with wizard levels 1, 2, 3+ (different zap counts)
- Test against lineups with 1, 2, 5+ enemies (target availability)
- Test when some enemies already dead (target filtering)
- Test when no enemies available (edge case handling)
- Test zap animation timing and visual effects
- Test interaction with shields/damage prevention abilities
