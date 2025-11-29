---
id: task-320
title: Fix iOS log rotation TEST_ID mismatch in test list mode
status: Done
assignee: []
created_date: '2025-11-28 15:33'
updated_date: '2025-11-28 15:42'
labels:
  - critical
  - ios
  - testing
  - test-framework
dependencies:
  - task-317
  - task-319
---

## Description

iOS test lists fail because log retrieval gets STALE log files containing previous test's TEST_ID instead of current test's TEST_ID, causing "No log file found containing TEST_ID" errors.

**Impact:** Test lists with multiple configs fail at 0% success rate even though tests execute successfully.

## Problem

When running iOS test lists (multiple configs), the test framework:
1. Uninstalls app after each config
2. Reinstalls app for next config
3. **BUT** log files persist across app uninstall
4. Godot rotates old `godot.log` on app startup
5. Log retrieval gets old/stale `godot.log` instead of current test's logs

## Root Cause Analysis

**Test Flow in Test List Mode:**

```
Config 1: firebase-three-actions-test
├─ App starts → Writes logs to godot.log (TEST_ID: xxx_1764332043)
├─ Test completes → godot.log contains TEST_ID xxx_1764332043
├─ App quits
└─ App uninstalled → ⚠️ Log files persist on device!

Config 2: firebase-two-actions-test
├─ App reinstalled
├─ App starts → Godot's RotatedFileLogger triggers:
│   ├─ Renames OLD godot.log → godot2025-11-28T13.14.20.log (contains old TEST_ID)
│   └─ Creates NEW empty godot.log
├─ Test starts → Writes logs with NEW TEST_ID (xxx_1764336011) to NEW godot.log
└─ ❌ Log retrieval happens TOO EARLY:
    ├─ Retrieves log directory BEFORE new logs written
    └─ Finds old godot.log (contains TEST_ID xxx_1764332043, not xxx_1764336011)
```

**Evidence from Failed Test:**

```bash
# Test expects:
🔍 Required TEST_ID: firebase-three-actions-test_ios_1764336011

# But retrieved log contains:
[INFO] DEBUG_TEST_SUCCESS { "test_id": "firebase-three-actions-test_ios_1764332043", ... }

# Log file timestamps:
-rw-r--r--  369K Nov 28 13:14 godot.log  # OLD log from previous test
-rw-r--r--  5.7M Nov 28 13:14 godot2025-11-28T13.14.20.log  # Rotated old log
```

**Key Insight:** The problem is NOT buffer flush (task-319 solved that) - it's that we're retrieving logs from the WRONG generation of the log file.

## Why This Doesn't Affect Single Config Tests

Single config tests work because:
- App installed fresh (no previous logs)
- No log rotation on first startup
- `godot.log` contains correct TEST_ID

## Why This Is Different from task-317

