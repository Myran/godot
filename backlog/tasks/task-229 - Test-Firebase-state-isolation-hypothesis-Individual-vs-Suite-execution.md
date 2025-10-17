---
id: task-229
title: Test Firebase state isolation hypothesis - Individual vs Suite execution
status: To Do
priority: high
assignee: []
created_date: '2025-10-17 14:33'
updated_date: '2025-10-17 19:30'
labels:
  - firebase
  - test-isolation
  - investigation
  - comprehensive-testing
  - diagnostic
dependencies:
  - task-216.01
  - task-225
  - task-227
  - task-228
---

## Description

**DIAGNOSTIC INVESTIGATION**: Systematically test whether Firebase state isolation failures occur due to rapid test execution in comprehensive suite vs. timing differences when running tests individually.

### Background

Latest comprehensive test run showed 3 Firebase-related failures (83.3% pass rate):
1. **firebase-three-actions-test**: `backend.firebase.performance` 27x slowdown (27s vs 1s)
2. **firebase-two-actions-test**: SIGSEGV crash (signal 11, fault addr 0x40)
3. **gamestate-complete-save-load-cycle-test**: Firebase database timeout

**Key Discovery** (task-216.01):
- System DOES call `pm clear` between every config (proper app reset)
- But Firebase C++ SDK lives in separate system processes (Google Play Services)
- These processes are NOT cleared by `pm clear`
- State may accumulate across rapid test execution

### Hypothesis

**Individual test execution** may succeed where **comprehensive suite** fails due to:
1. **Timing differences**: Human delays between commands allow Firebase SDK to reset
2. **Connection draining**: Time for Firebase connection pools to timeout
3. **Process isolation**: Separate shell invocations may trigger different cleanup
4. **Memory pressure relief**: Gaps between tests allow memory to be reclaimed

### Investigation Goal

Systematically determine:
1. Do individual test calls (without delays) pass?
2. If not, does adding sleep between calls fix it?
3. Can we replicate suite failures with minimal test lists?
4. What is the minimum inter-test delay needed for stability?

## Investigation Phases

### Phase 1: Individual Test Execution (Rapid-Fire, No Delays)

**Objective**: Test if problems occur when running configs individually back-to-back.

**Commands** (run 3 times each for reproducibility):
```bash
# Test 1: firebase-three-actions-test
just log-run test-android-target firebase-three-actions-test
just log-run test-android-target firebase-three-actions-test
just log-run test-android-target firebase-three-actions-test

# Test 2: firebase-two-actions-test
just log-run test-android-target firebase-two-actions-test
just log-run test-android-target firebase-two-actions-test
just log-run test-android-target firebase-two-actions-test

# Test 3: gamestate-complete-save-load-cycle-test
just log-run test-android-target gamestate-complete-save-load-cycle-test
just log-run test-android-target gamestate-complete-save-load-cycle-test
just log-run test-android-target gamestate-complete-save-load-cycle-test
```

**What to Record** (keep simple):
- Pass/Fail count for each config (e.g., "3/3 pass", "2/3 pass", "0/3 pass")
- Any crashes (SIGSEGV)
- Any timeouts

**Expected Results**:
- ✅ **If ALL PASS (9/9)**: Problem is specific to test list execution
- ❌ **If ANY FAIL**: Problem occurs even with individual execution → Go to Phase 2

**Success Criteria**:
- All 9 test runs pass (3x each config)
- No crashes or timeouts

---

### Phase 2: Individual Test Execution (With Delays)

**Objective**: If Phase 1 fails, test if delays between individual tests resolve issues.

**Only run if Phase 1 had failures.**

**Commands** (with 30-second delays, run 3 times):
```bash
# Run 1
just log-run test-android-target firebase-three-actions-test
sleep 30
just log-run test-android-target firebase-two-actions-test
sleep 30
just log-run test-android-target gamestate-complete-save-load-cycle-test
sleep 30

# Run 2
just log-run test-android-target firebase-three-actions-test
sleep 30
just log-run test-android-target firebase-two-actions-test
sleep 30
just log-run test-android-target gamestate-complete-save-load-cycle-test
sleep 30

# Run 3
just log-run test-android-target firebase-three-actions-test
sleep 30
just log-run test-android-target firebase-two-actions-test
sleep 30
just log-run test-android-target gamestate-complete-save-load-cycle-test
```

