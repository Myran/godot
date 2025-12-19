---
id: task-136
title: Fix Android static variable reset preventing DEBUG_TEST_SUCCESS logging
status: Done
assignee: []
created_date: '2025-09-10 12:06'
updated_date: '2025-12-18 10:37'
labels:
  - android
  - testing
  - debug
dependencies: []
priority: high
ordinal: 162000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
On Android, static variables in debug_action.gd are being reset between test context initialization and action execution, causing current_test_id to become empty and skipping all DEBUG_TEST_SUCCESS logging. This blocks Android automated testing validation and causes CI failures.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 current_test_id persists correctly during action execution on Android,DEBUG_TEST_SUCCESS logging works properly on Android platform,test_action_count increments correctly during action execution,Automated Android testing validation passes without '0 actions collected' failures
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Analyze current static variable usage in debug_action.gd that causes Android reset issues
2. Replace static current_test_id dependency with direct DebugConfigReader.get_test_metadata().get('test_id', '') calls
3. Update all debug action classes to use config-based test ID retrieval instead of static variables
4. Test fix with just test-android-target system.debug.registry_stats to verify DEBUG_TEST_SUCCESS logging
5. Validate that test_action_count increments properly during action execution on Android
6. Run comprehensive Android testing to ensure CI validation passes without '0 actions collected' failures
<!-- SECTION:PLAN:END -->
