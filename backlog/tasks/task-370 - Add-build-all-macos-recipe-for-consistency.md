---
id: task-370
title: Add build-all-macos recipe for consistency
status: Done
assignee: []
created_date: '2025-12-23 23:00'
updated_date: '2025-12-29 00:07'
labels:
  - build
  - macos
  - parity
  - phase-3
dependencies:
  - task-376
priority: low
ordinal: 267000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

macOS build commands use `templates-macos` instead of `build-all-macos`, breaking consistency with other platforms.

**Current state:**
- `build-all-android` ✅
- `build-all-windows` ✅
- `build-all-ios` (after task-365 rename)
- `build-all-macos` ❌ MISSING (uses `templates-macos` instead)

## Impact

- Inconsistent command discovery
- Users may try `build-all-macos` and fail
- Pattern breaks across platforms

## Solution

Add in `justfile-platform-macos.justfile`:
```just
# Complete macOS build with templates and all dependencies
build-all-macos force="no":
    @just templates-macos {{force}}
    @# Add any additional macOS-specific build steps here
```

This provides:
1. Consistent naming with other platforms
2. Single entry point for complete macOS builds
3. Room to add Sentry/Firebase integration steps later

## Reference

Part of platform parity analysis - Phase 3 Feature Parity.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Recipe build-all-macos implemented in justfile-platform-macos.justfile
- [x] #2 Recipe calls templates-macos and any additional build steps
- [x] #3 Validation: just build-all-macos executes full macOS build pipeline
- [x] #4 Validation: just --list shows build-all-macos alongside build-all-android/windows
- [ ] #5 Documentation updated to reference build-all-macos
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Order: Wave 2 (Pure Additions)

## Shared Code Path
Simple wrapper around existing `templates-macos`.

## Chunked Validation

### Chunk 1: Verify Current State
```bash
# Check what templates-macos does
just --show templates-macos
```

### Chunk 2: Implement build-all-macos
```just
# In justfile-platform-macos.justfile
# Complete macOS build with templates and all dependencies
build-all-macos force="no":
    @echo "Building all macOS components..."
    @just templates-macos {{force}}
    @echo "✅ macOS build complete"
```

### Chunk 3: Validate
```bash
# Should appear in list
just --list | grep "build-all-macos"

# Dry run (check it calls templates-macos)
just --dry-run build-all-macos
```
<!-- SECTION:PLAN:END -->
