---
id: task-034
title: Archer ability with first strike and volley mechanics
status: To Do
assignee: []
created_date: '2025-08-12 12:18'
updated_date: '2025-11-11 20:25'
labels:
  - complex-abilities
  - archer
  - multi-target
dependencies:
  - task-032
priority: low
---

## Assessment (2025-12-06)

**Value: HIGH** - Core gameplay feature. BLOCKER for other abilities.

**Recommendation: KEEP - INCREASE PRIORITY** - This task is a dependency for task-041 (Wizard), task-043 (Spearman), and task-044 (Barbarian). It should NOT be low priority if those abilities are needed. Consider promoting to Medium or High priority.

**Effort**: Small-Medium (architecture ready)
**Blocker**: Depends on task-032. BLOCKS: task-041, task-043, task-044
**Note**: Priority should match the urgency of dependent card abilities

---

## Description

**Updated 2025-10-26**: Removed task-040 dependency (archived performance optimization) since event filtering system is already implemented and functional.

## Description

Implement the Archer ability using the revolutionary three-class architecture (BattleRules, BattleAbilityEvent, AbilityHelper) demonstrating first strike priority mechanics and arrow volley targeting with dramatic code simplification. This ability validates the architecture's ability to handle complex multi-step ability logic using the single-parameter API while achieving 80% code reduction from traditional implementations.

## Implementation Strategy & Architecture Insights

### **Robustness-First Approach**

**Architecture Integration:**
- **Event Validation**: Use `AbilityHelper.should_process_event()` and `get_handled_event_classes()` for fail-fast event filtering
- **Centralized Targeting**: Leverage `BattleRules.deal_damage_to_random_enemies()` for deterministic arrow targeting
- **State Consistency**: Use `AbilityHelper.is_combat_pre()` for first strike timing to prevent race conditions

**Implementation Pattern:**
```gdscript
class_name ArcherAbility extends Ability
var damage_per_arrow: int = 1

func get_handled_event_classes() -> Array:
    return [BattleContext.CombatEvent, BattleContext.BattleStartEvent]

func handle_battle_event(unit: BattleAbilityEvent) -> void:
    # Fail-fast validation for robustness
    if not AbilityHelper.should_process_event(self, unit.event):
        return

    # First Strike - combat system handles timing automatically
    if AbilityHelper.is_combat_pre(unit) and unit.is_event_from_this_unit():
        # Combat system handles first strike - no custom logic needed

    # Arrow Volley - count forest allies and shoot arrows
    if unit.event is BattleContext.BattleStartEvent and unit.phase == core.Tempus.POST:
        var forest_allies = AbilityHelper.count_units_with_tags_in_lineup(
            unit.battle_context.allied_side.lineup, ["forest"], unit.get_self_unit()
        )
        if forest_allies > 0:
            # Single helper call replaces complex targeting logic
            AbilityHelper.deal_damage_to_random_enemy(unit, damage_per_arrow, forest_allies)
```

### **Simplicity Through Delegation**

**Code Reduction Strategy:**
- **Traditional Implementation**: 25+ lines with manual targeting, forest counting, and arrow logic
- **Revoluationary Implementation**: 8 lines with clear intent through helper methods
- **Key Insight**: Single `AbilityHelper.deal_damage_to_random_enemy()` call replaces entire arrow targeting system

**Robustness Benefits:**
- **Edge Case Handling**: Empty battlefields, missing targets automatically handled by BattleRules
- **Deterministic Behavior**: Centralized RNG ensures cross-platform consistency
- **Performance**: Event filtering prevents unnecessary processing on non-relevant events

**Testing Strategy:**
- **Unit Tests**: Validate forest unit counting and arrow targeting
- **Integration Tests**: Ensure first strike timing works with existing combat system
- **Performance Tests**: Confirm <5% overhead through event filtering optimization

### **Key Implementation Considerations**

**Event Timing:**
- First strike leverages existing combat timing - no custom timing logic needed
- Arrow volley triggers during `BattleStartEvent.POST` phase to ensure battlefield is ready
- Event filtering ensures ability only processes relevant events

**Target Validation:**
- `AbilityHelper.count_units_with_tags_in_lineup()` handles forest unit identification with proper exclusion
- `BattleRules.deal_damage_to_random_enemies()` ensures valid target selection
- Automatic handling of edge cases (no valid targets, empty enemy line, etc.)

**Cross-Platform Consistency:**
- All randomness flows through centralized BattleRules system
- Event-driven architecture ensures deterministic behavior across platforms
- No platform-specific code required in ability implementation
## Acceptance Criteria

- [ ] Archer first strike mechanic uses AbilityHelper.is_combat_pre() and revolutionary single-parameter API
- [ ] Arrow volley system uses AbilityHelper.deal_damage_to_random_enemy() for multi-target attacks
- [ ] Ability implements get_handled_event_classes() returning [BattleContext.CombatEvent BattleContext.BattleStartEvent]
- [ ] Revolutionary handle_battle_event(unit: UnitContext) API demonstrates 80% code reduction
- [ ] Event filtering optimization limits processing to relevant events only
- [ ] Code achieves dramatic simplification: traditional 25+ lines reduced to 8 lines with crystal-clear intent
- [ ] Cross-platform deterministic behavior maintained with proper RNG usage
- [ ] Performance benchmarks validate <5% overhead vs baseline implementation
