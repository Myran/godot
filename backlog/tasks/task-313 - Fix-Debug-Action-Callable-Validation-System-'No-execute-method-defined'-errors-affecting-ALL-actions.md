---
id: task-313
title: >-
  Fix: Debug Action Callable Validation System - 'No execute method defined'
  errors affecting ALL actions
status: Done
assignee: []
created_date: '2025-11-25 11:19'
updated_date: '2025-11-25 11:26'
labels:
  - critical
  - test-framework
  - debug-system
  - validation
dependencies: []
---

## Description

**CRITICAL: Global Debug Action Validation Failure**

All debug actions are failing with "No execute method defined" errors, affecting the entire test infrastructure. This is a global issue with the DebugAction callable validation system.

## Error Pattern

```
ERROR: No execute method defined for [action_name]
[ERROR] Action callable invalid { "action": "[action_name]" }
[ERROR] [font_size=24]ERROR: No execute method defined for [action_name][/font_size]
```

## Affected Actions

### System Actions (GDScript):
- `system.debug.registry_stats`
- `system.debug.replay_complete`
- `system.debug.logger_stats`
- All other system.debug.* actions

### C++ Firebase Actions:
- `cpp.firebase.database_availability`
- `cpp.firebase.error_handling`
- `cpp.firebase.get_value`
- `cpp.firebase.set_value`
- `cpp.firebase.signal_integrity`
- `cpp.firebase.timeout_behavior`
- All other cpp.firebase.* actions

## Investigation Timeline

### Initial Investigation (2025-11-25)
- Issue discovered during manual mode testing after commit 7b84196b
- Initially thought to be manual mode detection problem
- **Root Cause Analysis revealed**: Manual mode is working correctly - this is a separate issue

### Evidence Collection
**Test Session IDs for Reference:**
- `debug-session-1764068768-1464` (registry_stats test)
- `debug-session-1764069348-0923` (firebase-cpp-layer test)

**Key Finding**: Both system and C++ actions fail with identical callable validation errors, suggesting a global issue in the DebugAction system rather than action-specific problems.

## Technical Context

### DebugAction Registration Pattern
```gdscript
# System Actions (system_actions.gd)
DebugAction.create("system.debug.registry_stats", func() -> bool: return _show_registry_stats(registry))

# C++ Firebase Actions (cpp_firebase_actions.gd)
DebugAction.create("cpp.firebase.database_availability", func() -> bool: return _check_database_availability())
```

### Callable Execution Flow
1. DebugAction registration creates callable from function reference
2. DebugAction._execute_core() calls `action_callable.call()`
3. Validation at debug_action.gd:275-284 checks `action_callable.is_valid()`
4. If invalid → "No execute method defined" error

### Potential Root Causes
1. **Function Reference Issues**: Static function references not converting to valid Callables
2. **GDScript Compilation**: Binary changes not properly applied to callable references
3. **Registration Timing**: Actions registered before GDScript engine fully initialized
4. **Callable Creation**: DebugAction.create() callable wrapping has issues
5. **Platform Differences**: Callable validation failing differently on Android vs Desktop

## Files to Investigate

1. **`project/debug/actions/debug_action.gd`**
   - Lines 275-284: Callable validation and execution
   - Lines 371-375: Error generation for invalid callables
   - DebugAction.create() method

2. **`project/debug/actions/registrations/system_actions.gd`**
   - Action registration patterns
   - Function references used in DebugAction.create()

3. **`project/debug/actions/registrations/cpp_firebase_actions.gd`**
   - C++ action registration patterns
   - Lambda function callables

4. **`project/debug/actions/debug_action_registry.gd`**
   - Registration and validation process
   - How callables are stored and retrieved

## Critical Files for Testing

**Test Configs:**
- `tests/debug_configs/system.debug.registry_stats.json` - Single action test
- `tests/debug_configs/firebase-test-3-operations.json` - Multi-action test

**Log Files:**
- `/Users/mattiasmyhrman/repos/gametwo/logs/20251125_120556_test-android_system_debug_registry_stats.log`
- `/Users/mattiasmyhrman/repos/gametwo/logs/android_firebase-cpp-layer_android_1764069342.log`

## Test Commands

```bash
# Test system actions
just log-run-silent test-android 'system.debug.registry_stats'
just logs-errors [test_id]

# Test C++ actions
just log-run-silent test-android 'firebase-cpp-layer'
just logs-errors [test_id]

# Debug callable validation
rg -A 5 -B 5 "action_callable.is_valid" project/debug/actions/debug_action.gd
```

## Acceptance Criteria

- [ ] All system.debug.* actions execute without "No execute method defined" errors
- [ ] All cpp.firebase.* actions execute without "No execute method defined" errors
- [ ] DebugAction.create() successfully creates valid callables from function references
- [ ] Callable validation passes for both static functions and lambda functions
- [ ] Test framework works correctly for both single-action and multi-action configs
- [ ] Error logs show no "No execute method defined" entries for any registered actions

## Investigation Notes

**Confirmed Working:**
- Manual mode detection (FIXED in commit ec6bbec9)
- Test infrastructure initialization
- Action registration (actions appear in registry)
- App lifecycle (launch, execute, quit)

**Confirmed Broken:**
- Callable validation for ALL action types
- Execution of registered actions
- Function reference → Callable conversion

**Next Investigation Steps:**
1. Debug the DebugAction.create() method to see how callables are created
2. Check if there's a compilation/build issue affecting callable generation
3. Compare working vs non-working action registrations
4. Test on desktop vs Android to see if platform-specific issue

## Related Commits

- **ec6bbec9** - Fixed manual mode detection (SEPARATE from this issue)
- **7b84196b** - Manual mode detection changes (initially suspected but not the cause)

## Priority: CRITICAL

This affects the entire test infrastructure and prevents any debug actions from executing properly. The issue is global and affects all action types, suggesting a fundamental problem in the DebugAction system.
