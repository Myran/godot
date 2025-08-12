---
id: task-028
title: Update base Ability class with new architecture API
status: To Do
assignee: []
created_date: '2025-08-12 12:18'
updated_date: '2025-08-12 13:28'
labels:
  - architecture
  - api-design
  - backward-compatibility
dependencies:
  - task-026
priority: high
---

## Description

Refactor the existing base Ability class to implement the REVOLUTIONARY single-parameter API using UnitContext. This is the game-changing improvement that reduces method signatures from 5 separate parameters to a single UnitContext object. The new API enables dramatic code simplification and improved readability while maintaining backward compatibility during transition.
## Acceptance Criteria

- [ ] Base Ability class updated with revolutionary single-parameter method signature (handle_battle_event(unit: UnitContext))
- [ ] Backward compatibility maintained through method overloading or wrapper methods
- [ ] All existing ability subclasses continue to function without modification
- [ ] Revolutionary API reduces cognitive load from 5 parameters to 1 UnitContext object
- [ ] Strong typing applied to UnitContext parameter and return types
- [ ] Abstract method contracts clearly defined for subclass implementation
- [ ] Unit tests updated and expanded to cover new single-parameter API surface
- [ ] Integration tests validate seamless UnitContext creation and consumption
- [ ] Documentation updated with revolutionary API benefits and migration examples
- [ ] Performance validation shows UnitContext creation overhead is minimal
