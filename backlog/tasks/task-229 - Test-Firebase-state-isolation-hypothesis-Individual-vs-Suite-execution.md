---
id: task-229
title: Test Firebase state isolation hypothesis - Individual vs Suite execution
status: To Do
priority: high
assignee: []
created_date: '2025-10-17 14:33'
updated_date: '2025-10-17 14:33'
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

### Phase 1: Individual Test Execution (No Delays)

**Objective**: Test if problems occur when running configs individually with no extra delays.

**Commands** (run back-to-back, as fast as possible):
```bash
# Record start time
date +%s > /tmp/test_start_time

# Run 3 failing configs individually (rapid-fire)
just test-android-target firebase-three-actions-test
just test-android-target firebase-two-actions-test
just test-android-target gamestate-complete-save-load-cycle-test

# Record end time
date +%s > /tmp/test_end_time

# Calculate total time
echo "Total time: $(( $(cat /tmp/test_end_time) - $(cat /tmp/test_start_time) )) seconds"
```

**Expected Results**:
- ✅ **If ALL PASS**: Problem is specific to test list execution (single bash process)
- ❌ **If ANY FAIL**: Problem occurs even with individual test calls

**What to Record**:
- Pass/Fail status for each config
- Timing for `backend.firebase.performance` action (should be ~1s, not 27s)
- Any SIGSEGV crashes
- Any Firebase timeouts
- Total execution time

**Success Criteria**:
- All 3 configs pass
- Performance action completes in <3 seconds
- No crashes or timeouts

---

### Phase 2: Individual Test Execution (With Delays)

**Objective**: If Phase 1 fails, test if delays between individual tests resolve issues.

**Only run if Phase 1 had failures.**

**Commands** (with 30-second delays):
```bash
date +%s > /tmp/test_start_time

just test-android-target firebase-three-actions-test
sleep 30
just test-android-target firebase-two-actions-test
sleep 30
just test-android-target gamestate-complete-save-load-cycle-test

date +%s > /tmp/test_end_time
echo "Total time: $(( $(cat /tmp/test_end_time) - $(cat /tmp/test_start_time) )) seconds"
```

**Expected Results**:
- ✅ **If NOW PASS**: Timing is the issue - Firebase SDK needs cooldown period
- ❌ **If STILL FAIL**: Deeper Firebase SDK issue, not timing-related

**What to Record**:
- Pass/Fail status for each config
- Compare timing vs. Phase 1
- Firebase connection behavior during sleep periods

**Success Criteria**:
- All 3 configs pass with delays
- Performance metrics return to normal

---

### Phase 3: Minimal Test List (Single Config)

**Objective**: Create minimal test list to verify test list execution works with single config.

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

**Commands**:
```bash
just test-android diagnostic-single
```

**Expected Results**:
- ✅ **Should PASS**: Single config in test list behaves like individual execution
- ❌ **If FAILS**: Test list infrastructure itself has issues

**What to Record**:
- Pass/Fail status
- Performance metrics
- Compare with Phase 1 individual execution

---

### Phase 4: Two-Config Test List (Problematic Pair)

**Objective**: Find minimum config count that triggers failures.

**Setup**:
```bash
# Create test list with 2 configs that failed
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

**Commands**:
```bash
just test-android diagnostic-pair
```

**Expected Results**:
- ✅ **If PASS**: Problem requires more configs to manifest
- ❌ **If FAILS**: 2 configs sufficient to reproduce issue

**What to Record**:
- Which config fails (first or second?)
- Timing of failures
- Resource usage patterns

---

### Phase 5: Three-Config Test List (All Problematic)

**Objective**: Test with all 3 originally failing configs.

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

**Commands**:
```bash
just test-android diagnostic-triple
```

**Expected Results**:
- Should replicate original comprehensive suite failures
- Identify which configs trigger problems for later configs

**What to Record**:
- Pass/Fail for each config
- Order of failures
- Cumulative resource exhaustion pattern

---

### Phase 6: Add Firebase Process Cleanup

**Objective**: Test if killing Firebase system services between tests resolves issues.

**Only run if previous phases showed timing helps.**

**Implementation**:
```bash
# Modify clear-android-test-cache to add Firebase cleanup
# Location: justfiles/justfile-platform-android.justfile

