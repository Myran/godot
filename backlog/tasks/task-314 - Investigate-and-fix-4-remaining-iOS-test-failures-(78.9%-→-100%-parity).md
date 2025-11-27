---
id: task-314
title: Investigate and fix 4 remaining iOS test failures (78.9% → 100% parity)
status: Done
assignee: []
created_date: '2025-11-25'
updated_date: '2025-11-27 17:11'
labels:
  - ios
  - testing
  - firebase
  - platform-parity
dependencies:
  - task-291
priority: high
---

## Description

After fixing the timestamp collision bug in task-291, iOS testing improved from 5.3% to 78.9% pass rate (15/19 tests passing). This task tracks investigation and fixes for the remaining 4 failing tests to achieve 100% iOS parity with Android.

## Context

**Parent Task**: task-291 - Implement iOS Testing Infrastructure Parity with Android
**Fix Applied**: Log file selection timestamp collision resolved (commit a8534bf8)
**Current Status**: 15/19 iOS tests passing (78.9%)
**Target**: 19/19 iOS tests passing (100% - same as Android)

**Validation Run**: `logs/20251125_235018_test.log` (Session: 1764111018)

## Failing Tests

These 4 tests fail on iOS but pass on Android, indicating iOS-specific issues:

### 1. backend.firebase.async_pattern
- **Status**: ❌ FAILED on iOS
- **Android**: ✅ PASSED
- **Category**: Firebase Backend Layer
- **Investigation needed**: Why async pattern fails on iOS but works on Android

### 2. backend.firebase.error_handling
- **Status**: ❌ FAILED on iOS
- **Android**: ✅ PASSED
- **Category**: Firebase Backend Layer
- **Investigation needed**: Error handling differences between platforms

### 3. firebase-rtdb-layer
- **Status**: ❌ FAILED on iOS
- **Android**: ✅ PASSED
- **Category**: Firebase RTDB Layer
- **Investigation needed**: Real-time Database iOS implementation issues

### 4. system-performance
- **Status**: ❌ FAILED on iOS
- **Android**: ✅ PASSED
- **Category**: System Performance
- **Investigation needed**: Performance test iOS-specific problems

## Investigation Approach

### Phase 1: Evidence Gathering
For each failing test:
1. Run individual test on iOS: `just test-ios-ipad <config>`
2. Check test logs: `just logs-errors <TEST_ID>`
3. Compare with Android execution logs
4. Identify iOS-specific error patterns

### Phase 2: Root Cause Analysis
Potential causes to investigate:
- iOS-specific Firebase SDK differences
- Platform-specific API limitations
- Timing/threading differences on iOS
- Log collection issues specific to these tests
- Test configuration iOS compatibility

### Phase 3: Fix Implementation
- Apply targeted fixes per test
- Validate each fix individually
- Run full multi-platform suite to confirm no regressions

## ✅ ROOT CAUSE & FIXES IMPLEMENTED

**Discovery Date**: 2025-11-26
**Fix Commits**: d60789de (Fix 1), b107fc2d (Fix 2)

### Root Cause Identified - Two Related Bugs

All 4 failing tests shared a common pattern: **they passed when run in batches but failed when run individually**.

**Evidence:**
- `firebase-backend-batch-1.json` (contains async_pattern + lifecycle): ✅ **PASSED on iOS**
- `backend.firebase.async_pattern.json` (contains async_pattern alone): ❌ **FAILED on iOS**

**The Problems:**

The issue required TWO fixes because Fix 1 alone didn't work - Fix 2 was needed to enable Fix 1 to execute:

#### Problem 1: Auto-Quit Timing (Fixed by d60789de)
Auto-quit triggered before async operations completed:

1. Action dispatched to idle queue
2. Queue item processed and **removed from queue** (36ms)
3. Auto-quit sees `queue.size() == 0` → **triggers app quit immediately**
4. Async Firebase operation still running → **never completes**
5. No DEBUG_TEST_SUCCESS logged → **test fails validation**

**But this fix never ran** because the completion action was never being added to the queue!

#### Problem 2: Batch Dispatch Race Condition (Fixed by b107fc2d)
Queue processing interrupted batch dispatch:

1. Coordinator starts adding actions to queue
2. First action added → `core.action(SystemIdleActionEvent.new())` emits signal **synchronously**
3. ProcessQueueEvent handler executes **immediately** (Godot signals are sync by default)
4. Queue processing starts **before** coordinator finishes adding actions
5. Completion action never gets added
6. Auto-quit never runs (no completion trigger)
7. App terminates prematurely → test fails

