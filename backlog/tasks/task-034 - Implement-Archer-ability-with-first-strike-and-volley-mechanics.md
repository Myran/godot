---
id: task-034
title: Implement Archer ability with first strike and volley mechanics
status: To Do
assignee: []
created_date: '2025-08-12 12:18'
updated_date: '2025-08-12 13:58'
labels:
  - complex-abilities
  - archer
  - multi-target
dependencies:
  - task-032
priority: low

**Updated 2025-10-26**: Removed task-040 dependency (archived performance optimization) since event filtering system is already implemented and functional.
---

## Description

Implement the Archer ability using the revolutionary three-class architecture (BattleRules, UnitContext, AbilityHelper) demonstrating first strike priority mechanics and arrow volley targeting with dramatic code simplification. This ability validates the architecture's ability to handle complex multi-step ability logic using the single-parameter API while achieving 80% code reduction from traditional implementations.
## Acceptance Criteria

- [ ] Archer first strike mechanic uses AbilityHelper.is_combat_pre() and revolutionary single-parameter API
- [ ] Arrow volley system uses AbilityHelper.deal_damage_to_random_enemy() for multi-target attacks
- [ ] Ability implements get_handled_event_classes() returning [BattleContext.CombatEvent BattleContext.BattleStartEvent]
- [ ] Revolutionary handle_battle_event(unit: UnitContext) API demonstrates 80% code reduction
- [ ] Event filtering optimization limits processing to relevant events only
- [ ] Code achieves dramatic simplification: traditional 25+ lines reduced to 8 lines with crystal-clear intent
- [ ] Cross-platform deterministic behavior maintained with proper RNG usage
- [ ] Performance benchmarks validate <5% overhead vs baseline implementation
