---
id: task-347
title: >-
  Fix Firebase config JSON not found on Windows preventing Firebase RTDB
  integration
status: To Do
assignee: []
created_date: '2025-12-17 14:09'
updated_date: '2025-12-17 14:23'
labels:
  - firebase
  - windows
  - config-file
  - backend-factory
  - json-location
dependencies: []
priority: high
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
- [ ] #1 Unified backend selection logic across all platforms (Android, iOS, Windows, macOS, desktop)
- [ ] #2 Try Firebase backend first (check config + attempt initialization)
- [ ] #3 Fall back to local JSON only if Firebase fails to initialize
- [ ] #4 Respect force_local_data debug flag for testing
- [ ] #5 Remove platform-specific internet connectivity checks
<!-- AC:END -->
