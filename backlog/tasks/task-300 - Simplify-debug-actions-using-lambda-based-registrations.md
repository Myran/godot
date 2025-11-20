---
id: task-300
title: Simplify debug actions using lambda-based registrations
status: To Do
assignee: []
created_date: '2025-11-20 09:11'
updated_date: '2025-11-20 09:17'
labels:
  - debugging
  - code-reduction
  - lambda-functions
  - refactoring
  - maintenance
dependencies: []
priority: low
---

## Description

Reduce the file count and simplify maintenance by converting simple, single-purpose debug action scripts into inline lambda registrations within the registration files. This refactoring eliminates boilerplate code while maintaining all debug functionality through cleaner, more maintainable lambda-based implementations.

**Current Problem:**
```gdscript
# Separate file for each simple action
# project/debug/actions/rtdb/rtdb_delete_value_action.gd
class_name RTDBDeleteValueAction
extends DebugAction
func _init():
    action_name = "rtdb.database.remove_value"
func execute() -> bool:
    # Simple logic that could be inline
```

**Target Solution:**
```gdscript
# Inline lambda registration in rtdb_actions.gd
registry.register_action(
    DebugAction.create("rtdb.database.remove_value", func() -> bool:
        # Direct inline implementation
    )
)
```

**Benefits:**
- Reduced file count improves maintainability
- Eliminated boilerplate class definitions
- Logic is co-located with registration
- Simpler debugging and modification workflow
- Cleaner project structure

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] Identify simple debug actions suitable for lambda conversion (target: RTDBDeleteValueAction, RTDBUpdateValueAction, RTDBSetSimpleValueAction, RTDBGetSimpleValueAction)
- [ ] Refactor rtdb_actions.gd to use DebugAction.create() with lambda functions instead of class instantiation
- [ ] Implement inline lambda registrations for identified simple actions
- [ ] Ensure helper classes (RTDBTestPaths, TestUtils) remain accessible to registration scripts
- [ ] Convert delete value action logic to inline lambda with direct FirebaseService access
- [ ] Convert update value action logic to inline lambda with proper error handling
- [ ] Convert set simple value action logic to inline lambda with validation
- [ ] Convert get simple value action logic to inline lambda with result verification
- [ ] Delete obsolete individual action class files after successful migration
- [ ] Verify Debug Menu displays all converted actions correctly
- [ ] Test execution of all lambda-converted actions for proper success/failure reporting
- [ ] Ensure DebugAction.create() method properly supports lambda-based implementations
- [ ] Validate that all debug action categories and groupings remain intact
<!-- AC:END -->
