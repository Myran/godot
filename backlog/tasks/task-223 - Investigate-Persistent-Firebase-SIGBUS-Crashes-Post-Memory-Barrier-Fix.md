---
id: task-223
title: Investigate Persistent Firebase SIGBUS Crashes Post Memory Barrier Fix
status: Open
assignee: []
created_date: '2025-10-15 19:50'
updated_date: '2025-10-15 19:50'
labels:
  - critical
  - firebase
  - sigbus
  - memory-alignment
  - cpp-sdk
  - glthread
dependencies:
  - task-221
priority: high
---

## Description

**Firebase SIGBUS crashes persist after memory barrier fix (task-221)**. These crashes are a **separate issue** from the ARM64 memory ordering problem that was successfully resolved.

**Key Finding**: Memory barriers are working perfectly (42/42 executed successfully), but SIGBUS crashes continue due to **misaligned memory access** in Firebase C++ SDK, NOT memory ordering.

---

## Current Status

### Task-221 Resolution: ✅ COMPLETE

**Memory barriers validated across multiple scenarios:**
- ✅ 42 memory barriers executed successfully
- ✅ 14 Firebase requests completed with perfect barrier execution
- ✅ Zero memory ordering failures
- ✅ Zero await hangs on completed requests
- ✅ Production ready for deployment

**Commit**: a271fdb5 - "fix(firebase): Replace implicit memory barriers with explicit synchronization"

### Ongoing SIGBUS Crashes: ❌ SEPARATE ISSUE

**From latest full test suite** (logs/20251015_192324_test.log):
- ❌ `firebase-backend-batch-1`: SIGBUS crash (Android)
- ❌ `firebase-backend-layer`: SIGBUS crash (Android)
- ✅ Other Firebase tests: 10/12 passed (83%)

**Test Suite Impact**:
- 22% Android Firebase test failure rate
- 4/18 total Android test failures (2 Firebase SIGBUS, 2 checksum collection)

---

## SIGBUS Crash Analysis

### Crash Pattern (Consistent Across Tests)

**Test 1: firebase-backend-batch-1**
```
Fatal signal 7 (SIGBUS), code 1 (BUS_ADRALN), fault addr 0x86d9000c1b
Thread: GLThread 233757
```

**Test 2: firebase-backend-layer** (from task-221 validation)
```
Fatal signal 7 (SIGBUS), code 1 (BUS_ADRALN), fault addr 0x881c000c1e
Thread: GLThread 232122
```

**Test 3: firebase-heavy-sigbus-test** (stress test)
```
Fatal signal 7 (SIGBUS), code 1 (BUS_ADRALN), fault addr 0x8de0000bee
Thread: GLThread 233197
```

### Memory Alignment Analysis

**Crash Addresses**:
1. `0x86d9000c1b` → ends in `1b` ❌ (NOT 8-byte aligned)
2. `0x881c000c1e` → ends in `1e` ❌ (NOT 8-byte aligned)
3. `0x8de0000bee` → ends in `ee` ❌ (NOT 8-byte aligned)

**For 8-byte alignment**, addresses must end in `0` or `8`.

**Conclusion**: These are **memory alignment violations**, not memory ordering issues.

---

## Critical Evidence: Memory Barriers Working

### From firebase-backend-layer Test

**Firebase Requests Completed Successfully** (4/7 before crash):
```
Request 1: ✅ 381ms - All 3 barriers executed
  - complete_with_success called
  - _safe_copy_variant completed (BARRIER #1)
  - Result dict created (BARRIER #2)
  - _is_completed set (BARRIER #3)
  - Signal emitted, await resumed

Request 3: ✅ Completed - All barriers executed
Request 4: ✅ Completed - All barriers executed
Request 5: ✅ < 1ms - All barriers executed
```

**Failed Requests**:
```
Request 2: ❌ Never completed (Firebase C++ callback lost)
Request 6: ⏸️ Awaited just before crash
```

### From firebase-heavy-sigbus-test

**Firebase Requests Completed Successfully** (6 before crash):
```
Request 1: ✅ complete_with_success (payload_type: 28)
           ✅ _is_completed set, about to emit signal

Request 2: ✅ complete_with_success (payload_type: 28)
           ✅ _is_completed set, about to emit signal

Request 3-6: ✅ All completed with barriers
```

**Crash Timing**: ~45 seconds after last successful operation

---

## Root Cause Analysis

### Why This is NOT Memory Ordering

