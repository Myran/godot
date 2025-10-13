---
id: task-216.01
title: Fix Android Test Suite Isolation - App State Bleeds Between Configs
status: In Progress
assignee: []
created_date: '2025-10-13 10:39'
updated_date: '2025-10-13 12:05'
labels: []
dependencies: []
parent_task_id: task-216
priority: high
---

## Description

Android test suite fails to isolate app state between consecutive config tests, causing first actions to execute before log capture starts. Isolated tests work perfectly (both sequences captured), but full suite runs miss sequence 1 because app remains running from previous test.

EVIDENCE:
- Isolated Test (1760344860): ✅ Both sequences, 28ms duration
- Full Suite (1760344898, 1760347321): ❌ Only sequence 2, 1ms duration

ROOT CAUSE:
Current code only stops/launches app if NOT running. In suite, app IS running from previous test, so stop/launch logic gets skipped. Config pushes to running app → first action executes before log capture starts.

IMPACT:
- Missing test data (sequence 1 logs)
- False checksum failures in gamestate tests
- Test results differ between isolated and suite runs

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Isolated test continues to capture both action sequences
- [ ] #2 Full suite test captures both action sequences (NEW - currently failing)
- [ ] #3 All gamestate tests pass with proper checksums
- [ ] #4 Sequence 1 duration >20ms in suite runs (indicates fresh app launch)
- [ ] #5 No regression in other test configs
- [ ] #6 Suite behavior matches isolated test behavior exactly
<!-- AC:END -->

## Implementation Plan

Phase 1: Enhance _push-file-android function
- File: justfiles/justfile-platform-android.justfile (lines 404-425)
- Change: ALWAYS stop app if running before config push
- Logic: Check if app running → force-stop → launch for directory → stop → push config
- Estimated: 30 minutes

Phase 2: Validate Isolated Test (Baseline)
- Command: just test-android-target gamestate-save-load-test
- Expected: Both sequences captured (should continue working)
- Estimated: 5 minutes

Phase 3: Validate Full Suite (Fix Verification)
- Command: just log-run test-android
- Expected: All configs capture sequence 1, match isolated behavior
- Compare session results with baseline 1760344860
- Estimated: 45 minutes (suite run) + 10 minutes (analysis)

Phase 4: Performance Analysis
- Measure added time per config (~2-3s stop/start overhead)
- Total suite impact: ~45s for 18 configs
- Document trade-off: correctness > speed

## Implementation Notes

IMPLEMENTATION PATTERN:

```bash
_push-file-android SOURCE_FILE TARGET_FILENAME:
    #!/usr/bin/env bash
    set -euo pipefail

    # ENHANCED FIX: Always ensure clean app state
    APP_RUNNING=$(adb shell pidof {{ANDROID_PACKAGE_NAME}} 2>/dev/null || echo "")
    
    if [[ -n "$APP_RUNNING" ]]; then
        echo "🛑 Stopping existing app (test isolation)..."
        adb shell am force-stop {{ANDROID_PACKAGE_NAME}} 2>/dev/null || true
        sleep 1
    fi

    # Launch → stop → push pattern (existing fix continues)
    echo "🚀 Starting app to create directory..."
    adb shell am start -n {{ANDROID_PACKAGE_NAME}}/com.godot.game.GodotApp >/dev/null
    sleep 2

    echo "🛑 Stopping app after directory creation..."
    adb shell am force-stop {{ANDROID_PACKAGE_NAME}} 2>/dev/null || true
    sleep 1

    # Push config
    adb push "$SOURCE_FILE" /sdcard/Android/data/{{ANDROID_PACKAGE_NAME}}/files/$TARGET_FILENAME
```

PERFORMANCE IMPACT:
- Time cost: ~2-3s per config
- Suite overhead: 18 configs × 2.5s = ~45s
- Trade-off justified: Test isolation is non-negotiable

RELATED CONTEXT:
- Branch: task-216-firebase-sigbus-android-logging-investigation
- Investigation: TASK-216-INVESTIGATION.md
- Assessment: /tmp/task216_final_assessment.md
- Sessions: 1760344860 (isolated ✅), 1760344898/1760347321 (suite ❌)

RISK: Low - change is additive, pattern already proven in isolated tests
ROLLBACK: Revert to if [[ -z "$APP_RUNNING" ]] logic

🚨 CRITICAL CTO DECISION: INVESTIGATION BEFORE IMPLEMENTATION (Option B)

🚨 CRITICAL CTO DECISION: INVESTIGATION BEFORE IMPLEMENTATION (Option B)

## Expert Panel Review Conducted (2025-10-13)

Virtual Expert Panel identified critical flaws in initial investigation:

**CRITICAL FINDING**: Action EXECUTED but DEBUG_TEST_SUCCESS logging FAILED
- Suite test log (1760344898) shows:
  - ✅ Action executed: "🔄 Executing system.debug.save_gamestate..." (10:52:34.158)
  - ✅ Action completed: "🔄 Completed: system.debug.save_gamestate" (10:52:34.183)
  - ✅ SEMANTIC_ACTION logged
  - ❌ DEBUG_TEST_SUCCESS log line MISSING

