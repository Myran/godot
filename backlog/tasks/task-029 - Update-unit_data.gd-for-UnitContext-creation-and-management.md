---
id: task-029
title: Update unit_data.gd for UnitContext creation and management
status: To Do
assignee: []
created_date: '2025-08-12 12:18'
updated_date: '2025-08-12 13:28'
labels:
  - data-integration
  - lifecycle-management
  - memory-management
dependencies:
  - task-026
  - task-028
priority: high
---

## Description

Update unit_data.gd to be the EXCLUSIVE location for UnitContext creation as required by the architecture. This file becomes the single point where UnitContext.new() is called, creating context objects once per unit per event and reusing them across all abilities. This is critical for the revolutionary single-parameter API implementation.
## Acceptance Criteria

- [ ] unit_data.gd becomes the EXCLUSIVE location for UnitContext.new() calls
- [ ] check_abilities method updated to create UnitContext once per unit per event
- [ ] Same UnitContext instance reused for all abilities on the same unit during event processing
- [ ] Integration with UnitContext object pool system for efficient memory management
- [ ] Revolutionary single-parameter API implemented (ability.handle_battle_event(unit_context))
- [ ] Context lifecycle properly managed with creation and cleanup hooks
- [ ] Integration with existing unit creation and destruction flows seamless
- [ ] Memory management verified with no context leaks during unit lifecycle
- [ ] Performance impact measured and validated as acceptable (<5% overhead)
- [ ] Strong typing maintained throughout unit_data.gd modifications
- [ ] Unit tests cover exclusive context creation and reuse patterns
- [ ] Integration tests validate end-to-end revolutionary API implementation
