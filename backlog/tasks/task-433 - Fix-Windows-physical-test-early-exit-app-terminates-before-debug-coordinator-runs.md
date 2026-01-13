---
id: task-433
title: >-
  Fix Windows physical test early exit - app terminates before debug coordinator
  runs
status: To Do
assignee: []
created_date: '2026-01-13 12:58'
labels:
  - windows
  - test-framework
  - regression
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Windows physical machine tests are failing because the app exits before the debug coordinator can execute actions.

**Symptoms:**
- App runs for ~1 second then exits
- Log shows Firebase initialization starts, RTDB GetValue called, then log ends
- `start_debug_coordinator()` is never called
- Test reports "✅ COMPLETED" but 0 actions executed

**Evidence from logs/backend.firebase.async_pattern_windows-physical_1768307519.log:**
- Only 382 lines captured
- Last entry: `[RTDB C++] Calling ref.GetValue() - DatabaseReference appears valid`
- `TASK218_COORDINATOR_READY_WITH_DIAGNOSTICS` logged but `TASK218_COORDINATOR_START` never logged

**Potential causes to investigate:**
1. Hardcoded paths in SCP command (line 885 uses `/C:/Users/...` format)
2. Windows-specific initialization timeout
3. Process termination issue with PowerShell Start-Process
4. Config not being read correctly on Windows

**Related:**
- Wake fix committed in 1701bf2a (connectivity check now working)
- Tests worked before on Windows physical machine
<!-- SECTION:DESCRIPTION:END -->
