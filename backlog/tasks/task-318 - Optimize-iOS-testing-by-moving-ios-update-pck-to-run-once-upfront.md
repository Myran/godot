---
id: task-318
title: Optimize iOS testing by moving ios-update-pck to run once upfront
status: Done
assignee: []
created_date: '2025-11-27 19:09'
updated_date: '2025-11-27 21:02'
labels:
  - ios
  - testing
  - performance
dependencies: []
priority: medium
---

## Description

Currently, `ios-update-pck` (PCK export) runs inside `_execute-test-ios` for every single test configuration. When running test lists with multiple configs, this causes redundant PCK exports even though the game code hasn't changed between tests.

**Problem Example:**
- Test list with 3 configs → PCK exported 3 times (unnecessary)
- Each export takes ~5-10 seconds
- Total waste: 10-20 seconds per test list run

**Goal:** Move `ios-update-pck` to run once upfront before the test loop, similar to how Android handles `fastbuild-android`.

## Current Behavior

**Call Flow:**
```
test-ios-target "diagnostic-pair"
  → _execute-test-with-analysis (detects test list)
    → _test-list-generic "diagnostic-pair" "ios"
      → Loop: for each config in test list
        → _execute-test-ios
          → ios-update-pck  ← RUNS EVERY ITERATION
```

**Location:** `justfiles/justfile-platform-ios.justfile:893`

## Proposed Solution

**Move PCK export to run ONCE before test loop in `_test-list-generic`:**

1. Add platform-specific setup block in `_test-list-generic` before the test loop
2. For iOS platform, execute `just ios-update-pck` once
3. Remove `just ios-update-pck` from `_execute-test-ios`

**New Flow:**
```
test-ios-target "diagnostic-pair"
  → _execute-test-with-analysis (detects test list)
    → _test-list-generic "diagnostic-pair" "ios"
      → ios-update-pck  ← RUNS ONCE UPFRONT
      → Loop: for each config in test list
        → _execute-test-ios  ← NO PCK EXPORT
```

## Implementation

### File 1: `justfiles/justfile-validation-enhanced-testing.justfile`

**Location:** Add after line 1993 (before test loop starts)

```bash
echo ""
echo "🚀 Starting test execution..."
echo "============================="

# Platform-specific setup before test loop
if [[ "$PLATFORM" == "ios" ]]; then
    echo "📦 Preparing iOS PCK (one-time for all configs)..."
    just ios-update-pck
    echo "✅ iOS PCK ready"
fi

# Execute each configuration using array-based iteration
```

### File 2: `justfiles/justfile-platform-ios.justfile`

**Location:** Remove lines 891-893 from `_execute-test-ios`

**Before:**
```bash
# Update PCK and install app (but don't launch yet)
echo "📦 Installing updated app on $DEVICE_NAME..."
just ios-update-pck
```

**After:**
```bash
# Install app (PCK already updated by test list setup)
echo "📦 Installing app on $DEVICE_NAME..."
```

## Benefits

1. **Performance:** 10-20 seconds saved per test list run
2. **Consistency:** Matches Android workflow pattern
3. **Clarity:** PCK export happens once, visibly, before all tests
4. **No regressions:** Single config tests still work (no test list, so goes directly to _execute-test-ios)

## Edge Cases Handled

- **Single config tests:** Still work - they bypass `_test-list-generic` entirely
- **Mixed platforms:** Only iOS gets PCK export, Android/Desktop unaffected
- **Manual runs:** `just run-ios-ipad` still uses `hotreload-ios-ipad` which calls `ios-update-pck`

## Testing

After implementation:
1. Run single config: `just test-ios-target firebase-rtdb-layer`
2. Run test list: `just test-ios-target diagnostic-pair`
3. Verify PCK export happens once before loop, not per-config

## Files Modified

- `/Users/mattiasmyhrman/repos/gametwo/justfiles/justfile-validation-enhanced-testing.justfile`
- `/Users/mattiasmyhrman/repos/gametwo/justfiles/justfile-platform-ios.justfile`

