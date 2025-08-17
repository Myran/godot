---
id: task-063
title: Extract Unit Stat Calculations
status: To Do
assignee: []
created_date: '2025-08-17 08:10'
updated_date: '2025-08-17 08:22'
labels:
  - architecture
  - refactoring
  - units
  - functional
dependencies: []
priority: high
---

## Description

Move stat calculations from UnitData to UnitStatCalculator to create pure functions for stat computations. Current implementation mixes calculation logic with data storage.

## Acceptance Criteria

- [ ] UnitStatCalculator class created with pure calculation methods
- [ ] All stat calculation logic moved from UnitData
- [ ] Calculation functions are stateless and deterministic
- [ ] UnitData uses calculator for stat computations
- [ ] Unit tests validate calculation accuracy and purity

## Implementation Notes

**Part of Comprehensive Refactoring Initiative (task-074)** 
Phase 1: Critical Architecture Decoupling - UnitData Class Refactoring
This task extracts stat calculations from UnitData into a UnitStatCalculator with pure functions for stat computations.
