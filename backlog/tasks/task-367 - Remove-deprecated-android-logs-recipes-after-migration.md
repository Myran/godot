---
id: task-367
title: Remove deprecated android-logs-* recipes after migration
status: To Do
assignee: []
created_date: '2025-12-23 22:59'
updated_date: '2025-12-23 23:43'
labels:
  - cleanup
  - android
  - logs
  - phase-2
dependencies:
  - task-375
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

Three deprecated Android log recipes still exist and should be removed after migration period.

**Deprecated recipes:**
```
android-logs-clear-lightweight  → Use logs-android-clear
android-logs-health-check       → Use logs-android-health  
android-logs-search             → Use logs-android-device
```

These have deprecation warnings but are still present in the codebase.

## Impact

- Codebase clutter
- Potential confusion for users
- Maintenance burden

## Solution

1. Verify no active usage in scripts/documentation
2. Remove recipes from `justfile-android-device-logs.justfile`
3. Update any documentation referencing old names

## Timing

Remove after confirming migration is complete (check git blame for last usage).

## Reference

Part of platform parity analysis - Phase 2 Naming Standardization.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Verify no active usage of deprecated recipes in scripts/documentation
- [ ] #2 Remove android-logs-clear-lightweight from justfile
- [ ] #3 Remove android-logs-health-check from justfile
- [ ] #4 Remove android-logs-search from justfile
- [ ] #5 Validation: just android-logs-clear-lightweight returns 'recipe not found'
- [ ] #6 Validation: just logs-android-clear still works
- [ ] #7 Validation: just logs-android-health still works
- [ ] #8 Validation: just logs-android-device still works
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Order: Wave 5 (Cleanup) - After task-375

Only proceed after task-375 confirms no usage of deprecated names.

## Chunked Validation

### Chunk 1: Verify No Usage
```bash
# Search entire codebase for deprecated names
rg "android-logs-clear-lightweight|android-logs-health-check|android-logs-search" \
   --type-add 'all:*' -g '!*.log' -g '!*.md'

# If any hits, update those files first
```

### Chunk 2: Remove android-logs-clear-lightweight
```bash
# Remove from justfile-android-device-logs.justfile
# Validate replacement works
just logs-android-clear

# Verify removed
just android-logs-clear-lightweight 2>&1 | grep -q "not found"
```

### Chunk 3: Remove android-logs-health-check
```bash
# Remove from justfile
# Validate replacement works
just logs-android-health

# Verify removed
just android-logs-health-check 2>&1 | grep -q "not found"
```

### Chunk 4: Remove android-logs-search
```bash
# Remove from justfile
# Validate replacement works
just logs-android-device "test"

# Verify removed
just android-logs-search 2>&1 | grep -q "not found"
```

### Chunk 5: Final Verification
```bash
# No deprecated recipes remain
just --list | grep -E "android-logs-(clear-lightweight|health-check|search)"
# Should return empty
```
<!-- SECTION:PLAN:END -->
