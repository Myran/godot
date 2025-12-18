---
id: task-347
title: >-
  Fix Firebase config JSON not found on Windows preventing Firebase RTDB
  integration
status: Done
assignee: []
created_date: '2025-12-17 14:09'
updated_date: '2025-12-18 10:37'
labels:
  - firebase
  - windows
  - config-file
  - backend-factory
  - json-location
dependencies: []
priority: high
ordinal: 2000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The backend factory has platform-specific logic that causes issues. Instead of unified "try Firebase first" approach, it has:
- Android: Always forces Firebase
- Other platforms: Checks internet connectivity (times out on Windows)

This creates inconsistent behavior and platform-specific issues. The solution is to unify the logic across all platforms to:
1. Try Firebase first (check if config file exists and Firebase initializes)
2. Fall back to local JSON if Firebase isn't available
3. Respect debug flags (force_local_data) for testing

**Key Issues:**
- Internet check on Windows times out after 7 seconds, causing unnecessary fallback
- Platform-specific logic creates maintenance burden
- Firebase availability detection is flawed - it should check for config file existence and try initialization, not check internet

**Files to Modify:**
- `project/data/backends/backend_factory.gd` - Lines 116-138 need unified logic

**Current Status:**
- ✅ Sentry integration: Fully working on Windows (v1.2.0+241f16b)
- ✅ Firebase C++ layer: All tests pass (SDK initializes successfully)
- ❌ Firebase RTDB layer: Fails due to backend selection logic, not config issues

**Evidence from Logs:**
- Firebase app creates successfully: `[Firebase] Success creating app`
- Backend selection falls back after internet timeout: `"check_duration_sec": 6.887`
- Falls back to local instead of trying Firebase first
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Unified backend selection logic across all platforms (Android, iOS, Windows, macOS, desktop)
- [x] #2 Try Firebase backend first (check config + attempt initialization)
- [x] #3 Fall back to local JSON only if Firebase fails to initialize
- [x] #4 Respect force_local_data debug flag for testing
- [x] #5 Remove platform-specific internet connectivity checks
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Resolution Summary

Successfully identified and fixed the root cause of Firebase integration issues on Windows. The problem was NOT the missing Firebase config file (which exists), but the backend selection logic in `backend_factory.gd` that was performing platform-specific internet connectivity checks before trying Firebase.

### Root Cause
- Windows had a special-case in the backend selection that checked internet availability first
- This check timed out after ~7 seconds, causing Firebase to never get a chance to initialize
- Firebase SDK actually handles network unavailability gracefully with proper error codes

### Solution Implemented
1. **Unified backend selection logic** across all platforms (Android, iOS, macOS, Windows)
2. **Removed 90+ lines** of internet checking code (`_check_internet_availability()` function)
3. **All platforms now try Firebase first**, falling back to local if Firebase fails
4. Reduced `backend_factory.gd` from 227 to 122 lines (46% smaller)

### Test Results
- **Android**: 9/9 cpp-layer tests pass, 17/17 rtdb-layer tests pass
- **iOS**: 6/6 Firebase tests pass (after fixing Sentry dylib install names)
- **macOS**: Firebase tests pass
- **Windows**: 8/8 Firebase cpp-layer tests pass ✨

### Key Evidence from Windows Logs
```
[Firebase] Creating app (Windows)
[Firebase] Success creating app
[database] Attempting Firebase backend (unified cross-platform logic)
[Firebase] INITIALIZATION COMPLETE: Firebase service initialized successfully
[RTDB C++] Firebase Database instance obtained successfully
[cache] Card cache activated { "data_source": "firebase" }
```

All acceptance criteria for the task have been met:
1. ✅ Firebase RTDB integration now works on Windows
2. ✅ Windows uses the same backend selection logic as other platforms
3. ✅ Firebase config file is properly loaded (google-services-desktop.json)
4. ✅ All tests pass on Windows platform

The Firebase SDK gracefully handles network connectivity issues internally, making the pre-checks redundant and harmful on Windows.
<!-- SECTION:NOTES:END -->
