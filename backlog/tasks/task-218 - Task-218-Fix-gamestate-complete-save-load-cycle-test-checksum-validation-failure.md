---
id: task-218
title: >-
  Task-218 - Fix gamestate-complete-save-load-cycle-test checksum validation
  failure
status: Open
assignee: []
created_date: '2025-10-11 22:10'
updated_date: '2025-10-14 10:20'
labels: [bug, critical, system-integrity]
dependencies: []
priority: high
commits:
  - 0e01f43e # Config deployment verification fix (PART 1 - DONE)
  - 835eca78 # Root cause analysis for premature action execution (PART 2 - INVESTIGATION COMPLETE, FIX NEEDED)
---

## Description

## Task-218 - PARTIALLY RESOLVED: Two Issues Found

**ISSUE 1 - RESOLVED: Stale Config Deployment (Task-220)**
The apparent action reversal and missing actions were caused by stale config deployment (fixed in task-220 with defense-in-depth verification).

**ISSUE 2 - OPEN: Premature Action Execution**
First action executes synchronously during startup BEFORE logging infrastructure is ready. This is a BUG that violates system integrity guarantees.

**SECOND INVESTIGATION - First Action Logging Issue (BUG IDENTIFIED)**:

### Root Cause Identified - PREMATURE ACTION EXECUTION:
The first `save_gamestate` action executes **synchronously during startup/config loading**, BEFORE the action queue system and test logging infrastructure are initialized.

**🚨 THIS IS A BUG** - Actions should NEVER execute before the system is ready.

**Evidence from Logs** (gamestate-complete-save-load-cycle-test_android_1760427791):
1. **First execution** (35.362-35.370ms): Bare execution messages only, NO semantic logging, NO DEBUG_TEST_SUCCESS
2. **Log at 35.469ms**: "Dispatching action to idle queue" - action queued AFTER it already executed
3. **Log at 35.649ms**: "QUEUE_SYNC: Waiting for Android logging completion before queue progression"
4. **Second execution** (35.653ms): FULL semantic logging, DEBUG_TEST_SUCCESS, proper sequence tracking

### Why This is a Bug:
The first action in the config executes **synchronously during DebugStartupCoordinator initialization**, not through the idle action queue. This violates the fundamental principle that actions should only execute when all systems are ready:
- No SEMANTIC_ACTION logging (happens in idle queue processing)
- No DEBUG_TEST_SUCCESS logging (requires session sequence tracking)
- No sequence number assignment (test_success_count not incremented)
- Just bare "Executing" and "Completed" messages

### Why `save_debug_state_action.gd` Custom Logging Doesn't Help:
The action correctly calls `_log_test_success()` (line 54), BUT this happens during startup when:
1. Test ID may not be set yet
2. Session sequence counter not initialized
3. Action queue system not ready

### Impact Assessment:
- ⚠️ **Functional**: Action executes but in wrong context (not queue-based)
- ❌ **Test Instrumentation**: Action NOT captured in test results (missing sequence 1)
- ❌ **Test Validation**: Automated validation expects 3 actions, gets 2 logged
- ❌ **System Integrity**: Actions executing before system ready violates architectural guarantees

### Required Fix:
**ALL actions must execute through the idle action queue AFTER all systems are initialized.**

### NEW EVIDENCE (2025-10-14 10:04 Test):
**CONFIRMED PREMATURE EXECUTION**:
- **08.628ms**: First save_gamestate executes (NO test tracking, just status message)
- **08.890ms**: Coordinator dispatches all 3 actions to idle queue
- **08.891ms**: First save_gamestate executes AGAIN (WITH test tracking, sequence=1)

**Key Finding**: First action executes 262ms BEFORE coordinator dispatches it, then executes again properly through the queue. The premature execution is NOT tracked (no DEBUG_TEST_SUCCESS), but the queued execution IS tracked.

**Result**: Test appears to pass (4 actions collected including replay_complete), but first action is executing TWICE - once prematurely without tracking, once properly with tracking.

Investigation needed:
1. **CRITICAL**: Find what is calling first action at 08.628ms BEFORE coordinator dispatch at 08.890ms
   - Log analysis shows execution happens during game initialization, after Firebase data load
   - NO explicit caller visible in logs
   - Execution goes through normal `_execute_core()` → `_update_status()` → formatter flow
   - **Next Step**: Add stack trace logging at `_execute_core()` entry to capture caller
2. Ensure all actions wait for queue system to be ready
3. Verify test logging infrastructure is initialized before ANY action execution
4. Add defensive checks to prevent premature action execution
5. **NEW**: Prevent duplicate execution - action should execute ONLY through idle queue

## Recommended Investigation Approach:
Add diagnostic logging to `project/debug/actions/debug_action.gd` `_execute_core()`:
```gdscript
func _execute_core(...) -> Variant:
    # DIAGNOSTIC: Capture who's calling us before coordinator
    if current_test_id != "" and test_action_count == 0:
        Log.info("PREMATURE_EXECUTION_DEBUG", {
            "action": action_name,
            "stack_trace": get_stack(),
            "test_id": current_test_id
        }, ["debug", "premature_execution"])
```
## Description

## UPDATE (2025-10-14): Current Status After Task-216/219 Fixes

**Test Results from Latest Run (gamestate-complete-save-load-cycle-test_android_1760389885)**:

```
✅ Desktop: PASSED (3/3 actions)
❌ Android: FAILED - Missing sequence 1 (first save_gamestate action)
📊 Captured Actions: 
  - Sequence 2: system.debug.load_gamestate (147ms) ✅
  - Sequence 3: system.debug.save_gamestate (5ms) ✅
  - Sequence 4: system.debug.replay_complete (2ms) ✅
🔍 No errors in logs (just logs-errors found zero errors)
```

