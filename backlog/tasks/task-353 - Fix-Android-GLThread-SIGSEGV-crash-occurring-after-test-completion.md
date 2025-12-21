---
id: task-353
title: Fix Android GLThread SIGSEGV crash occurring after test completion
status: Open
assignee: []
created_date: '2025-12-19 11:03'
updated_date: '2025-12-21 15:27'
labels:
  - critical
  - android
  - graphics
  - crash
  - opengl
  - glthread
dependencies:
  - task-348
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Critical graphics crash occurring in Android GLThread (OpenGL graphics thread) after successful test execution, preventing proper test completion and validation. The crash happens with consistent pattern after tests finish executing, indicating a graphics/OpenGL cleanup issue.

The crash appears to be related to OpenGL resource cleanup during app shutdown/restart, specifically when the auto_quit feature triggers app restart between tests. This is blocking the entire Android testing workflow as every test "passes" but then fails during the crash detection phase.

Error pattern:
- Fatal signal 11 (SIGSEGV), code 1 (SEGV_MAPERR)
- Fault address: 0x0 (null pointer dereference)
- Thread: GLThread <number> (graphics rendering thread)
- Occurs after test actions complete successfully
- Affects multiple test configurations
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Tests run successfully without SIGSEGV crash
- [ ] #2 App shutdown/restart works cleanly
- [ ] #3 No null pointer dereferences in GLThread
- [ ] #4 All Android test configurations pass validation
- [ ] #5 Root cause identified and fixed
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Investigate Godot 4.3 Android OpenGL cleanup timing during auto_quit app restart cycle. Focus on GLThread null pointer access and race conditions between graphics resource cleanup and app shutdown.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Context & Investigation

### Recent Test Failures
Multiple Android tests are experiencing SIGSEGV crashes after successful execution:

**Test Examples:**
- `firebase-backend-layer_android_1766139962`: 8/8 actions passed, then crashed
- `firebase-backend-layer_android_1766140899`: 8/8 actions passed, then crashed
- `sentry-android-integration-test_android_1766141642`: 2/2 actions passed, then crashed
- `system-error-handling_android_1766141642`: 2/2 actions passed, then crashed

### Error Pattern Analysis
```
12-19 11:42:08.629  3147  3215 F libc    : Fatal signal 11 (SIGSEGV), code 1 (SEGV_MAPERR), fault addr 0x0 in tid 3215 (GLThread 118327), pid 3147 (gametwo)
```

**Consistent Elements:**
- Always in GLThread (graphics rendering thread)
- Always fault address 0x0 (null pointer)
- Always after test actions complete successfully
- Always during app shutdown/restart phase

### Triggering Conditions
- Occurs when `auto_quit=true` is set (automated tests)
- Happens between test completion and app restart
- Not present in manual testing mode
- Affects all Android test configurations

### Root Cause Hypothesis

1. **OpenGL Resource Cleanup Issue**: 
   - GLThread trying to access freed OpenGL resources
   - Race condition between app shutdown and graphics cleanup

2. **Auto Quit Timing**:
   - `adb shell am force-stop` followed by `am start` creates resource cleanup race
   - OpenGL context may be destroyed before GLThread finishes

3. **Godot 4.3 Android Export Issue**:
   - Potential bug in Godot's Android OpenGL cleanup
   - Related to renderer settings or graphics initialization

### Investigation Steps Performed

1. ✅ **Verified Sentry integration works** - no more "android_plugin is null" errors
2. ✅ **Confirmed AAR files in correct location** - `project/addons/sentry/bin/android/`
3. ✅ **Tests execute successfully** - all actions pass before crash
4. ✅ **Crash is post-execution** - happens after test actions complete

### Next Investigation Steps

1. **Check Godot Renderer Settings**:
   ```ini
   [rendering]
   renderer/rendering_method="gl_compatibility"
   renderer/rendering_method.mobile="gl_compatibility"
   ```

2. **Review Auto Quit Implementation**:
   - Timing between force-stop and start
   - Potential need for delay before restart

3. **Test Without Auto Quit**:
   ```bash
   just test-android-manual CONFIG
   # Manually observe if crash occurs
   ```

4. **OpenGL Resource Tracking**:
   - Check for OpenGL resource leaks
   - Verify proper cleanup order

5. **Godot 4.3 Bug Reports**:
   - Search for known issues with Android GLThread crashes
   - Check if related to specific renderer settings

### Current Workarounds

- Tests "pass" functionality-wise but fail validation due to crash
- Manual testing avoids the issue
- Issue only affects automated testing workflow

## Full Pipeline Analysis (2025-12-21)

### Scope Confirmation
- **19 crashes** in single full-pipeline run
- **100% Android test failure rate** due to this crash
- All crashes have identical signature - highly reproducible

### Timing Confirmation
Crashes occur specifically AFTER `system.debug.replay_complete` action passes:
```
| `system.debug.replay_complete` | System | ✅ **PASSED** | 3ms |
❌ CRASH DETECTED
```

This confirms the crash happens during app shutdown/cleanup phase, not during test execution.

### Crash Timestamps (sample from log)
```
12-21 12:08:26.732 - GLThread 137087
12-21 12:08:58.866 - GLThread 137212
12-21 12:09:36.359 - GLThread 137353
12-21 12:10:11.218 - GLThread 137512
... (19 total)
```

### Configurations Blocked
All Android tests affected including:
- `backend.firebase.*` (async_pattern, error_handling)
- `battle-*` (animated, logic-only, combat-only-validation)
- `firebase-*` (all backend/cpp/rtdb layers)
- `gamestate-*` (save-load tests)
- `system-*` (error-handling, layer-all, performance)

### Key Observation
Desktop and macOS tests for the same configurations pass without crashes, confirming this is Android-specific GLThread issue during shutdown.
<!-- SECTION:NOTES:END -->
