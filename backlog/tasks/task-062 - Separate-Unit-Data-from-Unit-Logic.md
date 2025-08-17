---
id: task-062
title: Separate Unit Data from Unit Logic
status: To Do
assignee: []
created_date: '2025-08-17 08:10'
updated_date: '2025-08-17 08:22'
labels:
  - architecture
  - refactoring
  - units
  - separation-of-concerns
dependencies: []
priority: high
---

## Description

Extract game logic from UnitData class to UnitBehavior class to achieve proper separation of concerns. The current 643-line UnitData class mixes data storage with complex game logic.

## Acceptance Criteria

- [ ] UnitBehavior class created with game logic methods
- [ ] Data storage remains in UnitData class only
- [ ] Clear separation between data and behavior established
- [ ] UnitData class reduced to data-only responsibilities
- [ ] Unit tests validate both data and behavior components

## Implementation Notes

**Part of Comprehensive Refactoring Initiative (task-074)** 
Phase 1: Critical Architecture Decoupling - UnitData Class Refactoring
This task addresses the UnitData god object (643 lines) by separating game logic into a UnitBehavior class while keeping only data storage in UnitData.
