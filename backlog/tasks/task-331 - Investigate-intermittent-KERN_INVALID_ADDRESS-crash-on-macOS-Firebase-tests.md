---
id: task-331
title: Investigate intermittent KERN_INVALID_ADDRESS crash on macOS Firebase tests
status: To Do
assignee: []
created_date: '2025-12-09 19:21'
labels:
  - firebase
  - macos
  - crash
  - intermittent
  - investigation
dependencies:
  - task-330
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

Intermittent crash occurs during macOS Firebase test execution. The crash happens at app cleanup/shutdown, after all test actions complete successfully.

## Crash Details

```
KERN_INVALID_ADDRESS at 0xd9
Exception 1, Code 1, Subcode 217
```

Address `0xd9` (217 decimal) suggests null pointer dereference or use-after-free.

## Triggering Test

```bash
just test-macos-target firebase-rtdb-layer
```

The crash is **intermittent** - doesn't occur on every run. Observed once during initial macOS Firebase integration testing.

## Context

- **Platform**: macOS (exported .app bundle)
- **Test Config**: `firebase-rtdb-layer` (16 RTDB actions)
- **Timing**: Occurs during app shutdown/cleanup, AFTER all actions complete
- **Sentry**: Crash captured by Sentry crash handler

## Likely Root Cause

Race condition in Firebase C++ SDK cleanup on macOS. Possible scenarios:
1. Firebase RTDB listeners not properly cleaned up before app exit
2. Use-after-free in Firebase SDK destructor
3. Thread safety issue during Firebase App::Terminate()

## Investigation Steps

1. Add logging to Firebase cleanup sequence in `firebase.mm`
2. Check if `remove_all_listeners` is called before app exit
3. Review Firebase C++ SDK desktop cleanup documentation
4. Consider adding explicit Firebase cleanup before Godot quit

## Related Files

- `godot/modules/firebase/firebase.mm` - Firebase initialization/cleanup
- `godot/modules/firebase/database.cpp` - RTDB implementation
- `tests/debug_configs/firebase-rtdb-layer.json` - Test config
- `justfiles/justfile-platform-macos.justfile` - macOS test execution

## Related Work

- task-330: Firebase macOS POC integration (parent task)
<!-- SECTION:DESCRIPTION:END -->
