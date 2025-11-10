---
id: task-266
title: Implement SentryManager.register_debug_actions() bridge
status: Open
assignee: []
created_date: '2025-11-10 09:53'
updated_date: '2025-11-10 09:54'
labels:
  - sentry
  - debug-coordinator
  - integration
  - testing
dependencies:
  - task-263
priority: high
---

## Description

Implement **`register_debug_actions()`** method in SentryManager to register Sentry-specific debug actions with GameTwo's Debug Coordinator system for unified testing and diagnostics.

## Context

**Integration Point:** DebugRegistry autoload
**Test Location:** `project/debug/actions/sentry/sentry_integration_bridges_action.gd:133-153`

**Current Behavior:**
- GameTwo has unified debug system via DebugRegistry
- All subsystems register debug actions for testing
- Sentry test actions exist but not integrated with DebugRegistry
- Inconsistent with GameTwo's debug infrastructure patterns

**Target Behavior:**
- Sentry debug actions registered with DebugRegistry
- Available via debug menu and test configurations
- Consistent with other GameTwo subsystems (Firebase, Battle, etc.)
- Runtime Sentry diagnostics accessible through debug interface

## Method Signature

```gdscript
func register_debug_actions() -> void
```

**No parameters required** - registers actions directly with DebugRegistry autoload

## Implementation Requirements

1. **Action Registration:**
   - Access DebugRegistry autoload singleton
   - Register all Sentry debug actions
   - Include existing TDD test actions (already implemented)
   - Add Sentry diagnostic/configuration actions

2. **Debug Actions to Register:**
   - **Existing TDD Tests:**
     - `sentry.validate_gdextension_loading` - Validate Sentry addon loading
     - `sentry.test_sdk_functionality` - Test Sentry SDK basic functionality
     - `sentry.test_crash_scenarios` - Test crash capture scenarios
     - `sentry.test_integration_bridges` - Test GameTwo integration bridges

   - **Additional Diagnostic Actions:**
     - `sentry.show_sdk_state` - Display current Sentry SDK configuration
     - `sentry.test_capture` - Send test event to Sentry
     - `sentry.show_context` - Display current user/session context
     - `sentry.toggle_enabled` - Enable/disable Sentry at runtime

3. **Registration Pattern:**
   - Follow GameTwo's DebugRegistry registration pattern
   - Use DebugAction class hierarchy (actions already extend DebugAction)
   - Register with appropriate categories (Sentry Debug, Diagnostics)
   - Respect GameTwo's action naming conventions

4. **Integration Consistency:**
   - Match patterns used by Firebase, Battle, System layers
   - Ensure actions are accessible via debug menu
   - Enable test configuration discovery
   - Support both desktop and Android platforms

## Test Validation

**Test Method:** `_test_debug_coordinator_compatibility()` in `sentry_integration_bridges_action.gd`

**Test Flow:**
1. Validates DebugRegistry autoload exists and is valid
2. Checks SentryManager has `register_debug_actions()` method
3. Expects return: `true` (bridge structure validated)

## Success Criteria

- [ ] Method `register_debug_actions()` exists in SentryManager
- [ ] Method takes no parameters
- [ ] Registers all existing Sentry debug actions with DebugRegistry
- [ ] Actions accessible via debug menu
- [ ] Actions discoverable in test configurations
- [ ] Test `_test_debug_coordinator_compatibility()` returns true
- [ ] Integration test shows 3/3 bridges working (all tasks complete)
- [ ] Works on both desktop and Android platforms

## Technical Considerations

**DebugRegistry Integration:**
- Access via `DebugRegistry` autoload singleton
- Use `DebugRegistry.register_action()` method
- Pass DebugAction instances (already implemented)
- Actions already extend DebugAction base class

**Existing Sentry Actions:**
- `SentryAddonValidationAction` - Already implemented
- `SentryIntegrationTestAction` - Already implemented
- `SentryCrashTestingAction` - Already implemented
- `SentryIntegrationBridgesAction` - Already implemented (current test)

**Action Discovery:**
- Actions located in `project/debug/actions/sentry/`
- All already instantiable via class_name
- Need to be registered during SentryManager initialization
- Should be registered early (during autoload phase)

**Initialization Timing:**
- Call during SentryManager._ready() or _init()
- Ensure DebugRegistry is available before registering
- Handle gracefully if DebugRegistry not available (shouldn't happen)

## Example Implementation (Pseudocode)

```gdscript
func register_debug_actions() -> void:
    if not DebugRegistry:
        Log.warning("DebugRegistry not available for Sentry action registration")
        return

    # Register existing TDD test actions
    DebugRegistry.register_action(SentryAddonValidationAction.new())
    DebugRegistry.register_action(SentryIntegrationTestAction.new())
    DebugRegistry.register_action(SentryCrashTestingAction.new())
    DebugRegistry.register_action(SentryIntegrationBridgesAction.new())

    # Register additional diagnostic actions (if implemented)
    # DebugRegistry.register_action(SentryShowStateAction.new())
    # DebugRegistry.register_action(SentryTestCaptureAction.new())
    # DebugRegistry.register_action(SentryShowContextAction.new())

    Log.debug("Sentry debug actions registered with DebugRegistry")
```

## Future Enhancements (Optional)

Additional diagnostic actions that could be implemented:

1. **`sentry.show_sdk_state`** - Display current Sentry SDK status
   - Enabled/disabled state
   - DSN configuration
   - Environment (development/production)
   - Sample rate settings

2. **`sentry.test_capture`** - Send test event to verify connectivity
   - Capture test message
   - Return success/failure
   - Display event ID

3. **`sentry.show_context`** - Display current context
   - User context (from Firebase)
   - Tags
   - Extras
   - Breadcrumbs

4. **`sentry.toggle_enabled`** - Runtime enable/disable
   - Toggle Sentry SDK on/off
   - Useful for debugging without Sentry noise
   - Persists across sessions

## Related Tasks

- **Parent:** task-263 - Implement SentryManager Engine singleton
- **Related:** task-264 - Advanced Logger error bridge
- **Related:** task-265 - Firebase context integration
- **Blocks:** task-263 completion (all 3 bridges required)

## Related Files

**Test:** `project/debug/actions/sentry/sentry_integration_bridges_action.gd:133-153`
**Existing Actions:** `project/debug/actions/sentry/`
  - `sentry_addon_validation_action.gd`
  - `sentry_integration_test_action.gd`
  - `sentry_crash_testing_action.gd`
  - `sentry_integration_bridges_action.gd`
**DebugRegistry:** `autoloads/debug_manager.gd` and `debug/debug_action_registry.gd`
**DebugAction Base:** `debug/debug_action.gd`
