---
id: task-150
title: Fix Firebase C++ SDK native crash in error handling tests
status: To Do
assignee: []
created_date: '2025-09-15 22:34'
updated_date: '2025-09-15 22:35'
labels:
  - critical
  - firebase
  - native-crash
  - android
  - error-handling
  - testing
dependencies: []
priority: high
---

## Description
--------------------------------------------------
**CRITICAL**: Firebase C++ SDK crashes with native SIGABRT during error handling tests, preventing action collection and causing test failures.

**Root Cause Discovery**: Investigation into task-147 "regression" revealed the actual issue is a Firebase C++ SDK native crash, not action collection or wildcard expansion problems.

**Native Crash Details**:
- Fatal signal 6 (SIGABRT) in `firebase::database::internal::QueryInternal::GetValue()+540`
- Crash occurs ~20 seconds after invalid path error testing begins
- Triggered by testing empty path `[]` in Firebase RTDB operations
- App terminates before DEBUG_TEST_SUCCESS messages can be logged

**Impact**:
- `system-error-handling`: 0 actions collected (native crash prevents completion)
- `battle-logic-only`: 0 actions collected (likely same Firebase crash root cause)
- Both configurations appear as "action collection failures" but are actually native crashes

**Investigation Evidence**:
- ✅ Wildcard expansion works correctly (`*.*.error_handling` finds 3 actions)
- ✅ Actions start and execute properly
- ✅ Firebase backend initializes successfully
- ✅ Task-149 await fix still in place and working
- ❌ Native crash in Firebase C++ SDK terminates execution

**Timeline**:
1. Actions discovered and dispatched correctly
2. `backend.firebase.error_handling` starts execution
3. Firebase error handling test begins with invalid path `[]`
4. ~20 seconds later: Native crash in `QueryInternal::GetValue()`
5. App terminates, no completion logs generated

Acceptance Criteria:
--------------------------------------------------
- [ ] #1 system-error-handling test completes without native Firebase crashes
- [ ] #2 battle-logic-only test completes without native Firebase crashes
- [ ] #3 Firebase error handling tests use safe patterns to avoid C++ SDK instability
- [ ] #4 Cross-platform testing confirms fix works on both Android and Desktop
- [ ] #5 All 3 error_handling actions (backend, cpp, rtdb) complete successfully
- [ ] #6 DEBUG_TEST_SUCCESS messages logged for all completed actions

Technical Notes:
--------------------------------------------------
**Firebase C++ SDK Crash Stack Trace**:
```
Fatal signal 6 (SIGABRT), code -1 (SI_QUEUE) in tid 9782
firebase::database::internal::QueryParams::operator==(firebase::database::internal::QueryParams const&) const+328
firebase::database::internal::QueryInternal::EndAt(firebase::Variant)+852
firebase::database::internal::QueryInternal::GetValue()+540
```

**NOT a regression from recent changes**:
- Commit a6346b40 (task 146-147 fix) only removed checksum validation
- Commit 02b36760 (task-145 fix) only added `set_data` before `get_data` in performance tests
- No code changes that would cause Firebase C++ SDK crashes

**Investigation Methodology**:
Used Advanced OODA Loop Debugging approach with evidence-first investigation that prevented false fixes to working systems.

Implementation Notes:
--------------------------------------------------
**Potential Solutions**:
1. **Path Validation**: Add Firebase path validation before SDK calls
2. **Error Boundary**: Wrap Firebase operations in try-catch with graceful fallback
3. **SDK Version**: Investigate if Firebase C++ SDK version regression
4. **Test Pattern**: Modify error handling tests to avoid problematic patterns

**Related Tasks**:
- Supersedes: task-147 (originally misdiagnosed as action collection issue)
- Related: task-149 (investigation task that helped identify this pattern)
- Related: task-146 (companion action collection issue with different root cause)

**Priority Justification**:
Native crashes are critical severity as they prevent entire test categories from functioning and could impact production stability.