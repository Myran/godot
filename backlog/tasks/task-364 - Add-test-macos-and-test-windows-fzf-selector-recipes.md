---
id: task-364
title: Add test-macos and test-windows fzf selector recipes
status: Done
assignee: []
created_date: '2025-12-23 22:58'
updated_date: '2025-12-24 00:09'
labels:
  - testing
  - parity
  - ux
  - phase-1
dependencies:
  - task-376
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

macOS and Windows platforms are missing fzf selector recipes for interactive config selection.

**Current state:**
- `test-android` ✅ (fzf selector)
- `test-editor` ✅ (fzf selector)
- `test-ios` ✅ (fzf selector)
- `test-macos` ❌ MISSING (only has target/manual)
- `test-windows` ❌ MISSING (only has target/manual)

## Impact

Users must remember exact config names for macOS/Windows testing instead of using interactive selection.

## Solution

Add recipes in respective platform justfiles:
1. `test-macos CONFIG=""` - Interactive selector with fzf when CONFIG empty
2. `test-windows CONFIG=""` - Interactive selector with fzf when CONFIG empty

Follow the pattern of `test-android` and `test-editor` selectors.

## Reference

Part of platform parity analysis - Phase 1 Critical Parity.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Recipe test-macos implemented with fzf selector
- [x] #2 Recipe test-windows implemented with fzf selector
- [x] #3 Empty CONFIG triggers interactive selection
- [x] #4 Validation: just test-macos shows fzf picker with available configs
- [x] #5 Validation: just test-windows shows fzf picker with available configs
- [x] #6 Validation: Selecting a config runs test-{platform}-target correctly
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Order: Wave 2 (Pure Additions)

## Shared Code Path
Reuse existing fzf selector pattern from `test-android` and `test-editor`.

## Chunked Validation

### Chunk 1: Identify Selector Pattern
```bash
# Find existing selector implementation
rg "^test-android:" justfiles/ -A15
rg "fzf" justfiles/justfile-testing-core.justfile
```

### Chunk 2: Implement test-macos
```just
# In justfile-platform-macos.justfile
test-macos CONFIG="":
    #!/usr/bin/env bash
    if [[ -z "{{CONFIG}}" ]]; then
        CONFIG=$(just _fzf-config-selector "macos")
        [[ -z "$CONFIG" ]] && exit 1
    fi
    just test-macos-target "$CONFIG"
```
Validate: `just test-macos` shows fzf picker

### Chunk 3: Implement test-windows
```just
# In justfile-platform-windows.justfile
test-windows CONFIG="":
    # Same pattern as test-macos
```
Validate: `just test-windows` shows fzf picker

### Chunk 4: Verify Integration
```bash
# Both should list in just --list
just --list | grep -E "^test-macos |^test-windows "
```
<!-- SECTION:PLAN:END -->
