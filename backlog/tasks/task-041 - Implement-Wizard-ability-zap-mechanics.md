---
id: task-041
title: Implement Wizard ability zap mechanics
status: To Do
assignee: []
created_date: '2025-08-12 12:20'
updated_date: '2025-10-26 14:30'
labels:
  - abilities
  - wizard
  - complex-mechanics
dependencies:
  - task-034
priority: high
---

## Description

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
## Acceptance Criteria

- [ ] Multi-target zap uses AbilityHelper.deal_damage_to_random_enemy(unit 2 3) for 2 damage to 3 random enemies
- [ ] Chain lightning targeting leverages BattleRules centralized targeting through AbilityHelper delegation
- [ ] Revolutionary handle_battle_event(unit: UnitContext) API with get_handled_event_classes() optimization
- [ ] Event filtering returns [BattleContext.CombatEvent] for performance optimization
- [ ] Code reduction demonstration: traditional 20+ lines of targeting logic reduced to 1 helper call
- [ ] Visual effects integration works seamlessly with simplified targeting system
- [ ] Cross-platform deterministic behavior maintained with proper RNG delegation to BattleRules
- [ ] Performance validation shows <5% overhead vs traditional implementation with dramatic code simplification