**Evidence**:
1. ✅ All completed requests show perfect barrier execution (42/42)
2. ✅ No await hangs on completed requests
3. ✅ No memory ordering race conditions
4. ✅ Signal emission and await resumption work correctly
5. ❌ Crash addresses are misaligned (alignment issue, not ordering)
6. ❌ Crashes occur in GLThread during cleanup, NOT during Firebase operations
7. ❌ Crash timing is ~45 seconds (typical timeout period)

### Why This IS Alignment/Firebase C++ SDK Issue

**Evidence**:
1. ❌ Crash addresses NOT 8-byte aligned
2. ❌ Crashes in GLThread (graphics thread), not main thread
3. ❌ Crashes during cleanup phase (~45s after operations)
4. ❌ Some Firebase C++ callbacks never arrive (Request 2, etc.)
5. ❌ Pending requests left in `_pending_requests` dictionary

**Hypothesis**:
```
1. Firebase C++ SDK returns misaligned memory for some requests
2. Request callbacks lost → requests stay in _pending_requests
3. After 45 seconds, timeout cleanup triggers
4. GLThread attempts to access misaligned memory during cleanup
5. SIGBUS (BUS_ADRALN) crash occurs
```

---

## Detailed Crash Timeline

### firebase-backend-layer (7 actions)

**Successful Operations** (first 3 actions):
```
17:56:03.349 - Request 1 await starts
17:56:03.730 - Request 1 completes ✅ (381ms, barriers executed)
17:56:03.732 - Request 2 await starts
17:56:04.707 - Request 3 completes ✅ (barriers executed)
17:56:05.010 - Request 4 completes ✅ (barriers executed)
17:56:05.014 - Request 5 completes ✅ (< 1ms, barriers executed)
17:56:05.204 - Request 6 await starts
```

**Crash** (~45 seconds later):
```
... [~45 seconds timeout period] ...
17:56:50.069 - SIGBUS crash in GLThread (cleanup phase)
```

**Key Observations**:
- Request 2 never completed (Firebase C++ callback lost)
- 4 other requests completed successfully with barriers
- Crash NOT during Firebase operations, but during cleanup
- Timing suggests timeout-related cleanup issue

---

## Investigation Required

### Phase 1: Firebase C++ Callback Analysis

**Questions**:
1. Why do some Firebase C++ callbacks never arrive? (Request 2)
2. Is there a Firebase C++ SDK request limit?
3. Are callbacks being silently dropped?
4. Is there a threading issue in Firebase C++ SDK?

**Investigation Steps**:
```bash
# Check Firebase C++ SDK logs
just android-logs-search "firebase.*callback\|firebase.*signal"

# Look for request ID patterns
just android-logs-search "request_id.*2"

# Check for Firebase C++ errors
just android-logs-search "firebase.*error\|firebase.*fail"
```

### Phase 2: Misaligned Memory Source

**Questions**:
1. Where does Firebase C++ SDK allocate memory?
2. Is `_safe_copy_variant()` creating aligned copies?
3. Are there alignment requirements for ARM64?
4. Is GLThread accessing Firebase data during cleanup?

**Investigation Steps**:
```gdscript
# Add alignment verification in _safe_copy_variant()
func _safe_copy_variant(source: Variant) -> Variant:
    var copy = source.duplicate(true)

    # Verify alignment (if possible in GDScript)
    var address = get_instance_id()  # Proxy for memory location
    Log.debug("Variant copy created", {
        "source_type": typeof(source),
        "copy_type": typeof(copy),
        "instance_id": address
    })

    return copy
```

### Phase 3: Cleanup Code Analysis

**Questions**:
1. What happens during timeout cleanup?
2. Does GLThread access `_pending_requests`?
3. Are there threading issues in cleanup code?
4. Is there a proper synchronization during cleanup?

**Investigation Steps**:
```bash
# Review cleanup code
rg "cleanup\|timeout\|_pending_requests" project/firebase/

# Check GLThread interactions
rg "GLThread\|RenderingServer" project/firebase/

# Review Firebase shutdown sequence
just android-logs-search "firebase.*shutdown\|firebase.*cleanup"
```

---

## Relationship to Task-152

### Task-152 Status: Done (2025-09-19)

**Task-152 claimed to resolve**:
- Firebase C++ SDK memory corruption
- Bus error crashes in multi-operation tests
- Firebase callback handling issues

**Evidence from task-152**:
```
✅ firebase-backend-layer test: 5/5 actions passed
✅ Multi-operation Firebase tests: No Bus error crashes
✅ Test suite success rate: 21/21 tests passed (100%)
```

### Current Reality: SIGBUS Crashes Continue

