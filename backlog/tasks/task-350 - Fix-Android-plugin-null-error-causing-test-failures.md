---
id: task-350
title: Fix Android plugin null error causing test failures
status: Done
assignee: []
created_date: '2025-12-19 05:20'
updated_date: '2025-12-22 23:44'
labels:
  - android
  - bugfix
  - testing
  - plugin
  - high-priority
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
During Android testing, all tests fail due to: `ERROR: Parameter "android_plugin" is null`

This error occurs during app initialization and prevents proper test execution. All 19 Android tests in the main test suite fail with this error.

**Error location**: Godot engine Android plugin initialization
**Impact**: 100% Android test failure rate
**Observed in**: logs/20251218_214913_test.log

**Possible causes**:
1. Android plugin not properly installed in export templates
2. Plugin initialization order issue
3. Missing plugin configuration in export_presets.cfg
4. fastbuild-android not run after recent changes
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Resolved (2025-12-23)

The "android_plugin is null" error was resolved as part of task-352. The Sentry SDK was updated to v1.2.0 with proper AAR files, and the shutdown sequence was fixed to call `SentrySDK.close()` before app termination.

This prevented the race condition where GLThread would try to access the destroyed Android plugin.
<!-- SECTION:NOTES:END -->
