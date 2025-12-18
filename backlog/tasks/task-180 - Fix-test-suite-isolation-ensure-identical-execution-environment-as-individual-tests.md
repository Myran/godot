---
id: task-180
title: >-
  Fix test suite isolation - ensure identical execution environment as
  individual tests
status: Done
assignee: []
created_date: '2025-09-25 12:20'
updated_date: '2025-12-18 10:37'
labels:
  - testing
  - isolation
  - test-framework
  - architecture
  - critical
dependencies: []
priority: high
ordinal: 125000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
# Fix test suite isolation: ensure identical execution environment as individual tests

## Problem Statement

**CRITICAL**: Test suite execution creates different environment conditions than individual test execution, violating the fundamental principle that each test should run under identical conditions regardless of execution context.

## Root Cause Analysis

### **🔍 Investigation Results (2025-09-25)**

**Issue**: Tests behave differently when run in test suite vs individually, causing silent failures and inconsistent reporting.

**Evidence from battle-logic-only test**:

**Individual Execution**:
```bash
just test-android-target battle-logic-only
✅ 4 actions executed and reported:
  - game.debug.hide_debug_menu → DEBUG_TEST_SUCCESS
  - game.lineup.populate_enemy → DEBUG_TEST_SUCCESS
  - game.battle.test_determinism_logic_only → RESTART_NEEDED → DEBUG_TEST_SUCCESS
  - system.debug.replay_complete → DEBUG_TEST_SUCCESS
```

**Test Suite Execution** (after other tests):
```bash
just test-android system-layer-all && just test-android-target battle-logic-only
❌ 2 actions executed and reported (SILENT FAILURES):
  - game.debug.hide_debug_menu → DEBUG_TEST_SUCCESS
  - game.lineup.populate_enemy → Executes successfully → NO DEBUG_TEST_SUCCESS
  - game.battle.test_determinism_logic_only → Executes successfully → NO DEBUG_TEST_SUCCESS
  - system.debug.replay_complete → DEBUG_TEST_SUCCESS
```

### **🎯 Technical Root Cause**

**Shared Session State in Test Lists**:

```bash
# justfile-validation-enhanced-testing.justfile:1531
TEST_SESSION="$(date +%s)"  # SINGLE session ID for ALL tests in suite
```

**vs Individual Execution**: Each test gets unique timestamp session ID → Fresh environment

### **🔍 Environment Variable Impact**

Test suite execution sets:
```bash
INSIDE_TEST_LIST_EXECUTION=true just _execute-test-with-analysis "$config" "$PLATFORM" "$TEST_SESSION"
```

This changes execution behavior compared to individual tests which don't have this variable set.

### **📊 Impact Analysis**

1. **Silent Failures**: Tests execute but fail to generate proper `DEBUG_TEST_SUCCESS` logs
2. **State Contamination**: Previous tests affect subsequent test execution
3. **Inconsistent Reporting**: Same test reports different action counts (4 vs 2)
4. **False Positives**: Tests marked as "PASSED" despite silent failures
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Each test in a test suite MUST execute under identical conditions as when run individually
- [ ] #2 No shared session state between tests in a suite
- [ ] #3 Each test gets fresh environment isolation (app restart, cache clear, unique session ID)
- [ ] #4 DEBUG_TEST_SUCCESS logging must be consistent between individual and suite execution
- [ ] #5 Same test must report identical action counts regardless of execution context
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
✅ RESOLVED: Test suite isolation successfully implemented. Evidence from 20250926_155152_test.log shows each test running in unique process (PIDs: 63465, 64479, 67380, 68503, 69747) with fresh environment isolation, unique session IDs, and consistent action counts. All acceptance criteria met.
## Implementation Options

### **Option 1: Individual Session Per Test**
- Modify test suite execution to generate unique session ID per test
- Ensure full app restart and cache clearing between tests
- Remove shared state dependencies

### **Option 2: Enhanced Isolation Framework**
- Implement complete environment isolation per test
- Add validation to ensure execution parity
- Create test suite validation that compares individual vs suite results

### **Option 3: Hybrid Approach**
- Keep shared session for coordination but ensure isolation mechanisms
- Add pre/post test hooks for environment reset
- Implement state validation between tests

## Test Validation

**Before Fix**:
```bash
just test-android-target battle-logic-only  # 4 actions
just test-android system-layer-all && just test-android-target battle-logic-only  # 2 actions ❌
```

**After Fix** (Must Pass):
```bash
just test-android-target battle-logic-only  # 4 actions
just test-android system-layer-all && just test-android-target battle-logic-only  # 4 actions ✅
```

## Related Issues

- **Task-178**: Fix battle-logic-only test interference (symptom of this root cause)
- Test framework reporting inconsistencies
- Determinism test validation failures

## Priority Justification

**HIGH PRIORITY**: This breaks the fundamental testing principle of isolated execution environments, making test results unreliable and masking real issues. Affects overall test suite integrity and confidence in CI/CD pipeline results.

## Technical Context

- File: `/Users/mattiasmyhrman/repos/gametwo/justfiles/justfile-validation-enhanced-testing.justfile`
- Key functions: `_test-list-generic`, `_execute-test-with-analysis`
- Session management: Lines 1525-1533
- Test execution loop: Lines 1622-1679
<!-- SECTION:NOTES:END -->
