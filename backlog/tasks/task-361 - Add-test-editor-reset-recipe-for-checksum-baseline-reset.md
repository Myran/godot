---
id: task-361
title: Add test-editor-reset recipe for checksum baseline reset
status: Done
assignee: []
created_date: '2025-12-23 22:58'
updated_date: '2025-12-29 00:07'
labels:
  - testing
  - parity
  - editor
  - phase-1
dependencies:
  - task-376
priority: medium
ordinal: 276000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

The editor platform has `test-editor-update` for updating checksum baselines but is missing `test-editor-reset` for resetting baselines completely.

**Current state:**
- `test-android-reset` ✅
- `test-macos-reset` ✅
- `test-windows-reset` ✅
- `test-editor-reset` ❌ MISSING

## Impact

Cannot reset checksum baselines for editor testing when starting fresh or after baseline corruption.

## Solution

Add `test-editor-reset CONFIG` recipe in `justfile-validation-enhanced-testing.justfile` following the pattern of `test-android-reset`.

## Reference

Part of platform parity analysis - Phase 1 Critical Parity.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Recipe test-editor-reset CONFIG implemented in justfile-validation-enhanced-testing.justfile
- [x] #2 Recipe follows same pattern as test-android-reset
- [x] #3 Validation: just test-editor-reset battle-animated executes without error
- [x] #4 Validation: Checksum baseline files are removed after reset
- [x] #5 Validation: Subsequent test-editor-target creates fresh baseline
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Order: Wave 2 (Pure Additions)

## Shared Code Path
Reuse existing `_reset-checksum-baseline` helper or create one that Android/macOS/editor all share.

## Chunked Validation

### Chunk 1: Identify Shared Pattern
```bash
# Find existing reset implementation
rg "test-android-reset|test-macos-reset" justfiles/ -A10
# Identify common logic to extract
```

### Chunk 2: Create/Reuse Helper (if needed)
```just
# If helper doesn't exist, create:
_reset-checksum-baseline PLATFORM CONFIG:
    @rm -rf "tests/checksum_baselines/{{PLATFORM}}/{{CONFIG}}"
    @echo "Reset {{PLATFORM}} baseline for {{CONFIG}}"
```

### Chunk 3: Implement test-editor-reset
```just
test-editor-reset CONFIG:
    @just _reset-checksum-baseline editor {{CONFIG}}
```

### Chunk 4: Validate
```bash
# Create dummy baseline
mkdir -p tests/checksum_baselines/editor/battle-animated
touch tests/checksum_baselines/editor/battle-animated/test.json

# Run reset
just test-editor-reset battle-animated

# Verify removed
ls tests/checksum_baselines/editor/battle-animated 2>&1 | grep -q "No such file"
```
<!-- SECTION:PLAN:END -->
