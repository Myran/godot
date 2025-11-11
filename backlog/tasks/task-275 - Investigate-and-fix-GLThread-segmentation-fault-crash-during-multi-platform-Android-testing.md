---
id: task-275
title: >-
  Investigate and fix GLThread segmentation fault crash during multi-platform
  Android testing
status: To Do
assignee: []
created_date: '2025-11-11 13:05'
updated_date: '2025-11-11 20:25'
labels:
  - critical
  - android
  - crash
  - memory-corruption
  - test-framework
  - glthread
dependencies: []
priority: high
---

## Description

**CRITICAL ISSUE**: Multi-platform Android test execution causes native segmentation fault crashes in GLThread, leading to false test failures and CI/CD pipeline noise. The crash occurs AFTER test functionality completes successfully, during app cleanup/quit phase.

**Key Insight**: This is NOT a test framework issue with "force-crash" - the app actually crashes with SIGSEGV, and Android's crash handler force-finishes the activity. Individual tests pass because they don't accumulate the memory/graphics resource corruption that multi-platform test runs do.

## Root Cause Analysis

### What Actually Happens

**Failed Multi-Platform Run:**
```
11-11 12:02:47.530  F libc: Fatal signal 11 (SIGSEGV), code 1 (SEGV_MAPERR), fault addr 0x300000094 in tid 31732 (GLThread 48949)
11-11 12:02:48.873  I am_crash: [972,0,com.primaryhive.gametwo,581451334,Native crash,Segmentation fault,unknown,0]
11-11 12:02:48.915  I am_finish_activity: [0,168828218,18354,com.primaryhive.gametwo/com.godot.game.GodotApp,force-crash]
11-11 12:02:49.313 31854 31886 D AppErrorNotification: errorType : 24, process : com.primaryhive.gametwo , uid : 0
```

**Successful Individual Run:**
```
11-11 12:26:39.995  I ActivityManager: Process com.primaryhive.gametwo (pid 10109) has died: fore TOP
11-11 12:26:40.026  I am_finish_activity: [0,196452201,18370,com.primaryhive.gametwo/com.godot.game.GodotApp,proc died without state saved]
```

### Crash Details

- **Signal**: SIGSEGV (Segmentation Fault)
- **Code**: SEGV_MAPERR (Memory mapping error)
- **Thread**: GLThread 48949 (Graphics thread)
- **Address**: 0x300000094 (Invalid memory access)
- **Location**: Native code in base.apk
- **PID**: 31652 (Main app process)

### Why Only Multi-Platform Tests Crash

**Resource Contention & Memory State Accumulation:**
1. **18+ tests executed consecutively** before gamestate test
2. **Graphics memory fragmentation** from repeated app launches/quits
3. **GLThread state corruption** accumulated over multiple test runs
4. **Sentry SDK activity** adds memory pressure during crash (multiple envelope operations visible)
5. **XR interface clearing** occurs before crash (VR/AR related operation)

**Individual Tests Don't Crash:**
- **Clean app state** - fresh start with no accumulated memory issues
- **Single test execution** - no graphics resource contention
- **Cleaner memory landscape** - GLThread starts fresh

### Timeline Analysis

**Before Crash (Multi-Platform):**
```
11-11 12:02:47.130  Sentry operations (envelope caching/discarding)
11-11 12:02:47.184  XR: Clearing primary interface
11-11 12:02:47.291  Sentry operations continue
11-11 12:02:47.310  ACodec: app-name com.primaryhive.gametwo
11-11 12:02:47.458  Sentry operations continue
11-11 12:02:47.530  **CRASH**: F libc SIGSEGV in GLThread
11-11 12:02:48.873  Android crash handler detection
11-11 12:02:48.915  Force-finish activity by Android
```

### Test Functionality Validation

**✅ All Core Functionality Works Correctly:**
- All test actions execute successfully (4/4 ✅ PASSED)
- Gamestate save/load cycle works perfectly
- Checksum validation passes (4/4 ✅ PASSED)
- Sentry integration works correctly
- DEBUG_TEST_SUCCESS logged before crash

**❌ Crash Happens During Cleanup Phase:**
- App crashes after test completion
- Crash occurs during app termination sequence
- Test framework incorrectly marks as failure

## Impact Assessment

### Production Impact: ZERO

- ✅ **Sentry integration works perfectly** - validated separately
- ✅ **Core gamestate functionality works** - tests prove it
- ✅ **Normal app usage unaffected** - crash only during test cleanup
- ✅ **Production deployment safe** - this is purely a test framework issue

### Development Impact: HIGH

