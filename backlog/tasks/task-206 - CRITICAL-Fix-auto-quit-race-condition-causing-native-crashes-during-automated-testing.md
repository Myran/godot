# Task 206: CRITICAL - Fix auto-quit race condition causing native crashes during automated testing

**Status**: 🔴 Critical  
**Priority**: P0 (Blocks reliable automated testing)  
**Created**: 2025-10-07  
**Discovered During**: task-202 completion event investigation

## Problem

Automated testing with `auto_quit: true` causes **native crashes (Bus error)** when the quit mechanism triggers while actions are still queued or executing.

### Crash Pattern

```
Timeline:
1. Action N completes → logs emitted → chunk processing done
2. _ensure_android_log_completion() returns  
3. Action N+1 starts executing (already dispatched from queue)
4. Auto-quit triggers (mechanism unknown - needs investigation)
5. Native crash: Bus error during Action N+1 execution
6. Process dies with signal
```

### Evidence

From `firebase-backend-batch-1_android_1759871695.log`:

```
23:15:00.708 - method_mapping starts executing
23:15:00.761 - "Android chunk processing completed via signal"
23:15:01.524 - Native crash stack traces (F DEBUG)
23:15:02.879 - am_crash: Native crash, Bus error
23:15:03.071 - Process died
```

**Config has 3 actions, only 2 executed successfully before crash.**

### Root Cause

The auto-quit mechanism:
1. Waits for chunk processing from current action
2. Does NOT check if more actions are queued  
3. Triggers quit while next action is mid-execution
4. Causes memory corruption → native crash

## Impact

- ❌ Test framework reports "PASSED" while app CRASHED
- ❌ Unreliable automated testing 
- ❌ False positive test results
- ❌ Random failures in CI/CD

## Required Fix

Auto-quit must be **queue-aware**:

```gdscript
# BEFORE quit, check:
1. All actions completed (not just current one)
2. Action queue is empty
3. No actions currently executing
4. All chunk processing done
```

## Investigation Needed

1. Find where quit is actually triggered after chunk processing
2. Determine if this is: 
   - Signal connection in coordinator?
   - Idle queue handler?
   - Event system integration?
3. Identify all quit trigger points

## Acceptance Criteria

- [ ] Auto-quit waits for ALL queued actions to complete
- [ ] No crashes when auto_quit triggers
- [ ] Test validation confirms app exits cleanly (not crashed)
- [ ] Full test suite passes without native crashes

## Related

- Discovered during: task-202 (completion event detection)
- Previous commit: d65f5589 (completion event detection fix)
- Latest commit: f7096343 (test_id in completion events)

## Notes

The completion event detection fix (f7096343) is CORRECT and working.
This is a separate, critical safety issue in the auto-quit mechanism.
