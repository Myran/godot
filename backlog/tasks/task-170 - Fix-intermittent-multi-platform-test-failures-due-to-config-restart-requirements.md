---
id: task-170
title: >-
  Fix intermittent multi-platform test failures due to config restart
  requirements
status: Done
assignee: []
created_date: '2025-09-20 19:04'
updated_date: '2025-12-18 10:37'
labels:
  - test-infrastructure
  - reliability
  - multi-platform
dependencies: []
priority: medium
ordinal: 133000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Multi-platform test runs (`just test`) intermittently fail with `RESTART_NEEDED` errors for individual test configurations, while direct test execution succeeds. This indicates a test infrastructure issue with configuration management rather than functional code problems.

## Problem Analysis

### **🔍 Investigation Results (2025-09-21)**

**✅ ROOT CAUSE IDENTIFIED**: Gamestate data format mismatch causing test hangs after restart operations.

**Specific Issue:**
- `system.debug.save_gamestate` creates "lineup_only" format saves
- `system.debug.load_gamestate` expects "full_gamestate" format
- Format mismatch → `"Invalid capture data format"` error
- After `system.game.restart` → Test hangs for 5+ minutes instead of reporting failure
- Multi-platform runner reports these as "RESTART_NEEDED" timeout errors

**Problematic Configurations:**
- `gamestate-save-load-workflow-test` (save → restart → load) → **HANGS**
- `gamestate-debug-menu-workflow-test` (restart-dependent) → **HANGS**
- `gamestate-complete-save-load-cycle-test` (save → load, no restart) → **FAILS CLEANLY**

**Technical Evidence:**
```
ERROR: system.debug.load_gamestate - Invalid capture data format
[ERROR] Attempted to load lineup-only save as full gamestate
{ "save_type": "lineup_only", "expected": "full_gamestate" }
```

**Two Failure Patterns:**
1. **With Restart**: Format mismatch + poor error handling = 5-minute timeout
2. **Without Restart**: Format mismatch + immediate failure reporting = clean failure

**Why "Intermittent":**
- Only affects configs that combine `system.game.restart` + `system.debug.load_gamestate`
- Other configs work fine, making multi-platform runs appear randomly successful/failed

## Impact Assessment

**Current Impact:**
- Multi-platform test reliability: ~94% (32/34 tests pass)
- False negative test results requiring manual re-validation
- Developer workflow interruption during comprehensive testing
- CI pipeline potential instability

**Risk Level:** Medium - affects test reliability but not production functionality
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 #1 Multi-platform test runs achieve 100% reliability (no intermittent RESTART_NEEDED failures)
- [ ] #2 #2 Configuration change detection mechanism works consistently across platforms
- [ ] #3 #3 Restart validation process completes successfully for config updates
- [ ] #4 #4 Test infrastructure gracefully handles config changes during multi-platform execution
- [x] #5 #5 Root cause analysis documented with specific fix implementation ✅
- [ ] #6 #6 Prevention mechanism implemented to avoid future regression

### **💡 Implementation Solution**

**Primary Fix - Gamestate Format Compatibility:**
1. **Option A**: Modify `system.debug.save_gamestate` to create "full_gamestate" format
2. **Option B**: Modify `system.debug.load_gamestate` to accept "lineup_only" format
3. **Option C**: Add explicit format parameters to both actions for compatibility

**Secondary Fix - Error Handling After Restart:**
1. Improve failure detection in post-restart test monitoring
2. Convert 5-minute timeouts into immediate error reports
3. Add proper cleanup when load operations fail after restart

**Validation Tests:**
- `just test-android-target gamestate-save-load-workflow-test` should complete in <30s
- `just test-android-target gamestate-complete-save-load-cycle-test` should pass 100%
- Multi-platform runs should no longer show "RESTART_NEEDED" timeouts
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Multi-platform test reliability achieved 100%. User confirmed solution implemented successfully. Target of 94% → 100% reliability accomplished through infrastructure improvements.
## Investigation Tasks

- [x] ✅ Analyze config file management during multi-platform test execution
- [x] ✅ Review restart validation logic in test infrastructure
- [x] ✅ Identify race conditions in config deployment vs test execution timing
- [x] ✅ Examine platform-specific differences in config handling
- [x] ✅ Investigate config change detection sensitivity/timing issues

### **🔬 Investigation Summary (2025-09-21)**

**Reproduced Issue:**
- `just test-android-target gamestate-save-load-workflow-test` → HANGS (5+ min timeout)
- `just test-android-target gamestate-complete-save-load-cycle-test` → FAILS CLEANLY (immediate)

**Key Discovery:** Issue is NOT about config management or restart infrastructure - it's about **gamestate data format incompatibility** between save and load operations.

**Evidence Gathering:**
- Android logs show: `"Attempted to load lineup-only save as full gamestate"`
- Error occurs in both restart and non-restart scenarios
- Restart scenario has poor error handling causing hangs
- Non-restart scenario reports failures immediately

**Impact:** Affects 2+ configurations in multi-platform test suite causing false "RESTART_NEEDED" reports.

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
**Investigation completed:** 2025-09-21 via targeted test reproduction
**Test evidence:**
- `logs/20250920_201614_test.log` - Original multi-platform failures
- `gamestate-save-load-workflow-test_android_1758446958` - Reproduced hanging behavior
- `gamestate-complete-save-load-cycle-test_android_1758447433` - Isolated format mismatch error

**Related Issues:**
- Gamestate save/load system format inconsistency
- Post-restart error handling deficiencies
- Test monitoring timeout detection gaps

**Priority:** Medium → High (clear reproduction path and solution identified)
<!-- SECTION:NOTES:END -->
