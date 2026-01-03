---
id: task-411
title: >-
  Fix iOS Remote Config test failures - get_int and get_string returning
  unexpected values despite fetch_and_activate succeeding
status: Done
assignee: []
created_date: '2026-01-02 19:56'
updated_date: '2026-01-02 22:49'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Root Cause: **Persistent Firebase Remote Config Cache** on iOS Device

The iOS device had persistent cached Remote Config data from previous test runs that survived normal app updates.

### Investigation Timeline

**Initial Hypothesis (INCORRECT):** Firebase Remote Config Console has Platform condition targeting iOS differently.

**Investigation Steps:**
1. Added comprehensive diagnostic logging to `remote_config.cpp`:
   - Firebase App configuration logging (Project ID, App ID, API Key)
   - Value source logging (STATIC/REMOTE/DEFAULT) for all getter methods
   - POST-FETCH DIAGNOSTIC DUMP showing all keys with values and sources

2. Retrieved actual Firebase Remote Config template via MCP tool:
   - **NO platform conditions** found in the template
   - Expected parameters present: `welcome_message`, `max_players`, `retry_count`, `app_name`
   - Only country-based condition (`insweden`) exists

3. Verified Firebase configuration files:
   - iOS `GoogleService-Info.plist`: Project ID `gametwo-89299`
   - Desktop `google-services-desktop.json`: Project ID `gametwo-89299`
   - Same Firebase project, same configuration

**Actual Root Cause:** iOS device had **persistent cache** containing old/test Remote Config data:
- Before cache clear: `["test_string", "test_bool", "test_number", "test_int", "test_float"]`
- After cache clear: All tests PASSED with correct values

### Resolution

1. **Deleted app from iOS device:**
   ```bash
   xcrun devicectl device uninstall app --device 38A3A7F3-6C49-5C54-B86E-D84C81ABD10C com.primaryhive.gametwo
   ```

2. **Re-deployed fresh app build**

3. **All Remote Config tests now PASS:**
   - `test.remote_config.set_defaults` ✅ (63ms)
   - `test.remote_config.fetch_async` ✅ (199ms)
   - `test.remote_config.activate_async` ✅ (176ms)

### Technical Findings

- **Firebase Project:** `gametwo-89299` (consistent across iOS and Desktop)
- **iOS Bundle ID:** `com.primaryhive.gametwo`
- **Cache persistence:** iOS Firebase SDK cache is at **system level** - survives app updates/reinstalls
- **`minimum_fetch_interval = 0` setting:** Only affects fetch throttling, does NOT clear persistent cache
- **Cache bypass:** `fetch(cache_expiration=0)` was not sufficient to clear the persistent cache

### Lessons Learned

1. **Always fully uninstall/reinstall app** when investigating Firebase Remote Config cache issues
2. **Verify actual Firebase Console template** before concluding platform-specific targeting exists
3. iOS Firebase SDK cache persistence is more aggressive than Desktop
4. The C++ diagnostic logging added (`remote_config.cpp`) will help identify similar issues in the future

### Cross-Platform Validation (2026-01-03)

**build-export-test-all firebase-remote-config-tests:**
- ✅ macOS: PASSED
- ✅ Windows: PASSED
- ✅ Android: PASSED
- ✅ iOS: PASSED

**Confirmed:** iOS Remote Config works correctly after clearing persistent cache. All other platforms were unaffected by this issue.
<!-- SECTION:DESCRIPTION:END -->
