---
id: task-392
title: Investigate macOS ObjectDB slot_max errors in firebase-rtdb-layer test
status: To Do
assignee: []
created_date: '2025-12-28 09:59'
updated_date: '2025-12-28 10:26'
labels:
  - macos
  - firebase
  - memory
  - objectdb
dependencies: []
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

The `firebase-rtdb-layer` test on macOS fails error analysis with:
```
ERROR: Condition "slot >= slot_max" is true. Returning: nullptr
```
(3 occurrences)

## Root Cause Analysis

The `slot >= slot_max` error is from Godot's `ObjectDB::add_instance()` in `godot/core/object/object.cpp`:
- ObjectDB has a fixed number of slots for tracking objects
- When all slots are exhausted, this error is raised
- Indicates either object leak or too many objects created simultaneously

## Affected Test

- **Config**: firebase-rtdb-layer (macOS only)
- **Actions**: 16 RTDB operations (all PASSED)
- **Status**: Test actions pass, but error analysis fails due to ObjectDB errors

## Investigation Notes

- The test executes 16 Firebase RTDB operations in sequence
- Each operation may create multiple Godot objects (signals, callbacks, etc.)
- Objects may not be properly freed between operations
- macOS-specific: Android version passes without this error

## Potential Causes

1. **Object leak in Firebase module**: RTDB listeners/callbacks not cleaned up
2. **GDScript object accumulation**: Signals or references holding objects
3. **macOS-specific behavior**: Different object lifecycle on macOS vs Android

## Evidence

Log file: `logs/20251227_232355_pipeline-rebuild.log`
- All 16 actions PASSED
- 3 slot_max errors in logs
- 90 warnings

## Next Steps

1. Run `just test-macos-target firebase-rtdb-layer` with verbose ObjectDB monitoring
2. Compare object counts between platforms
3. Check for unreleased listeners/callbacks in RTDB code
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Investigation Findings

**Root Cause**: The error occurs during **Sentry SDK shutdown**, not during test execution.

**Sequence**:
1. Firebase cleanup completes successfully
2. Sentry SDK starts shutdown
3. `slot >= slot_max` errors (3x) during Sentry cleanup
4. XR interfaces removed
5. ObjectDB reports leaked instances

**Key Evidence**:
- Error happens at `get_instance (./core/object/object.h:1055)` - Sentry trying to access freed objects
- Windows also has `ObjectDB instances leaked` but no slot_max error
- Only firebase-rtdb-layer (16 RTDB operations) triggers this on macOS
- All other macOS tests pass without this error

**Assessment**: Low priority since:
- All test actions PASS (16/16)
- Error occurs only during app shutdown
- macOS-specific (Windows has same leak warning but no error)
- Likely Sentry SDK cleanup order issue on macOS

**Potential Fixes**:
1. Update error analysis to ignore shutdown-phase errors
2. Investigate Sentry SDK macOS cleanup sequence
3. Mark as known issue/expected behavior

## Rerun Confirmation (Dec 28, 2025)

Ran `just test-macos-target firebase-rtdb-layer` to confirm:

**Results**:
- All 16 RTDB actions: ✅ PASSED
- Firebase config: ✅ Loaded from bundled .app (`gametwo_debug.app/Contents/Resources/google-services-desktop.json`)
- slot_max errors: 3x during Sentry shutdown (unchanged)
- Error analysis: ❌ FAILED (due to shutdown errors)

**Conclusion**: Issue confirmed as Sentry SDK shutdown cleanup problem on macOS, not related to Firebase config or test functionality. All actual test actions pass successfully.
<!-- SECTION:NOTES:END -->