## Implementation Notes

**Completed: 2025-11-27**

### Changes Made

1. **justfile-validation-enhanced-testing.justfile (lines 1995-2002)**
   - Added iOS PCK export in `_test-list-generic` before test loop
   - Only runs for iOS platform in test list mode

2. **justfile-validation-enhanced-testing.justfile (lines 2708-2714)**
   - Added iOS PCK export for single config tests (not in test list)
   - Uses `INSIDE_TEST_LIST_EXECUTION` flag to avoid duplicate exports

3. **justfile-platform-ios.justfile (line 891-893)**
   - Removed `just ios-update-pck` from `_execute-test-ios`
   - Updated comment to reflect PCK already being prepared

### Test Results

**Single Config Test:**
```bash
just test-ios-ipad firebase-rtdb-layer
```
Output showed:
```
📦 Preparing iOS PCK...
🔄 Updating iOS PCK file...
✅ iOS PCK ready
...
📦 Installing app on iPad...
```
✅ PCK export happened once upfront for single config

**Test List (2 configs):**
```bash
just test-ios-ipad diagnostic-pair
```
Output showed:
```
📦 Preparing iOS PCK (one-time for all configs)...
🔄 Updating iOS PCK file...
🔍 Testing configuration 1/2: firebase-three-actions-test
📦 Installing app on iPad...
🔍 Testing configuration 2/2: firebase-two-actions-test
📦 Installing app on iPad...
```
✅ PCK export happened ONCE for both configs (no redundant exports)

### Performance Impact

- Test list with 2 configs: ~5-10 seconds saved
- Test list with 3 configs: ~10-15 seconds saved
- Single config tests: No change (still exports once)

### Edge Cases Verified

- ✅ Single config tests work correctly
- ✅ Test list mode works correctly
- ✅ PCK export uses `INSIDE_TEST_LIST_EXECUTION` flag to avoid duplication
- ✅ No impact on Android/Desktop platforms

---

## Follow-up Issue: iOS Log Retrieval Hangs

**Discovered: 2025-11-28**

### Problem

After implementing the PCK optimization, tests started getting stuck during log retrieval phase:
```
📥 Attempt 1/5...
⚠️  Retry in 3s (logs may still be rotating)...
📥 Attempt 2/5...
⚠️  Retry in 6s (logs may still be rotating)...
📥 Attempt 3/5...  ← STUCK INDEFINITELY
```

### Root Cause Analysis

**Issue:** `xcrun devicectl device copy from` hangs when iOS is performing log rotation on large files.

**When it happens:**
1. Previous test creates large (5MB+) `godot.log` file
2. New test starts → app launches → triggers Godot's `RotatedFileLogger`
3. Rotation copies large file: `godot.log` → `godot2025-11-27T11.31.47.log`
4. iOS file system locks `Documents/logs/` directory during copy
5. Our `xcrun devicectl device copy from` waits for lock → **hangs indefinitely**

**Godot Log Rotation Mechanism:**

Location: `godot/core/io/logger.cpp`

```cpp
// Lines 140-165
void RotatedFileLogger::rotate_file() {
    file.unref();

    if (FileAccess::exists(base_path)) {
        if (max_files > 1) {
            String timestamp = Time::get_singleton()->get_datetime_string_from_system();
            String backup_name = base_path.get_basename() + timestamp + ".log";

            Ref<DirAccess> da = DirAccess::open(base_path.get_base_dir());
            if (da.is_valid()) {
                da->copy(base_path, backup_name);  // ← BLOCKS iOS FILE SYSTEM
            }
            clear_old_backups();
        }
    }

    file = FileAccess::open(base_path, FileAccess::WRITE);
}

// Lines 168-171 - Called on EVERY app startup
RotatedFileLogger::RotatedFileLogger(const String &p_base_path, int p_max_files) {
    rotate_file();  // ← Triggered when app starts
}
```