**From latest test run (2025-10-15)**:
```
❌ firebase-backend-batch-1: SIGBUS crash
❌ firebase-backend-layer: SIGBUS crash
```

**Possible Explanations**:
1. **Regression**: Recent changes reintroduced the issue
2. **Incomplete Fix**: Task-152 fixed symptoms, not root cause
3. **Different Issue**: Current SIGBUS crashes have different root cause
4. **Environmental**: Different test environment or configuration

**Action Required**: Re-open task-152 or determine if this is a new issue.

---

## Proposed Investigation Plan

### Priority 1: Determine If This Is Same Issue as Task-152 (1-2 hours)

**Steps**:
1. Review task-152 resolution commits (commits mentioned in task-152)
2. Check if any recent changes could have regressed
3. Compare current SIGBUS crashes to task-152 patterns
4. Determine if task-152 should be re-opened

**Decision Point**: Re-open task-152 OR continue with task-223 as new issue.

### Priority 2: Firebase C++ Callback Investigation (2-4 hours)

**Steps**:
1. Add detailed logging for Firebase C++ callback arrivals
2. Track request ID patterns (which callbacks arrive vs lost)
3. Investigate Firebase C++ SDK request limits
4. Check for threading issues in Firebase C++ SDK

**Goal**: Understand why some callbacks never arrive.

### Priority 3: Memory Alignment Investigation (4-6 hours)

**Steps**:
1. Add alignment verification in `_safe_copy_variant()`
2. Check Firebase C++ SDK memory allocation patterns
3. Review ARM64 alignment requirements
4. Investigate GLThread memory access during cleanup

**Goal**: Identify source of misaligned memory.

### Priority 4: Cleanup Code Review (2-4 hours)

**Steps**:
1. Review timeout cleanup implementation
2. Check GLThread interactions with Firebase data
3. Verify synchronization during cleanup
4. Add defensive null checks in cleanup code

**Goal**: Prevent crashes during cleanup even if memory is misaligned.

---

## Success Criteria

### Acceptance Criteria

- [ ] Understand why Firebase C++ callbacks are lost (Request 2, etc.)
- [ ] Identify source of misaligned memory
- [ ] Determine relationship to task-152
- [ ] Propose concrete fix for SIGBUS crashes
- [ ] Validate fix: `firebase-backend-layer` passes 10/10 runs

### Validation Tests

```bash
# Test firebase-backend-batch-1 (10 runs)
for i in {1..10}; do
    just test-android-target firebase-backend-batch-1
done

# Test firebase-backend-layer (10 runs)
for i in {1..10}; do
    just test-android-target firebase-backend-layer
done

# Check results: Should be 20/20 PASSED
```

---

## Business Impact Assessment

### Current Risk: ⚠️ **MEDIUM-HIGH**

**22% Android Firebase test failure rate:**
- Production Firebase operations may crash
- User data operations at risk
- Cannot fully validate Firebase functionality on Android

**Mitigating Factors**:
- 83% of Firebase tests passing (10/12)
- Memory barriers working correctly (prevents await hangs)
- Issue appears in batch/heavy operations, not simple requests

### Risk If Not Fixed: ⚠️ **HIGH**

**Production implications**:
- App crashes during batch Firebase operations
- User data loss if crash during save
- Support costs from crash reports
- Reputation damage

---

## Related Tasks and Documents

### Related Tasks

- **task-221**: ✅ DONE - Firebase await heisenbug (memory barriers working)
- **task-152**: ✅ DONE (claimed) - Firebase C++ SDK memory corruption (may need re-opening)
- **task-222**: 🔄 OPEN - Android checksum collection race condition

### Analysis Documents

- `/tmp/task221_comprehensive_validation_summary.md` - Multi-scenario validation proving memory barriers work
- `/tmp/task221_sigbus_analysis.md` - First SIGBUS crash analysis showing separation from memory ordering
- `/tmp/cto_full_test_suite_analysis.md` - CTO-level assessment of test framework validity
- `logs/20251015_192324_test.log` - Full test suite run showing current failures

### Code Locations

- `project/firebase/firebase_request.gd` - Request completion with memory barriers
- `project/firebase/firebase_service.gd` - Firebase service with `_pending_requests`
- Firebase C++ SDK - Godot submodule (external dependency)

---

**Priority Justification**: **HIGH** - While memory barriers work correctly, 22% Firebase test failure rate indicates production stability risk. Issue is separate from task-221 but equally important for production deployment.

**Created**: 2025-10-15 19:50
**Dependencies**: Task-221 (completed)
**Status**: Open - Investigation required
