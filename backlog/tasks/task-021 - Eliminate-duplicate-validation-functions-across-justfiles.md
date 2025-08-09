---
id: task-021
title: Eliminate duplicate validation functions across justfiles
status: In Progress
assignee: []
created_date: '2025-08-09 06:44'
updated_date: '2025-08-09 07:03'
labels:
  - refactor
  - justfiles
  - validation
dependencies: []
priority: high
---

## Description

There are 19+ duplicate validation functions scattered across multiple justfile modules, creating maintenance issues and inconsistent behavior. Functions like _validate-android-device, _validate-ios-tools, _validate-godot-editor, and _validate-path-exists appear multiple times with identical implementations.

## Acceptance Criteria

- [ ] All duplicate validation functions are identified and catalogued
- [ ] Central validation module justfile-validation-shared.justfile is created with consolidated functions
- [ ] All justfiles import validation functions from the shared module instead of duplicating them
- [ ] No validation function appears in more than one file
- [ ] All existing validation behavior is preserved after consolidation

## Implementation Plan

1. Create comprehensive testing baseline to validate current functionality
2. Map all duplicate validation functions and their dependencies
3. Design consolidated validation module architecture
4. Implement incremental migration with safety checks
5. Test impact after each consolidation step
6. Update all imports to use consolidated functions
7. Clean up duplicate functions after successful migration
