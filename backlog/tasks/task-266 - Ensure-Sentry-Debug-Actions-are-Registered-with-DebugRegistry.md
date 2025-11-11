---
id: task-266
title: Ensure Sentry Debug Actions are Registered with DebugRegistry
status: Open
assignee: []
created_date: '2025-11-10 09:53'
updated_date: '2025-11-10 23:13'
labels:
  - sentry
  - debug-coordinator
  - integration
  - testing
dependencies: []
priority: low
---

## Description

Verify Sentry debug actions are properly registered with DebugRegistry and accessible via debug menu. No intermediate bridge layer needed - debug actions already exist and follow GameTwo's patterns.

## Context

**Expert Panel Decision (2025-11-10):**
- Simplified from SentryManager bridge to direct registration
- Debug actions already exist and extend DebugAction
- Just need to ensure they're registered with DebugRegistry (likely already happening via auto-discovery)
- Reduces implementation time from 6-8h to 2-3h (62% reduction)

**Current Behavior:**
- Sentry debug actions exist in `project/debug/actions/sentry/`
- All actions extend DebugAction base class
- Actions may already be auto-discovered by DebugRegistry
- Test actions are accessible and functional (tests pass)

**Target Behavior:**
- Verify all Sentry actions are registered with DebugRegistry
- Ensure actions are accessible via debug menu
- Confirm test configuration discovery works
- Consistent with other GameTwo subsystems

## Existing Sentry Debug Actions

**Currently Implemented:**
1. `SentryAddonValidationAction` - Validate Sentry GDExtension loading
2. `SentryIntegrationTestAction` - Test SentrySDK basic functionality
3. `SentryCrashTestingAction` - Test crash capture scenarios
4. `SentryIntegrationBridgesAction` - Test direct integration (needs update)

**Location:** `project/debug/actions/sentry/*.gd`

All actions:
- ✅ Already extend `DebugAction` base class
- ✅ Already have proper action names and categories
- ✅ Already implement required methods
- ✅ Already work in test configurations

## Required Implementation

### **Option 1: Verify Auto-Discovery (Preferred)**

Check if DebugRegistry already auto-discovers Sentry actions:

```gdscript
# Test if actions are already registered
var sentry_actions = DebugRegistry.get_actions_by_category("Sentry Debug")
print("Registered Sentry actions: ", sentry_actions.size())
```

If auto-discovery works → **No implementation needed** ✅

### **Option 2: Manual Registration (If Needed)**

If auto-discovery doesn't work, add explicit registration:

```gdscript
# In project/debug/sentry_debug_registration.gd (new file)
extends Node

func _ready() -> void:
	_register_sentry_actions()

func _register_sentry_actions() -> void:
	if not is_instance_valid(DebugRegistry):
		return

	# Register all Sentry debug actions
	DebugRegistry.register_action(SentryAddonValidationAction.new())
	DebugRegistry.register_action(SentryIntegrationTestAction.new())
	DebugRegistry.register_action(SentryCrashTestingAction.new())
	DebugRegistry.register_action(SentryIntegrationBridgesAction.new())

	Log.debug("Sentry debug actions registered", {}, ["debug", "sentry"])
```

Then add as autoload in `project.godot`:
```
SentryDebugRegistration="*res://debug/sentry_debug_registration.gd"
```

### **Option 3: Update Existing Registration (If Pattern Exists)**

If GameTwo has existing debug action registration patterns, follow them:

```gdscript
# Check existing patterns in:
# - project/debug/firebase_debug_registration.gd (example)
# - project/debug/battle_debug_registration.gd (example)
# Follow same pattern for Sentry actions
```

## Success Criteria

- [ ] Verify Sentry actions appear in debug menu (desktop)
- [ ] Confirm test configurations can discover Sentry actions
- [ ] All 4 existing Sentry actions registered
- [ ] Actions accessible on both desktop and Android
- [ ] No duplicate registrations
- [ ] Consistent with Firebase/Battle registration patterns

## Technical Considerations

**DebugRegistry Auto-Discovery:**
- Check if DebugRegistry scans `debug/actions/` directories
- If yes, Sentry actions should be auto-discovered
- Verify by checking DebugRegistry implementation

**Registration Patterns:**
- Follow existing patterns for Firebase, Battle, System debug actions
- Check if other subsystems use autoload registration
- Maintain consistency with GameTwo's architecture

**Priority Assessment:**
- **Low priority** - Actions already work in tests
- Only needed if debug menu access is required
- Auto-discovery may already handle this

## Investigation Steps

1. **Check DebugRegistry Implementation:**
   ```gdscript
   # Read: project/debug/debug_action_registry.gd
   # Look for: auto-discovery, directory scanning, registration methods
   ```

2. **Test Current State:**
   ```gdscript
   # Run desktop with debug menu
   # Check if "Sentry Debug" category appears
   # If yes → Already working, no implementation needed
   ```

3. **Check Existing Patterns:**
   ```bash
   rg "register_action" project/debug --type gd
   rg "DebugRegistry" project --type gd -A 3
   ```

## Estimated Effort

**2-3 hours** (vs 6-8 hours for SentryManager bridge approach)

- Investigation: 1 hour (check auto-discovery)
- Implementation: 0-1 hour (only if manual registration needed)
- Testing: 0.5 hour
- Documentation: 0.5 hour

**If auto-discovery works: 1 hour total** (investigation + verification only)

## Related Work

**Existing Files:**
- `project/debug/actions/sentry/*.gd` - All debug actions already implemented
- `project/debug/debug_action_registry.gd` - DebugRegistry implementation
- `project/debug/debug_action.gd` - Base class (already used by Sentry actions)

**Test Files:**
- `project/debug/actions/sentry/sentry_integration_bridges_action.gd` - Update to validate direct integration instead of bridges

**Reference:**
- task-263 - Direct SentrySDK Integration in Advanced Logger
- task-265 - Add Firebase User Context to Sentry

## Expert Panel Recommendation

**Benefits of Direct Registration:**
- ✅ Actions already exist and work
- ✅ No wrapper layer needed
- ✅ May already be auto-discovered
- ✅ Consistent with GameTwo's patterns
- ✅ Simple verification task vs complex implementation

**Previous Approach Rejected:**
- ❌ SentryManager bridge added unnecessary layer
- ❌ Debug actions don't need "manager" to register themselves
- ❌ Inconsistent with how other subsystems register actions

See `/tmp/task-263-expert-panel-evaluation.md` for complete analysis.

## Dependencies

**Independent task** - no dependencies on SentryManager (task-263/264 obsolete)

Can be implemented in parallel with:
- task-263: Direct Advanced Logger integration
- task-265: Firebase user context integration

## Future Enhancements (Optional)

Additional diagnostic actions that could be added:

1. **`sentry.show_sdk_state`** - Display current SDK configuration
2. **`sentry.test_capture`** - Send test event to Sentry
3. **`sentry.show_context`** - Display user/session context
4. **`sentry.toggle_enabled`** - Runtime enable/disable

**Note:** Only add if needed - existing 4 actions may be sufficient for current requirements.