**What to Record** (keep simple):
- Pass/Fail count for each config (e.g., "3/3 pass")
- Compare with Phase 1 results

**Expected Results**:
- ✅ **If NOW PASS**: Timing is the issue - Firebase SDK needs cooldown
- ❌ **If STILL FAIL**: Not timing-related, deeper issue

**Success Criteria**:
- All 9 test runs pass (3x each config with delays)

---

### Phase 3: Minimal Test List (Single Config)

**Objective**: Test if single config in test list works (baseline for test list execution).

**Setup**:
```bash
# Create minimal test list with just one config
cat > tests/test_lists/diagnostic-single.json << 'EOF'
{
  "name": "Diagnostic Single Config",
  "description": "Minimal test list - single Firebase config",
  "configs": [
    "firebase-three-actions-test"
  ]
}
EOF
```

**Commands** (run 3 times):
```bash
just log-run test-android diagnostic-single
just log-run test-android diagnostic-single
just log-run test-android diagnostic-single
```

**What to Record** (keep simple):
- Pass/Fail count (e.g., "3/3 pass")
- Compare with Phase 1 results

**Expected Results**:
- ✅ **If PASS (3/3)**: Single config in test list works fine
- ❌ **If FAILS**: Test list infrastructure has issues

**Success Criteria**:
- All 3 runs pass

---

### Phase 4: Two-Config Test List (Problematic Pair)

**Objective**: Test if 2 configs in test list trigger failures.

**Setup**:
```bash
# Create test list with 2 configs
cat > tests/test_lists/diagnostic-pair.json << 'EOF'
{
  "name": "Diagnostic Config Pair",
  "description": "Two problematic Firebase configs",
  "configs": [
    "firebase-three-actions-test",
    "firebase-two-actions-test"
  ]
}
EOF
```

**Commands** (run 3 times):
```bash
just log-run test-android diagnostic-pair
just log-run test-android diagnostic-pair
just log-run test-android diagnostic-pair
```

**What to Record** (keep simple):
- Pass/Fail count (e.g., "3/3 pass", "2/3 pass")
- If fails, which config fails (first or second)?

**Expected Results**:
- ✅ **If PASS (3/3)**: Need more configs to trigger issue
- ❌ **If FAILS**: 2 configs sufficient to reproduce

**Success Criteria**:
- Document pass/fail pattern

---

### Phase 5: Three-Config Test List (All Problematic)

**Objective**: Test with all 3 originally failing configs (should replicate comprehensive suite failures).

**Setup**:
```bash
cat > tests/test_lists/diagnostic-triple.json << 'EOF'
{
  "name": "Diagnostic Triple Configs",
  "description": "All three problematic Firebase configs",
  "configs": [
    "firebase-three-actions-test",
    "firebase-two-actions-test",
    "gamestate-complete-save-load-cycle-test"
  ]
}
EOF
```

**Commands** (run 3 times):
```bash
just log-run test-android diagnostic-triple
just log-run test-android diagnostic-triple
just log-run test-android diagnostic-triple
```

**What to Record** (keep simple):
- Pass/Fail count (e.g., "1/3 pass", "0/3 pass")
- Which configs fail (first, second, third, or all?)
- Pattern of failures

**Expected Results**:
- ❌ **Should FAIL**: Replicate comprehensive suite failures
- Identify which configs trigger problems

**Success Criteria**:
- Document failure pattern (which configs fail consistently)

---

### Phase 6: Test With Longer Inter-Config Delays

**Objective**: Test if increasing delay between configs in test list resolves issues.

**Only run if Phase 5 shows consistent failures.**

