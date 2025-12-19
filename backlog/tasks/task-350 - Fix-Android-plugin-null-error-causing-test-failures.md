---
id: task-350
title: Fix Android plugin null error causing test failures
status: To Do
assignee: []
created_date: '2025-12-19 05:20'
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
