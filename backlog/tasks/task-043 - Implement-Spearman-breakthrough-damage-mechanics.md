---
id: task-043
title: Implement Spearman breakthrough damage mechanics
status: To Do
assignee: []
created_date: '2025-08-12 12:20'
updated_date: '2025-08-12 13:58'
labels:
  - abilities
  - spearman
  - breakthrough
dependencies:
  - task-034
  - task-040
priority: high
---

## Description

Implement the Spearman breakthrough damage mechanics using the revolutionary three-class architecture demonstrating positional multi-target damage through BattleRules delegation. This ability showcases the architecture's ability to handle complex line-of-sight calculations and positioning logic through centralized game rules while achieving dramatic code simplification with the AbilityHelper multi-target damage pattern.
## Acceptance Criteria

- [ ] Breakthrough line targeting uses BattleRules centralized positioning logic through AbilityHelper delegation
- [ ] Multi-target damage leverages AbilityHelper.deal_damage_to_positioned_enemies() pattern for line attacks
- [ ] Revolutionary handle_battle_event(unit: UnitContext) API with get_handled_event_classes() returning [BattleContext.CombatEvent]
- [ ] Line-of-sight calculations centralized in BattleRules with position-based targeting rules
- [ ] Damage reduction per target implemented through BattleRules diminishing damage calculations
- [ ] Event filtering optimization limits processing to combat events only for performance
- [ ] Code simplification demonstration: complex positioning logic reduced through centralized rule delegation
- [ ] Cross-platform deterministic behavior maintained with BattleRules handling all positioning calculations
