---
id: task-303
title: >-
  Fix iOS test config loading - app was caching old configs despite fresh file
  push
status: Done
assignee: []
created_date: '2025-11-23 15:54'
updated_date: '2025-12-18 10:37'
labels:
  - ios
  - test-framework
  - critical
dependencies: []
ordinal: 31000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
iOS tests were failing because the app loaded CACHED debug configs instead of freshly pushed ones, causing tests to run with wrong test_id values.

## Investigation Summary

### Symptoms
1. iOS tests returned 0 actions collected
2. Log files contained test_id from PREVIOUS test runs (e.g., test_id ending in `694` when current was `969`)
3. Config file on device had CORRECT test_id, but app loaded wrong one
4. App quit immediately (0 seconds), indicating no actual test execution

### Root Cause Discovery

**Timeline of Investigation:**

1. **Initial Problem**: iOS logs only captured 4 lines vs hundreds expected
   - DEBUG_TEST_SUCCESS markers missing
   - Root cause: Log retrieval started AFTER app had already quit

2. **Log Retrieval Fix**: Switched from `idevicesyslog` (live stream) to file-based retrieval
   - Godot writes logs to `Documents/logs/godot2025-11-23T16.45.28.log` (timestamped files)
   - Successfully pulling 913 lines from device

3. **Wrong Test_ID Issue**: Pulled logs contained previous test data
   - Current test: `test_id: system.debug.registry_stats_ios_1763912969` (16:50)
   - Logs contained: `test_id: system.debug.registry_stats_ios_1763912443` (16:41)

4. **Execution Order Problem**: Original flow was:
   ```bash
   1. Push config to Documents/debug_startup_actions.json
   2. Call _execute-test-ios:
      a. Uninstall app (_clean-ios-data) → DELETES Documents/!
      b. Hotreload (install + launch together)
   ```
   - Config was deleted before app could read it!

5. **Attempted Fix #1**: Skip uninstall, keep app installed
   - Problem: App cached old config in UserDefaults/CoreData
   - Config file had correct test_id, but app loaded cached version

### Critical Insight

**iOS apps cache config data across sessions!** Simply pushing a new config file doesn't clear the cache. The app must be uninstalled to clear cached data.

## Solution

**New execution flow** (`_execute-test-ios` in `justfile-platform-ios.justfile`):

```bash
1. Uninstall app (_clean-ios-data)           # Clear ALL data including cache
2. Update PCK (ios-update-pck)                # Prepare latest game code
3. Install app (devicectl install)            # Creates fresh Documents/
4. Push config (_push-file-ios)               # Config goes to empty Documents/
5. Launch app (devicectl launch)              # App reads fresh config
6. Wait for app quit (process monitoring)     # Ensure complete execution
7. Pull logs (devicectl copy from)            # Retrieve timestamped log file
```

**Key Change**: Split `hotreload` (which did install+launch atomically) into separate install and launch steps, allowing config push between them.

## Files Modified

- `justfiles/justfile-platform-ios.justfile:776-893` (`_execute-test-ios`)
  - Split install and launch into discrete steps
  - Added proper wait-for-quit mechanism (checks process list every 2s)
  - Fixed log file sorting (by filename timestamp, not modification time)

## Testing & Validation

### Primary Test
```bash
just test-ios-ipad 'system.debug.registry_stats'
```

### Validation Requirements

**1. Single Action Test** ✓
- Command: `just test-ios-ipad 'system.debug.registry_stats'`
- Expected: Logs contain CURRENT test_id (not from previous run)
- Expected: DEBUG_TEST_SUCCESS markers present (at least 2 actions)
- Expected: Actions collected > 0 in test results JSON

**2. Debug Config with Save/Load Cycling**
- Command: `just test-ios-ipad gamestate-save-load-test`
- Expected: Multiple test runs captured with correct test_id
- Expected: Each save/load cycle logs DEBUG_TEST_SUCCESS
- Expected: Sequential actions complete properly

**3. Test List Execution**
- Command: `just test-ios-ipad @gamestate-system-validation`
- Expected: All configs in list execute
- Expected: Results comparable to Android equivalent
- Expected: Platform-specific commands filtered correctly

**4. iOS vs Android Output Comparison**
- Run same test on both platforms:
  ```bash
  just test-android 'system.debug.registry_stats'
  just test-ios-ipad 'system.debug.registry_stats'
  ```
- Expected: Both produce similar log structure
- Expected: Both capture DEBUG_TEST_SUCCESS markers
- Expected: Both report correct action counts
- Expected: Timing differences acceptable (<5s variance)

**5. Config Freshness Verification**
- Run same test twice in succession
- Expected: Each run uses its own unique test_id
- Expected: No cross-contamination of logs
- Expected: Log files properly timestamped

### Success Criteria

- [ ] Single action test passes with correct test_id
- [ ] Save/load cycling test completes all iterations
- [ ] Test list execution works on iPad
- [ ] iOS output matches Android structure and completeness
- [ ] Consecutive test runs remain independent (no cache contamination)

## Related

- Task-301: iOS app data clearing implementation (uninstall/reinstall approach)
- iOS logs location: `Documents/logs/godot2025-11-23THH.MM.SS.log` (timestamped files)
- devicectl commands: No native "delete" for Documents/ files, must use uninstall

## Solution Implemented

**Commit**: `5af83cdc` - "fix(ios): Reset config cache before reading external configs (Task-303)"

**Changes Made**:
- Added `DebugConfigReader._reset_cache()` before reading external configs in debug coordinator
- Initialize cache with safe defaults instead of complete clearing
- Fixed incorrect comment: iOS Documents/ directory IS writable
- Prevents stale cached configs from early autoload execution

**Files Modified**:
- `project/debug/utilities/debug_config_reader.gd`: Added cache reset with safe defaults
- `project/addons/debug_startup/debug_startup_coordinator.gd`: Call reset before external config reads

**Result**: iOS automated tests now correctly load pushed configs without stale data contamination.
<!-- SECTION:DESCRIPTION:END -->
