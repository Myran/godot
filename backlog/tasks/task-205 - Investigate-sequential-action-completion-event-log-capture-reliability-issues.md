---
id: task-205
title: Investigate sequential action completion event log capture reliability issues
status: Done
assignee: []
created_date: '2025-10-07 14:54'
updated_date: '2025-12-18 10:37'
labels:
  - testing
  - logging
  - sequential-actions
  - test-framework
dependencies: []
priority: high
ordinal: 108000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Sequential action completion events are emitted by code but not consistently captured by test framework.

## Root Cause Analysis Required

### Problem Statement
Sequential action completion events are emitted by code but not consistently captured by test framework:

**Individual Test Results:**
- `backend.firebase.error_handling` tested at 15:53-15:55: **1/1 completion events** ✅
- Same test in full suite at 16:03: **0/1 completion events** ❌

**Pattern:**
- Same build (fastbuild-android at ~15:53)
- Same code (base class emission path)
- Different test execution context (individual vs full suite)
- Actions complete successfully (100% pass rate)
- Completion events not detected by framework

### Evidence

**Working Individual Test:**
```
just test-android-target backend.firebase.error_handling
📋 Found 1 sequential action(s), 1 completion event(s)
✅ All sequential actions completed (1/1)
```

**Failing Full Suite Test (logs/20251007_160338_test.log):**
```
Session: 1759845819 (16:03:39 CEST)
backend.firebase.error_handling (android) - Detected: 00/1 completion events
⚠️ Timeout waiting for sequential actions (after 30s)
```

**Log File Evidence:**
- File: `android_backend.firebase.error_handling_android_1759845819.log`
- Action registered: ✅
- Action executed: ✅ "Completed: backend.firebase.error_handling"
- DEBUG_TEST_SUCCESS: ❌ Not logged
- Sequential completion event: ❌ Not found in logs

### Investigation Areas

1. **Log Capture Timing**
   - When are logs captured relative to action completion?
   - Is there a race condition between event emission and log extraction?
   - Full suite: logs extracted after all actions complete
   - Individual test: logs extracted immediately after single action

2. **Log Buffer/Cycling**
   - Android logcat buffer size and cycling behavior
   - Multi-config test suite generates more logs
   - Completion events might be pushed out of buffer before capture

3. **Success Signal Propagation**
   - Why is DEBUG_TEST_SUCCESS not logged for this action?
   - `execute_backend_action()` returns bool to base class
   - Base class checks success before emitting completion event (line 305)
   - If success=false, no completion event emitted

4. **Execution Path Differences**
   - Individual test: Direct action execution
   - Full suite: Actions queued and executed in batch
   - Different coordinator state/timing?

### Key Code Paths

**Base Class Emission (debug_action.gd:305-321):**
```gdscript
if success:
    if not auto_continue:
        Log.info("Sequential action completed - emitting completion event", ...)
        core.action(core.SequentialActionCompleteEvent.new(...))
```

**Requires:**
- `success = true` from action callable
- `auto_continue = false`

**Firebase Backend Action (backend_firebase_debug_action.gd:196-269):**
```gdscript
func execute_backend_action() -> bool:
    # Executes logic via _execute_action_logic()
    # Logs success via _log_test_success()
    return success  # Returns to base class _execute_core()
```

### Root Cause Hypotheses

**Hypothesis 1: Log Capture Race Condition**
- Completion event emitted but not yet in logcat buffer
- Test framework extracts logs too early
- Individual tests wait longer/extract later

**Hypothesis 2: Success Not Propagating**
- `execute_backend_action()` returns false
- Base class skips completion event emission (line 305)
- No DEBUG_TEST_SUCCESS = action failed internally

**Hypothesis 3: Logcat Buffer Overflow**
- Full suite generates 18 config logs
- Android logcat buffer ~256KB-1MB
- Older logs (including completion events) get cycled out
- Individual test has minimal log volume

**Hypothesis 4: Log Tag Filtering**
- Test framework searches for specific log tags
- Completion events use different tags in full suite vs individual
- Tag filtering differs between test modes

### Investigation Plan

1. **Verify Code Deployment** - Check if latest build includes base class emission
2. **Check Success Propagation** - Look for DEBUG_TEST_SUCCESS for the action
3. **Analyze Log Capture Timing** - Compare timestamps: action completion vs log extraction
4. **Test Log Buffer Hypothesis** - Count total log lines in full suite vs individual test
5. **Compare Detection Logic** - Find where test framework detects completion events

### Recommended Approach

**Short-term Fix (Pragmatic):**
- Restore manual completion event emission in custom callable actions
- Accept potential duplication (2/1) as better than missing (0/1)
- Test framework passes with >= N events

**Long-term Fix (Proper):**
- Identify and fix root cause in log capture/timing
- Ensure base class emission works reliably in all contexts
- Remove manual emissions once reliability confirmed

### Success Criteria

- ✅ Both individual tests AND full suite show correct event counts
- ✅ No 30-second timeouts
- ✅ No duplication (N/N, not 2N/N)
- ✅ 100% test pass rate maintained
<!-- SECTION:DESCRIPTION:END -->
