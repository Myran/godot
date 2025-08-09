---
id: task-022
title: Remove legacy and dead code from justfiles
status: To Do
assignee: []
created_date: '2025-08-09 06:44'
labels:
  - refactor
  - justfiles
  - cleanup
dependencies: []
priority: high
---

## Description

The justfiles codebase contains 22+ instances of legacy and dead code that clutters the system and creates confusion. This includes _removed_* functions that are marked as removed but still exist, legacy fallback code paths that are never executed, and comment blocks marked with '# REMOVED:' followed by dead implementations.

## Acceptance Criteria

- [ ] All _removed_* functions are completely deleted from all justfiles
- [ ] All '# REMOVED:' comment blocks and their associated dead code are eliminated
- [ ] Legacy fallback code paths that are unreachable are identified and removed
- [ ] No dead or legacy code remains in any justfile module
- [ ] All remaining functions are verified to be actively used and functional
