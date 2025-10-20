---
id: task-225
title: >-
  Fix Firebase crash signals - SIGBUS (GLThread) & SIGSEGV in comprehensive test
  suite
status: To Do
assignee: []
created_date: '2025-10-17 11:21'
updated_date: '2025-10-18 16:59'
labels:
  - firebase
  - crash
  - sigbus
  - sigsegv
  - android
  - glthread
  - production-critical
  - test-suite
dependencies: []
priority: high
---

## Description

**PRODUCTION CRITICAL**: Firebase backend tests crash with multiple signal patterns (SIGBUS, SIGSEGV) on Android, occurring both during execution and after test completion.

### Crash Pattern

**Three distinct crash patterns identified:**

1. **firebase-backend-batch-1**: SIGBUS at `10:11:31` in test run (original)
2. **firebase-backend-layer**: SIGBUS at `10:14:07` in test run (original)
3. **firebase-two-actions-test**: SIGSEGV at `13:55:25` in comprehensive test suite (NEW)

**Critical Observations:**
- SIGBUS crashes: Tests execute successfully (all actions PASSED) but crash during or after completion
- SIGSEGV crash: Occurs in comprehensive test suite execution (NEW pattern)
- Different signal types suggest multiple root causes or manifestations

### Crash Details

**firebase-backend-batch-1 crash:**
```
Fatal signal 7 (SIGBUS), code 1 (BUS_ADRALN), fault addr 0x8744000c19
in tid 27620 (GLThread 254187), pid 27489 (aryhive.gametwo)
```

**firebase-backend-layer crash:**
```
Fatal signal 7 (SIGBUS), code 1 (BUS_ADRALN), fault addr 0x8898000c19
in tid 678 (GLThread 254707), pid 403 (aryhive.gametwo)
```

**firebase-two-actions-test crash (NEW - 2025-10-17 13:55):**
```
Fatal signal 11 (SIGSEGV), code 1 (SEGV_MAPERR), fault addr 0x40
in tid 9488 (aryhive.gametwo), pid 9488 (aryhive.gametwo)
```

**Crash Pattern Analysis:**

**SIGBUS Pattern (signals 1-2):**
- Signal: SIGBUS (signal 7)
- Code: BUS_ADRALN (code 1) - Unaligned memory access
- Thread: GLThread (OpenGL rendering thread)
- Both fault addresses in similar range (0x87/88...000c19)

**SIGSEGV Pattern (signal 3 - NEW):**
- Signal: SIGSEGV (signal 11) - Invalid memory access
- Code: SEGV_MAPERR (code 1) - Address not mapped to object
- Thread: Main thread (not GLThread)
- Fault addr: 0x40 (very low address, likely null pointer + offset)
- Context: Comprehensive test suite execution

### Test Execution Status

**firebase-backend-batch-1:**
- ✅ `backend.firebase.async_pattern` - PASSED (280ms, 352ms)
- ✅ `backend.firebase.lifecycle` - PASSED (285ms)
- ✅ ERROR ANALYSIS PASSED (0 errors)
- ❌ CRASH DETECTED during/after test completion

**firebase-backend-layer:**
- ✅ `backend.firebase.async_pattern` - PASSED (358ms, 429ms)
- ✅ `backend.firebase.lifecycle` - PASSED (273ms)
- ✅ ERROR ANALYSIS PASSED (0 errors)
- ❌ CRASH DETECTED during/after test completion

**firebase-two-actions-test (NEW - comprehensive suite):**
- ✅ ERROR ANALYSIS PASSED (0 errors before crash)
- ❌ CRASH DETECTED: SIGSEGV in main thread
- **Context**: Occurred during comprehensive test suite run
- **Source**: `logs/20251017_134504_test.log`
- **Historical Success**: task-154, task-207 show 100% success in individual runs
- **Key Difference**: Only crashes in full test suite execution

### **🔍 NEW FINDINGS (2025-10-18 Task-230 Validation)**

**Root Cause Precision**: Through detailed analysis of Task-230 Firebase cleanup implementation validation, identified the **exact crash point** and **impact assessment**:

