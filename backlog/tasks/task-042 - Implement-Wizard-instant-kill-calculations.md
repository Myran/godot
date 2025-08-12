---
id: task-042
title: Implement Wizard instant kill calculations
status: To Do
assignee: []
created_date: '2025-08-12 12:20'
updated_date: '2025-08-12 13:58'
labels:
  - abilities
  - wizard
  - instant-kill
dependencies:
  - task-034
  - task-040
priority: high
---

## Description

Implement the Wizard instant kill probability system using the revolutionary three-class architecture with AbilityHelper damage calculation patterns. This ability demonstrates the architecture's ability to handle complex probability-based damage calculations with proper randomization, level scaling, and edge case handling while maintaining dramatic code simplification through the BattleRules delegation pattern.
## Acceptance Criteria

- [ ] Instant kill probability calculations use AbilityHelper pattern with BattleRules delegation for damage logic
- [ ] Level scaling system leverages UnitContext automatic state access through revolutionary single-parameter API
- [ ] Boss immunity rules implemented using BattleRules centralized rule checking through AbilityHelper
- [ ] Revolutionary handle_battle_event(unit: UnitContext) API with targeted event filtering for CombatEvent only
- [ ] Randomization uses proper RNG seeding delegated to BattleRules for cross-platform determinism
- [ ] Edge case handling for special unit types centralized in BattleRules with AbilityHelper delegation
- [ ] Code reduction achievement: complex probability calculations simplified through helper pattern architecture
- [ ] Performance optimization with event filtering and centralized calculation logic shows <5% overhead vs baseline
