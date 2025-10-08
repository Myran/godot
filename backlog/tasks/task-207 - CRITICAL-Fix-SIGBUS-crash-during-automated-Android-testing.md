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

### Root Cause Analysis

**What we know**:
1. Crash is in Godot engine's GLThread (not GDScript)
2. Bus error (SIGBUS) indicates memory alignment issue
3. Occurs during automated test execution
4. NOT related to auto-quit mechanism (verified in task-206)
5. Test framework doesn't detect the crash (logs show crash but test reports PASSED)

**What we suspect**:
- Resource loading bug in Godot engine
- Possible threading issue during automated test mode
- Memory corruption in graphics/rendering subsystem
- May be specific to certain actions or resource types

## Impact

**Critical Issues**:
- ❌ False positive test results (reports PASSED when app crashed)
- ❌ Unreliable automated testing
- ❌ Cannot trust CI/CD validation
- ❌ Production code may ship with undetected bugs

## Investigation Needed

### 1. Crash Detection
- Why does test framework report PASSED when app crashes?
- Need to check process exit status or crash indicators
- May need to parse logcat for crash signals

### 2. Root Cause
- Which specific actions trigger the crash?
- Is it resource loading, graphics operations, or something else?
- Can we reproduce on desktop or only Android?
- Is it related to test automation or happens in manual testing too?

### 3. Workarounds
- Can we disable certain graphics features during automated tests?
- Should we add crash detection to test framework?
- Is there a Godot engine fix/patch available?

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
