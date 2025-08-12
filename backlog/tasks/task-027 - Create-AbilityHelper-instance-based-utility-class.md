---
id: task-027
title: Create AbilityHelper instance-based utility class
status: To Do
assignee: []
created_date: '2025-08-12 12:17'
updated_date: '2025-08-12 13:28'
labels:
  - architecture
  - utilities
  - instance-design
dependencies:
  - task-025
priority: high
---

## Description

Implement the AbilityHelper class using STATIC methods for pure ability-specific utilities as specified in the architecture. This class provides ability-focused helper methods and delegates complex operations to BattleRules static methods. While performance expert recommended instance-based approach, architecture requires static methods for consistent separation of concerns and type-safe design.
## Acceptance Criteria

- [ ] AbilityHelper class implemented with STATIC methods only
- [ ] Event type checking methods implemented (is_death_post is_damage_pre is_combat_pre is_battle_start_post)
- [ ] Single-unit event creation methods implemented (grant_health_bonus grant_attack_bonus deal_damage_to_unit)
- [ ] Complex operation delegation methods implemented (deal_damage_to_random_enemy grant_ally_bonuses) that call BattleRules
- [ ] Event filtering optimization method implemented (should_process_event) using class references
- [ ] Strong typing enforced with proper return type annotations
- [ ] Unit tests cover all helper methods with edge cases
- [ ] Integration tests validate helper delegation to BattleRules
- [ ] Performance validation shows acceptable overhead for static method calls
- [ ] Class follows exact signatures from architecture doc-001
