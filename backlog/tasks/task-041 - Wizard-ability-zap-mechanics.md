---
id: task-041
title: Wizard ability zap mechanics
status: Done
assignee: []
created_date: '2025-08-12 12:20'
updated_date: '2026-01-07 04:04'
labels:
  - abilities
  - wizard
  - complex-mechanics
dependencies:
  - task-034
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement the Wizard zap mechanics using the revolutionary three-class architecture demonstrating multi-target chain lightning with the AbilityHelper.deal_damage_to_random_enemy() pattern. This ability showcases the architecture's power to simplify complex targeting logic from 20+ lines to a single helper call while maintaining full chain lightning functionality and visual effects integration.

**Phase 1 Analysis Complete (2025-10-26)**:
- ✅ Dependencies resolved (task-040 removed - unnecessary performance optimization)
- ✅ Architecture ready (BattleRules, AbilityHelper, BattleAbilityEvent all functional)
- ✅ Event system validated (CombatEvent, DamageEvent available)
- ✅ Implementation ready when needed

Unit Details:
- **Card ID**: 16
- **Ability String**: "alternateattack:zap;1"
- **Requirements**: Multi-target chain lightning, 2 damage to random enemies per level

## Implementation Strategy & Architecture Insights

### **Robustness-First Approach**

**Instant Kill Robustness Pattern:**
- **Use High Damage Instead**: Replace "instant kill" with 999 damage to handle edge cases robustly
- **Shield Handling**: High damage allows shield abilities and damage reduction to work correctly
- **Deterministic Targeting**: Use `BattleRules.deal_damage_to_random_enemies()` for consistent cross-platform behavior

**Implementation Pattern:**
```gdscript
class_name WizardAbility extends Ability

func get_handled_event_classes() -> Array:
    return [BattleContext.CombatEvent]

func handle_battle_event(unit: BattleAbilityEvent) -> void:
    # Fail-fast validation for robustness
    if not AbilityHelper.should_process_event(self, unit.event):
        return

    # Zap triggers during unit's combat action with proper timing
    if AbilityHelper.is_combat_pre(unit) and unit.is_event_from_this_unit():
        var wizard_level = unit.get_self_unit().level
        if wizard_level > 0:
            # Robust multi-target implementation - one zap per level
            for i in range(wizard_level):
                # Use high damage instead of instant kill for robustness
                AbilityHelper.deal_damage_to_random_enemy(unit, 999, 1)
```

### **Simplicity Through Delegation**

**Code Reduction Strategy:**
- **Traditional Implementation**: 20+ lines with manual targeting, chain logic, and death handling
- **Revolutionary Implementation**: 6 lines with clear intent through helper methods
- **Key Insight**: Single loop with `AbilityHelper.deal_damage_to_random_enemy()` replaces entire chain lightning system

**Robustness Benefits:**
- **Shield Interaction**: High damage approach allows shield abilities to function correctly
- **Edge Case Handling**: Empty battlefields, death mid-zap automatically handled by BattleRules
- **Deterministic Behavior**: Centralized RNG ensures same target selection across platforms

**Visual Effects Integration:**
- **Automatic Effect Triggers**: Each damage event automatically triggers appropriate zap animations
- **Sequential Feedback**: Loop creates natural sequential visual feedback for chain lightning
- **No Custom Effect Logic**: Damage system handles all visual and audio feedback

### **Key Implementation Considerations**

**Level-Based Scaling:**
- **One Zap Per Level**: `range(wizard_level)` ensures proper scaling with unit progression
- **Damage Consistency**: Each zap deals same damage (999) for reliable "instant kill" behavior
- **Level Validation**: Check `wizard_level > 0` to prevent unnecessary processing

**Event Timing Strategy:**
- **Combat Pre-Phase**: `AbilityHelper.is_combat_pre()` ensures zap triggers before unit's normal attack
- **Unit Validation**: `unit.is_event_from_this_unit()` prevents zap from triggering on other units' combat
- **Event Filtering**: `get_handled_event_classes([BattleContext.CombatEvent])` optimizes performance

**Error Prevention:**
- **Target Validation**: `BattleRules.deal_damage_to_random_enemies()` handles missing targets gracefully
- **Death State**: High damage approach works correctly even if targets die mid-sequence
- **Race Conditions**: Event timing prevents conflicts with normal combat resolution

**Testing Strategy:**
- **Unit Tests**: Validate level scaling and targeting logic
- **Integration Tests**: Ensure zap timing works with combat system
- **Edge Case Tests**: Verify behavior with empty battlefield, shield abilities, death mid-zap
<!-- SECTION:DESCRIPTION:END -->

## Assessment (2025-12-06)

**Value: HIGH** - Core gameplay feature required for complete card roster.

**Recommendation: KEEP** - Essential card ability. Wizard is a key unit. Architecture ready, implementation documented. Depends on task-034 (Archer) being completed first.

**Effort**: Small (architecture ready, single ability implementation)
**Blocker**: Depends on task-034

---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Multi-target zap uses AbilityHelper.deal_damage_to_random_enemy(unit 2 3) for 2 damage to 3 random enemies
- [ ] #2 Chain lightning targeting leverages BattleRules centralized targeting through AbilityHelper delegation
- [ ] #3 Revolutionary handle_battle_event(unit: UnitContext) API with get_handled_event_classes() optimization
- [ ] #4 Event filtering returns [BattleContext.CombatEvent] for performance optimization
- [ ] #5 Code reduction demonstration: traditional 20+ lines of targeting logic reduced to 1 helper call
- [ ] #6 Visual effects integration works seamlessly with simplified targeting system
- [ ] #7 Cross-platform deterministic behavior maintained with proper RNG delegation to BattleRules
- [ ] #8 Performance validation shows <5% overhead vs traditional implementation with dramatic code simplification
<!-- AC:END -->
