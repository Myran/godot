---
id: task-025
title: Create BattleRules core class with instance-based architecture
status: To Do
assignee: []
created_date: '2025-08-12 12:17'
updated_date: '2025-08-12 13:28'
labels:
  - architecture
  - battle-system
  - foundation
dependencies: []
priority: high
---

## Description

Implement the foundational BattleRules class using STATIC methods for core game mechanics and targeting rules. This class centralizes all game logic ('how the game works') and provides reusable rule queries that can be called from any system. The static approach ensures consistent rule application and eliminates state management complexity.
## Acceptance Criteria

- [ ] BattleRules class created with STATIC methods only
- [ ] Core position and targeting rules implemented (get_ally_positions get_enemy_positions count_allies_alive count_enemies_alive)
- [ ] Multi-target operations implemented (deal_damage_to_random_enemies grant_bonuses_to_all_allies)
- [ ] All methods use BattleContext as first parameter with proper typing
- [ ] Methods follow exact signatures from architecture doc-001
- [ ] Class has no instance state or constructor
- [ ] Unit tests created with 90%+ code coverage for all static methods
- [ ] Performance benchmark validates static method efficiency
