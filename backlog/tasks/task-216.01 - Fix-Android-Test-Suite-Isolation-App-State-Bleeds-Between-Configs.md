---
id: task-216.01
title: Fix Android Test Suite Isolation - App State Bleeds Between Configs
status: To Do
assignee: []
created_date: '2025-10-13 10:39'
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
