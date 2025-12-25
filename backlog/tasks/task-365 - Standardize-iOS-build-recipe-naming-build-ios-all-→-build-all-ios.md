---
id: task-365
title: Standardize iOS build recipe naming (build-ios-all → build-all-ios)
status: Done
assignee: []
created_date: '2025-12-23 22:59'
updated_date: '2025-12-25 17:06'
labels:
  - naming
  - ios
  - build
  - phase-2
dependencies:
  - task-376
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

iOS build recipe uses inconsistent word order compared to other platforms.

**Current naming:**
- `build-all-android` ✅
- `build-all-windows` ✅
- `build-ios-all` ❌ (inconsistent word order)

## Impact

- Inconsistent command discovery
- Users may try `build-all-ios` and fail
- Breaks pattern muscle memory

## Solution

Rename in `justfile-platform-ios.justfile`:
- `build-ios-all` → `build-all-ios`

Keep `build-ios-all` as deprecated alias for backwards compatibility (remove after 1 month).

## Reference

Part of platform parity analysis - Phase 2 Naming Standardization.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Recipe renamed from build-ios-all to build-all-ios
- [ ] #2 All internal references updated
- [ ] #3 Validation: just build-all-ios executes full iOS build pipeline
- [ ] #4 Validation: just build-ios-all returns 'recipe not found'
- [ ] #5 Validation: just --list | grep build-all- shows consistent naming
- [ ] #6 Documentation updated to reference new name
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Order: Wave 5 (Direct Renames)

## No Aliases - Direct Rename with Reference Updates

## Chunked Validation

### Chunk 1: Rename Recipe
```bash
# In justfile-platform-ios.justfile
# Change: build-ios-all → build-all-ios

# Validate new name works
just build-all-ios --dry-run

# Verify old name gone
just build-ios-all 2>&1 | grep -q "not found"
```

### Chunk 2: Update Internal References
```bash
# Find recipes that call build-ios-all
rg "build-ios-all" justfiles/

# Update each to build-all-ios
# Validate each calling recipe still works
```

### Chunk 3: Update Documentation
```bash
# Find doc references
rg "build-ios-all" CLAUDE.md CLAUDE-ADVANCED.md

# Update all
# Validate
rg "build-ios-all" CLAUDE.md  # Should return empty
```

### Chunk 4: Verify Naming Consistency
```bash
just --list | grep "build-all-"
# Should show: build-all-android, build-all-ios, build-all-windows, build-all-macos
```
<!-- SECTION:PLAN:END -->
