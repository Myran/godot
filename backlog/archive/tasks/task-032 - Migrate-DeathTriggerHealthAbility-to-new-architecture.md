---
id: task-032
title: Migrate DeathTriggerHealthAbility to new architecture
status: To Do
assignee: []
created_date: '2025-08-12 12:18'
updated_date: '2025-08-12 13:53'
labels:
  - migration
  - ability-implementation
  - validation
dependencies:
  - task-031
  - task-033
priority: medium
---

## Description

Migrate the DeathTriggerHealthAbility from the legacy 5-parameter API to the revolutionary single-parameter architecture. This serves as the foundational template migration that establishes the pattern for all subsequent ability migrations, demonstrating the 50-80% code reduction and architectural benefits.
## Acceptance Criteria

- [ ] Revolutionary single-parameter API implemented (handle_battle_event(unit: UnitContext) replaces 5-parameter method)
- [ ] Event filtering optimization using get_handled_event_classes() method
- [ ] AbilityHelper.is_death_post() and AbilityHelper.grant_health_bonus() methods utilized
- [ ] Template migration pattern documented with before/after code examples
- [ ] Behavioral compatibility verified through comprehensive regression testing
- [ ] 50-80% code reduction measured and documented (target: 8+ lines → 3 lines)
- [ ] All existing tests continue to pass without modification
- [ ] Migration can be safely rolled back if issues are discovered

## Implementation Plan

### Migration Pattern Template

**BEFORE (Legacy 5-parameter API - 8+ lines):**
```gdscript
func handle_battle_event(
    phase: core.Tempus,
    unit_position: int,
    is_allied_unit: bool,
    battle_context: BattleContext,
    battle_event: Context.Event
) -> void:
    if phase == core.Tempus.POST and battle_event is BattleContext.DeathEvent:
        var stat_event: BattleContext.StatChangeEvent = BattleContext.StatChangeEvent.new(
            Battle.UNIT_HEALTH, unit_position, is_allied_unit, health_bonus
        )
        battle_context.add_event(stat_event)
```

**AFTER (Revolutionary Single-Parameter API - 3 lines):**
```gdscript
func get_handled_event_classes() -> Array:
    return [BattleContext.DeathEvent]

func handle_battle_event(unit: UnitContext) -> void:
    if AbilityHelper.is_death_post(unit):
        AbilityHelper.grant_health_bonus(unit, health_bonus)
```

### Revolutionary API Changes

1. **Event Filtering Optimization**: `get_handled_event_classes()` enables system-level event filtering
2. **Single Parameter**: `handle_battle_event(unit: UnitContext)` replaces 5 separate parameters
3. **Helper Methods**: `AbilityHelper.is_death_post()` and `AbilityHelper.grant_health_bonus()`
4. **Smart Context**: `UnitContext` provides all necessary battle state through delegation

### Code Reduction Measurement

- **Before**: 8+ lines of complex parameter handling and event creation
- **After**: 3 lines with crystal-clear intent and helper methods
- **Reduction**: ~62% code reduction (8 lines → 3 lines)
- **Readability**: Self-documenting method names improve code comprehension
- **Maintainability**: Centralized helper methods reduce duplication

### Architecture Benefits

- ✅ **Perfect Separation of Concerns**: Game rules moved to BattleRules, utilities to AbilityHelper
- ✅ **Type Safety**: Using class references instead of manual type checking
- ✅ **Performance**: Event filtering at system level prevents unnecessary ability calls
- ✅ **Testability**: Helper methods can be unit tested independently
- ✅ **Consistency**: Unified pattern for all ability implementations
