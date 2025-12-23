---
id: task-373
title: Add run-windows recipe for quick Windows launch
status: To Do
assignee: []
created_date: '2025-12-23 23:00'
updated_date: '2025-12-23 23:41'
labels:
  - windows
  - run
  - parity
  - phase-3
dependencies:
  - task-376
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

Windows platform is missing a simple run command that exists for other platforms.

**Current state:**
- `run-android` ✅
- `run-macos` ✅
- `run-desktop` → `run-editor` ✅ (renamed)
- `run-ios-iphone/ipad` ✅
- `run-windows` ❌ MISSING

Windows has `win-physical-deploy` but no simple run command.

## Impact

- Inconsistent workflow for Windows
- Must manually combine deploy + launch steps

## Solution

Add in `justfile-platform-windows.justfile`:
```just
# Run Windows app on physical machine
run-windows:
    @just win-physical-wake-wait
    @just win-physical-deploy
    @# Launch the app
    ssh -i ~/.ssh/id_rsa administrator@192.168.50.80 \
        'cd C:\Users\Administrator\gametwo && start gametwo.exe'
```

Consider also:
- `run-windows-vm` for VM testing (if supported)
- `run-windows-debug` for debug builds
- `run-windows-release` for release builds

## Reference

Part of platform parity analysis - Phase 3 Feature Parity.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Recipe run-windows implemented in justfile-platform-windows.justfile
- [ ] #2 Recipe handles Wake-on-LAN if machine is asleep
- [ ] #3 Recipe deploys and launches app on physical machine
- [ ] #4 Validation: just run-windows wakes machine if needed
- [ ] #5 Validation: just run-windows deploys latest build
- [ ] #6 Validation: just run-windows launches gametwo.exe on physical machine
- [ ] #7 Validation: Console output shows app is running
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Order: Wave 2 (Pure Additions)

## Shared Code Path
Reuse existing `win-physical-*` helpers.

## Chunked Validation

### Chunk 1: Audit Existing Helpers
```bash
just --list | grep "win-physical"
# Review: win-physical-wake, win-physical-deploy, etc.
```

### Chunk 2: Implement run-windows
```just
# In justfile-platform-windows.justfile
run-windows:
    @echo "Starting Windows app on physical machine..."
    @just win-physical-wake-wait
    @just win-physical-deploy
    @ssh administrator@192.168.50.80 'cd gametwo && start gametwo.exe'
    @echo "✅ Windows app launched"
```

### Chunk 3: Validate
```bash
# Check machine is reachable first
just win-physical-status

# Run (requires physical machine awake)
just run-windows
```
<!-- SECTION:PLAN:END -->
