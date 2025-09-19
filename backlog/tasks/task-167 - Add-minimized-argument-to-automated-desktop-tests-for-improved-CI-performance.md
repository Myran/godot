---
id: task-167
title: >-
  Add --minimized argument to automated desktop tests for improved CI
  performance
status: Done
assignee: []
created_date: '2025-09-19 20:53'
updated_date: '2025-09-19 21:21'
labels: []
dependencies: []
priority: medium
---

## Description

## Context

Recent commits added support for --minimized flag to project/main.gd (lines 27-30) which sets DisplayServer.WINDOW_MODE_MINIMIZED when the flag is detected in command line arguments.

## Current State

Desktop automated tests in justfile-validation-enhanced-testing.justfile:2618 and :3216 use:
```bash
./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --test-mode
```

## Required Change

Add --minimized argument to automated desktop test execution to improve CI performance and reduce resource usage:
```bash  
./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --test-mode --minimized
```

## Files to Update

1. justfile-validation-enhanced-testing.justfile:2618 (in _run-desktop-test function)
2. justfile-validation-enhanced-testing.justfile:3216 (in _test-desktop-target-original function)  

## Benefits

- Reduces desktop resource usage during automated testing
- Improves CI performance by avoiding window rendering overhead
- Maintains visual consistency with headless testing approach
- No impact on test functionality - only affects window visibility

## Implementation Notes

- Only applies to automated tests (test-desktop-target)
- Manual desktop tests (test-desktop-manual) should remain visible
- Verify --minimized flag works correctly with --test-mode combination

## Implementation Complete

Successfully implemented --minimized argument for automated desktop tests in justfile-validation-enhanced-testing.justfile.

### Changes Made:
1. Line 2618: Added --minimized to _run-desktop-test function
2. Line 3216: Added --minimized to _test-desktop-target-original function

### Validation Results:
✅ Minimize flag properly detected: "Minimized flag detected, setting window to minimized mode"
✅ Command line args include both flags: ["--test-mode", "--minimized"]  
✅ Manual tests (test-desktop-manual) correctly remain visible
✅ Automated tests execute successfully with minimized windows

### Benefits Achieved:
- Reduced CI resource usage by avoiding window rendering overhead
- Improved automated test performance
- Maintained full test functionality
- Clean separation between manual (visible) and automated (minimized) tests

Implementation follows simplicity and robustness principles: minimal changes with clear separation of concerns.
