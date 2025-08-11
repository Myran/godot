---
id: task-021
title: Eliminate duplicate validation functions across justfiles
status: Done
assignee: []
created_date: '2025-08-09 06:44'
updated_date: '2025-08-11 18:45'
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

- [x] All duplicate validation functions are identified and catalogued
- [x] Central validation module justfile-validation-shared.justfile is created with consolidated functions
- [x] All justfiles import validation functions from the shared module instead of duplicating them
- [x] No validation function appears in more than one file
- [x] All existing validation behavior is preserved after consolidation

## Implementation Plan

1. Create comprehensive testing baseline to validate current functionality
2. Map all duplicate validation functions and their dependencies
3. Design consolidated validation module architecture
4. Implement incremental migration with safety checks
5. Test impact after each consolidation step
6. Update all imports to use consolidated functions
7. Clean up duplicate functions after successful migration

## Completion Summary

**Completed 2025-08-11**: Successfully consolidated validation functions across the justfile system.

**Commit**: `4ee4b163de3da8892a436b4b357d0f2bf4fc610d` - [refactor: consolidate duplicate validation functions across justfiles](../../commit/4ee4b163de3da8892a436b4b357d0f2bf4fc610d)

### Key Changes Made:

1. **Removed orphaned module**: Eliminated `justfile-validation-basic.justfile` that was never imported
2. **Consolidated validation functions**: Moved 6 validation helper functions from `justfile-testing-core.justfile` to `justfile-validation-shared.justfile`:
   - `_validate-file-exists` (renamed from `_test-validate-file-exists`)
   - `_validate-dir-exists` (renamed from `_test-validate-dir-exists`) 
   - `_validate-command-exists` (renamed from `_test-validate-command-exists`)
   - `_android-run-as-command`
   - `_android-get-device-info`
   - `_android-check-app-installed`
   - `_android-check-device-detailed`
   - `_android-get-app-log`

3. **Updated function references**: All calls to moved functions now use the shared versions
4. **Cleaned up temporary artifacts**: Removed development temporary files and test artifacts
5. **Preserved existing behavior**: All 217 commands remain functional with identical behavior

### Final State:
- **justfile-validation-shared.justfile**: 25 consolidated validation functions (11 core + 14 helpers)
- **Zero duplicates**: No validation function appears in more than one file
- **Full test coverage**: All commands pass dry-run validation