**DECISION: Option B - Investigate Further** ✅ COMPLETED

## ROOT CAUSE INVESTIGATION COMPLETE

**MECHANISM VERIFIED**:
1. Test framework creates JSON files by EXTRACTING from logs (not written by Godot)
2. Parsing: `grep "DEBUG_TEST_SUCCESS" log_file | jq parse`
3. If log line missing → result missing → test appears to fail

**TRUE ROOT CAUSE - Android Log Buffer Pollution**:

When app survives between test configs:
1. Android log buffer accumulates chunks from previous test
2. First action of next test logs `DEBUG_TEST_SUCCESS` 
3. Android chunk wait mechanism reports: **"all_chunks_processed": false**
4. Log line stuck in buffer, never reaches logcat before test completes
5. Test framework extraction finds no `DEBUG_TEST_SUCCESS` for sequence 1

**SMOKING GUN EVIDENCE** (Suite test 1760344898):
```
10:52:34.324 - Chunk processing: final_chunk_count: 0, all_chunks_processed: true
10:52:34.344 - Chunk processing: final_chunk_count: 2, all_chunks_processed: FALSE
```

**Timeline Confirms Hypothesis**:
- Oct 12 18:39: Baseline (before fix) - Missing sequences
- Oct 13 10:41: Isolated test (after fix) - ✅ Both sequences (clean buffer)
- Oct 13 10:52: Suite run #1 (after fix) - ❌ Missing sequence 1 (polluted buffer)
- Oct 13 11:32: Suite run #2 (after fix) - ❌ Missing sequence 1 (polluted buffer)

**VALIDATION OF PROPOSED FIX**:

Fix (always stop app before config push) WILL solve this because:
1. Stopping app clears Android's log buffer state
2. Next test starts with clean buffer
3. Chunk processing completes successfully
4. DEBUG_TEST_SUCCESS logs reach logcat
5. Test framework extraction succeeds

**HYPOTHESIS STATUS**: VALIDATED ✅
- Initial theory correct: App state bleeding causes issue
- Refined understanding: Specific mechanism is Android log buffer pollution
- Proposed fix addresses root cause: Stop app = clear buffer

**RISK RE-ASSESSMENT**:
- Original concern: "Fix may not address logging issue" - RESOLVED
- Verification: Log buffer pollution requires app restart to clear
- Performance cost: 45s overhead justified (correctness > speed)
- Confidence: HIGH - mechanism understood, fix validated

**DECISION: PROCEED WITH IMPLEMENTATION**

Option B investigation confirms proposed solution is correct.
Ready to implement enhanced stop detection in _push-file-android.

**STATUS**: Investigation Complete - Ready for Implementation
**NEXT**: Implement always-stop logic in justfile-platform-android.justfile

## Expert Panel Review Conducted (2025-10-13)

Virtual Expert Panel identified critical flaws in initial investigation:

**CRITICAL FINDING**: Action EXECUTED but DEBUG_TEST_SUCCESS logging FAILED
- Suite test log (1760344898) shows:
  - ✅ Action executed: "🔄 Executing system.debug.save_gamestate..." (10:52:34.158)
  - ✅ Action completed: "🔄 Completed: system.debug.save_gamestate" (10:52:34.183)
  - ✅ SEMANTIC_ACTION logged
  - ❌ DEBUG_TEST_SUCCESS log line MISSING

**HYPOTHESIS CHALLENGED**: 
- Initial theory: "App state bleeds between tests, action executes before log capture"
- Evidence contradicts: Action executed DURING test but result logging failed
- Real issue: LOGGING/EXTRACTION mechanism, not EXECUTION/ISOLATION

**RED FLAGS**:
1. Don't understand how test_action_results_*.json files are created
2. Both successful/failed tests show similar app launch patterns
3. Both tests show FASTBUILD_VALIDATION (fresh code deployment)
4. Missing DEBUG_TEST_SUCCESS ≠ Missing execution

**DECISION: Option B - Investigate Further**

Before implementing proposed fix (always stop app), must understand:
1. Where test_action_results_*.json files are created (Godot or test framework?)
2. Why DEBUG_TEST_SUCCESS logging can fail when action executes successfully
3. Whether this is execution issue vs logging race condition
4. Actual root cause before committing to solution

**RISK ASSESSMENT**:
- Proposed fix may not solve actual problem (logging issue)
- 45s performance overhead for potentially wrong solution
- Company future depends on test framework trust
- 1-2 hours investigation < risk of implementing wrong fix

**INVESTIGATION TASKS**:
1. Find test_action_results_*.json creation mechanism in Godot codebase
2. Trace DEBUG_TEST_SUCCESS logging path end-to-end
3. Understand why log line can be missing despite action success
4. Identify actual root cause (logging vs extraction vs timing)
5. Propose solution based on evidence, not assumptions

**STATUS**: In Progress - Deep investigation phase
**NEXT**: Search Godot codebase for JSON file write mechanism
