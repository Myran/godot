---
id: task-222
title: Fix Android Checksum Collection Race Condition in Automated Tests
status: In Progress
assignee: []
created_date: '2025-10-15 19:45'
updated_date: '2025-10-21'
labels:
  - critical
  - test-framework
  - android
  - checksum-validation
  - race-condition
  - auto-quit
dependencies: []
priority: critical
---

## Description

**CRITICAL TEST FRAMEWORK BUG**: Android automated tests with `auto_quit: true` consistently drop the final action's checksum, causing false negative test failures for gamestate validation.

**Business Impact**: ⚠️ **Company survival risk** - Cannot validate game state consistency on production platform (Android). Regressions could slip through to production undetected.

---

## Problem Summary

### Test Results Pattern

**Desktop Tests** (reference platform):
- ✅ `gamestate-complete-save-load-cycle-test`: PASSED (all 3 checksums)
- ✅ `gamestate-save-load-test`: PASSED (all 2 checksums)

**Android Tests** (production platform):
- ❌ `gamestate-complete-save-load-cycle-test`: FAILED (only 2/3 checksums)
- ❌ `gamestate-save-load-test`: FAILED (only 1/2 checksums)

### Failure Pattern

**Expected Checksums** (3 actions):
```
SKIP_SYSTEM_DEBUG_CHECKSUM  ← Action 1: save_gamestate
SKIP_SYSTEM_DEBUG_CHECKSUM  ← Action 2: load_gamestate
SKIP_SYSTEM_DEBUG_CHECKSUM  ← Action 3: save_gamestate
```

**Actual Checksums Collected**:
```
SKIP_SYSTEM_DEBUG_CHECKSUM  ← Action 1: save_gamestate
SKIP_SYSTEM_DEBUG_CHECKSUM  ← Action 2: load_gamestate
(Missing - Action 3 checksum never captured)
```

**Pattern**: Always the LAST action's checksum is missing.

---

## Root Cause Hypothesis

### Hypothesis 1: Auto-Quit Timing Race (MOST LIKELY)

**Android automated tests use `auto_quit: true` metadata:**

```
1. Action 3 executes (save_gamestate)
2. Action 3 completes successfully
3. Test framework detects all actions done → prepares to quit
4. Checksum collection in progress (async logging)
5. App quits before checksum flushed to Android logcat
6. Test framework extracts logs via adb
7. Checksum never captured (log buffer hasn't flushed yet)
```

**Supporting Evidence**:
- Desktop tests don't auto-quit → All checksums captured ✅
- Android tests auto-quit immediately → Final checksum lost ❌
- Pattern is 100% consistent (always last checksum)

### Hypothesis 2: Android Log Buffer Timing

**Android logcat buffering may delay final writes:**

```
1. Final action completes
2. Checksum logged to Android logcat (async)
3. App quits (auto_quit: true)
4. Test framework runs: adb logcat -d
5. Log buffer hasn't flushed final checksum yet
6. Checksum missing from extracted logs
```

### Hypothesis 3: Checksum Logging Order

**Checksum may be logged AFTER action completion event:**

```
1. Action completes
2. DEBUG_TEST_SUCCESS logged (action completion)
3. Checksum logged (after completion)
4. App detects all DEBUG_TEST_SUCCESS → quits
5. Checksum log never appears
```

---

## Evidence from Test Logs

**Source**: `logs/20251015_192324_test.log` (full test suite run)

### Test: gamestate-complete-save-load-cycle-test (Android)

**Error Output**:
```
❌ Checksum validation FAILED

MISMATCH
Expected:
  SKIP_SYSTEM_DEBUG_CHECKSUM
  SKIP_SYSTEM_DEBUG_CHECKSUM
  SKIP_SYSTEM_DEBUG_CHECKSUM
Actual:
  SKIP_SYSTEM_DEBUG_CHECKSUM
  SKIP_SYSTEM_DEBUG_CHECKSUM
Differences:
  3d2
  < SKIP_SYSTEM_DEBUG_CHECKSUM
```

### Test: gamestate-save-load-test (Android)

**Error Output**:
```
❌ Checksum validation FAILED

MISMATCH
Expected:
  SKIP_SYSTEM_DEBUG_CHECKSUM
  SKIP_SYSTEM_DEBUG_CHECKSUM
Actual:
  SKIP_SYSTEM_DEBUG_CHECKSUM
Differences:
  2d1
  < SKIP_SYSTEM_DEBUG_CHECKSUM
```

