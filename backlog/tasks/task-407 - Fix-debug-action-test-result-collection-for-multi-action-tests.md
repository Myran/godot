---
id: task-407
title: Fix debug action test result collection for multi-action tests
status: To Do
assignee: []
created_date: '2025-12-31 22:59'
labels:
  - testing
  - debug-framework
  - bugfix
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Debug test configs with multiple actions only record 1 action result in JSON instead of all executed actions.

**Root Cause**: The test result collection system only captures `system.debug.replay_complete` instead of individual action results.

**Impact**:
- Test reporting incomplete
- Can't verify individual action pass/fail from JSON
- Affects automated test reporting and CI

**Evidence**:
- firebase-analytics-tests ran 6 actions but only 1 recorded
- Logs confirm all 6 actions executed successfully
- C++ verification shows all tests passed

**Acceptance Criteria**:
- All executed debug actions record individual results in JSON
- Test summary accurately reflects total actions passed/failed
- Each action shows duration, success status, and error message
<!-- SECTION:DESCRIPTION:END -->