- **task-317**: Log rotation DURING test (large files being copied)
- **task-320**: Log rotation BETWEEN tests (previous test's logs persisting)

## Why This Is Different from task-319

- **task-319**: Logs buffered in memory, not flushed to disk (SOLVED ✅)
- **task-320**: Logs ARE flushed and written, but TEST_ID mismatch due to stale files

## Proposed Solutions

### Option 1: Delete Old Logs Before Each Test (Simple)

Clear device logs before starting each test:

```bash
# In _execute-test-ios, before app launch
xcrun devicectl device copy from \
    --device "$IOS_DEVICE_ID" \
    --source "Documents/logs/" \
    --destination "/tmp/backup_logs_$$" \
    --domain-type appDataContainer \
    --domain-identifier "{{IOS_BUNDLE_IDENTIFIER}}"

# Delete logs directory on device
# (iOS doesn't have a direct delete command, so reinstall deletes app data)
```

**Pros:**
- Clean slate for each test
- No stale logs
- Simple logic

**Cons:**
- Loses historical logs for debugging
- Requires additional device operations

### Option 2: Search Rotated Logs By Timestamp (Robust)

Instead of searching for TEST_ID in files, use file modification time:

```bash
# Get test start timestamp
TEST_START_TIME=$(date +%s)

# After test completes, find logs created AFTER test started
LATEST_LOG=$(find "$IOS_LOG_DIR" -name "godot*.log" -type f -newermt "@$TEST_START_TIME" -exec grep -l "$TEST_ID" {} \; 2>/dev/null | head -1)

# Fallback: If no new logs, search by most recent modification
if [[ -z "$LATEST_LOG" ]]; then
    LATEST_LOG=$(find "$IOS_LOG_DIR" -name "godot*.log" -type f -exec stat -f "%m %N" {} \; | sort -rn | head -1 | cut -d' ' -f2-)
fi
```

**Pros:**
- Robust against rotation timing
- Preserves historical logs
- Works with test lists

**Cons:**
- More complex logic
- Depends on device clock accuracy

### Option 3: Wait for Log Rotation to Complete (Hack)

Add delay after app launch to let rotation finish:

```bash
# After app launch, wait for rotation
sleep 5

# Then retrieve logs
```

**Pros:**
- Minimal code change

**Cons:**
- Timing-based (unreliable)
- Slows down all tests
- Doesn't solve root cause

## Recommended Solution

**Option 2** (timestamp-based search) with fallback to TEST_ID search:

1. Record test start timestamp
2. After test completes, search for logs created AFTER test start
3. Filter results by TEST_ID match
4. If no match, fall back to most recent log file

This handles:
- Log rotation between tests ✅
- Stale log files ✅
- Test lists ✅
- Historical debugging ✅

## Related Tasks

- **task-317**: Log rotation retry logic (30s timeout)
- **task-319**: Buffer flush delay (SOLVED with flush_stdout_on_print)
- **task-318**: PCK export optimization

## Files to Modify

- `justfiles/justfile-platform-ios.justfile:996-1020` - Log file search logic

---

## Root Cause Investigation (2025-11-28)

### Discovery Process

1. **Initial Symptom:** Test list `diagnostic-pair` failed with "No log file found containing TEST_ID"
2. **First Hypothesis:** Buffer flush issue (task-319)
3. **Evidence Collection:** Retrieved log file at `/tmp/ios_logs_60551/godot.log`
4. **Key Finding:** Log file CONTAINS DEBUG_TEST_SUCCESS entries (buffer flush working!)
5. **Critical Insight:** TEST_ID mismatch - log has `xxx_1764332043`, test expects `xxx_1764336011`

### Detailed Timeline Analysis

**Retrieved Log Files:**
```bash
-rw-r--r--  369K Nov 28 13:14 /tmp/ios_logs_60551/godot.log
-rw-r--r--  5.7M Nov 28 13:14 /tmp/ios_logs_60551/godot2025-11-28T13.14.20.log
-rw-r--r--  365K Nov 28 12:04 /tmp/ios_logs_60551/godot2025-11-28T12.04.31.log
```

**Test Execution Timeline:**
- **13:14:20** - Config 1 completes, writes to `godot.log` (TEST_ID: xxx_1764332043)
- **13:14:20** - Godot rotation: `godot.log` → `godot2025-11-28T13.14.20.log` (5.7MB)
- **14:20:11** - Config 2 starts (TEST_ID: xxx_1764336011)
- **14:20:11** - Config 2 writes to NEW `godot.log`
- **14:20:54** - Log retrieval finds STALE `godot.log` from 13:14

**Timestamp Evidence:**
```bash
# From failed log:
🔍 Required TEST_ID: firebase-three-actions-test_ios_1764336011  # Epoch: 1764336011
🔍 Required TEST_ID: firebase-two-actions-test_ios_1764336011

# But retrieved log contains:
[INFO] DEBUG_TEST_SUCCESS { "test_id": "firebase-three-actions-test_ios_1764332043", ... }
                                                     # Epoch: 1764332043

# Time difference:
1764336011 - 1764332043 = 3968 seconds = 66 minutes = 1 hour 6 minutes
```

### Why Log Files Persist

**iOS App Uninstall Behavior:**
- ✅ Deletes app binary
- ✅ Deletes app data container
- ❌ **Does NOT delete Documents/logs/** directory

**Godot Log Rotation Behavior (on app startup):**
```cpp
// godot/core/io/logger.cpp:140-165
void RotatedFileLogger::rotate_file() {
    file.unref();

    if (FileAccess::exists(base_path)) {  // If godot.log exists
        if (max_files > 1) {
            String timestamp = Time::get_singleton()->get_datetime_string_from_system();
            String backup_name = base_path.get_basename() + timestamp + ".log";

            Ref<DirAccess> da = DirAccess::open(base_path.get_base_dir());
            if (da.is_valid()) {
                da->copy(base_path, backup_name);  // godot.log → godot2025-11-28T13.14.20.log
            }
            clear_old_backups();
        }
    }

    file = FileAccess::open(base_path, FileAccess::WRITE);  // Create NEW godot.log
}
```

**Result:** Each test in a list sees PREVIOUS test's `godot.log`, rotates it, creates new one.

### Why TEST_ID Search Fails

**Current Log Retrieval Logic (justfile-platform-ios.justfile:1003):**
```bash
LATEST_LOG=$(find "$IOS_LOG_DIR" -name "godot*.log" -type f -exec grep -l "$TEST_ID" {} \; 2>/dev/null | head -1)
```

**Problem:** This searches ALL `godot*.log` files and returns FIRST match, which is often the STALE `godot.log`.

**Example:**
```bash
# Directory after test list run:
godot.log                         # 369K, contains OLD TEST_ID xxx_1764332043
godot2025-11-28T13.14.20.log     # 5.7M, rotated OLD log
godot2025-11-28T12.04.31.log     # 365K, even older

# Search for TEST_ID xxx_1764336011:
grep -l "xxx_1764336011" godot*.log
# → No matches! Current test's logs are in a DIFFERENT generation of godot.log

# Search for OLD TEST_ID xxx_1764332043:
grep -l "xxx_1764332043" godot*.log
# → godot.log (WRONG! This is stale)
# → godot2025-11-28T13.14.20.log (CORRECT! But not searched first)
```

### Why This Only Affects Test Lists

**Single Config Test:**
```
1. Fresh install (no previous logs)
2. App starts → No rotation (godot.log doesn't exist yet)
3. Creates NEW godot.log with current TEST_ID
4. Log retrieval finds correct TEST_ID ✅
```

**Test List (Multiple Configs):**
```
Config 1:
1. Fresh install
2. Creates godot.log with TEST_ID_1
3. Test completes
4. App uninstalled → godot.log persists ⚠️

Config 2:
1. Reinstall
2. App starts → Rotates godot.log (TEST_ID_1) → godot2025-11-28T13.14.20.log
3. Creates NEW godot.log with TEST_ID_2
4. Log retrieval happens → Finds OLD godot.log with TEST_ID_1 ❌
5. Fails: "No log file found containing TEST_ID_2"
```

### Evidence from Retrieved Logs

**From `/tmp/ios_logs_60551/godot.log` (stale file):**
```
[INFO] DEBUG_TEST_SUCCESS { "test_id": "firebase-three-actions-test_ios_1764332043", ... }
[INFO] TEST_COMPLETE_firebase-three-actions-test_ios_1764332043
```

**Expected but Missing:**
```
[INFO] DEBUG_TEST_SUCCESS { "test_id": "firebase-three-actions-test_ios_1764336011", ... }
[INFO] TEST_COMPLETE_firebase-three-actions-test_ios_1764336011
```

### Solution Validation Requirements

Any fix must handle:
1. ✅ Single config tests (working)
2. ✅ Test lists with multiple configs (currently failing)
3. ✅ Log rotation during test (task-317)
4. ✅ Buffer flush timing (task-319 - solved)
5. ✅ Historical log debugging (preserve rotated logs)

### Recommended Implementation

**Timestamp-based log search with TEST_ID validation:**

```bash
# Record test start time BEFORE launching app
TEST_START_TIME=$(date +%s)

# After test completes and logs retrieved
echo "🔍 Searching for log file containing current TEST_ID..."
echo "🔍 Required TEST_ID: $TEST_ID"
echo "🔍 Test started at: $TEST_START_TIME ($(date -r $TEST_START_TIME))"

# Find logs modified AFTER test start
CANDIDATE_LOGS=$(find "$IOS_LOG_DIR" -name "godot*.log" -type f -newermt "@$TEST_START_TIME" 2>/dev/null)

if [[ -n "$CANDIDATE_LOGS" ]]; then
    # Search recent logs for TEST_ID
    LATEST_LOG=$(echo "$CANDIDATE_LOGS" | xargs grep -l "$TEST_ID" 2>/dev/null | head -1)

    if [[ -n "$LATEST_LOG" ]]; then
        echo "✅ Found log file created during test: $(basename "$LATEST_LOG")"
    else
        echo "⚠️  Recent logs found but no TEST_ID match"
        echo "📋 Candidate logs:"
        echo "$CANDIDATE_LOGS" | while read log; do
            echo "   - $(basename "$log") ($(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$log"))"
        done
    fi
else
    echo "⚠️  No logs modified after test start time"
    echo "💡 Falling back to most recent log file"

    # Fallback: Find most recently modified log with TEST_ID
    LATEST_LOG=$(find "$IOS_LOG_DIR" -name "godot*.log" -type f -exec stat -f "%m %N" {} \; 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2- | xargs grep -l "$TEST_ID" 2>/dev/null | head -1)
fi

if [[ -z "$LATEST_LOG" ]]; then
    echo "❌ EXPLICIT FAILURE: No log file found containing TEST_ID: $TEST_ID"
    echo ""
    echo "📋 Available log files in retrieved directory:"
    ls -lh "$IOS_LOG_DIR"
    exit 1
fi
```

**Benefits:**
- Filters logs by test execution time window ✅
- Validates TEST_ID presence ✅
- Provides diagnostic output for debugging ✅
- Falls back gracefully ✅
- Preserves historical logs ✅

### Implementation (2025-11-28)

**Changes Made:**

1. **Record test start timestamp** (`justfile-platform-ios.justfile:911-913`)
   ```bash
   # Record test start time BEFORE launching app (Task-320: Log rotation TEST_ID mismatch fix)
   # This timestamp is used to filter logs created DURING this test execution
   TEST_START_TIME=$(date +%s)
   ```

2. **Timestamp-based log search with TEST_ID validation** (`justfile-platform-ios.justfile:1000-1058`)
   ```bash
   # Task-320: Timestamp-based log search with TEST_ID validation
   # Filters logs by test execution time window to prevent stale log retrieval
   echo "🔍 Test started at: $TEST_START_TIME ($(date -r $TEST_START_TIME))"

   # Find logs modified AFTER test start (macOS date format)
   CANDIDATE_LOGS=$(find "$IOS_LOG_DIR" -name "godot*.log" -type f -newermt "@$TEST_START_TIME" 2>/dev/null)

   if [[ -n "$CANDIDATE_LOGS" ]]; then
       # Search recent logs for TEST_ID
       LATEST_LOG=$(echo "$CANDIDATE_LOGS" | xargs grep -l "$TEST_ID" 2>/dev/null | head -1)
       if [[ -n "$LATEST_LOG" ]]; then
           echo "✅ Found log file created during test: $(basename "$LATEST_LOG")"
       fi
   else
       # Fallback: Find most recently modified log with TEST_ID
       LATEST_LOG=$(find "$IOS_LOG_DIR" -name "godot*.log" -type f -exec stat -f "%m %N" {} \; 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2- | xargs grep -l "$TEST_ID" 2>/dev/null | head -1)
   fi
   ```

**How It Works:**

1. **Before app launch**: Records `TEST_START_TIME=$(date +%s)` to capture exact start timestamp
2. **After test completes**: Searches logs using `find -newermt "@$TEST_START_TIME"` to filter only recent logs
3. **Primary search**: Finds logs created DURING test execution containing current TEST_ID
4. **Fallback**: If no timestamp match, uses most recently modified log with TEST_ID
5. **Diagnostic output**: Shows test start time and candidate logs for debugging

**Benefits:**

- ✅ Prevents stale log retrieval in test lists
- ✅ Handles log rotation between tests
- ✅ Preserves historical logs for debugging
- ✅ Provides diagnostic output for troubleshooting
- ✅ Falls back gracefully if timestamp filtering fails
- ✅ Works with both single config and test list modes

### Validation Results (2025-11-28 16:48)

**Bug Fix Applied:**
- Fixed `find -newermt` exit code issue by adding `|| true`
- Added `-r` flag to `xargs` to prevent running on empty input

**Test 1: diagnostic-single (Single Config)**
```
✅ PASSED - 100% success rate (1/1 configs)
🔍 Timestamp-based search working correctly
```

**Test 2: diagnostic-pair (Test List - 2 Configs)**
```
Before Fix: 0% success rate (0/2 configs) - "No log file found containing TEST_ID"
After Fix:  100% success rate (2/2 configs) - ✅ Both configs passed

Config 1: firebase-three-actions-test
🔍 Test started at: 1764344884 (16:48:04)
✅ PASSED

Config 2: firebase-two-actions-test
🔍 Test started at: 1764344906 (16:48:26)
✅ PASSED
```

**Key Improvements:**
- ✅ Test list success rate: **0% → 100%**
- ✅ Timestamp-based search correctly filters logs by test execution window
- ✅ No stale log retrieval issues
- ✅ Single config tests still work (backwards compatible)
- ✅ Diagnostic output helpful for debugging

### Testing Plan

1. ✅ Test with diagnostic-pair (2 configs) - **VALIDATED - 100% PASS**
2. Test with larger test lists (3+ configs)
3. ✅ Validate single config tests still work - **VALIDATED - 100% PASS**
4. Document any edge cases discovered
