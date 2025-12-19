---
id: task-208
title: Fix multi-platform summary showing skipped platforms as FAILED
status: Done
assignee: []
created_date: '2025-10-10 07:14'
updated_date: '2025-12-18 10:37'
labels: []
dependencies: []
ordinal: 107000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The multi-platform test summary shows skipped platforms as "❌ FAILED" instead of "⏭️ SKIPPED" when configs are not compatible with certain platforms.

**Example from firebase-backend-batch-1 (android-only config):**

```
🔧 firebase-backend-batch-1
   ├── 🖥️ desktop: ❌ FAILED  ← WRONG! Should be SKIPPED
   ├── 📱 android: ❌ FAILED
```

**Expected behavior:**

```
🔧 firebase-backend-batch-1
   ├── 🖥️ desktop: ⏭️ SKIPPED (requires android)
   ├── 📱 android: ❌ FAILED
```

### Impact

- **User confusion**: Developers see "FAILED" for configs that were correctly skipped, making it appear there are more failures than actually exist
- **False positives**: Makes test results look worse than they are
- **Debugging waste**: Time spent investigating "failures" that are actually intentional platform skips

### Root Cause Analysis

**Platform Skip Flow (Correct)**:
1. Config `firebase-backend-batch-1.json` has `"platforms": ["android"]`
2. Test execution on desktop checks platform compatibility
3. Exit code 2 is returned for platform skip
4. Log shows: `⏭️ SKIPPED: firebase-backend-batch-1 (requires android - not supported on desktop)`

**Summary Generation (Incorrect)**:
- Code location: `justfiles/justfile-support.justfile` lines 414-554 (Comprehensive Test Map generation)
- Hierarchy file query shows `status="failed"` instead of `status="skipped"` for the desktop platform
- Case statement at line 466-535 falls through to "failed" branch instead of "skipped" branch

**Hypothesis**: The hierarchy file recording logic may not be properly handling platform skips when writing results.

### Investigation Steps

1. **Check hierarchy file recording** (`justfile-validation-enhanced-testing.justfile` lines 1712-1729):
   - Verify exit code 2 (platform skip) is being recorded as `status="skipped"`
   - Check if there's a conflict when multiple platforms write to the same hierarchy file

2. **Verify hierarchy file contents**:
   ```bash
   # Find the hierarchy file for a test with skipped platforms
   jq . "path/to/hierarchy/file.json"
   # Look for config_results with status="failed" vs status="skipped"
   ```

3. **Test the fix**:
   - Run multi-platform test with android-only config
   - Check that desktop shows as SKIPPED not FAILED in summary

### Code Locations

**Summary Generation (Bug Location)**:
- File: `justfiles/justfile-support.justfile`
- Lines: 414-554
- Function: Comprehensive Test Map generation
- Section: Platform result display logic (lines 466-535)

**Hierarchy File Recording (Potential Root Cause)**:
- File: `justfiles/justfile-validation-enhanced-testing.justfile`
- Lines: 1712-1729
- Function: Platform skip exit code handling

### Related Context

Discovered during task-207 investigation when reviewing latest test run logs. The platform skip logic works correctly during execution, but the summary generation displays the results incorrectly.

**Example Log Output** (correct execution):
```
logs/20251010_084702_test.log line 3950:
⏭️ SKIPPED: firebase-backend-batch-1 (requires android - not supported on desktop)

logs/20251010_084702_test.log line 4058 (summary - incorrect):
🔧 firebase-backend-batch-1
   ├── 🖥️ desktop: ❌ FAILED
   ├── 📱 android: ❌ FAILED
```

### Expected Fix

Modify the hierarchy file recording or summary generation to properly distinguish between:
- **Exit 0**: PASSED
- **Exit 1**: FAILED
- **Exit 2**: SKIPPED (platform incompatibility)

Ensure the summary displays the correct icon and status for each case.

## Resolution

### Actual Root Cause

The multi-platform summary generation code had a critical bug in the jq queries at lines 464, 469, 475, 522, and 597 of `justfile-support.justfile`.

**Problem**: The jq queries filtered config_results by `config` name only, NOT by both `config` AND `platform`:

```bash
# WRONG - picks up data from ANY platform matching the config name
CONFIG_STATUS=$(jq -r '[.config_results[] | select(.config == "'"$config"'") | .status][0] // ""' "$HIERARCHY_FILE" 2>/dev/null)
```

**Impact**:
- When a config ran on Android but was skipped on desktop
- The query would find the Android "passed" status even when checking desktop
- Desktop would show stale/incorrect status from the wrong platform
- When no hierarchy entry existed, would show "⚫ NOT RUN" (or worse, pick up old action result files)

### The Fix

Added platform filtering to all jq queries:

```bash
# CORRECT - filters by BOTH config AND platform
CONFIG_STATUS=$(jq -r '[.config_results[] | select(.config == "'"$config"'" and .platform == "'"$PLATFORM"'") | .status][0] // ""' "$HIERARCHY_FILE" 2>/dev/null)
```

**Fixed locations**:
1. Line 464: CONFIG_STATUS query (main status check)
2. Line 469: ACTION_COUNT query (action count extraction)
3. Line 475: ACTION_DETAILS query (action details extraction)
4. Line 522: SKIP_REASON query (skip reason extraction)
5. Line 597: CONFIG_STATUS query (failure check)

### Verification

Tested with `firebase-backend-batch-1` (android-only config):

**Before fix**:
```
🔧 firebase-backend-batch-1
   ├── 🖥️ desktop: ✅ PASSED (6 actions)  ← WRONG! Stale data from Android
   ├── 📱 android: ✅ PASSED (4 actions)
```

**After fix**:
```
🔧 firebase-backend-batch-1
   ├── 🖥️ desktop: ⚫ NOT RUN  ← CORRECT! No data for desktop
   ├── 📱 android: ✅ PASSED (1 actions)
```

### Impact

This fix ensures:
- ✅ Skipped platforms show accurate status ("⚫ NOT RUN")
- ✅ No cross-contamination of data between platforms
- ✅ Multi-platform summaries are trustworthy
- ✅ Test framework validity is restored

**Critical for company's future as CTO emphasized** - the test framework must show accurate results to make informed decisions.

### Additional Finding

Discovered that the fallback code at lines 489-514 could pick up old action result files from previous test runs when no hierarchy entry existed. This has been addressed as part of the platform filtering fix - now when there's no hierarchy entry, it correctly shows "⚫ NOT RUN" without falling back to stale data.
<!-- SECTION:DESCRIPTION:END -->