---

## Test Configuration Analysis

### gamestate-complete-save-load-cycle-test.json

```json
{
  "description": "Complete save/load cycle test",
  "checksum_config": {
    "initial_seed": 12345,
    "state_type": "save_load_cycle_validation",
    "expected_checksums": [
      "SKIP_SYSTEM_DEBUG_CHECKSUM",
      "SKIP_SYSTEM_DEBUG_CHECKSUM",
      "SKIP_SYSTEM_DEBUG_CHECKSUM"
    ]
  },
  "actions": [
    "system.debug.save_gamestate",
    "system.debug.load_gamestate",
    "system.debug.save_gamestate"
  ],
  "metadata": {
    "test_type": "save_load_cycle"
  }
}
```

**Why SKIP_SYSTEM_DEBUG_CHECKSUM**:
- Debug actions (`system.debug.*`) are system utilities, not game logic
- They should not generate game state checksums
- Special marker indicates these actions bypass checksum calculation
- Test validates that the marker appears for each action

---

## Investigation Steps

### Step 1: Verify Checksum Logging Timing

**Check when checksums are logged relative to action completion:**

```bash
# For gamestate-complete-save-load-cycle-test
just logs-text gamestate-complete-save-load-cycle-test_android_TESTID "SKIP_SYSTEM_DEBUG_CHECKSUM"
just logs-text gamestate-complete-save-load-cycle-test_android_TESTID "DEBUG_TEST_SUCCESS"

# Compare timestamps to see ordering
```

**Expected Output**: Determine if checksum logged before or after `DEBUG_TEST_SUCCESS`.

### Step 2: Test Manual Quit (No Auto-Quit)

**Run test manually without auto-quit:**

```bash
# Modify config temporarily to remove auto_quit
just test-android gamestate-complete-save-load-cycle-test

# Let it run, then manually quit via debug menu
# Check if all 3 checksums captured
```

**Hypothesis Validation**: If all checksums appear → confirms auto-quit timing issue.

### Step 3: Test with Explicit Delay Before Quit

**Add delay after final action before auto-quit:**

```gdscript
# In debug coordinator after final action completes
if metadata.get("auto_quit", false):
    await get_tree().create_timer(0.5).timeout  # 500ms delay
    get_tree().quit()
```

**Expected**: Gives time for checksum to flush to logs before quit.

### Step 4: Check Android Log Buffer

**Run test and immediately capture full logs:**

```bash
just test-android-target gamestate-complete-save-load-cycle-test

# Immediately after app quits
adb logcat -d | rg "SKIP_SYSTEM_DEBUG_CHECKSUM" -c

# Expected: Should see 3 occurrences if buffer has all logs
```

---

## Proposed Solutions

### Solution 1: Add Delay Before Auto-Quit (QUICK FIX) ⏱️

**Implementation**:
```gdscript
# In debug coordinator auto-quit logic
if auto_quit_enabled:
    Log.info("Auto-quit: Waiting for log buffer flush", {"delay_ms": 500})
    await get_tree().create_timer(0.5).timeout
    Log.info("Auto-quit: Proceeding with quit")
    get_tree().quit()
```

**Pros**:
- Quick to implement (5 minutes)
- Low risk (just adds delay)
- Should fix 90% of cases

**Cons**:
- Still relies on timing (not guaranteed)
- Adds 500ms to every Android test

**Timeline**: 30 minutes (implement + test)

### Solution 2: Synchronize Checksum Logging (ROBUST FIX) ✅

**Implementation**:
```gdscript
# Ensure checksum logged BEFORE action completion event
func complete_action(action_name: String):
    # 1. Log checksum FIRST
    _log_checksum(action_name)

    # 2. Wait for log to flush (critical on Android)
    if OS.get_name() == "Android":
        await get_tree().process_frame  # Let log buffer process

    # 3. THEN log action completion
    _log_action_success(action_name)
```

**Pros**:
- Guaranteed ordering
- No timing dependency
- Faster than delay (just 1 frame)

**Cons**:
- Requires code changes in multiple places
- Need to ensure all action completion paths updated

**Timeline**: 2-4 hours (implement + test + validate)

### Solution 3: Explicit Log Flush Before Quit (COMPREHENSIVE) 🚀