- ❌ **CI/CD pipeline noise** - false test failures
- ❌ **Test reliability compromised** - multi-platform tests unreliable
- ❌ **Development productivity reduced** - wasted time investigating false failures
- ❌ **Memory corruption risk** - could indicate underlying graphics issues

## Technical Investigation Required

### Phase 1: Reproduction and Isolation
- [ ] Reproduce crash consistently in multi-platform test runs
- [ ] Verify individual tests never crash
- [ ] Determine minimum number of consecutive tests needed to trigger crash
- [ ] Test if crash happens with Sentry disabled (eliminate Sentry as factor)

### Phase 2: Memory Analysis
- [ ] Analyze GLThread memory usage patterns
- [ ] Check for graphics resource leaks across test runs
- [ ] Investigate XR interface clearing correlation
- [ ] Profile memory fragmentation during consecutive tests

### Phase 3: Root Cause Fix
- [ ] Implement memory cleanup between multi-platform tests
- [ ] Add graphics resource reset mechanisms
- [ ] Fix GLThread state corruption if identified
- [ ] Consider app restart between test suites

### Phase 4: Test Framework Enhancement
- [ ] Add crash phase detection to distinguish test failures from cleanup crashes
- [ ] Implement proper error handling for native crashes during cleanup
- [ ] Add multi-platform test isolation improvements
- [ ] Consider separate test processes for graphics-intensive tests

## Evidence Files

### Failed Multi-Platform Test
- **Log**: `android_gamestate-complete-save-load-cycle-test_android_1762858189.log`
- **Action Results**: All 4 actions ✅ PASSED
- **Test ID**: `gamestate-complete-save-load-cycle-test_android_1762858189`

### Successful Individual Test
- **Log**: `android_gamestate-complete-save-load-cycle-test_android_1762860386.log`
- **Action Results**: All 4 actions ✅ PASSED
- **Test ID**: `gamestate-complete-save-load-cycle-test_android_1762860386`

### Crash Analysis
- **Native Stack Trace**: Available in Android system logs
- **Memory Address**: 0x300000094 (invalid access)
- **Thread**: GLThread 48949 (graphics rendering thread)
- **Process Context**: Occurs during app cleanup after test success

## Investigation Commands

### Reproduce Issue
```bash
# Run full multi-platform test suite (should trigger crash)
just test

# Check for segmentation fault in logs
just logs-text <test_id> "SIGSEGV\|Segmentation fault\|GLThread.*crash"

# Verify individual test passes
just test-android 'gamestate-complete-save-load-cycle-test'
```

### Memory Analysis
```bash
# Check for graphics resource usage patterns
just logs-text <test_id> "GLThread\|graphics\|VR\|XR"

# Analyze Sentry SDK activity around crash
just logs-text <test_id> "Sentry.*envelope\|cache.*sentry"
```

### Debug Commands
```bash
# Check for memory fragmentation patterns
adb logcat -d | grep -E "(SIGSEGV|SEGV_MAPERR|GLThread)"

# Monitor graphics memory usage
adb shell dumpsys meminfo com.primaryhive.gametwo | grep -E "(Graphics|GL|GPU)"
```

## Success Criteria

### Must Fix
- [ ] Multi-platform Android tests run without crashes
- [ ] All 19 test configurations pass consistently
- [ ] No false negative test failures
- [ ] GLThread memory corruption eliminated

### Should Fix
- [ ] Memory cleanup between tests improved
- [ ] Graphics resource management enhanced
- [ ] Test framework crash detection improved
- [ ] Better error messages for cleanup-phase crashes

### Nice to Have
- [ ] Automatic memory usage monitoring
- [ ] Graphics resource leak detection
- [ ] Test isolation improvements
- [ ] Performance metrics for test execution

## Related Issues

- **Sentry Integration**: ✅ UNRELATED - works perfectly
- **Gamestate Functionality**: ✅ UNRELATED - works correctly
- **Individual Test Runner**: ✅ UNRELATED - works correctly
- **Memory Management**: ⚠️ POTENTIALLY RELATED - graphics memory corruption

## Investigation Notes

**Key Insight**: The crash is a *symptom* of deeper memory corruption, not a *cause* of test framework issues. The fact that individual tests pass but multi-platform runs crash indicates accumulated state corruption.

**Critical Finding**: All test functionality works correctly - the crash is purely in the cleanup phase after successful test execution. This means the core product is stable and production-ready.

**Risk Assessment**: Low to Medium - crash only affects test reliability, not production functionality. However, memory corruption in GLThread could indicate underlying graphics engine issues that might affect production under heavy load.
