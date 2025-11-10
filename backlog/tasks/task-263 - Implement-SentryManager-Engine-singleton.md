---
id: task-263
title: Implement SentryManager Engine singleton
status: Open
assignee: []
created_date: '2025-11-10 09:51'
updated_date: '2025-11-10 09:51'
labels:
  - sentry
  - integration
  - tdd
  - gdextension
dependencies: []
priority: high
---

## Description

Implement **SentryManager** as an Engine singleton (GDExtension) to bridge Sentry SDK with GameTwo's existing infrastructure systems (Advanced Logger, Firebase, Debug Coordinator).

## Context

**Current State:**
- Sentry SDK integrated via GDExtension addon
- TDD test `sentry.test_integration_bridges` validates bridge structure
- Test currently fails (0/3 bridges working) - expected TDD behavior
- GameTwo infrastructure (Log, FirebaseService, DebugRegistry) fully operational

**Test Location:** `project/debug/actions/sentry/sentry_integration_bridges_action.gd`

**Test Expectation:**
```gdscript
Engine.get_singleton("SentryManager")  // Should return valid Node
```

## Required Implementation

SentryManager must be registered as an Engine singleton (not a GDScript autoload) with 3 bridge methods:

1. **`handle_advanced_logger_error()`** - Capture Advanced Logger errors to Sentry
2. **`setup_firebase_context()`** - Enrich Sentry events with Firebase user context
3. **`register_debug_actions()`** - Register Sentry debug actions with DebugRegistry

See subtasks (task-264, task-265, task-266) for detailed specifications of each method.

## Success Criteria

- [ ] SentryManager registered as Engine singleton
- [ ] Accessible via `Engine.get_singleton("SentryManager")`
- [ ] Returns valid Node (not null)
- [ ] All 3 bridge methods implemented (see subtasks)
- [ ] Test `sentry.test_integration_bridges` passes (3/3 bridges working)
- [ ] GDExtension properly configured in sentry.gdextension
- [ ] Works on both desktop and Android platforms

## Technical Considerations

**GDExtension Registration:**
- Likely needs C++/GDNative implementation
- Must register with ClassDB as singleton
- Should extend Node or appropriate Godot base class

**Platform Compatibility:**
- Desktop: Use existing Sentry native SDK
- Android: Use Sentry Android SDK integration
- Cross-platform singleton registration

## Related Work

**Test File:** `project/debug/actions/sentry/sentry_integration_bridges_action.gd`
**Sentry Addon:** `addons/sentry/`
**Other Sentry Tests:**
- `sentry_addon_validation_action.gd` - PASSED ✅
- `sentry_integration_test_action.gd` - PASSED ✅
- `sentry_crash_testing_action.gd` - Simulated TDD tests

## Dependencies

This task has 3 subtasks that define the specific bridge method implementations:
- task-264: Implement handle_advanced_logger_error()
- task-265: Implement setup_firebase_context()
- task-266: Implement register_debug_actions()

All subtasks must be completed for this parent task to be considered done.
