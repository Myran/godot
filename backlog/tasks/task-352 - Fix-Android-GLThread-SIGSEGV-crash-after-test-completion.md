---
id: task-352
title: Fix Android GLThread SIGSEGV crash after test completion
status: To Do
assignee:
  - '@claude'
created_date: '2025-12-19 10:58'
updated_date: '2025-12-19 11:02'
labels:
  - critical
  - android
  - graphics
  - crash
  - test-framework
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Critical Android graphics thread crash occurring consistently after test execution completes. The crash happens in the GLThread after successful test completion and flush, preventing proper test cleanup and causing test failures despite successful execution.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Tests complete without GLThread crashes,Graphics cleanup completes successfully after test execution,Sentry captures error details without crashing,Root cause identified and fixed

- [ ] #2 Tests complete without GLThread crashes,Graphics cleanup completes successfully after test execution,Sentry captures error details without crashing,Root cause identified and fixed
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Crash Details

**Pattern Observed:**
- Crash occurs consistently after test completion
- Last log: 
- Fatal signal 11 (SIGSEGV) in GLThread with null pointer dereference
- Fault address: 0x0 (SEGV_MAPERR)
- Thread: GLThread 118876

**Error Sequence:**
1. Test executes successfully
2. Debug flush completes ()
3. Sentry logs completion message
4. ERROR: Parameter 'android_plugin' is null (sentry/android_sdk.cpp:142)
5. GLThread crashes with SIGSEGV

**Reproduction Steps:**
1. Run any Android test configuration
2. Wait for test to complete
3. Crash occurs during cleanup phase

**Log Snippets:**

**Impact:**
- Tests report as failures despite successful execution
- No proper test cleanup
- Cannot run automated test suites reliably
- Blocks CI/CD pipeline

**Investigation Areas:**
1. Sentry SDK integration with Godot's GL thread lifecycle
2. Android plugin null reference during shutdown
3. Graphics resource cleanup order
4. GL thread synchronization during app termination
<!-- SECTION:NOTES:END -->
