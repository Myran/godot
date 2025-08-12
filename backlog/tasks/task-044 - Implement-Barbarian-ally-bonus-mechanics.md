---
id: task-044
title: Implement Barbarian ally bonus mechanics
status: To Do
assignee: []
created_date: '2025-08-12 12:20'
updated_date: '2025-08-12 13:58'
labels:
  - abilities
  - barbarian
  - ally-bonuses
dependencies:
  - task-034
  - task-040
priority: high
---

## Description

Implement the Barbarian ally bonus mechanics using the revolutionary three-class architecture demonstrating cross-unit state management through the AbilityHelper.grant_ally_bonuses() pattern. This ability validates the architecture's power to handle complex multi-unit interactions and area detection through BattleRules delegation while achieving dramatic code simplification from traditional 15+ line implementations to single helper calls.
## Acceptance Criteria

- [ ] Ally bonus system uses AbilityHelper.grant_ally_bonuses(unit 1 1) for +1/+1 bonuses to all allies
- [ ] Enemy death detection leverages AbilityHelper.is_death_post() and revolutionary single-parameter API
- [ ] Cross-unit state management handled through BattleRules.grant_bonuses_to_all_allies() delegation
- [ ] Revolutionary handle_battle_event(unit: UnitContext) API with get_handled_event_classes() returning [BattleContext.DeathEvent]
- [ ] Area detection and ally identification centralized in BattleRules positioning logic
- [ ] Bonus duration and stacking managed through BattleRules centralized state management
- [ ] Code reduction demonstration: traditional 15+ lines reduced to 1 helper call with crystal-clear intent
- [ ] Performance optimization with death event filtering and centralized bonus calculation logic