**Why batches sometimes worked:**
- Timing luck - sometimes all actions added before queue processing started
- Multiple actions provided buffer time for race condition

**Why individual tests always failed:**
- Single action → queue processing always won the race
- Completion action never added → no auto-quit trigger
- Fix 1 never executed

### Fix Implementation

#### Fix 1: Auto-Quit Timing
**File Modified**: `project/debug/actions/registrations/system_actions.gd:437`
**Commit**: d60789de

**Change**: Modified `_replay_complete()` auto-quit logic to wait for BOTH conditions:
```gdscript
# BEFORE (buggy):
while game_node._idle_action_queue.size() > 0:
    await Engine.get_main_loop().process_frame

# AFTER (fixed):
while game_node._idle_action_queue.size() > 0 or game_node._processing_idle_action:
    await Engine.get_main_loop().process_frame
```

**Key Insight:**
- `_idle_action_queue.size() == 0` → queue empty, but async ops may still be running
- `_processing_idle_action == false` → all async operations completed
- Must wait for BOTH to ensure DEBUG_TEST_SUCCESS is logged before app quits

#### Fix 2: Batch Dispatch Pause Mechanism
**Files Modified**:
- `project/core/game.gd` - Added `_batch_dispatch_in_progress` flag
- `project/core/events/core_event_resolver.gd:426-447` - Check flag before queue processing
- `project/addons/debug_startup/debug_startup_coordinator.gd:119-216` - Set/clear flag around batch dispatch

**Commit**: b107fc2d

**Changes**:
1. Added pause flag to prevent queue processing during batch dispatch
2. Set flag before loop, clear after completion action added
3. Manually trigger ProcessQueueEvent after batch complete

```gdscript
# In game.gd - add flag
var _batch_dispatch_in_progress: bool = false

# In coordinator - enable pause before dispatch
game_node._batch_dispatch_in_progress = true
# ... dispatch actions loop ...
# ... add completion action ...
game_node._batch_dispatch_in_progress = false
core.action(core.ProcessQueueEvent.new())  # Trigger processing now

# In event resolver - check flag
if game._batch_dispatch_in_progress:
    return  # Skip queue processing during batch dispatch
```

**Key Insight:**
- Godot signals are synchronous by default
- `core.action()` emits signals that execute handlers immediately
- Must pause queue processing until all actions added atomically
- Both fixes required for complete solution

### Android Validation Results

All 4 previously failing tests now pass with 100% success rate:

| Test | Actions | Result | Evidence |
|------|---------|--------|----------|
| backend.firebase.async_pattern | 3/3 | ✅ **100%** | DEBUG_TEST_SUCCESS logged, 366ms & 422ms durations |
| backend.firebase.error_handling | 2/2 | ✅ **100%** | All actions completed successfully |
| firebase-rtdb-layer | 16/16 | ✅ **100%** | Wildcard expansion working perfectly |
| system-performance | 6/6 | ✅ **100%** | Multi-wildcard patterns resolved correctly |

**Total**: 27/27 actions passed (100%)

### iOS Validation Results

**Validation Run**: `logs/20251126_102105_test.log` (Session: 1764148865)

| Status | Count | Details |
|--------|-------|---------|
| ✅ Passed | 15/19 | 78.9% pass rate (same as before Fix 2) |
| ❌ Failed | 4/19 | Log capture issue, not execution failure |

**Critical Discovery** (TEST_ID: 1764173653):
The fix IS working! Direct log evidence shows:
```
✅ BATCH DISPATCH START logged
✅ BATCH DISPATCH LOOP COMPLETE logged
✅ BATCH DISPATCH COMPLETE with "completion_auto_added": true
✅ backend.firebase.async_pattern: 156ms + 193ms (sequences 1 & 2)
✅ SequentialActionCompleteEvent emitted
✅ system.debug.replay_complete executed (sequence 3)
✅ TEST_COMPLETE logged
```

**Remaining Failures** (iOS log extraction issue):
1. `backend.firebase.async_pattern` - timeout shows "actions executed successfully"
2. `firebase-backend-batch-3` - TBD
3. `firebase-rtdb-layer` - TBD
4. `system-performance` - TBD

