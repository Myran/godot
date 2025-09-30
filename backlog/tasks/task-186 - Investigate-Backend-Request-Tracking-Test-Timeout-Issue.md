---
id: task-186
title: Investigate Backend Request Tracking Test Timeout Issue
status: To Do
assignee: []
created_date: '2025-09-30 07:59'
labels: [testing, firebase-backend, timeout, investigation]
dependencies: []
priority: High
---

## Description

During TASK-185 Phase 3 conversion work, the `backend.firebase.request_tracking` action was successfully converted to use TestUtils pattern. However, Android automated testing revealed a potential timeout issue:

**Observed Behavior:**
- Test execution shows `✅ PASSED` status overall
- Action starts executing properly (logs show "Testing Firebase Backend request tracking...")
- Firebase operations complete successfully (logs show "DatabaseService: set_data completed successfully")
- Test appears to complete, but only shows `system.debug.replay_complete` in action execution summary
- No PASSED/FAILED status message found in logs for the actual backend.firebase.request_tracking action
- Test may be timing out while waiting for all async operations to complete

**Context from TASK-185:**
- Converted 2 Backend actions: `backend_request_tracking_test_action.gd` and `backend_timer_manager_test_action.gd`
- Both now use TestUtils.time_operation(), TestUtils.make_test_key(), TestUtils.make_test_value()
- All CI validation passed (format, lint, syntax, runtime)
- Fastbuild-android deployment successful
- Firebase operations are executing and completing at the low level
- Issue appears to be in test result reporting or async operation completion signaling

**Test Evidence:**
- Test ID: `backend.firebase.request_tracking_android_1759219066`
- Log file: `android_backend.firebase.request_tracking_android_1759219066.log`
- Firebase operations completing: "DatabaseService: set_data completed successfully"
- No test result message: No "Request Tracking test PASSED" or "FAILED" found in logs

## Reproduction Commands

```bash
# 1. Ensure latest GDScript changes deployed to Android
just fastbuild-android

# 2. Run the specific test that shows timeout behavior
just test-android-target backend.firebase.request_tracking

# 3. Check for completion status in logs
just logs-text backend.firebase.request_tracking_android_TESTID "Request Tracking test"

# 4. Check if PASSED/FAILED message exists
just logs-text backend.firebase.request_tracking_TESTID "PASSED"
just logs-text backend.firebase.request_tracking_TESTID "FAILED"

# 5. Verify Firebase operations are completing
just logs-text backend.firebase.request_tracking_TESTID "completed successfully"

# 6. Check for any timeout indicators
just logs-errors backend.firebase.request_tracking_TESTID

# 7. Alternative: Run timer_manager action (similar pattern, may have same issue)
just test-android-target backend.firebase.timer_manager
```

**Log Analysis Commands:**
```bash
# Check full Android logs for initialization issues (not just test results)
just android-logs-search "backend.firebase.request_tracking"

# Check for timing issues in async operations
just logs-pattern TESTID "*.timeout"

# Verify TestUtils.time_operation() is working correctly
just logs-text TESTID "time_operation"
```

## Affected Files

- `project/debug/actions/firebase_backend/backend_request_tracking_test_action.gd`
- `project/debug/actions/firebase_backend/backend_timer_manager_test_action.gd`
- `project/misc/test_utils.gd` (TestUtils.time_operation helper)
- `project/misc/test_constants.gd` (LOG_TAGS, ERROR_CODES)

**Conversion Pattern Used:**
```gdscript
# Old pattern (multiple lines):
var start_time: int = Time.get_ticks_msec()
var result: bool = await test_backend_async_pattern(...)
var duration: int = Time.get_ticks_msec() - start_time

# New pattern (using TestUtils):
var op: Dictionary = await TestUtils.time_operation(
    "operation_name",
    func() -> Variant:
        return await test_backend_async_pattern(...)
)
var duration: int = TestUtils.get_duration_ms(op)
var result: bool = op.result
```

## Investigation Steps

### Phase 1: Verify Async Behavior
1. **Compare with Pre-Conversion Behavior:**
   - Check git history for original test behavior: `git log --oneline --grep="backend" | head -20`
   - Find last successful test run before conversion
   - Compare log patterns between old and new implementation

2. **Desktop vs Android Comparison:**
   ```bash
   # Test on Desktop first (faster iteration)
   just test-desktop-target backend.firebase.request_tracking
   just logs-text DESKTOP_TESTID "Request Tracking test"

   # Compare Desktop vs Android behavior
   # Desktop may show different async completion timing
   ```

3. **TestUtils.time_operation() Lambda Behavior:**
   - Verify lambda functions properly capture await results
   - Check if `func() -> Variant` return type works correctly with async operations
   - Consider if lambda introduces timing issues with Firebase signals

### Phase 2: Action Execution Flow
1. **Check Action Result Reporting:**
   ```bash
   # Look for DebugActionResult creation
   just logs-text TESTID "make_success_result"
   just logs-text TESTID "make_failure_result"

   # Check if action completes _execute_action_logic
   just logs-text TESTID "_execute_action_logic"
   ```

2. **Verify Result Object Returns:**
   - Confirm `TestUtils.make_success_result()` returns proper DebugActionResult
   - Check if result reaches action completion handler
   - Verify `_update_status()` calls complete before return

3. **Sequential Operation Completion:**
   ```bash
   # Backend request_tracking has 3 sequential test sections
   just logs-text TESTID "sequential_request_tracking"
   just logs-text TESTID "rapid_request_handling"
   just logs-text TESTID "request_signal_helper_pattern"
   ```

### Phase 3: Root Cause Analysis
**Hypothesis 1: Lambda Async Issue**
- Lambda functions may not properly propagate await completion
- Test: Temporarily revert one operation to old pattern, compare behavior

**Hypothesis 2: Result Creation Timing**
- `TestUtils.make_success_result()` called before all operations finish
- Test: Add explicit logging before/after result creation

**Hypothesis 3: Test Infrastructure Issue**
- Android automated testing may have different completion detection
- Test: Run same test in manual mode (without auto_quit)

**Hypothesis 4: Log Chunk Splitting**
- Success message may be split across log chunks on Android
- Test: Search for partial strings: "Request Tracking" separately from "PASSED"

## Acceptance Criteria

- [ ] Identify root cause of missing "Request Tracking test PASSED/FAILED" message in logs
- [ ] Verify TestUtils.time_operation() works correctly with Firebase async operations
- [ ] Confirm all 3 test sections (sequential, rapid, pattern) complete successfully
- [ ] Validate action returns proper DebugActionResult to test infrastructure
- [ ] Test passes with clear PASSED/FAILED status in logs
- [ ] Document any timing considerations for TestUtils with async Firebase operations
- [ ] Verify timer_manager action (similar pattern) also works correctly

## Priority Justification

**High Priority** because:
1. Affects TASK-185 Phase 3 mass conversion (58 remaining actions)
2. TestUtils pattern needs validation before converting remaining actions
3. Silent failures or timeouts could mask real issues
4. Backend actions are critical path for Firebase integration testing
5. Pattern will be used across all remaining Backend and RTDB actions

## Related Tasks

- **TASK-185**: Simplify Debug Actions System Through Simple GDScript Utilities (parent task)
- Backend request_tracking and timer_manager actions recently converted
- Pattern applies to 12 remaining RTDB actions awaiting conversion
