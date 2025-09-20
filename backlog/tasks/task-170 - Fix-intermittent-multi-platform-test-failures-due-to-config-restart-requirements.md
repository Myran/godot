---
id: task-170
title: >-
  Fix intermittent multi-platform test failures due to config restart
  requirements
status: To Do
assignee: []
created_date: '2025-09-20 19:04'
updated_date: '2025-09-20 19:04'
labels:
  - test-infrastructure
  - reliability
  - multi-platform
dependencies: []
priority: medium
---

## Description

Multi-platform test runs (`just test`) intermittently fail with `RESTART_NEEDED` errors for individual test configurations, while direct test execution succeeds. This indicates a test infrastructure issue with configuration management rather than functional code problems.

## Problem Analysis

**Symptoms:**
- Multi-platform test shows: `❌ Failed: 2` (battle-logic-only on both platforms)
- Error logs show: `DEBUG_TEST_RESTART_NEEDED` with `reason: "config_updated"`
- Direct test execution: `just test-android-target battle-logic-only` ✅ PASSES
- Direct test execution: `just test-desktop-target battle-logic-only` ✅ PASSES

**Root Cause:**
Test infrastructure detects configuration file changes during multi-platform execution and requires restart validation, but the restart mechanism fails intermittently.

**Evidence:**
- Test ID: battle-logic-only_desktop_1758392174 shows `RESTART_NEEDED`
- Test ID: battle-logic-only_android_1758392174 shows same issue
- Both tests pass 100% when run individually with fresh config deployment

## Impact Assessment

**Current Impact:**
- Multi-platform test reliability: ~94% (32/34 tests pass)
- False negative test results requiring manual re-validation
- Developer workflow interruption during comprehensive testing
- CI pipeline potential instability

**Risk Level:** Medium - affects test reliability but not production functionality

## Acceptance Criteria

- [ ] #1 Multi-platform test runs achieve 100% reliability (no intermittent RESTART_NEEDED failures)
- [ ] #2 Configuration change detection mechanism works consistently across platforms
- [ ] #3 Restart validation process completes successfully for config updates
- [ ] #4 Test infrastructure gracefully handles config changes during multi-platform execution
- [ ] #5 Root cause analysis documented with specific fix implementation
- [ ] #6 Prevention mechanism implemented to avoid future regression

## Investigation Tasks

- [ ] Analyze config file management during multi-platform test execution
- [ ] Review restart validation logic in test infrastructure
- [ ] Identify race conditions in config deployment vs test execution timing
- [ ] Examine platform-specific differences in config handling
- [ ] Investigate config change detection sensitivity/timing issues

## Success Metrics

**Before Fix:**
- Multi-platform test reliability: ~94% (32/34 pass rate)
- Manual re-validation required for false negatives

**After Fix:**
- Multi-platform test reliability: 100% (or >99%)
- No manual re-validation needed for config-related failures
- Consistent behavior between multi-platform and direct test execution

## Related Context

**Discovered during:** Timer abuse pattern cleanup (task-118) validation
**Functional verification:** Direct tests pass 100%, confirming code changes are correct
**Test logs:** Available in logs/20250920_201614_test.log for detailed analysis
