---
id: task-428
title: Fix Windows physical debug coordinator returns 0 actions
status: To Do
assignee: []
created_date: '2026-01-07 16:41'
labels:
  - windows
  - testing
  - debug-framework
  - infrastructure
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

Windows physical machine tests complete but collect 0 debug actions. The test infrastructure deploys and launches the app, but no debug actions execute.

## Evidence

```
📊 Actions collected: 0
🎯 TEST_ID: backend.firebase.async_pattern_windows-physical_1767800760
❌ CRITICAL TEST FAILURE: No actions found in results file
💡 This indicates debug coordinator or test context initialization issues
```

Test execution shows:
- Config deployed successfully
- App launched on physical machine (192.168.50.80)
- Logs retrieved (313 lines)
- But action results JSON is empty

## Impact

Blocks cross-platform Firebase validation on Windows (task-403 criterion #10).

## Investigation Required

1. Check if debug_startup_actions.json is properly deployed to Windows user data dir
2. Verify debug coordinator reads config correctly on Windows physical
3. Check if Windows user data path differs from expected location
4. May need Windows-specific config deployment logic
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Windows physical tests collect > 0 actions
- [ ] #2 Debug coordinator executes on Windows physical
- [ ] #3 build-export-test-windows firebase-all passes at least one config
- [ ] #4 Action results JSON properly populated
<!-- AC:END -->
