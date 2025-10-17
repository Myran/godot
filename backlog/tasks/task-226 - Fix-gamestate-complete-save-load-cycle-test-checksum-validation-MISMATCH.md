---
id: task-226
title: Fix gamestate-complete-save-load-cycle-test checksum validation MISMATCH
status: To Do
priority: medium
assignee: []
created_date: '2025-10-17 11:26'
labels:
  - gamestate
  - checksum
  - validation
  - test-framework
  - determinism
dependencies: []
---

## Description

**TEST FRAMEWORK ISSUE**: `gamestate-complete-save-load-cycle-test` fails checksum validation on both desktop and Android despite all actions completing successfully. The test framework extracts 4 checksums but only validates 3, causing a MISMATCH failure.

### Failure Pattern

**Common to both platforms:**
- Config expects **4 checksums** (`SKIP_SYSTEM_DEBUG_CHECKSUM` x 4)
- Log extraction finds **4 checksums** from logs
- Validation table shows only **3 checksums**
- **4th checksum missing** from validation comparison
- Result: **❌ Checksum validation FAILED - MISMATCH**

### Platform-Specific Details

**Desktop (gamestate-complete-save-load-cycle-test_desktop_1760688404):**
```
Actions executed:
✅ system.debug.save_gamestate - PASSED (5ms)
✅ system.debug.load_gamestate - PASSED (118ms)
✅ system.debug.save_gamestate - PASSED (8ms)
✅ system.debug.replay_complete - PASSED (1ms)

Checksum validation:
📸 Extracted 4 checksums from logs
📋 Checksum table shows only 3:
| 1 | checksum_validation | SKIP_SYSTEM_... | SKIP_SYSTEM_... | ✅ |
| 2 | checksum_validation | SKIP_SYSTEM_... | SKIP_SYSTEM_... | ✅ |
| 3 | checksum_validation | SKIP_SYSTEM_... | SKIP_SYSTEM_... | ✅ |
(4th checksum missing from table)

❌ Checksum validation FAILED - MISMATCH
```

**Android (gamestate-complete-save-load-cycle-test_android_1760688404):**
```
Actions executed:
✅ system.debug.save_gamestate - PASSED (23ms)
❌ system.debug.load_gamestate - MISSING from results table
✅ system.debug.save_gamestate - PASSED (56ms)
✅ system.debug.replay_complete - PASSED (2ms)

Checksum validation:
📸 Extracted 4 checksums from logs
📋 Checksum table shows only 3 (same pattern as desktop)

❌ Checksum validation FAILED - MISMATCH
```

**Critical Observation:**
- All checksums shown in table are ✅ PASS
- Missing 4th checksum causes MISMATCH
- Android also missing `load_gamestate` action from results (but test passed)

## Root Cause Hypothesis

**Test Framework Bug** in checksum validation logic:

**Primary Hypothesis:**
The 4th checksum corresponds to `system.debug.replay_complete` action, which may have special handling in the validation framework that causes it to be:
1. Extracted from logs (shows "Extracted 4 checksums")
2. But skipped during validation table generation
3. Resulting in count mismatch: 4 expected vs 3 validated

**Supporting Evidence:**
- Config lists `replay_complete` as 4th action after 2 saves + 1 load
- Config has 4 expected checksums (all `SKIP_SYSTEM_DEBUG_CHECKSUM`)
- `replay_complete` may be treated as "non-checksum" action in validation logic
- Framework explicitly expects 4 but only shows 3 in comparison

**Alternative Hypothesis:**
The validation framework has off-by-one error or array indexing issue:
- Extracts all 4 checksums correctly
- But stops iteration at index 2 (3rd item) instead of 3 (4th item)
- Missing checksum #4 causes validation failure

## Investigation Approach

### Phase 1: Locate Validation Code (15 min)
```bash
# Find checksum validation logic
rg "Extracted.*checksums" justfiles/ -A 20 | head -100
rg "Checksum-to-Action Mapping" justfiles/ -A 30 | head -100
rg "Checksum validation FAILED" justfiles/ -B 30 | head -100

# Check replay_complete special handling
rg "replay_complete" justfiles/ | rg "checksum\|validation" -i
```

### Phase 2: Understand Validation Logic (30 min)
1. **Find where checksums are extracted** from logs
2. **Find where validation table is generated** (the 3-row table)
3. **Find where count comparison happens** (4 expected vs actual)
4. **Check if `replay_complete` is excluded** from checksum validation

### Phase 3: Fix Options (depends on findings)

**Option A: replay_complete should NOT have checksum**
- Fix config: Remove 4th expected checksum
- Config should have 3 checksums for 3 checksum-generating actions
- `replay_complete` marked as non-checksum action

**Option B: replay_complete SHOULD have checksum**
- Fix validation logic: Include `replay_complete` in validation table
- Ensure all 4 checksums compared properly
- Fix iteration/indexing bug

**Option C: load_gamestate checksum missing (Android)**
- Android missing `load_gamestate` from results
- This could be why 4th checksum validation fails
- Fix: Investigate why Android `load_gamestate` not in results

## Related Files

**Config:**
- `tests/debug_configs/gamestate-complete-save-load-cycle-test.json`

**Validation Framework:**
- `justfiles/justfile-validation-enhanced-testing.justfile` - Checksum validation logic
- Search for: "Extracted.*checksums", "Checksum-to-Action Mapping", "MISMATCH"

**Related Test:**
- `gamestate-save-load-test` - Similar test, check if it passes or has same issue

## Debug Commands

```bash
# Quick reproduction
just test-desktop gamestate-complete-save-load-cycle-test
just test-android gamestate-complete-save-load-cycle-test

# Check related test
just test-desktop gamestate-save-load-test
just test-android gamestate-save-load-test

# Manual validation
# 1. Check config structure
cat tests/debug_configs/gamestate-complete-save-load-cycle-test.json | jq

# 2. Check how many actions should generate checksums
rg "checksum_validation" tests/debug_configs/gamestate-complete-save-load-cycle-test.json

# 3. Test with different checksum count
# Edit config: Change expected_checksums to array of 3 instead of 4
```

## Acceptance Criteria

- [ ] `gamestate-complete-save-load-cycle-test` passes on desktop (10/10 runs)
- [ ] `gamestate-complete-save-load-cycle-test` passes on Android (10/10 runs)
- [ ] All 4 checksums validated if config expects 4, or config updated to expect 3
- [ ] Checksum validation table shows correct number of checksums
- [ ] No MISMATCH errors when actual matches expected
- [ ] `load_gamestate` action appears in Android results table
- [ ] Validation logic clearly handles `replay_complete` checksum (or lack thereof)

## Evidence

**Source Log:** `logs/20251017_100644_test.log`
**Test Session:** `1760688404`
**Date:** 2025-10-17 10:08 (desktop), 10:08 (android)
**Status:** Both platforms failed with identical MISMATCH pattern
