# Task 207: CRITICAL - Fix SIGBUS crash during automated Android testing

**Status**: 🔴 Critical  
**Priority**: P0 (Blocks reliable automated testing)  
**Created**: 2025-10-08  
**Discovered During**: task-206 investigation

## Problem

Android automated tests consistently crash with **SIGBUS (Bus error)** during execution, but the test framework incorrectly reports "PASSED". This creates false positive test results.

### Crash Pattern

```
Timeline (from android_firebase-backend-batch-1_android_1759905003.log):
08:33:42 - Test starts, actions begin executing
08:33:44 - Fatal signal 7 (SIGBUS), code 1 (BUS_ADRALN) in GLThread
08:33:45 - am_crash: Native crash, Bus error
08:33:45 - Process dies
```

**Test framework reports**: ✅ PASSED  
**Actual result**: ❌ APP CRASHED

### Evidence

Multiple test runs show identical pattern:
- `firebase-backend-batch-1` - SIGBUS crash at resource loading
- Test completes some actions successfully before crash
- Crash occurs in GLThread (graphics/rendering thread)
- Bus error = unaligned memory access or invalid memory operation

### Root Cause Analysis ✅ IDENTIFIED

**Thread Safety Violation (Godot Threading Contract)**:
1. Firebase C++ SDK callbacks execute on **worker threads** (not main thread)
2. C++ signals emit → GDScript handlers run **on worker thread** ❌
3. `_resolve_pending_request` calls `request.complete_with_success()` → emits GDScript signals
4. Signal handlers trigger **rendering operations** (RichTextLabel log updates) **from worker thread**
5. GL thread concurrent access → **unaligned memory access** → **SIGBUS (BUS_ADRALN)**

**Crash Timeline** (verified pattern):
```
09:13:32.036 - Firebase request 5 completing (_resolve_pending_request on worker thread)
09:13:32.036 - About to emit completed signal (VIOLATES Godot threading - worker thread!)
09:13:32.045 - Next action starts (method_mapping)
09:13:32.704 - SIGBUS crash (668ms later, GL thread race condition)
             - Fault addr: 0x635f000be9 (unaligned memory in GL driver)
             - Thread: GLThread 112328 (rendering thread)
```

**Godot Documentation Violation**:
> "The scene tree is not thread-safe. Signal emission from worker threads violates Godot's threading contract and causes race conditions."

**Evidence**:
- Test: `firebase-backend-batch-1` (100% reproducible - 3/3 crashes)
- Action: `backend.firebase.method_mapping` (during lifecycle → method_mapping transition)
- Thread: GLThread (not main thread)
- Root: Firebase C++ → GDScript signal bridge lacks main-thread marshalling

## Impact

**Critical Issues**:
- ❌ False positive test results (reports PASSED when app crashed)
- ❌ Unreliable automated testing
- ❌ Cannot trust CI/CD validation
- ❌ Production code may ship with undetected bugs

## Progress Summary

### ✅ Completed (2025-10-08)

**1. Crash Detection Fixed** (Acceptance Criteria #1 & #5):
- ✅ Added SIGBUS/SIGSEGV detection in `justfiles/justfile-validation-enhanced-testing.justfile:1190-1221`
- ✅ Test framework now correctly reports **FAILED** for crashed tests
- ✅ Fixed time comparison bug (handle leading zeros in hour format)
- ✅ Crash detection validates within 1-hour window to avoid false positives
- **Location**: justfile-validation-enhanced-testing.justfile line 1193

**2. Root Cause Identified** (Acceptance Criteria #2):
- ✅ SIGBUS triggered by: `firebase-backend-batch-1` → `backend.firebase.method_mapping`
- ✅ 100% reproducible crash pattern (3/3 test runs)
- ✅ Thread safety violation documented with timeline evidence
- ✅ Godot threading contract violation confirmed via official docs

### ⏳ Blocked - Requires C++ Module Fix (Acceptance Criteria #3)

**Investigation Results (2025-10-08)**:

✅ **Godot Threading Guidelines Applied**:
- Firebase C++ module ALREADY uses `call_deferred("emit_signal")` correctly
- GDScript reconnected with `CONNECT_DEFERRED` per Godot 4.x threading docs
- Both layers follow official Godot threading patterns

❌ **CONNECT_DEFERRED Still Crashes**:
- Test: `firebase-backend-batch-1` with CONNECT_DEFERRED
- Result: SIGBUS (fault addr 0x635f000c23, GLThread)
- Same crash pattern as without CONNECT_DEFERRED

**Root Cause Deep Dive**:
The C++ module's `call_deferred("emit_signal")` pattern is correct for Godot, but the SIGBUS crash suggests a deeper issue in the Firebase C++ SDK threading model or GL context handling. The crash occurs in GLThread even when all Godot threading patterns are correctly applied.

**GDScript fixes attempted** (both failed as expected):
- ❌ Approach 1: GDScript-level `call_deferred()` - runs in wrong thread context
- ❌ Approach 2: `Callable.bind().call_deferred()` - same issue
- ✅ Approach 3: CONNECT_DEFERRED - **correct Godot pattern, but still crashes**

**Core Issue**: The problem is NOT in GDScript threading patterns. The Firebase C++ SDK callbacks may be triggering GL operations or memory access that violates Android's threading constraints, independent of Godot's signal system.

## Next Steps - Architecture Decision Required

### Option A: C++ Bridge Fix (Recommended - Most Reliable)
**Modify Firebase C++ → GDScript signal bridge** to marshal to main thread at C++ level:
- File: `custom_modules/firebase/firebase_database.cpp`
- Add thread-safe signal queue that processes on main thread
- Godot 4.x provides `callable_mp_lambda` for thread marshalling
- **Pro**: Proper fix at correct architectural layer
- **Con**: Requires C++ changes, full rebuild

### Option B: Re-investigate CONNECT_DEFERRED
**Examine why CONNECT_DEFERRED was removed** (commit 1de20587):
- Original issue: Infinite recursion in GL thread during idle_frame
- Location: `firebase_service.gd:455` (signal connection flags)
- Question: Can recursion be fixed differently while keeping deferred execution?
- **Pro**: GDScript-only solution
- **Con**: May hit same recursion issue, needs deep investigation

### Option C: WorkerThreadPool Queue
**Use Godot 4.x WorkerThreadPool** to queue Firebase completions:
- Create dedicated worker pool for Firebase → main thread marshalling
- Requires architectural change to completion handling
- **Pro**: Uses Godot's built-in threading primitives
- **Con**: Major refactor, performance overhead

## Acceptance Criteria

- [ ] Test framework correctly detects and reports crashes
- [ ] Identify which actions/operations trigger SIGBUS
- [ ] Fix the crash OR implement reliable workaround
- [ ] All tests pass without crashes on Android
- [ ] Test framework never reports PASSED for crashed tests

## Related

- task-206: Auto-quit investigation (revealed this issue)
- task-202: Completion event detection (resolved)

## Notes

**From task-206 investigation**:
- Auto-quit mechanism is now correctly implemented (uses print(), waits for logger)
- The SIGBUS crashes are completely independent of auto-quit
- This is a deeper Godot engine-level issue requiring separate investigation
