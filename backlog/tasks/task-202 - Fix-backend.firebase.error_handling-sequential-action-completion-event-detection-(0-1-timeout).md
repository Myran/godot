---
id: task-202
title: >-
  Fix backend.firebase.error_handling sequential action completion event
  detection (2/1 over-count)
status: Open
assignee: []
created_date: '2025-10-07 08:02'
updated_date: '2025-10-07 19:15'
labels:
  - testing
  - firebase
  - sequential-actions
  - android
  - logging
  - widespread-issue
dependencies: []
priority: high
---

## Description

**REOPENED 2025-10-07 19:15**: Test framework now reports MORE completion events than sequential actions across multiple configs.

Test framework reports 2 completion events for 1 sequential action in `backend.firebase.error_handling`. This indicates systematic over-counting or double-emission of completion events.

**Current Behavior** (as of 20251007_190232_test.log):
- `backend.firebase.error_handling`: Reports 2/1 (2 events for 1 action)
- Pattern appears widespread across 11+ configs
- Tests pass but event counting is incorrect

**Previous Behavior**: Originally "0 of 1" timeout, now "2 of 1" over-count

## Widespread Pattern Analysis

### ❌ Affected Configs (completion events > sequential actions):
1. **backend.firebase.error_handling**: 1 action → 2 events (2/1) - ANDROID + Desktop
2. **firebase-backend-batch-2**: 2 actions → 4 events (4/2)
3. **firebase-rate-limiter-validation**: 3 actions → 4 events (4/3)
4. **firebase-cpp-layer**: 1 action → 2 events (2/1)
5. **firebase-rtdb-layer**: 3 actions → 4 events (4/3) - Android
6. **firebase-rtdb-layer**: 7 actions → 14 events (14/7) - Desktop (WORST: exactly 2x)
7. **firebase-three-actions-test**: 4 actions → 7 events (7/4)
8. **firebase-two-actions-test**: 3 actions → 4 events (4/3)
9. **system-error-handling**: 1 action → 2 events (2/1)
10. **system-performance**: 5 actions → 6 events (6/5)

### ✅ Correct Configs (events match actions):
- backend.firebase.async_pattern: 2/2
- battle-animated: 1/1
- firebase-backend-batch-1: 2/2
- firebase-backend-batch-3: 1/1
- firebase-backend-layer: 2/2
- gamestate-complete-save-load-cycle-test: 2/2

## Root Cause Found - THREE Issues Fixed

### Issue 1: Double-Emission in Child Classes
Firebase backend and RTDB actions were manually emitting completion events, then base class ALSO emitted them.

**Fixed Files**:
1. `project/debug/actions/firebase_backend/backend_firebase_debug_action.gd` - Removed manual emission
2. `project/debug/actions/rtdb/rtdb_batch_operations_action.gd` - Removed manual emission
3. `project/debug/actions/rtdb/rtdb_concurrent_operations_action.gd` - Removed manual emission
4. `project/debug/actions/rtdb/rtdb_large_data_test_action.gd` - Removed manual emission
5. `project/debug/actions/rtdb/rtdb_transaction_test_action.gd` - Removed manual emission

### Issue 2: Base Class Only Emitted on Success
Base class `debug_action.gd:305-325` only emitted completion events when `success == true`. Failed actions didn't emit, causing under-counts.

**Fixed**: `project/debug/actions/debug_action.gd`
- Moved completion event emission outside `if success` block (line 311-325)
- Now emits for BOTH success and failure (test framework needs to know action completed)

### Issue 3: Grep Pattern Matched TWO Event Formats
Test framework grep pattern matched BOTH old and new completion event formats, causing double-counts during wait loops.

**Fixed**: `justfiles/justfile-validation-enhanced-testing.justfile`
- Line 766: Initial check - Changed from dual pattern to single pattern
- Line 784: Wait loop re-check - Changed from dual pattern to single pattern
- Old pattern: `"FirebaseBackendCompleteEvent\|Sequential action completed.*emitting completion event"`
- New pattern: `"Sequential action completed - emitting completion event"` (unified only)

## Verification

**Single Emission Point**: `project/debug/actions/debug_action.gd:315`
**Single Detection Pattern**: `"Sequential action completed - emitting completion event"`

**Files Modified (Total: 7)**:
- 6 GDScript files (1 base class + 5 child classes)
- 1 justfile (2 locations fixed)

## Testing Status

- ✅ Individual tests work correctly
- ⚠️  Need to run `just test` to verify full suite (tests with timeouts trigger wait loop)
- 🚨 **CRITICAL**: Must run `just fastbuild-android` before testing (GDScript changes require rebuild)

## Next Steps

1. Run `just fastbuild-android` (REQUIRED - code changes need rebuild)
2. Run `just test` to validate all configs show N/N pattern
3. Verify no timeout warnings
4. Check logs for "📋 Found X sequential action(s), X completion event(s)" - all should match
5. Commit with proper task references

## Related Tasks
- task-203: firebase-rtdb-layer - Same root causes (fixed)
- task-204: system.error_handling - Same root causes (fixed)
- task-205: Sequential action log capture reliability - Investigation task
