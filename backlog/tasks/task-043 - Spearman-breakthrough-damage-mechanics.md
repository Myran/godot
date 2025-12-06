---
id: task-043
title: Spearman breakthrough damage mechanics
status: To Do
assignee: []
created_date: '2025-08-12 12:20'
updated_date: '2025-11-11 20:25'
labels:
  - abilities
  - spearman
  - breakthrough
dependencies:
  - task-034
priority: medium
---

## Assessment (2025-12-06)

**Value: HIGH** - Core gameplay feature required for complete card roster.

**Recommendation: KEEP** - Essential card ability. Spearman needs breakthrough mechanic. Architecture ready. Depends on task-034 (Archer) being completed first.

**Effort**: Small-Medium (architecture ready, positional logic needed)
**Blocker**: Depends on task-034

---

## Description

Implement the Spearman breakthrough damage mechanics using the revolutionary three-class architecture demonstrating positional multi-target damage through BattleRules delegation. This ability showcases the architecture's ability to handle complex line-of-sight calculations and positioning logic through centralized game rules while achieving dramatic code simplification with the AbilityHelper multi-target damage pattern.

**Phase 1 Analysis Complete (2025-10-26)**:
- ✅ Dependencies resolved (task-040 removed - unnecessary performance optimization)
- ✅ Architecture ready (BattleRules, AbilityHelper, BattleAbilityEvent all functional)
- ✅ Event system validated (CombatEvent, DamageEvent available)
- ✅ Implementation ready when needed

Unit Details:
- **Card ID**: 13
- **Ability String**: "damage:frontandbackrow"
- **Requirements**: Front and back row line attacks with positional targeting

## Implementation Strategy & Architecture Insights

### **Robustness-First Approach**

**Position-Based Targeting Strategy:**
- **New BattleRules Method Required**: `get_breakthrough_targets()` for line-of-sight calculations
- **Position Validation**: Use `BattleRules.is_position_valid()` for all breakthrough targeting
- **Deterministic Targeting**: Centralized positioning ensures consistent cross-platform behavior

**Required BattleRules Extension:**
```gdscript
# NEW: Breakthrough targeting method needed in BattleRules
static func get_breakthrough_targets(
    context: BattleContext, primary_target: int, target_allied: bool
) -> Array[int]:
    """Get positions for breakthrough line attacks with line-of-sight validation"""
    var targets: Array[int] = []
    var primary_line = primary_target / Battle.LINE_SIZE
    var target_line = target_allied ? context.allied_line : context.enemy_line

    # Calculate breakthrough target (same position, opposite line)
    var breakthrough_pos = primary_target % Battle.LINE_SIZE + (target_line * Battle.LINE_SIZE)

    # Validate line-of-sight and position availability
    if is_position_valid(context, breakthrough_pos, not target_allied):
        targets.append(breakthrough_pos)

    return targets
```

**Implementation Pattern:**
```gdscript
class_name SpearmanAbility extends Ability

func get_handled_event_classes() -> Array:
    return [BattleContext.CombatEvent]

func handle_battle_event(unit: BattleAbilityEvent) -> void:
    # Fail-fast validation for robustness
    if not AbilityHelper.should_process_event(self, unit.event):
        return

    # Breakthrough triggers after successful combat
    if AbilityHelper.is_combat_post(unit) and unit.is_event_from_this_unit():
        # Extract primary target from combat event
        var target_position = get_combat_target_position(unit.event)
        if target_position != Battle.NO_UNIT_FOUND:
            # Calculate breakthrough targets using centralized positioning
            var breakthrough_targets = BattleRules.get_breakthrough_targets(
                unit.battle_context, target_position, not unit.is_allied
            )
            # Apply damage to all valid breakthrough positions
            for target_pos in breakthrough_targets:
                AbilityHelper.deal_damage_to_unit_at_position(
                    unit, target_pos, not unit.is_allied, unit.get_self_unit().current_attack
                )
```

### **Simplicity Through Centralization**

**Code Reduction Strategy:**
- **Traditional Implementation**: 30+ lines with manual positioning, line-of-sight calculation, and validation
- **Revolutionary Implementation**: 10 lines with clear intent through centralized rules
- **Key Insight**: Single `BattleRules.get_breakthrough_targets()` call replaces entire positioning system

**Robustness Benefits:**
- **Position Validation**: All targeting flows through centralized validation system
- **Edge Case Handling**: Empty positions, invalid targets automatically handled by BattleRules
- **Deterministic Behavior**: Centralized positioning ensures same breakthrough calculation across platforms

**Line-of-Sight Logic:**
- **Centralized Calculations**: All positioning logic lives in BattleRules, not distributed across abilities
- **Consistent Rules**: Same positioning system used by all abilities requiring complex targeting
- **Battlefield Awareness**: Full context available for advanced positioning calculations

### **Key Implementation Considerations**

**Target Extraction Strategy:**
- **Combat Event Analysis**: Extract primary target from `unit.event` using existing combat system
- **Position Validation**: Ensure `target_position != Battle.NO_UNIT_FOUND` before breakthrough calculation
- **Event Timing**: Use `AbilityHelper.is_combat_post()` to trigger after primary attack resolves

**Breakthrough Mechanics:**
- **Line-Based Targeting**: Same column position, opposite battle line
- **Damage Application**: Use unit's current attack damage for breakthrough hit
- **Multi-Target Support**: Loop handles multiple breakthrough positions if rules allow

**Error Prevention:**
- **Position Validation**: `BattleRules.is_position_valid()` prevents invalid targeting
- **Target Availability**: Check for valid units at breakthrough positions
- **Combat State**: Post-combat timing ensures primary attack completed before breakthrough

**Integration Requirements:**
- **BattleRules Extension**: Must implement `get_breakthrough_targets()` method
- **AbilityHelper Method**: May need `deal_damage_to_unit_at_position()` if not already available
- **Combat System**: Ensure combat events expose target position information

**Testing Strategy:**
- **Unit Tests**: Validate breakthrough positioning calculations
- **Integration Tests**: Ensure breakthrough timing works with combat resolution
- **Edge Case Tests**: Verify behavior with empty positions, invalid targets, battlefield edges
## Acceptance Criteria

- [ ] Breakthrough line targeting uses BattleRules centralized positioning logic through AbilityHelper delegation
- [ ] Multi-target damage leverages AbilityHelper.deal_damage_to_positioned_enemies() pattern for line attacks
- [ ] Revolutionary handle_battle_event(unit: UnitContext) API with get_handled_event_classes() returning [BattleContext.CombatEvent]
- [ ] Line-of-sight calculations centralized in BattleRules with position-based targeting rules
- [ ] Damage reduction per target implemented through BattleRules diminishing damage calculations
- [ ] Event filtering optimization limits processing to combat events only for performance
- [ ] Code simplification demonstration: complex positioning logic reduced through centralized rule delegation
- [ ] Cross-platform deterministic behavior maintained with BattleRules handling all positioning calculations