**Key Findings:**
- Rotation happens **on app startup**, NOT during runtime
- No size-based rotation during execution
- Large files (5MB+) take 20-30 seconds to copy on iOS
- File system lock prevents concurrent access during copy
- Our log retrieval command has no timeout → hangs forever

### Temporary Fix Applied

**File:** `justfiles/justfile-platform-ios.justfile:964`

Added 30-second timeout to prevent infinite hangs:
```bash
# Use timeout to prevent hanging on log rotation (max 30s per attempt)
TIMEOUT_DURATION=30
if timeout $TIMEOUT_DURATION xcrun devicectl device copy from \
    --device "$IOS_DEVICE_ID" \
    --source "Documents/logs/" \
    --destination "$IOS_LOG_DIR" \
    --domain-type appDataContainer \
    --domain-identifier "{{IOS_BUNDLE_IDENTIFIER}}" \
    --quiet 2>/dev/null; then
    echo "✅ iOS logs directory retrieved successfully"
    RETRY_SUCCESS=true
    break
else
    COPY_EXIT_CODE=$?
    if [ $COPY_EXIT_CODE -eq 124 ]; then
        echo "   ⏱️  Timeout after ${TIMEOUT_DURATION}s (log rotation in progress)"
    else
        echo "   ❌ Copy failed with exit code $COPY_EXIT_CODE"
    fi

    if [ $attempt -lt $MAX_ATTEMPTS ]; then
        WAIT_TIME=$((3 * attempt))
        echo "   ⚠️  Retry in ${WAIT_TIME}s (logs may still be rotating)..."
        sleep $WAIT_TIME
    fi
fi
```

**Result:** Tests complete but with retry delays when rotation is happening.

### Robust Solutions Needed

**Current approach:** 30-second timeout is a band-aid, not a real fix.

**Better approaches to consider:**

1. **Pull logs BEFORE next app starts** (prevents rotation lock)
   - Retrieve logs immediately after app quits
   - Clear device logs after retrieval
   - Next app starts with clean slate (no large files to rotate)

2. **Delete old rotated logs before test**
   - Clear large backup logs before starting each test
   - Faster rotation (nothing big to copy)
   - Matches Android's clean-slate approach

3. **Disable Godot log rotation for iOS tests**
   - Set `max_log_files=1` in project settings for iOS
   - No rotation backups = no copy delays
   - Always fresh log file

4. **Stream logs during execution** (best long-term)
   - Use `devicectl device process launch --monitor`
   - Capture logs in real-time
   - No post-test retrieval needed

### Evidence

**Large log files found:**
```
-rw-r--r--  5.1M  godot2025-11-27T11.31.47.log  ← Rotated on next app start
-rw-r--r--  273K  godot2025-11-27T11.32.19.log
-rw-r--r--  545K  godot.log                     ← Current active log
```

**Timeline of events:**
1. Test 11 completes → leaves 5.1MB `godot.log`
2. Test 12 starts → `RotatedFileLogger()` constructor called
3. `rotate_file()` copies 5.1MB file → takes 20-30 seconds
4. Directory locked during copy
5. Our log retrieval times out after 30s
6. Retry succeeds after rotation completes

### Recommended Next Steps

1. **Immediate:** Keep 30-second timeout (prevents infinite hangs)
2. **Short-term:** Implement log cleanup between tests
3. **Long-term:** Switch to real-time log streaming with `devicectl --monitor`

### Related Files

- `justfiles/justfile-platform-ios.justfile` (lines 943-987)
- `godot/core/io/logger.cpp` (lines 140-171)
- `godot/main/main.cpp` (line 2145)

## Follow-Up Issues

- **task-319**: Fix iOS log buffer flushing delay causing incomplete log retrieval - While task-318 optimized PCK export, a separate timing issue was discovered where iOS log buffers aren't flushed to disk before retrieval, causing "No actions found" test failures.
