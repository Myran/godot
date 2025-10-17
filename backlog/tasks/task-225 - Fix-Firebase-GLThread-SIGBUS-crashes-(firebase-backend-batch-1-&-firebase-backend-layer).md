---
id: task-225
title: >-
  Fix Firebase GLThread SIGBUS crashes (firebase-backend-batch-1 &
  firebase-backend-layer)
status: To Do
priority: high
assignee: []
created_date: '2025-10-17 11:21'
updated_date: '2025-10-17 11:21'
labels:
  - firebase
  - crash
  - sigbus
  - android
  - glthread
  - production-critical
dependencies: []
---

## Description

**PRODUCTION CRITICAL**: Firebase backend tests crash with SIGBUS in GLThread on Android after successfully completing test actions.

### Crash Pattern

Two Firebase backend configs crash with identical SIGBUS pattern:
- **firebase-backend-batch-1**: SIGBUS at `10:11:31` in test run
- **firebase-backend-layer**: SIGBUS at `10:14:07` in test run

**Critical Detail**: Tests execute successfully (all actions PASSED) but crash during or after completion.

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

**Common Pattern:**
- Signal: SIGBUS (signal 7)
- Code: BUS_ADRALN (code 1) - Unaligned memory access
- Thread: GLThread (OpenGL rendering thread)
- Both fault addresses in similar range (0x87/88...000c19)

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

## Root Cause Hypothesis

**SIGBUS BUS_ADRALN** indicates unaligned memory access in GLThread (OpenGL rendering thread).

**Likely Causes:**
1. **Godot rendering cleanup race condition** - Firebase operations complete, app auto-quits, but GLThread still accessing freed/moved memory during shutdown
2. **ARM64 alignment requirement violation** - GLThread attempting unaligned memory access (ARM64 strict alignment)
3. **Firebase SDK memory corruption** - SDK writes to memory that GLThread later accesses in misaligned way

**Critical Observation:**
- Crashes happen in **GLThread** (rendering), not Firebase thread
- Tests using **auto_quit: true** - crash may be during shutdown sequence
- Both crashes occur **after** Firebase operations complete successfully

## Investigation Approach

### Phase 1: Evidence Gathering (30 min)
```bash
# Get full crash details from latest test
just android-logs-search "SIGBUS" | head -100

# Check crash timing vs test completion
just logs-text firebase-backend-batch-1_android_1760688404 "replay_complete\|auto_quit\|SIGBUS"

# Look for similar crashes in history
rg "Fatal signal 7.*GLThread" logs/*.log | head -20

# Check if other Firebase tests crash
just test-android firebase-cpp-layer
just android-logs-search "SIGBUS"
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

- [ ] Firebase backend tests complete without SIGBUS crashes
- [ ] `firebase-backend-batch-1` passes consistently (10/10 runs)
- [ ] `firebase-backend-layer` passes consistently (10/10 runs)
- [ ] No crash signals detected in Android logcat after Firebase tests
- [ ] Auto-quit functionality works safely with Firebase operations
- [ ] No regression in other Firebase test configurations

## Evidence

**Source Log:** `logs/20251017_100644_test.log`
**Test Session:** `1760688404`
**Date:** 2025-10-17 10:11-10:14
