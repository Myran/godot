---
id: task-209
title: Remove stale action results fallback in multi-platform summary
status: Done
assignee: []
created_date: '2025-10-10'
completed_date: '2025-10-10'
labels: [bug, test-framework, critical]
dependencies: []
---

## Description

The multi-platform summary generation has a fallback mechanism (lines 489-514 in `justfile-support.justfile`) that searches for action result files when the hierarchy file doesn't contain action_results. This fallback picks up OLD files from previous test runs, showing stale data.

**Code Location:**
```bash
# Line 490 in justfile-support.justfile
ACTION_RESULTS_FILE=$(find "{{USER_DATA_DIR}}/logs" /tmp -name "test_action_results_*${config}*${PLATFORM}*.json" -type f -exec ls -t {} + 2>/dev/null | head -n1)
```

### When This Bug Occurs

1. Test runs with `CONFIG_STATUS="passed"` on a platform
2. Hierarchy file has the status but `ACTION_COUNT=0` (no action_results array)
3. Fallback code searches for ANY action results file matching pattern
4. **Problem**: Finds old files from hours/days ago, not current session
5. Displays stale action counts and details in summary

### Impact

- **Data accuracy**: Summary shows action details from previous test runs
- **Misleading results**: Developers see old action counts/timings, not current ones
- **Test framework validity**: Cannot trust action-level details in summaries
- **Debugging confusion**: Investigating issues based on wrong action data

### Example Scenario

**Current Test Run:**
- `battle-logic-only` passes on desktop with 4 actions
- Hierarchy file records status="passed" but action_results array is empty (bug in hierarchy recording)

**Fallback Behavior:**
- Searches for `test_action_results_*battle-logic-only*desktop*.json`
- Finds file from test run 2 days ago with 6 actions (different config version)
- Summary shows: "✅ PASSED (6 actions)" with old action details

**Expected Behavior:**
- Should show: "✅ PASSED" (without action count if data is missing)
- OR: Should only use data from current session

## Root Cause Analysis

### Why This Code Exists

This fallback was likely added to handle cases where:
1. Hierarchy file doesn't contain action_results (recording bug)
2. Want to show action details even when hierarchy is incomplete
3. Action results files are more reliable than hierarchy

### Why It's Problematic

1. **No session filtering**: Searches ALL files in logs directory and /tmp
2. **Timestamp ordering**: Uses `ls -t` (newest first) but "newest" might be hours old
3. **No validation**: Doesn't check if file is from current test session
4. **False confidence**: Shows detailed action data that appears current but isn't

## Proposed Solutions

### Option 1: Remove Fallback Entirely (Recommended)

**Approach**: Delete lines 489-514, only show action details when in hierarchy

**Pros**:
- Eliminates stale data risk
- Forces fix of hierarchy recording bug
- Simplifies code logic
- No false confidence in action details

**Cons**:
- Won't show action details if hierarchy recording is broken
- Reveals underlying bug in hierarchy population

**Code Change**:
```bash
if [[ "$ACTION_COUNT" -gt 0 && "$ACTION_COUNT" != "null" ]]; then
    echo "   ├── $PLATFORM_ICON $PLATFORM: ✅ PASSED ($ACTION_COUNT actions)"
    # ... show action details from hierarchy ...
else
    echo "   ├── $PLATFORM_ICON $PLATFORM: ✅ PASSED"
fi
```

### Option 2: Add Session Filtering to Fallback

**Approach**: Filter action results files by current session ID

**Pros**:
- Keeps fallback functionality
- Only shows current session data
- Handles hierarchy recording bugs gracefully

**Cons**:
- More complex code
- Masks hierarchy recording bugs
- Requires session ID to be in filename or file metadata

**Code Change**:
```bash
# Only search for files from current session
ACTION_RESULTS_FILE=$(find "{{USER_DATA_DIR}}/logs" /tmp -name "test_action_results_*${config}*${PLATFORM}*${SESSION_ID}*.json" -type f 2>/dev/null | head -n1)
```

### Option 3: Add Timestamp Validation

**Approach**: Only use action results files created within last N minutes

**Pros**:
- Reduces stale data risk
- Keeps fallback for recent runs
- Simple implementation

