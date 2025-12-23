---
id: task-371
title: 'Add iOS export recipes (export-ios-all, export-ios-debug, export-ios-release)'
status: To Do
assignee: []
created_date: '2025-12-23 23:00'
updated_date: '2025-12-23 23:42'
labels:
  - export
  - ios
  - parity
  - phase-3
dependencies:
  - task-365
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

iOS export commands are inconsistent with other platforms and incomplete.

**Current state:**
- `export-android-all` → `export-all-android` ✅
- `export-macos-all`, `export-macos-debug`, `export-macos-release` ✅
- `export-windows-all`, `export-windows-debug`, `export-windows-release` ✅
- `export-pck-ios` ✅ (PCK only)
- `export-ios-all` ❌ MISSING
- `export-ios-debug` ❌ MISSING
- `export-ios-release` ❌ MISSING

iOS only has PCK export, not full IPA/app exports.

## Impact

- Incomplete iOS export workflow
- Must use `build-ios-app-debug/release` instead of unified export commands
- Breaks pattern consistency

## Solution

Add in `justfile-platform-ios.justfile`:
1. `export-ios-debug` - Export debug iOS app (PCK + build)
2. `export-ios-release` - Export release iOS app (PCK + build)
3. `export-ios-all` - Export both debug and release

These should orchestrate:
1. PCK export via Godot
2. Xcode build via `build-ios-app-*`
3. Output .ipa or .app bundle

## Complexity Note

iOS exports are more complex than other platforms due to code signing, provisioning profiles, and Xcode requirements. May need to document limitations.

## Reference

Part of platform parity analysis - Phase 3 Feature Parity.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Recipe export-ios-debug implemented (PCK + Xcode debug build)
- [ ] #2 Recipe export-ios-release implemented (PCK + Xcode release build)
- [ ] #3 Recipe export-ios-all implemented (both variants)
- [ ] #4 Validation: just export-ios-debug produces debug .app bundle
- [ ] #5 Validation: just export-ios-release produces release .app bundle
- [ ] #6 Validation: just export-ios-all produces both variants
- [ ] #7 Code signing and provisioning handled correctly
- [ ] #8 Documentation notes any iOS-specific limitations
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Order: Wave 3 (iOS Parity) - After task-365

Wait for task-365 to rename build-ios-all → build-all-ios first.

## Shared Code Path
Wrap existing `export-pck-ios` and `build-ios-app-*` recipes.

## Chunked Validation

### Chunk 1: Audit Existing iOS Export
```bash
just --list | grep -E "export.*ios|build-ios"
# Understand: export-pck-ios, build-ios-app-debug, build-ios-app-release
```

### Chunk 2: Implement export-ios-debug
```just
export-ios-debug:
    @echo "Exporting iOS debug build..."
    @just export-pck-ios
    @just build-ios-app-debug
    @echo "✅ iOS debug export complete"
```
Validate: `just export-ios-debug` produces .app

### Chunk 3: Implement export-ios-release
```just
export-ios-release:
    @echo "Exporting iOS release build..."
    @just export-pck-ios
    @just build-ios-app-release
    @echo "✅ iOS release export complete"
```
Validate: `just export-ios-release` produces .app

### Chunk 4: Implement export-ios-all
```just
export-ios-all:
    @just export-ios-debug
    @just export-ios-release
```
Validate: `just export-ios-all` produces both variants

### Chunk 5: Verify Naming Consistency
```bash
just --list | grep "export-ios"
just --list | grep "export-macos"
# Patterns should match
```
<!-- SECTION:PLAN:END -->
