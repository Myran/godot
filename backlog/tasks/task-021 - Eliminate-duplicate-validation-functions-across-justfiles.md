---
id: task-021
title: Eliminate duplicate validation functions across justfiles
status: To Do
assignee: []
created_date: '2025-08-09 06:44'
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
