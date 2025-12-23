---
id: task-359
title: Fix iOS checksum extraction in test framework
status: Done
assignee: []
created_date: '2025-12-22 14:01'
updated_date: '2025-12-23 12:18'
labels:
  - test-framework
  - ios
  - checksum
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

The `_extract-checksums-unified` recipe fails during iOS test runs with "No checksums found in test logs".

## Evidence

From `20251222_104921_full-pipeline.log`:
```
📸 Checksum Validation:
======================
⚠️  Checksum extraction failed from iOS test log:
  error: Recipe `_extract-checksums-unified` failed with exit code 1
⚠️  No checksums found in test logs
This could indicate:
  • Test completed too quickly for checksum capture
  • SessionManager not logging checksums properly
  • Debug actions not being executed
```

## Impact

- iOS tests marked as failed due to checksum extraction issues
- `backend.firebase.async_pattern` on iOS affected
- Test framework reliability reduced

## Investigation Areas

1. Check if iOS logs are being captured correctly
2. Verify SessionManager checksum logging on iOS platform
3. Compare iOS log format with Android/desktop formats
4. Check timing of checksum capture vs test completion
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 iOS tests with checksum validation pass successfully
- [ ] #2 SEMANTIC_ACTION logs preserved after iOS log filtering
- [ ] #3 Checksums extracted correctly from iOS test logs
- [ ] #4 Parity with Android/desktop checksum extraction behavior
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## OODA Investigation - Session 2025-12-23

### OBSERVE Phase
**Evidence collected:**
1. From pipeline log `20251222_104921_full-pipeline.log`:
   - iOS logs ARE being extracted successfully (881-2666 lines raw)
   - But filtering reduces to only 20-77 lines (96-97% filtered out)
   - Error occurs during checksum extraction: `Recipe _extract-checksums-unified failed with exit code 1`

2. Affected tests:
   - `gamestate-complete-save-load-cycle-test_ios_1766398177`
   - `gamestate-save-load-test_ios_1766398177`

### ORIENT Phase
**Root cause identified:**

The `_extract-logs` iOS case (line 868-878 in `justfile-validation-enhanced-testing.justfile`) filters logs too aggressively:

```bash
grep "$TEST_ID" "$LOG_FILE" > "${LOG_FILE}.filtered"
```

This keeps ONLY lines containing the TEST_ID. However:
- `SEMANTIC_ACTION` logs (which contain `pre_action_checksum`) may not include TEST_ID directly
- The checksum extraction (`_extract-checksums-unified`) looks for `SEMANTIC_ACTION` patterns
- After filtering, these critical lines are removed → no checksums found

**Comparison with other platforms:**
- Android: Uses `adb logcat` directly, no aggressive filtering
- Desktop: Uses full temp output file, no filtering
- iOS: Aggressive TEST_ID filtering removes SEMANTIC_ACTION lines

### DECIDE Phase (In Progress)
Running test to verify hypothesis...

### DECIDE Phase - ROOT CAUSE CONFIRMED

**Live test verification (2025-12-23):**

```
just test-ios-target gamestate-save-load-test

Raw iOS logs captured:      974 lines
Filtered relevant logs:       28 lines
Result: "No checksums found in test logs"
```

**Evidence from raw log (`/tmp/ios_test_*.log`):**
- Contains `SEMANTIC_ACTION` entries with `pre_action_checksum`
- These lines do NOT contain the TEST_ID string
- Only 28 lines out of 974 contain the TEST_ID
- After filtering, all SEMANTIC_ACTION lines are removed

**Root Cause:**

In `justfile-validation-enhanced-testing.justfile` line 868-878:
```bash
# iOS logs are already clean from timestamped files - just filter for current TEST_ID
grep "$TEST_ID" "$LOG_FILE" > "${LOG_FILE}.filtered" 2>/dev/null
```

This aggressive filtering removes SEMANTIC_ACTION lines because they contain `session_id` (e.g., `session_20251223_114410_8a5df165`) but NOT the `TEST_ID` (e.g., `gamestate-save-load-test_ios_1766486616`).

### Proposed Solution

**Option A: Expand iOS filtering (Recommended)**
Keep lines containing TEST_ID OR SEMANTIC_ACTION:
```bash
grep -E "($TEST_ID|SEMANTIC_ACTION)" "$LOG_FILE" > "${LOG_FILE}.filtered"
```

**Option B: Match Android pattern**
Use same cross-platform filter as Android (line 822):
```bash
grep -E "($TEST_ID|{{CROSS_PLATFORM_TEST_BASE}})" | sort -u
```

**Option C: Skip filtering entirely**
IOS already gets clean timestamped logs - just use full log content.

### Impact
- All iOS tests with checksum validation are broken
- Affects: gamestate-*, any config with `checksum_config`

### ACT Phase - FIX IMPLEMENTED

**Fix applied (2025-12-23 13:15):**

In `justfile-validation-enhanced-testing.justfile` line 870-873:
```bash
# RESTORED: Use CROSS-PLATFORM TEST FILTER (shared with Android)
grep -E "($TEST_ID|{{CROSS_PLATFORM_TEST_BASE}})" "$LOG_FILE" | sort -u > "${LOG_FILE}.filtered"
```

**Verification:**
- Before fix: 0 SEMANTIC_ACTION entries in filtered log, "No checksums found"
- After fix: 4 SEMANTIC_ACTION entries preserved, checksums extracted successfully
- CI validation: ✅ PASSED

**Root cause summary:**
Commit `ec418688` (Nov 24, 2025) changed iOS from shared `CROSS_PLATFORM_TEST_BASE` filter to TEST_ID-only filter, breaking checksum extraction. The fix restores the shared code path for iOS/Android parity.

**Why it wasn't shared originally:**
The comment said "iOS logs are already clean from timestamped files - just filter for current TEST_ID" but this was incorrect - SEMANTIC_ACTION logs don't contain TEST_ID, so they were filtered out. Android uses the shared filter correctly.
<!-- SECTION:NOTES:END -->
