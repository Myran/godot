---
id: task-008
title: Document Archer unit abilities and stats
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

Document and validate the Archer unit (ID: 5) with First Strike and Arrows abilities providing pre-combat advantage and ranged attacks

## Acceptance Criteria

- [ ] Archer unit has correct base stats (1/2, soldier tribe)
- [ ] First Strike ability gives combat priority
- [ ] Arrows ability scales with friendly forest units
- [ ] Implementation for abilities_archer.gd and battle interaction is accurate

## Implementation Plan

**Complexity**: 🔴 Complex
**Current System**: ⚠️ Needs priority system and projectile mechanics

### Technical Approach
Create `FirstStrikeArrowsAbility` combining two mechanics - first strike priority and start-of-combat arrow volleys:

```gdscript
class_name FirstStrikeArrowsAbility extends Ability

func handle_battle_event(phase: core.Tempus, unit_position: int, is_allied_unit: bool, battle_context: BattleContext, battle_event: Context.Event) -> void:
    if phase == core.Tempus.POST and battle_event is BattleContext.BattleStartEvent:
        # Fire arrows at start of combat, before any attacks
        fire_arrow_volley(battle_context, unit_position, is_allied_unit)
        
    elif phase == core.Tempus.PRE and battle_event is BattleContext.AttackEvent:
        var attack_event: BattleContext.AttackEvent = battle_event as BattleContext.AttackEvent
        if attack_event.attacker_position == unit_position:
            # Apply first strike priority for normal attacks
            attack_event.priority = 999  # High priority for first strike

func fire_arrow_volley(battle_context: BattleContext, archer_position: int, is_allied_unit: bool) -> void:
    var forest_count: int = count_tribe_units(battle_context, is_allied_unit, "forest", archer_position)
    var archer_level: int = get_unit_level(battle_context, archer_position)
    var enemy_side: Side = get_enemy_side(battle_context, is_allied_unit)
    
    for i in forest_count:
        var target = select_random_living_unit(enemy_side)
        if target:
            play_arrow_animation(archer_position, target.position)
            await animation_complete
            apply_damage(archer_level, target.position, enemy_side)
```

### Required Changes
1. **Battle Start Event System**:
   - Add `BattleStartEvent` to fire at combat beginning
   - Execute start-of-combat abilities before any attacks
   - Proper timing and sequencing of multiple start-of-combat effects

2. **Battle Priority System**:
   - Add priority field to attack events
   - Sort attacks by priority before resolution
   - Handle simultaneous priority conflicts

3. **Projectile System**:
   - Arrow projectile animations with source-to-target trajectory
   - Sequential animation timing (not simultaneous)
   - Visual and audio feedback for arrow impacts

4. **Utility Systems**:
   - Count allied units with "forest" tribe (excluding archer)
   - Random enemy selection from living units
   - Damage application with proper event handling

### Battle System Requirements
```gdscript
# In battle system:
func resolve_arrow_volley(action_data: Dictionary):
    var arrow_count: int = action_data.arrow_count
    var damage_per_arrow: int = action_data.damage_per_arrow
    var enemy_side: Side = get_enemy_side(action_data.is_allied_attack)
    
    for i in arrow_count:
        var target = select_random_living_unit(enemy_side)
        if target:
            play_arrow_animation(unit_position, target.position)
            await animation_complete
            apply_damage(damage_per_arrow, target.position, enemy_side)

func sort_attacks_by_priority(attacks: Array[AttackEvent]) -> Array[AttackEvent]:
    attacks.sort_custom(func(a, b): return a.priority > b.priority)
    return attacks
```

### New Systems Required
1. **Priority Attack System**:
   - Attack event priority field and sorting
   - Resolution order based on priority values
   - Handle priority ties (simultaneous resolution)

2. **Pre-Action System**:
   - Execute abilities before main attack
   - Support multiple pre-actions per attack
   - Proper timing and animation sequencing

3. **Projectile System** (shared with other abilities):
   - Arrow projectile animations
   - Source-to-target trajectory calculation
   - Multiple projectile timing and effects

4. **Dynamic Tribe Counting**:
   - Real-time counting of ally tribes
   - Exclude self from tribe counts
   - Handle battlefield state changes

### Dependencies
- Battle start event system (📋 New system, shared with Knight Gold)
- Priority-based combat system (📋 Major new system) 
- Projectile animation system (📋 Major new system, shared with Wizard/Lizard)
- Tribe counting utilities (📋 New utility system)
- Random enemy selection (📋 Shared with Wizard ability)

### Technical Details
- **Arrow Timing**: Fires at START of combat, before any attacks (including first strike attacks)
- **First Strike**: Separate mechanic - normal attacks resolve before enemy priority attacks
- **Arrow Count**: Equals number of allied "forest" units (excluding archer)
- **Arrow Damage**: Each arrow deals damage equal to archer's level  
- **Target Selection**: Each arrow independently targets random living enemy
- **Sequence**: 1) Arrow volley fires, 2) Normal combat begins, 3) First strike priority applies
- **Edge Cases**: No forest allies (no arrows), no enemies (wasted arrows)

### Testing Strategy  
- Test arrow volley fires at combat start (before any attacks)
- Test first strike priority during normal combat phase
- Test arrow scaling with 0, 1, 2, 3+ forest allies
- Test arrow damage scaling with archer level 1, 2, 3+
- Test against various enemy lineup sizes
- Test arrows vs enemies that die from arrows (target filtering)
- Test animation timing and visual effects
- Test interaction with enemy shields/damage prevention
