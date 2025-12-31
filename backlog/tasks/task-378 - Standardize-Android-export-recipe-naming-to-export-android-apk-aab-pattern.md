---
id: task-378
title: Standardize Android export recipe naming to export-android-apk/aab pattern
status: Done
assignee: []
created_date: '2025-12-23 23:16'
updated_date: '2025-12-29 00:07'
labels:
  - naming
  - android
  - export
  - phase-2
dependencies:
  - task-376
priority: low
ordinal: 250
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

Android export recipes use inconsistent naming pattern compared to other platforms.

**Current naming:**
- `export-apk-debug` / `export-apk-release` ❌ (format-first)
- `export-aab-android` ❌ (mixed pattern)
- `export-apk-android` ❌ (format-first)

**Other platforms use platform-first:**
- `export-macos-debug` / `export-macos-release` ✅
- `export-windows-debug` / `export-windows-release` ✅
- `export-ios-debug` / `export-ios-release` (planned)

## Solution

Rename to `export-android-{format}[-variant]` pattern:

| Old Name | New Name |
|----------|----------|
| `export-apk-debug` | `export-android-apk-debug` |
| `export-apk-release` | `export-android-apk-release` |
| `export-apk-android` | `export-android-apk` (both variants) |
| `export-aab-android` | `export-android-aab` |
| `export-all-android` | Keep as-is (already correct) |

Also consider:
- `export-android-aab-debug` / `export-android-aab-release` if AAB has variants

Keep old names as deprecated aliases for backwards compatibility.

## Benefits

- Consistent `export-{platform}-*` pattern across all platforms
- Easier command discovery with `just --list | grep export-android`
- Clear distinction: platform first, then format, then variant

## Reference

Part of platform parity analysis - Phase 2 Naming Standardization.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Recipe export-apk-debug renamed to export-android-apk-debug
- [ ] #2 Recipe export-apk-release renamed to export-android-apk-release
- [ ] #3 Recipe export-apk-android renamed to export-android-apk
- [ ] #4 Recipe export-aab-android renamed to export-android-aab
- [ ] #5 All internal references updated
- [ ] #6 Validation: just export-android-apk-debug produces debug APK
- [ ] #7 Validation: just export-android-apk-release produces release APK
- [ ] #8 Validation: just export-android-aab produces AAB
- [ ] #9 Validation: just export-apk-debug returns 'recipe not found'
- [ ] #10 Validation: just --list | grep export-android shows consistent naming
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Order: Wave 5 (Direct Renames)

## No Aliases - Direct Rename with Reference Updates

## Chunked Validation

### Chunk 1: Rename APK Recipes
```bash
# In justfile-platform-android.justfile
export-apk-debug → export-android-apk-debug
export-apk-release → export-android-apk-release
export-apk-android → export-android-apk

# Validate
just export-android-apk-debug --dry-run
just export-android-apk-release --dry-run
just export-android-apk --dry-run

# Verify old names gone
just export-apk-debug 2>&1 | grep -q "not found"
```

### Chunk 2: Rename AAB Recipe
```bash
export-aab-android → export-android-aab

# Validate
just export-android-aab --dry-run
```

### Chunk 3: Update Internal References
```bash
# Find all references
rg "export-apk-debug|export-apk-release|export-apk-android|export-aab-android" justfiles/

# Update each
# Validate calling recipes work
```

### Chunk 4: Update Documentation
```bash
rg "export-apk-|export-aab-" CLAUDE.md CLAUDE-ADVANCED.md justfiles/CLAUDE.md

# Update all references
# Validate none remain
```

### Chunk 5: Verify Pattern Consistency
```bash
just --list | grep "export-android-"
# Should show:
# export-android-apk
# export-android-apk-debug
# export-android-apk-release
# export-android-aab
# export-all-android
```
<!-- SECTION:PLAN:END -->
