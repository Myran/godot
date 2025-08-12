---
id: task-037
title: Migrate MergeBonusAbility to new architecture
status: To Do
assignee: []
created_date: '2025-08-12 12:19'
updated_date: '2025-08-12 13:56'
labels:
  - migration
  - abilities
  - architecture
dependencies:
  - task-032
priority: high
---

## Description

Migrate the MergeBonusAbility from legacy draft event handling to revolutionary single-parameter architecture. This migration demonstrates cross-event-system compatibility (draft + battle events) and complex merge logic using the architectural patterns established in task-032.
## Acceptance Criteria

- [ ] Revolutionary single-parameter API implemented for both battle and draft events
- [ ] Event filtering optimization using get_handled_event_classes() methods
- [ ] Draft event handling migrated to use DraftContext integration patterns
- [ ] Merge detection logic simplified using AbilityHelper.is_merge_event() methods
- [ ] Bonus calculation logic centralized in AbilityHelper.calculate_merge_bonus()
- [ ] Template migration pattern from task-032 applied to draft event system
- [ ] Self-trigger prevention logic maintained with improved clarity
- [ ] Behavioral compatibility verified through comprehensive regression testing
- [ ] 50-80% code reduction measured and documented
- [ ] All existing tests continue to pass without modification
- [ ] Merge bonus calculations match original implementation exactly

## Implementation Plan

### Cross-Event-System Migration

**BEFORE (Legacy Draft Event Handling - 25+ lines):**
```gdscript
func handle_draft_event(
    phase: core.Tempus,
    _unit_position: int,
    unit: Block,
    draft_context: DraftContext,
    draft_event: core.CoreEvent
) -> void:
    if phase != core.Tempus.POST:
        return

    if not draft_event is core.DraftMergeEvent:
        return

    if not unit.block_context == Cards.CONTEXT.LINEUP:
        return

    var merge_event: core.DraftMergeEvent = draft_event
    var card: Card = unit

    var card_id: String = card.unit_info.card_info.get("id", "")
    var merged_card_ids: Array[String] = []
    for match_card: Card in merge_event.matches:
        merged_card_ids.append(match_card.unit_info.card_info.get("id", ""))
    var level: int = card.level
    var calc_attack_bonus: int = base_attack_bonus * level
    var calc_health_bonus: int = base_health_bonus * level

    # Complex logging and validation logic (10+ more lines)
    if merge_event.matches.has(card):
        return  # Self-trigger prevention

    var stat_effect_event: core.StatEffectEvent = core.StatEffectEvent.new(
        card, calc_health_bonus, calc_attack_bonus, core.EventSource.SYSTEM_CASCADE
    )
    draft_context.add_event(stat_effect_event)
```

**AFTER (Revolutionary Single-Parameter API - 6 lines):**
```gdscript
func get_handled_draft_event_classes() -> Array:
    return [core.DraftMergeEvent]

func handle_draft_event(unit: DraftContext) -> void:
    if AbilityHelper.is_merge_post(unit) and AbilityHelper.is_lineup_context(unit):
        if not AbilityHelper.is_self_trigger(unit, self):
            var bonuses = AbilityHelper.calculate_merge_bonus(unit, base_health_bonus, base_attack_bonus)
            AbilityHelper.apply_stat_bonus(unit, bonuses.health, bonuses.attack)
```

### Revolutionary Draft System Integration

**Complex Merge Logic Simplified:**
```gdscript
# BEFORE: Manual merge validation and calculation (15+ lines)
if not draft_event is core.DraftMergeEvent:
    return
var merge_event: core.DraftMergeEvent = draft_event
var level: int = card.level
var calc_attack_bonus: int = base_attack_bonus * level
var calc_health_bonus: int = base_health_bonus * level
if merge_event.matches.has(card):
    return  # Self-trigger prevention
var stat_effect_event: core.StatEffectEvent = core.StatEffectEvent.new(
    card, calc_health_bonus, calc_attack_bonus, core.EventSource.SYSTEM_CASCADE
)

# AFTER: Helper method delegation (3 lines)
if not AbilityHelper.is_self_trigger(unit, self):
    var bonuses = AbilityHelper.calculate_merge_bonus(unit, base_health_bonus, base_attack_bonus)
    AbilityHelper.apply_stat_bonus(unit, bonuses.health, bonuses.attack)
```

### Cross-Event-System Architecture Features

1. **Unified API Pattern**: Both `handle_draft_event(unit: DraftContext)` and `handle_battle_event(unit: UnitContext)` follow same pattern
2. **Event Filtering**: `get_handled_draft_event_classes()` mirrors battle event filtering
3. **Smart Validation**: `AbilityHelper.is_merge_post()` and `AbilityHelper.is_lineup_context()`
4. **Self-Trigger Prevention**: `AbilityHelper.is_self_trigger()` centralizes complex logic
5. **Calculation Helpers**: `AbilityHelper.calculate_merge_bonus()` handles level-based scaling

### Code Reduction Measurement

- **Before**: 25+ lines with complex manual validation, calculation, and event creation
- **After**: 6 lines with helper method delegation and clear intent
- **Reduction**: ~76% code reduction (25 lines → 6 lines)
- **Logic Centralization**: Merge detection, bonus calculation, and self-trigger prevention moved to helpers
- **Readability**: Method names like `is_self_trigger()` are immediately understandable

### Template Pattern Application to Draft System

Extending task-032 template to draft event system:
- ✅ **Event Filtering**: `get_handled_draft_event_classes()` for performance optimization
- ✅ **Single Parameter**: Revolutionary `handle_draft_event(unit: DraftContext)` API  
- ✅ **Helper Integration**: AbilityHelper manages merge-specific operations
- ✅ **Smart Validation**: Context-aware validation through helper methods
- ✅ **Behavioral Preservation**: Complex merge logic maintained through centralized helpers
- ✅ **Cross-System Consistency**: Same architectural patterns across battle and draft events