**Implementation**:
```bash
# Modify test list loop (justfile-validation-enhanced-testing.justfile around line 1762)
# Change from: sleep 2
# Change to: sleep 10
```

**Commands** (run 3 times):
```bash
just log-run test-android diagnostic-triple
just log-run test-android diagnostic-triple
just log-run test-android diagnostic-triple
```

**What to Record** (keep simple):
- Pass/Fail count with 10s delays
- Compare with Phase 5 results (2s delays)

**Expected Results**:
- ✅ **If NOW PASS**: Delay duration is the issue
- ❌ **If STILL FAIL**: Not about delay duration

**Success Criteria**:
- Document whether longer delays help

---

### Phase 7: Test Firebase Process Cleanup

**Objective**: Test if killing Firebase system services between tests resolves issues.

**Only run if Phase 6 fails but Phase 2 showed delays help.**

**Implementation**:
```bash
# Modify clear-android-test-cache to add Firebase cleanup
# Location: justfiles/justfile-platform-android.justfile

# Add after "pm clear {{ANDROID_PACKAGE_NAME}}":
echo "🔧 Stopping Firebase system services..."
adb -s {{ANDROID_DEVICE_ID}} shell "am force-stop com.google.android.gms" 2>/dev/null || true
sleep 5
```

**Commands** (run 3 times with modified cleanup):
```bash
just log-run test-android diagnostic-triple
just log-run test-android diagnostic-triple
just log-run test-android diagnostic-triple
```

**What to Record** (keep simple):
- Pass/Fail count with Firebase cleanup
- Compare with Phase 5/6 results

**Expected Results**:
- ✅ **If NOW PASS**: Firebase process cleanup is the solution
- ❌ **If STILL FAIL**: Deeper Firebase SDK issue

**Success Criteria**:
- Document whether Firebase process cleanup helps

---

## Analysis Commands (Use After Each Phase)

**Check test results** (logs saved automatically by `just log-run`):
```bash
# View logs in logs/ directory
ls -lt logs/*.log | head -5

# Quick analysis
just logs-last                              # Latest test results
just logs-errors TEST_ID                    # If failures found
```

**Debug specific issues** (only if needed):
```bash
# Check for crashes
just android-logs-search "SIGSEGV|SIGBUS|fatal"

# Check for timeouts
just logs-text TEST_ID "timeout|timed out"

# Check Firebase performance
just logs-text TEST_ID "backend.firebase.performance"
```

## Acceptance Criteria

- [ ] Phase 1 completed - Individual rapid-fire tests (9 runs total, 3x each config)
- [ ] Phase 2 completed if Phase 1 failed - Individual tests with delays
- [ ] Phase 3 completed - Single-config test list (3 runs)
- [ ] Phase 4 completed - Two-config test list (3 runs)
- [ ] Phase 5 completed - Three-config test list (3 runs)
- [ ] Phase 6 completed if needed - Longer delays tested (10s vs 2s)
- [ ] Phase 7 completed if needed - Firebase process cleanup tested
- [ ] Root cause narrowed down based on which phase shows change in behavior
- [ ] Solution proposed and documented

## Expected Outcomes (Quick Reference)

**Phase 1 ✅ (all pass)**: Problem is test list execution, not Firebase itself
**Phase 1 ❌ + Phase 2 ✅**: Firebase needs cooldown time between tests
**Phase 1 ❌ + Phase 2 ❌**: Fundamental Firebase SDK issue (deeper investigation needed)
**Phase 3-4 ✅ + Phase 5 ❌**: Problem needs 3+ configs to manifest
**Phase 6 ✅ (longer delays help)**: Increase inter-config delay in test lists
**Phase 7 ✅ (Firebase cleanup helps)**: Add Firebase process cleanup to test infrastructure

## Related Tasks

- **task-216.01**: Test suite isolation - found `pm clear` is called but Firebase SDK persists
- **task-225**: Firebase crashes (SIGBUS, SIGSEGV) in comprehensive suite
- **task-227**: `backend.firebase.performance` 27x slowdown
- **task-228**: Firebase database timeouts in gamestate test