# Add after "pm clear {{ANDROID_PACKAGE_NAME}}":
echo "🔧 Stopping Firebase system services..."
adb -s {{ANDROID_DEVICE_ID}} shell "am force-stop com.google.android.gms" 2>/dev/null || true
echo "⏳ Waiting for Firebase SDK to reset..."
sleep 5
```

**Commands**:
```bash
# Re-run comprehensive suite
just test-android diagnostic-triple
```

**Expected Results**:
- ✅ **If NOW PASS**: Firebase process cleanup is the solution
- ❌ **If STILL FAIL**: Need different approach

---

### Phase 7: Increase Test List Inter-Config Delay

**Objective**: Test if simply increasing sleep between configs in test lists resolves issues.

**Implementation**:
```bash
# Modify test list loop (justfile-validation-enhanced-testing.justfile line 1762)
# Change from: sleep 2
# Change to: sleep 10  # Or sleep 5
```

**Commands**:
```bash
just test-android diagnostic-triple
```

**Expected Results**:
- Measure if longer delays prevent state accumulation
- Find minimum delay needed for stability

---

## Analysis Framework

### For Each Phase, Record:

1. **Test Results**:
   ```bash
   # Check latest test IDs
   ls -lt ~/Library/Application\ Support/Godot/app_userdata/gametwo/logs/test_action_results_*.json | head -3

   # Analyze each test
   just logs-errors TEST_ID
   ```

2. **Performance Metrics**:
   ```bash
   # Check firebase-three-actions-test performance timing
   just logs-text TEST_ID "backend.firebase.performance" | grep duration
   ```

3. **Firebase Process State**:
   ```bash
   # Before test
   adb shell "ps -A | grep -E '(firebase|gms)'" > /tmp/before_firebase_ps.txt

   # After test
   adb shell "ps -A | grep -E '(firebase|gms)'" > /tmp/after_firebase_ps.txt

   # Compare
   diff /tmp/before_firebase_ps.txt /tmp/after_firebase_ps.txt
   ```

4. **Memory/Resource Usage**:
   ```bash
   # Check for resource exhaustion patterns
   just android-logs-search "OutOfMemory|ResourceExhausted|TooManyConnections"
   ```

## Acceptance Criteria

- [ ] Phase 1 completed - Individual tests documented (pass/fail)
- [ ] Phase 2 completed if Phase 1 failed - Delay effectiveness measured
- [ ] Phase 3 completed - Single-config test list validated
- [ ] Phase 4 completed - Two-config behavior documented
- [ ] Phase 5 completed - Three-config failures reproduced
- [ ] Root cause identified: Timing vs. Process isolation vs. Resource exhaustion
- [ ] Solution proposed based on evidence
- [ ] Solution tested and validated (18/18 configs pass)

## Expected Outcomes

### Scenario A: Individual Tests Pass (Phase 1 ✅)
**Conclusion**: Test list execution infrastructure causes issues
**Solution**: Investigate bash process state, environment variables, test list loop

### Scenario B: Individual Tests Fail, Delays Help (Phase 1 ❌, Phase 2 ✅)
**Conclusion**: Firebase SDK needs cooldown time between tests
**Solution**: Increase inter-test delays or add Firebase process cleanup

### Scenario C: All Individual Tests Fail (Phase 1 ❌, Phase 2 ❌)
**Conclusion**: Fundamental Firebase SDK state issue
**Solution**: Deep Firebase SDK investigation, possibly device reboot required

### Scenario D: Minimal Test Lists Pass (Phase 3-5 ✅)
**Conclusion**: Scale/accumulation issue - needs full comprehensive suite to trigger
**Solution**: Test with progressively larger lists to find threshold

## Debug Commands

```bash
# Quick status check
just logs-last

# Detailed error analysis
just logs-errors TEST_ID

# Firebase-specific search
just logs-text TEST_ID "firebase" | head -50

# Check Firebase processes
adb shell "dumpsys activity services | grep -i firebase" | head -20

# Monitor Firebase connections
adb shell "netstat -an | grep 443 | wc -l"  # Count active HTTPS connections

# Check app memory
adb shell "dumpsys meminfo com.primaryhive.gametwo | head -20"
```

## Related Tasks

- **task-216.01**: Test suite isolation - found `pm clear` is called but Firebase SDK persists
- **task-225**: Firebase crashes (SIGBUS, SIGSEGV) in comprehensive suite
- **task-227**: `backend.firebase.performance` 27x slowdown
- **task-228**: Firebase database timeouts in gamestate test
