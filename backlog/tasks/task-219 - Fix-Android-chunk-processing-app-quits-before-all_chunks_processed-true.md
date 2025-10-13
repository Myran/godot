---
id: task-219
title: 'Fix Android chunk processing - app quits before all_chunks_processed: true'
status: To Do
assignee:
  - me
created_date: '2025-10-13 17:58'
labels: []
dependencies: []
parent_task_id: task-216
priority: high
---

## Description

Android tests show persistent `"all_chunks_processed": false` with `"final_chunk_count": 2` warnings in logs, indicating the app may be quitting before Android's internal logging mechanism properly flushes all log chunks. While Task-216.01 fixed the immediate issue of missing DEBUG_TEST_SUCCESS logs, the underlying chunk processing mechanism needs investigation.

## Problem Statement

After each DEBUG_TEST_SUCCESS log, the following pattern appears:
```
[INFO] Android chunk processing completed via signal { "final_chunk_count": 0, "all_chunks_processed": true }
[INFO] Android chunk processing completed via signal { "final_chunk_count": 2, "all_chunks_processed": false }
```

This suggests:
1. Android's logging has a multi-chunk architecture
2. Some chunks are not being fully processed before app quit
3. The app may be terminating too quickly after action completion

## Current Behavior

**Observed Pattern** (consistent across all tests):
- Action executes successfully
- DEBUG_TEST_SUCCESS log appears in logcat ✅
- Chunk processing reports: `all_chunks_processed: true` (first)
- Chunk processing reports: `all_chunks_processed: false, final_chunk_count: 2` (second)
- App quits via auto_quit mechanism

**Impact**:
- Currently: Logs are captured successfully (Task-216.01 fix working)
- Potential risk: If chunk processing affects log reliability, future tests could fail
- Uncertainty: What happens to the 2 unprocessed chunks?

## Reproduction

Run any automated Android test and check logs for chunk processing:

```bash
# Test with 2 actions
just test-android-target gamestate-save-load-test

# Check logs for chunk processing
TEST_ID=gamestate-save-load-test_android_TIMESTAMP
rg "all_chunks_processed" "~/Library/Application Support/Godot/app_userdata/gametwo/logs/android_${TEST_ID}.log"
```

**Expected**: `"all_chunks_processed": true` for all chunk processing signals
**Actual**: Mixed - `true` followed by `false` with `final_chunk_count: 2`

## Evidence

### Test 1: gamestate-save-load-test (1760375558)
```
19:12:47.739 DEBUG_TEST_SUCCESS { sequence: 1 } ✅
19:12:47.791 all_chunks_processed: true
19:12:47.821 all_chunks_processed: false, final_chunk_count: 2 ⚠️
19:12:47.822 DEBUG_TEST_SUCCESS { sequence: 2 } ✅
19:12:47.828 all_chunks_processed: true
19:12:47.828 all_chunks_processed: false, final_chunk_count: 2 ⚠️
```

### Test 2: gamestate-complete-save-load-cycle-test (1760375639)
```
19:14:06.668 DEBUG_TEST_SUCCESS { sequence: 1 } ✅
19:14:06.878 all_chunks_processed: true
19:14:06.908 all_chunks_processed: false, final_chunk_count: 2 ⚠️
19:14:06.910 DEBUG_TEST_SUCCESS { sequence: 2 } ✅
[Pattern repeats for sequences 3 and 4]
```

### Test 3: firebase-two-actions-test (1760375664)
Same pattern observed across all 4 actions.

## Root Cause Hypothesis

**Primary Theory**: App quit timing issue
- `auto_quit: true` triggers immediate app termination after final action
- Android's logging system needs time to flush chunks
- App quits before chunk processing completes

**Alternative Theories**:
1. Chunk architecture is normal - some chunks are intentionally delayed/batched
2. GDScript logger implementation doesn't wait for chunk signals
3. Android logcat buffering behavior with rapid app termination

## Investigation Steps

1. **Understand Chunk Architecture**:
   - Search GDScript codebase for chunk processing implementation
   - Identify what "chunk" means in logging context
   - Determine if `final_chunk_count: 2` indicates a problem

2. **Test Timing Hypothesis**:
   - Add delay before auto_quit
   - Monitor if chunks complete with extra time
   - Compare manual quit vs auto_quit behavior

3. **Trace Chunk Lifecycle**:
   - Find where chunk processing signals originate
   - Understand the signal flow
   - Identify if app should wait for chunk completion

4. **Platform Comparison**:
   - Check if desktop has similar chunk processing
   - Compare Android-specific logging code
   - Identify Android-specific constraints

## Acceptance Criteria

- [ ] Understand what log chunks are and why they fail to process
- [ ] Determine if `all_chunks_processed: false` is actually a problem
- [ ] If it's a problem: App waits for chunk processing before quit
- [ ] If it's not a problem: Document why and close as expected behavior
- [ ] All automated tests show `all_chunks_processed: true` consistently
- [ ] No regression in test execution time

## Related

- Parent: task-216 (Firebase SIGBUS Android logging investigation)
- Prerequisite: task-216.01 (Test isolation fix - completed)
- Context: Task-216.01 fixed immediate log capture, this addresses underlying mechanism