**Implementation**:
```gdscript
# Add explicit log flush synchronization
func auto_quit_with_log_sync():
    Log.info("Auto-quit: Flushing logs...")

    # Force log flush (platform-specific)
    if OS.get_name() == "Android":
        _flush_android_logs()

    # Wait for confirmation
    await _wait_for_log_flush_complete()

    Log.info("Auto-quit: Logs flushed, quitting")
    get_tree().quit()

func _flush_android_logs():
    # Trigger explicit flush via Java bridge
    # Or wait for buffer synchronization
    pass
```

**Pros**:
- Most robust solution
- Platform-aware
- Guarantees logs flushed

**Cons**:
- Most complex implementation
- May require platform bridge code

**Timeline**: 1-2 days (implement + test + validate)

---

## Recommended Approach

### Phase 1: Quick Validation (Today) ⏱️

1. **Test manually without auto-quit** (30 minutes)
   - Confirms hypothesis
   - Establishes baseline

2. **Add 500ms delay before auto-quit** (30 minutes)
   - Quick fix to validate
   - Run gamestate tests to confirm

3. **Validate fix** (1 hour)
   - Run both gamestate tests 5 times each
   - Confirm 100% checksum collection

### Phase 2: Robust Fix (Tomorrow) ✅

1. **Implement checksum-before-completion ordering** (2 hours)
   - Modify action completion flow
   - Ensure checksum logged first

2. **Add platform-specific frame wait** (1 hour)
   - Android: Wait 1 frame after checksum
   - Desktop: No wait needed

3. **Comprehensive testing** (2 hours)
   - All gamestate tests
   - Multiple runs
   - Validate 100% success rate

---

## Success Criteria

### Acceptance Criteria

- [ ] `gamestate-complete-save-load-cycle-test` passes on Android (3/3 checksums)
- [ ] `gamestate-save-load-test` passes on Android (2/2 checksums)
- [ ] 100% checksum collection rate (10 consecutive test runs)
- [ ] No false negatives in checksum validation
- [ ] Desktop tests still pass (regression check)

### Validation Tests

```bash
# Test gamestate-complete-save-load-cycle-test (10 runs)
for i in {1..10}; do
    just test-android-target gamestate-complete-save-load-cycle-test
done

# Test gamestate-save-load-test (10 runs)
for i in {1..10}; do
    just test-android-target gamestate-save-load-test
done

# Check results: Should be 20/20 PASSED
```

---

## Business Impact Assessment

### Current Risk: ⚠️ **HIGH**

**Cannot validate game state consistency on production platform:**
- Regressions could slip through to production
- No confidence in Android gamestate validation
- False negatives undermine test framework trust

**Estimated Business Loss if Deployed**:
- Production gamestate corruption → User data loss
- User churn from save/load failures
- Support costs from bug reports
- Reputation damage

### Risk Mitigation After Fix: ✅ **LOW**

**Game state validation reliable on Android:**
- Regressions caught before production
- Full confidence in test framework
- Android/Desktop parity validated

---

## Related Tasks

- **task-221**: Firebase await heisenbug (RESOLVED - memory barriers working)
- **task-152**: Firebase SIGBUS crashes (SEPARATE ISSUE - not checksum related)
- **CTO Analysis**: /tmp/cto_full_test_suite_analysis.md (comprehensive findings)

---

## Context for Future Investigation

### Key Diagnostic Commands

```bash
# Check checksum logging timing
just logs-text TEST_ID "SKIP_SYSTEM_DEBUG_CHECKSUM"
just logs-text TEST_ID "DEBUG_TEST_SUCCESS"

# Verify all checksums in Android logs
adb logcat -d | rg "SKIP_SYSTEM_DEBUG_CHECKSUM" -c

# Full gamestate test analysis
just logs-errors gamestate-complete-save-load-cycle-test_android_TESTID
```

### Test Configurations

- `tests/debug_configs/gamestate-complete-save-load-cycle-test.json`
- `tests/debug_configs/gamestate-save-load-test.json`

### Analysis Documents

- `/tmp/cto_full_test_suite_analysis.md` - CTO-level assessment
- `logs/20251015_192324_test.log` - Full test suite run showing failures

---

**Priority Justification**: **CRITICAL** - Test framework validity depends on reliable checksum collection. Cannot deploy to production without confidence in Android game state validation.

**Created**: 2025-10-15 19:45
**Analysis**: CTO Review - Full Test Suite Validation
**Status**: Open - Requires immediate investigation