**Pattern:**
- Successful logs (TEST_ID 1764173653): 30 lines, all DEBUG_TEST_SUCCESS markers present
- Failed logs (TEST_ID 1764148865): 17 lines, missing DEBUG_TEST_SUCCESS markers
- **Issue is log capture inconsistency, not code execution**

**Batch Config Evidence:**
- `firebase-backend-batch-1` (includes async_pattern): ✅ PASSED on iOS
- `firebase-backend-batch-2`: ✅ PASSED on iOS
- This confirms fix working - individual tests fail due to log capture, not execution

### Impact

- ✅ Fixes iOS test parity issue (Fix 1 + Fix 2 required)
- ✅ Enables reliable single-action async testing
- ✅ Works for wildcard expansion (rtdb.*, *.*.performance)
- ✅ No config changes required
- ✅ Platform-agnostic fix (benefits all platforms)
- ⚠️ iOS log capture needs investigation (separate issue)

### Fix 3: iOS Log Retrieval Retry Logic
**Date**: 2025-11-27
**Commit**: 57d9271d
**File Modified**: `justfiles/justfile-platform-ios.justfile`

**Root Cause Discovered:**
The "iOS log capture inconsistency" was caused by Godot log rotation timing:
- Godot rotates log files when `godot.log` exceeds ~500KB-1MB during app shutdown
- Log rotation locks `Documents/logs/` directory for 20-30 seconds for large files (5MB+)
- Tests with heavy logging triggered rotation that exceeded the 3-second wait period
- `firebase-rtdb-layer` generated 5.6MB of logs → 24-second rotation delay

**Timeline Evidence (firebase-rtdb-layer):**
```
13:55:50 - App quit
13:55:53 - Log retrieval attempted (3s wait) → ❌ FAILED
13:56:17 - Log file finalized (24 seconds later)
```

**Solution Implemented:**
1. **Retry logic with exponential backoff** (5 attempts max):
   - Attempt 1: 3s wait (fast tests succeed here)
   - Attempt 2: 3s additional (total 6s)
   - Attempt 3: 6s additional (total 12s)
   - Attempt 4: 9s additional (total 21s)
   - Attempt 5: 12s additional (total 33s max)

2. **Removed ineffective `_clear-ios-logs` call**:
   - App uninstall/reinstall already clears Documents/
   - Marker file approach didn't actually delete anything
   - Reduced code complexity

**Validation Results:**
- ✅ `firebase-rtdb-layer`: PASSED (needed 4 retry attempts, ~18s)
- ✅ `system-performance`: PASSED (needed 3 retry attempts, ~12s)
- ✅ **Full iOS test suite: 19/19 PASSED (100%)**

**Impact:**
- Fast tests still complete in 3s (no performance impact)
- Heavy tests get time needed (up to 33s for log rotation)
- No false failures from log retrieval timing issues

## Current Status

**Functional Fix**: ✅ COMPLETE (all 3 fixes working on iOS)
**Validation Issue**: ✅ RESOLVED (log retrieval retry logic)
**iOS Test Pass Rate**: ✅ 19/19 (100% - parity achieved!)

## Success Criteria

- [x] All 4 tests execute successfully on iOS (confirmed via TEST_ID 1764173653)
- [ ] iOS test validation pass rate: 19/19 (100%) - blocked by log capture issue
- [ ] Multi-platform test suite: `just test-multi-platform "main"` shows 100% iOS pass rate
- [x] No regressions in the 15 currently passing iOS tests

## Investigation Commands

```bash
# Test individual configs on iOS
just test-ios-ipad backend.firebase.async_pattern
just test-ios-ipad backend.firebase.error_handling
just test-ios-ipad firebase-rtdb-layer
just test-ios-ipad system-performance

# Analyze logs
just logs-errors <TEST_ID>
just logs-text <TEST_ID> "ERROR"
just logs-text <TEST_ID> "FAILED"

# Compare with Android
just test-android-target backend.firebase.async_pattern
# Compare logs between platforms
```

## Expected Outcome

After completing this task:
- iOS testing infrastructure: 100% parity with Android
- All tests in "main" test list pass on all platforms (Android, iOS, Desktop)
- iOS can be trusted for daily validation workflows

## Related

- Parent: task-291 - iOS Testing Infrastructure Parity
- Fixes: Timestamp collision bug (resolved)
- Remaining: 4 iOS-specific test failures (this task)
- Log: `logs/20251125_235018_test.log`
