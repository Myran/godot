---
id: task-413
title: >-
  Fix Sentry Android AAR ClassNotFoundException - transitive dependencies not
  resolved
status: Done
assignee: []
created_date: '2026-01-03 12:24'
updated_date: '2026-01-03 15:26'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

Android Firebase Auth tests are failing with:
```
Caused by: java.lang.ClassNotFoundException: Didn't find class "io.sentry.SentryLogEvent" on path
ERROR: Parameter "methods" is null.
```

## Root Cause

The Sentry Android AAR (`sentry_android_godot_plugin.release.aar`) is included as a local file in `project/android/build.gradle`:

```gradle
releaseImplementation fileTree(dir: 'libs/release', include: ['**/*.jar', '*.aar'])
```

When AAR files are included as local files, Gradle **does not resolve their transitive dependencies**. The Sentry plugin AAR declares `implementation("io.sentry:sentry-android:8.28.0")` in its `build.gradle.kts`, but this dependency is not included when the AAR is consumed as a local file.

## Verified

- ✅ Editor tests PASS (4/4 actions, 100%)
- ✅ Auth.cpp implementation is correct
- ❌ Android tests FAIL due to Sentry ClassNotFoundException
- ❌ Same issue affects other Firebase tests (firebase-cpp-layer)

## Solution Options

1. **Option 1**: Add Sentry Android SDK dependency directly to game's build.gradle
   ```gradle
   implementation "io.sentry:sentry-android:8.28.0"
   ```

2. **Option 2**: Publish Sentry AAR to local Maven repository (so dependencies are resolved)

3. **Option 3**: Use Fat AAR (include all dependencies in the AAR itself)

## Acceptance Criteria

1. Android auth tests pass (cpp.firebase.auth.tests)
2. No ClassNotFoundException for SentryLogEvent
3. Sentry SDK is properly initialized on Android
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Resolution Summary (2026-01-03)

### Root Cause Confirmed
Local AAR files in Gradle don't resolve transitive dependencies. The Sentry plugin AAR declares `implementation("io.sentry:sentry-android:8.28.0")` but this wasn't included when consumed as local file.

### Solution Applied
Option 1 implemented: Added Sentry Android SDK dependency directly to `inject/firebase_dependencies.gradle`:
```gradle
implementation "io.sentry:sentry-android:8.28.0"
```

### Validation Results
| Platform | Build | Test | Notes |
|----------|-------|------|-------|
| Android | ✅ PASS | ✅ PASS (6/6) | All Firebase Auth tests pass |
| iOS | ✅ PASS | ⚠️ SKIP | Test infra issue (IOS_TEST_DEVICE) |
| macOS | ❌ N/A | N/A | Unrelated Facebook module linking issue |

### Additional Fixes
During testing, discovered and fixed GDScript auth action issues:
1. Fixed signal parameter count mismatch (C++ has 4 params, GDScript expected 5)
2. Fixed wrong signal name (`id_token_result` not `id_token_completed`)
<!-- SECTION:NOTES:END -->