**Crash During Action Execution (Not Post-Completion):**
- **Previous understanding**: Tests completed successfully then crashed during cleanup
- **NEW EVIDENCE**: Crash occurs **DURING** `backend.firebase.method_mapping` execution
- **Impact**: Prevents completion event emission and causes test framework to register failure

**Evidence from firebase-backend-batch-1 (TEST_ID: firebase-backend-batch-1_android_1760786212):**
```
✅ DEBUG_TEST_SUCCESS: backend.firebase.async_pattern (2 instances) - COMPLETED
✅ DEBUG_TEST_SUCCESS: backend.firebase.lifecycle (1 instance) - COMPLETED
❌ NO SUCCESS ENTRY: backend.firebase.method_mapping - CRASHED DURING EXECUTION
✅ SequentialActionCompleteEvent: Emitted for async_pattern & lifecycle
❌ NO COMPLETION EVENT: method_mapping - CRASH PREVENTED EMISSION
```

**SIGBUS Crash Signature (Updated):**
```
Fatal signal 7 (SIGBUS), code 1 (BUS_ADRALN), fault addr 0x8744000c19
Timestamp: 10-18 13:22:09.920 (during method_mapping execution)
Thread: GLThread 254187 (consistent pattern)
Stack trace: libgodot_android.so memory access violation
```

**Task-230 Firebase Cleanup Impact:**
- ✅ **68% Performance Improvement**: Firebase operations significantly faster (230ms vs 728ms avg)
- ✅ **Cleanup Implementation Working**: No issues with Firebase resource cleanup
- ✅ **Functionally Correct**: Task-230 implementation is solid and beneficial
- ❌ **Unrelated Memory Issue**: SIGBUS crash is separate ARM64 alignment problem

**Test Framework Behavior:**
- ✅ **Correctly Detecting Incomplete Execution**: 2/3 completion events registered accurately
- ✅ **Proper Failure Reporting**: Test marked as FAILED due to incomplete execution
- ❌ **Not Framework Bug**: Test framework working correctly - actual crash occurred

**Technical Implications:**
1. **Memory Alignment Issue**: ARM64-specific unaligned memory access in Firebase C++ bindings
2. **Method-Specific Crash**: `backend.firebase.method_mapping` triggers the alignment issue
3. **Task-230 Success**: Firebase cleanup implementation is working correctly
4. **Separate Fix Required**: Need ARM64 memory alignment fix independent of Task-230

**Analysis Source**: `logs/20251018_131652_test.log`, comparison with `logs/20251017_134504_test.log`
**Investigation Method**: Systematic completion event analysis and crash timing correlation

## Root Cause Hypothesis

### SIGBUS Pattern (GLThread crashes)

**SIGBUS BUS_ADRALN** indicates unaligned memory access in GLThread (OpenGL rendering thread).

**Likely Causes:**
1. **Godot rendering cleanup race condition** - Firebase operations complete, app auto-quits, but GLThread still accessing freed/moved memory during shutdown
2. **ARM64 alignment requirement violation** - GLThread attempting unaligned memory access (ARM64 strict alignment)
3. **Firebase SDK memory corruption** - SDK writes to memory that GLThread later accesses in misaligned way

**Critical Observations:**
- Crashes happen in **GLThread** (rendering), not Firebase thread
- Tests using **auto_quit: true** - crash may be during shutdown sequence
- Both crashes occur **after** Firebase operations complete successfully

### SIGSEGV Pattern (Main thread crash - NEW)

**SIGSEGV SEGV_MAPERR at 0x40** suggests null pointer dereference with offset.

**Likely Causes:**
1. **Test suite state accumulation** - Firebase SDK state from previous tests causes null pointer access
2. **Object lifetime issue** - Firebase object destroyed but still referenced (dangling pointer)
3. **Memory exhaustion** - Comprehensive suite depletes resources, causing allocation failures
4. **Shutdown race condition** - Different manifestation of auto-quit timing issue

**Critical Observations:**
- **Only crashes in comprehensive suite**, not individual runs (test-154, test-207 showed 100% success)
- Main thread crash (not GLThread) suggests different root cause than SIGBUS
- Fault address 0x40 = null pointer + 64 byte offset (typical object member access)
- Related to **task-216.01** (test suite isolation) and **task-215** (comprehensive test failures)

