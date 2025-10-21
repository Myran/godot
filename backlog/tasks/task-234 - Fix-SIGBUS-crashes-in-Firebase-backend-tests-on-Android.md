---
id: task-234
title: Fix SIGBUS crashes in Firebase backend tests on Android
status: In Progress
assignee: []
created_date: '2025-10-21 22:10'
labels:
  - critical
  - firebase
  - android
  - crash
  - sigbus
dependencies: []
priority: critical
---

## Description

Android Firebase backend tests are crashing with SIGBUS (Signal 7) fatal errors during or after test execution. The crashes occur in the GLThread, suggesting potential memory alignment or access issues related to graphics/rendering operations that happen concurrently with Firebase operations.

**Impact**: Prevents validation of Firebase backend layer functionality on Android.

## Affected Tests

- `firebase-backend-batch-1` - ❌ SIGBUS crash
- `firebase-backend-layer` - ❌ SIGBUS crash
- Other Firebase backend tests pass (batch-2, batch-3, cpp-layer, rtdb-layer, etc.)

## Error Details

### Crash 1: firebase-backend-batch-1
```
10-21 21:59:36.923 F libc: Fatal signal 7 (SIGBUS), code 1 (BUS_ADRALN), 
fault addr 0x87e6000c2a in tid GLThread, pid gametwo
```

### Crash 2: firebase-backend-layer
```
10-21 22:01:40.225 F libc: Fatal signal 7 (SIGBUS), code 1 (BUS_ADRALN), 
fault addr 0x893a000c2a in tid GLThread, pid gametwo
```

## Analysis

**SIGBUS (Bus Error)**: Indicates memory access alignment issues or accessing invalid memory addresses.

**Key Observations**:
1. **Tests pass functionally** - All actions execute successfully before crash
2. **Crash in GLThread** - Graphics/rendering thread, not Firebase thread
3. **Similar fault addresses** - Pattern suggests same root cause
4. **BUS_ADRALN code** - Unaligned memory access
5. **Only certain backend tests** - batch-1 and layer configs crash, others don't

**Hypotheses**:
1. **Memory corruption** - Firebase operations corrupting graphics memory
2. **Resource cleanup timing** - Race condition during app shutdown
3. **Thread synchronization** - Firebase and GL threads accessing shared memory
4. **Specific test actions** - batch-1 and layer configs trigger unique code paths

## Investigation Steps

- [ ] Compare firebase-backend-batch-1 vs batch-2/3 configs (what's different?)
- [ ] Compare firebase-backend-layer vs cpp-layer/rtdb-layer configs
- [ ] Check for memory barriers/atomic operations in Firebase backend code
- [ ] Review GLThread interactions during Firebase operations
- [ ] Check if crash happens during or after test completion
- [ ] Search for similar SIGBUS issues in project history (task-221, task-222, task-223)
- [ ] Use adb logcat to get full backtrace around crash
- [ ] Check if related to recent task-233 Signal/SignalAwaiter changes

## Quick Reproduction

```bash
# Run failing test to reproduce crash
just test-android firebase-backend-batch-1

# Get crash details
just android-logs-search "SIGBUS"
adb logcat -d | rg -i 'fatal signal'

# Check what makes batch-1 different from batch-2
diff tests/debug_configs/firebase-backend-batch-1.json \
     tests/debug_configs/firebase-backend-batch-2.json
```

## Related Context

**Task-233**: Just fixed Firebase cleanup and SignalAwaiter issues - verify these fixes didn't introduce the SIGBUS crashes (check if crashes existed before).

**Previous SIGBUS fixes**:
- task-221: Firebase memory barriers (SIGBUS related)
- task-222: Android checksum race conditions
- task-223: Firebase SIGBUS crashes

Check git history to see if SIGBUS crashes in these specific tests are new or pre-existing.

## Acceptance Criteria

- [ ] firebase-backend-batch-1 passes on Android without crashes
- [ ] firebase-backend-layer passes on Android without crashes  
- [ ] No SIGBUS errors in test logs
- [ ] All Firebase backend actions execute successfully
- [ ] Graphics thread remains stable during Firebase operations

## Priority Justification

**Critical**: SIGBUS crashes indicate potential memory corruption that could affect production stability. Even though tests pass functionally, crashes during shutdown suggest underlying issues that could manifest in other scenarios.
