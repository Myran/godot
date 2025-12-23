---
id: task-379
title: 'Add iOS checksum baseline management (test-ios-update, test-ios-reset)'
status: To Do
assignee: []
created_date: '2025-12-23 23:18'
updated_date: '2025-12-23 23:42'
labels:
  - testing
  - parity
  - ios
  - checksum
  - phase-1
dependencies:
  - task-376
  - task-361
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

iOS platform is missing checksum baseline management recipes, making it impossible to validate determinism across test runs.

**Current state:**
- `test-android-update/reset` ✅
- `test-macos-update/reset` ✅
- `test-editor-update/reset` ✅
- `test-ios-update/reset` ❌ MISSING

## Impact

- Cannot validate deterministic behavior on iOS
- No way to update baselines after legitimate changes
- iOS testing is 40% less capable than Android

## Solution

Add recipes in `justfile-validation-enhanced-testing.justfile`:
1. `test-ios-update CONFIG` - Update checksum baseline after legitimate changes
2. `test-ios-reset CONFIG` - Reset checksum baseline for fresh start

Follow the pattern established by Android/macOS implementations.

## Reference

Part of platform parity analysis - Phase 1 Critical Parity.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Recipe test-ios-update CONFIG implemented
- [ ] #2 Recipe test-ios-reset CONFIG implemented
- [ ] #3 Recipes follow same pattern as test-android-update/reset
- [ ] #4 Validation: just test-ios-update battle-animated executes without error
- [ ] #5 Validation: just test-ios-reset battle-animated executes without error
- [ ] #6 Validation: Checksum baseline files are created/updated correctly
- [ ] #7 Validation: test-ios-target detects checksum mismatches after changes
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Order: Wave 3 (iOS Parity) - First

## Shared Code Path
Reuse same `_update-checksum-baseline` and `_reset-checksum-baseline` helpers from task-361.

## Chunked Validation

### Chunk 1: Verify Helper Exists
```bash
# After task-361, these should exist:
rg "_reset-checksum-baseline|_update-checksum-baseline" justfiles/
```

### Chunk 2: Implement test-ios-reset
```just
test-ios-reset CONFIG:
    @just _reset-checksum-baseline ios {{CONFIG}}
```
Validate:
```bash
just test-ios-reset battle-animated
ls tests/checksum_baselines/ios/battle-animated 2>&1 | grep -q "No such file"
```

### Chunk 3: Implement test-ios-update
```just
test-ios-update CONFIG:
    @just _update-checksum-baseline ios {{CONFIG}}
```
Validate:
```bash
# Run test first to generate checksums
just test-ios-target battle-animated
# Then update baseline
just test-ios-update battle-animated
# Verify baseline created
ls tests/checksum_baselines/ios/battle-animated/
```

### Chunk 4: Integration Test
```bash
# Full cycle: reset → test → update → test (should pass)
just test-ios-reset battle-animated
just test-ios-target battle-animated  # Creates baseline
just test-ios-target battle-animated  # Should pass with baseline
```
<!-- SECTION:PLAN:END -->
