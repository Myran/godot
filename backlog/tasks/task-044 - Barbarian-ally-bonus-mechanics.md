---
id: task-044
title: Barbarian ally bonus mechanics
status: Done
assignee: []
created_date: '2025-08-12 12:20'
updated_date: '2026-01-07 04:00'
labels:
  - abilities
  - barbarian
  - ally-bonuses
dependencies:
  - task-034
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement the Barbarian ally bonus mechanics using the revolutionary three-class architecture demonstrating cross-unit state management through the AbilityHelper.grant_ally_bonuses() pattern. This ability validates the architecture's power to handle complex multi-unit interactions and area detection through BattleRules delegation while achieving dramatic code simplification from traditional 15+ line implementations to single helper calls.

**Phase 1 Analysis Complete (2025-10-26)**:
- ✅ Dependencies resolved (task-040 removed - unnecessary performance optimization)
- ✅ Architecture ready (BattleRules, AbilityHelper, BattleAbilityEvent all functional)
- ✅ Event system validated (DeathEvent, StatChangeEvent available)
- ✅ Implementation ready when needed

Unit Details:
- **Card ID**: 3
- **Ability String**: "cleave:1"
- **Requirements**: Death-triggered ally bonuses, +1/+1 to all allies when enemies die

## Implementation Strategy & Architecture Insights

### **Robustness-First Approach**

**Death-Triggered Robustness Pattern:**
- **Reliable Death Detection**: Use `AbilityHelper.is_death_post()` for consistent death event handling
- **Enemy Validation**: `not unit.is_allied` prevents triggering on ally deaths
- **Centralized Bonus Application**: `AbilityHelper.grant_ally_bonuses()` ensures consistent state management

**Implementation Pattern:**
```gdscript
class_name BarbarianAbility extends Ability

func get_handled_event_classes() -> Array:
    return [BattleContext.DeathEvent]

func handle_battle_event(unit: BattleAbilityEvent) -> void:
    # Fail-fast validation for robustness
    if not AbilityHelper.should_process_event(self, unit.event):
        return

    # Trigger when enemies die (not allies)
    if AbilityHelper.is_death_post(unit) and not unit.is_allied:
        # Single helper call replaces complex multi-unit bonus logic
        AbilityHelper.grant_ally_bonuses(unit, 1, 1)  # +1/+1 to all allies
```

### **Simplicity Through Delegation**

**Code Reduction Strategy:**
- **Traditional Implementation**: 15+ lines with manual ally iteration, bonus calculation, and state management
- **Revolutionary Implementation**: 4 lines with crystal-clear intent through helper methods
- **Key Insight**: Single `AbilityHelper.grant_ally_bonuses()` call replaces entire multi-unit bonus system

**Robustness Benefits:**
- **Automatic Ally Detection**: `AbilityHelper.grant_ally_bonuses()` handles ally identification through BattleRules positioning
- **State Consistency**: Centralized bonus application prevents race conditions and state inconsistencies
- **Edge Case Handling**: Empty battlefield, missing allies automatically handled by BattleRules

**Cross-Unit State Management:**
- **Centralized Logic**: All bonus calculations flow through BattleRules system
- **Consistent Application**: Same bonus system used by all abilities granting multi-unit effects
- **Stacking Rules**: Centralized state management handles bonus duration and stacking automatically

### **Key Implementation Considerations**

**Death Event Strategy:**
- **Post-Death Timing**: `AbilityHelper.is_death_post()` ensures death is fully resolved before bonus application
- **Enemy Validation**: `not unit.is_allied` critical for preventing infinite loops or incorrect triggers
- **Event Filtering**: `get_handled_event_classes([BattleContext.DeathEvent])` optimizes performance

**Bonus Application Mechanics:**
- **Multi-Unit Targeting**: `AbilityHelper.grant_ally_bonuses()` handles all ally detection and bonus application
- **Stat Modification**: +1 attack and +1 health applied consistently to all allies
- **Battlefield Awareness**: Full context available for advanced ally detection rules

**Error Prevention:**
- **Death Validation**: Reliable death detection prevents triggering on non-death events
- **Team Validation**: Enemy validation prevents self-triggering or ally-triggering bugs
- **State Consistency**: Centralized bonus system prevents partial applications or state corruption

**Integration Benefits:**
- **Visual Effects**: Bonus application automatically triggers appropriate visual feedback
- **Sound Integration**: Multi-unit bonuses create cohesive audio feedback through existing systems
- **UI Updates**: Stat changes automatically reflected in unit displays through existing stat system

**Testing Strategy:**
- **Unit Tests**: Validate death detection and enemy validation logic
- **Integration Tests**: Ensure bonus timing works with death resolution system
- **Edge Case Tests**: Verify behavior with multiple deaths, empty battlefield, single ally scenarios

**Performance Considerations:**
- **Event Filtering**: Death event filtering prevents unnecessary processing on non-death events
- **Centralized Calculations**: Single bonus calculation pass through BattleRules system
- **Minimal Overhead**: Simple death check and single helper call ensure <5% performance impact

**Architecture Validation:**
- **Single-Parameter API**: Demonstrates revolutionary `handle_battle_event(unit: BattleAbilityEvent)` simplification
- **Event-Driven Design**: Clean separation between death detection and bonus application
- **Delegation Pattern**: Shows architecture's power to reduce complex multi-unit interactions to simple helper calls
<!-- SECTION:DESCRIPTION:END -->

## Assessment (2025-12-06)

**Value: HIGH** - Core gameplay feature required for complete card roster.

**Recommendation: KEEP** - This is essential game content. The Barbarian card needs this ability to be playable. Architecture is ready, implementation is well-documented. Should be implemented when card content is priority.

**Blocker**: Depends on task-034 (Archer ability) which should be completed first.

---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Ally bonus system uses AbilityHelper.grant_ally_bonuses(unit 1 1) for +1/+1 bonuses to all allies
- [x] #2 Enemy death detection leverages AbilityHelper.is_death_post() and revolutionary single-parameter API
- [x] #3 Cross-unit state management handled through BattleRules.grant_bonuses_to_all_allies() delegation
- [x] #4 Revolutionary handle_battle_event(unit: UnitContext) API with get_handled_event_classes() returning [BattleContext.DeathEvent]
- [x] #5 Area detection and ally identification centralized in BattleRules positioning logic
- [x] #6 Bonus duration and stacking managed through BattleRules centralized state management
- [x] #7 Code reduction demonstration: traditional 15+ lines reduced to 1 helper call with crystal-clear intent
- [x] #8 Performance optimization with death event filtering and centralized bonus calculation logic
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
BarbarianAbility class created with death-triggered ally bonus mechanics.

Implementation:

- Created `project/rules/barbarian_ability.gd`

- Uses `get_handled_event_classes()` returning `[BattleContext.DeathEvent]`

- Uses `AbilityHelper.is_death_post()` to detect enemy deaths in POST phase

- Uses `not event.is_allied` to verify the dying unit is an enemy

- Uses `AbilityHelper.grant_ally_bonuses(event, 1, 1)` for +1/+1 to all allies

- Integrated into ability creation system (`block_base_card.gd` deserialization)

- Integrated into ability parser (`abilities_handler.gd` maps "cleave" to BarbarianAbility)

Files modified:

- project/rules/barbarian_ability.gd (created)

- project/core/clicker/blocks/block_base_card.gd (added BarbarianAbility case)

- project/rules/abilities_handler.gd (added "cleave" ability type)
<!-- SECTION:NOTES:END -->