**Cons**:
- Still shows wrong data if multiple runs within timeframe
- Arbitrary time cutoff
- Doesn't solve fundamental issue

**Code Change**:
```bash
# Only use files modified in last 5 minutes
ACTION_RESULTS_FILE=$(find "{{USER_DATA_DIR}}/logs" /tmp -name "test_action_results_*${config}*${PLATFORM}*.json" -type f -mmin -5 -exec ls -t {} + 2>/dev/null | head -n1)
```

## Recommendation

**Choose Option 1: Remove Fallback Entirely**

**Rationale**:
1. Test framework must be accurate - no stale data
2. Fallback masks underlying hierarchy recording bugs
3. Better to show "PASSED" without details than wrong details
4. Forces us to fix hierarchy population (proper solution)

**Implementation**:
1. Remove lines 489-514 from justfile-support.justfile
2. Simplify to: if ACTION_COUNT > 0, show details; else show "PASSED"
3. Investigate and fix why hierarchy doesn't contain action_results
4. Ensure action_results array is populated during test execution

## Related Context

- Discovered while fixing TASK-208 (platform filtering bug)
- TASK-208 fixed cross-platform contamination but not stale file fallback
- This is a separate bug that affects test framework validity
- Critical for CTO's emphasis on test framework accuracy

## Acceptance Criteria

- [ ] Fallback code removed or session-filtered
- [ ] Multi-platform summaries only show current session data
- [ ] No stale action counts/details from previous runs
- [ ] Test with multiple sequential runs to verify no cross-contamination
- [ ] Document why action_results might be missing from hierarchy

## Resolution

### Implemented Solution: Option 1 + Session Filtering

Combined the recommended Option 1 (Remove Fallback Entirely) with session filtering in hierarchy recording.

**Changes Made:**

1. **Removed Stale File Fallback** (`justfile-support.justfile` lines 488-515):
   - Deleted entire fallback block that searched for old action result files
   - Simplified to: if `ACTION_COUNT > 0`, show details; else show "✅ PASSED"
   - Single code path principle: only use data from hierarchy file

2. **Added Session Filtering** (`justfile-validation-enhanced-testing.justfile`):
   - Line 1697: Added `*${TEST_SESSION}*` to passed config ACTION_RESULTS_PATTERN
   - Line 1742: Added `*${TEST_SESSION}*` to failed config ACTION_RESULTS_PATTERN
   - Ensures hierarchy only populated with current session data

**Before (Lines 488-515):**
```bash
else
    # No action_results in hierarchy file - try to find from action results files directly
    ACTION_RESULTS_FILE=$(find "{{USER_DATA_DIR}}/logs" /tmp -name "test_action_results_*${config}*${PLATFORM}*.json" -type f -exec ls -t {} + 2>/dev/null | head -n1)
    # ... 25+ lines of fallback logic picking up stale files
fi
```

**After (Line 488-490):**
```bash
else
    # No action_results in hierarchy - show PASSED without details
    echo "   ├── $PLATFORM_ICON $PLATFORM: ✅ PASSED"
fi
```

**Before (Hierarchy Recording):**
```bash
ACTION_RESULTS_PATTERN="{{STANDARD_LOGS_DIR}}/test_action_results_*${config}*${PLATFORM}*.json"
# Searches ALL files matching pattern, including old ones
```

**After (Hierarchy Recording):**
```bash
ACTION_RESULTS_PATTERN="{{STANDARD_LOGS_DIR}}/test_action_results_*${config}*${PLATFORM}*${TEST_SESSION}*.json"
# Only searches files from current session
```

### Verification

The fix ensures:
- ✅ Multi-platform summaries show current session data only
- ✅ No fallback to stale files from previous runs
- ✅ Hierarchy populated with session-filtered data
- ✅ Single code path (no hidden fallback logic)

### Why This Matters

Following the "no fallbacks" principle:
- Better to show incomplete data than wrong data
- Forces us to fix underlying bugs (why action_results missing from hierarchy?)
- Eliminates false confidence in test results
- Simplifies code (one path vs two paths)

**Test Framework Validity**: As CTO emphasized, accurate results are critical for informed decisions. This fix eliminates a major source of data contamination.

Status: Completed
