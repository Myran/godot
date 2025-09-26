---
id: task-179
title: >-
  Fix missing embedded debug config causing determinism test validation mode
  failure
status: Done
assignee: []
created_date: '2025-09-25 10:14'
updated_date: '2025-09-25 12:20'
labels:
  - testing
  - battle-logic
  - determinism
  - debug-startup
  - config
dependencies: []
priority: high
---

## Description

Root cause: res://debug_startup_actions.json missing file causes debug startup coordinator to terminate early, preventing proper config loading. This breaks determinism test recording/validation cycle. Fix: Create missing embedded config file with default structure.

## Resolution

**PROBLEM IDENTIFIED:**
- Debug startup coordinator looks for `user://debug_startup_actions.json`
- If not found, falls back to `res://debug_startup_actions.json`
- Embedded config file was missing, causing early termination with empty actions array
- This broke config file persistence mechanism between test framework and determinism test

**SOLUTION IMPLEMENTED:**
- Created missing embedded config file: `/project/addons/debug_startup/debug_startup_actions.json`
- Added default structure with basic debug actions for proper startup coordination
- Ensures debug startup coordinator initializes correctly even without external config

**CONFIG FILE CONTENT:**
```json
{
  "description": "Default debug startup actions - used when no external config is found",
  "actions": [
    "system.debug.registry_stats",
    "system.debug.hide_menu"
  ],
  "metadata": {
    "auto_continue": true
  }
}
```

**TESTING PERFORMED:**
1. **Pre-fix validation:** Confirmed debug startup coordinator early termination
2. **Post-fix validation:** Verified debug startup coordinator loads config correctly
3. **Integration test:** Ran battle-logic-only test to verify config persistence
4. **Cross-platform validation:** Tested on both Android and desktop platforms

**TEST EXECUTION:**
```bash
# Validation of embedded config fix
just test-android battle-logic-only
# Result: ✅ Debug startup coordinator now initializes correctly
# Impact: Partial fix - deeper config persistence issue remains in task-178
```

**OUTCOME:**
✅ Debug startup coordinator no longer terminates early
✅ Embedded config file provides proper fallback structure
⚠️ Determinism test validation mode still not working (requires task-178 resolution)

**RELATED TASKS:**
- Task-178: Main determinism test validation issue (requires this fix + deeper investigation)
- Both tasks contribute to resolving the complete determinism test recording/validation cycle
