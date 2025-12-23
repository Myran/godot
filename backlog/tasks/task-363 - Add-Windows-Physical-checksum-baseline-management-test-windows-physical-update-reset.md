---
id: task-363
title: >-
  Add Windows-Physical checksum baseline management
  (test-windows-physical-update/reset)
status: To Do
assignee: []
created_date: '2025-12-23 22:58'
updated_date: '2025-12-23 23:42'
labels:
  - testing
  - parity
  - windows
  - checksum
  - phase-1
dependencies:
  - task-376
  - task-361
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

Windows-Physical platform is missing checksum baseline management recipes, making it impossible to validate determinism on physical Windows machine.

**Current state:**
- `test-android-update/reset` ✅
- `test-windows-update/reset` ✅ (VM)
- `test-windows-physical-target/manual` ✅
- `test-windows-physical-update/reset` ❌ MISSING

## Impact

- Cannot validate deterministic behavior on Windows physical machine
- No way to update baselines after legitimate changes
- Windows-Physical testing is 50% less capable than Android

## Solution

Add recipes in `justfile-platform-windows.justfile`:
1. `test-windows-physical-update CONFIG` - Update checksum baseline
2. `test-windows-physical-reset CONFIG` - Reset checksum baseline

Must handle remote file operations via SSH/SCP to physical machine (192.168.50.80).

## Reference

Part of platform parity analysis - Phase 1 Critical Parity.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Recipe test-windows-physical-update CONFIG implemented
- [ ] #2 Recipe test-windows-physical-reset CONFIG implemented
- [ ] #3 Remote file operations via SSH/SCP work correctly
- [ ] #4 Validation: just test-windows-physical-update battle-animated executes without error
- [ ] #5 Validation: just test-windows-physical-reset battle-animated executes without error
- [ ] #6 Validation: Checksum files on physical machine (192.168.50.80) are updated/removed
- [ ] #7 Validation: test-windows-physical-target detects checksum mismatches
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Order: Wave 4 (Windows-Physical Parity)

## Shared Code Path
Reuse `_update-checksum-baseline` and `_reset-checksum-baseline` helpers, but wrap with SSH for remote execution.

## Chunked Validation

### Chunk 1: Verify SSH Access
```bash
just win-physical-status
ssh administrator@192.168.50.80 "echo Connected"
```

### Chunk 2: Implement test-windows-physical-reset
```just
test-windows-physical-reset CONFIG:
    @echo "Resetting Windows-Physical baseline for {{CONFIG}}..."
    @just win-physical-wake-wait
    @ssh administrator@192.168.50.80 "rmdir /s /q checksum_baselines\\windows-physical\\{{CONFIG}}" 2>/dev/null || true
    @echo "✅ Baseline reset"
```
Validate:
```bash
just test-windows-physical-reset battle-animated
```

### Chunk 3: Implement test-windows-physical-update
```just
test-windows-physical-update CONFIG:
    @echo "Updating Windows-Physical baseline for {{CONFIG}}..."
    @just win-physical-wake-wait
    @# Copy local checksums to remote baseline location
    @scp -r tests/checksum_baselines/windows-physical/{{CONFIG}} \
        administrator@192.168.50.80:checksum_baselines/windows-physical/
    @echo "✅ Baseline updated"
```
Validate:
```bash
just test-windows-physical-update battle-animated
ssh administrator@192.168.50.80 "dir checksum_baselines\\windows-physical\\battle-animated"
```

### Chunk 4: Integration Test
```bash
just test-windows-physical-reset battle-animated
just test-windows-physical-target battle-animated
just test-windows-physical-update battle-animated
just test-windows-physical-target battle-animated  # Should pass
```
<!-- SECTION:PLAN:END -->