## Investigation Approach

### Phase 1: Evidence Gathering (30 min)
```bash
# Get full crash details from latest test (both SIGBUS and SIGSEGV)
just android-logs-search "SIGBUS\|SIGSEGV" | head -100

# Check crash timing vs test completion
just logs-text firebase-backend-batch-1_android_1760688404 "replay_complete\|auto_quit\|SIGBUS"
just logs-text firebase-two-actions-test_android_1760701504 "replay_complete\|auto_quit\|SIGSEGV"

# Look for similar crashes in history
rg "Fatal signal (7|11).*GLThread" logs/*.log | head -20
rg "Fatal signal 11.*SIGSEGV" logs/20251017_134504_test.log -B 10 -A 10

# Compare individual vs suite execution for firebase-two-actions-test
just test-android-target firebase-two-actions-test  # Individual run
just test  # Full suite - check if it crashes

# Check if other Firebase tests crash
just test-android firebase-cpp-layer
just android-logs-search "SIGBUS\|SIGSEGV"
```

### Phase 2: Narrowing Down (1 hour)
1. **Test without auto_quit**: Do crashes happen without auto_quit?
2. **Test with longer delay**: Add delay before auto_quit
3. **Check GLThread state**: Look for "ObjectDB instances leaked" warnings
4. **Firebase cleanup timing**: Check Firebase SDK cleanup vs app quit timing

### Phase 3: Root Cause Options (depends on findings)

**Option A: Auto-quit race condition**
- Crash disappears without auto_quit
- Fix: Add proper cleanup wait or delay before quit

**Option B: Memory alignment in Godot/Firebase**
- Crash persists regardless of auto_quit
- Fix: Requires C++ investigation in Firebase SDK or Godot engine

**Option C: Rendering cleanup issue**
- Related to visual scene cleanup during Firebase operations
- Fix: Ensure rendering thread completes before Firebase shutdown

## Related Tasks

- task-213: Firebase thread-safe singleton architecture (SIGBUS fixes)
- task-223: Previous SIGBUS investigation (may be related pattern)
- task-218: Coordinator startup synchronization (timing fixes)

**Note:** This may be a regression or new instance of previously fixed SIGBUS issues.

## Debug Commands

```bash
# Quick reproduction
just test-android firebase-backend-batch-1
just android-logs-search "SIGBUS"

# Detailed crash analysis
adb logcat -d | rg -i "fatal signal" -A 20 -B 5

# Check for memory corruption patterns
just android-logs-search "ObjectDB\|leaked\|freed"

# Test without auto_quit
# Manually edit firebase-backend-batch-1.json, remove auto_quit
just test-android firebase-backend-batch-1
```

## Acceptance Criteria

- [ ] Firebase backend tests complete without SIGBUS or SIGSEGV crashes
- [ ] `firebase-backend-batch-1` passes consistently (10/10 runs, individual and suite)
- [ ] `firebase-backend-layer` passes consistently (10/10 runs, individual and suite)
- [ ] `firebase-two-actions-test` passes consistently in comprehensive suite (10/10 runs)
- [ ] No crash signals detected in Android logcat after Firebase tests
- [ ] Auto-quit functionality works safely with Firebase operations
- [ ] Test suite isolation prevents state accumulation (task-216.01)
- [ ] No regression in other Firebase test configurations

## Evidence

### SIGBUS Crashes (Original)
**Source Log:** `logs/20251017_100644_test.log`
**Test Session:** `1760688404`
**Date:** 2025-10-17 10:11-10:14
**Configs:** firebase-backend-batch-1, firebase-backend-layer

### SIGSEGV Crash (NEW - Comprehensive Suite)
**Source Log:** `logs/20251017_134504_test.log`
**Test Session:** `1760701504`
**Date:** 2025-10-17 13:55:25
**Config:** firebase-two-actions-test
**Crash Details:**
```
10-17 13:55:25.788  9488  9488 F libc    : Fatal signal 11 (SIGSEGV), code 1 (SEGV_MAPERR), fault addr 0x40 in tid 9488 (aryhive.gametwo), pid 9488 (aryhive.gametwo)
```