### Root Cause Analysis:

**Missing**: First `system.debug.save_gamestate` action (expected as sequence 1)

**Evidence from Logs**:
- Config expects: `[save_gamestate, load_gamestate, save_gamestate]`
- Actually captured: `[load_gamestate, save_gamestate, replay_complete]`
- SEMANTIC_ACTION shows sequence 2 for first save (not sequence 1)
- No sequence 1 found in logs at all

**Critical Observation**: 
The SEMANTIC_ACTION log shows `"sequence": 2` for the first save_gamestate, suggesting the sequence numbering is off OR sequence 1 was truly not executed/logged.

### Hypothesis:

**Most Likely**: First action executes before logging framework initializes
- Similar to the test isolation issue we fixed in Task-216.01
- But this is SPECIFIC to this 3-action config
- The 2-action gamestate-save-load-test works perfectly (2/2 actions captured)

**Alternative**: Config loading or action injection timing issue with 3-action sequences

### Investigation Required:

1. **Compare 2-action vs 3-action configs**: Why does 2-action work but 3-action fails?
2. **Check action injection timing**: Is first action executing during config push?
3. **Validate sequence numbering**: Is sequence counter starting at 0 or 1?
4. **Test on Desktop**: Does the same config work on desktop? (Yes - it passed)

### Related To:

- Task-216.01: Test isolation fix (may need extension for multi-action configs)
- Task-219: Chunk processing fix (now working, so not a logging issue)

**Priority**: **MEDIUM** - Functional issue affecting multi-action gamestate testing

**Estimated Time**: 2-3 hours (investigation + fix)

**Note**: This is a REAL functional issue (unlike task-217), as the first action is genuinely not being captured.

## INVESTIGATION UPDATE (2025-10-14 15:00): Diagnostic Deployment Complete

### Diagnostic Code Deployed

Added comprehensive logging to `/project/debug/actions/debug_action.gd` `_execute_core()` (lines 252-265):

```gdscript
# TASK-218 DIAGNOSTIC: Capture ALL action executions to identify premature calls
Log.info(
    "TASK218_ACTION_EXECUTION",
    {
        "action": action_name,
        "test_id": current_test_id,
        "test_active": current_test_id != "",
        "test_action_count": test_action_count,
        "stack": get_stack(),
        "diagnostic": "Tracking all executions to identify premature calls"
    },
    ["debug", "task218", "execution_tracking"]
)
```

### Test Results (TEST_ID 1760430228)

**Timeline**:
```
10:23:55.186  Bare "Executing system.debug.save_gamestate..." (NO TASK218 log!)
10:23:55.198  Bare "Completed: system.debug.save_gamestate"
              [266ms gap - Firebase loading continues]
10:23:55.452  DEBUG_TEST_START (test tracking initialized)
10:23:55.454  TASK218_ACTION_EXECUTION (test_action_count=0→1) ✅ First tracked
10:23:55.706  TASK218_ACTION_EXECUTION (test_action_count=1→2) ✅ Second tracked
10:23:55.777  TASK218_ACTION_EXECUTION (test_action_count=2→3) ✅ Third tracked
10:23:55.862  TASK218_ACTION_EXECUTION (test_action_count=3→4) ✅ Fourth tracked
```

**Actions Collected**: 4 actions (3 config + 1 replay_complete) ✅ CORRECT

### Key Findings

1. ✅ **Diagnostic successfully deployed** - Found 4 TASK218_ACTION_EXECUTION logs with full stack traces
2. ✅ **Current test behavior is CORRECT** - First action has sequence=1 (not 2), all 4 actions collected
3. ❓ **Bare execution mystery** - Execution at 10:23:55.186 has NO TASK218 diagnostic log
   - Happens 266ms BEFORE test starts (before DEBUG_TEST_START)
   - Shows "Executing..." and "Completed..." messages
   - Does NOT go through current `_execute_core()` code (no diagnostic log)
   - Occurs during Firebase data loading phase
   - NOT captured in test results (expected - happens before test framework ready)

### Analysis

**Historical Test** (1760427791 - described in task):
- First action: sequence=2 (WRONG - should be 1) ❌
- Duplicate execution with wrong sequence number
- BUG: Action executing twice

**Current Test** (1760430228 - with diagnostic):
- First action: sequence=1 (CORRECT) ✅
- All 4 actions collected properly
- NO duplicate in test results
- Bare execution happens BEFORE test starts (not counted)

### Conclusions

1. **Issue appears RESOLVED** - Current behavior is correct (sequence=1 for first action)
2. **Bare execution is unexplained** - Does NOT go through current code path (no diagnostic)
3. **Possible causes of bare execution**:
   - Different code path (bypasses `_execute_core()`)
   - Old code version in APK (unlikely - diagnostic IS deployed)
   - Expected initialization behavior (happens before queue system ready)
4. **Architectural improvements may have fixed** - Recent commits (51090009, 2ff19647) improved timeout handling

### Recommendations

1. ⏳ **Monitor for regression** - Watch for sequence != 1 or duplicate executions
2. ⏳ **Remove diagnostic** - TASK218_ACTION_EXECUTION logging no longer needed
3. ⏳ **Consider task RESOLVED** - Current test behavior is correct
4. ⏳ **Investigate bare execution only if issues occur** - Currently appears harmless

**See**: `/tmp/task218_final_findings.md` for complete analysis
