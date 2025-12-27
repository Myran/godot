---
id: task-389
title: 'Rename Sentry build recipes: desktop → macos for consistency'
status: Done
assignee: []
created_date: '2025-12-27 10:00'
updated_date: '2025-12-27 10:01'
labels:
  - refactor
  - sentry
  - naming-consistency
dependencies: []
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Summary
Sentry build recipes use "desktop" naming while test recipes were renamed to use "editor" for Godot editor and "macos" for exported apps (commit a100fe20).

## Current Naming (Inconsistent)

**Sentry Build Recipes:**
```
build-sentry-gdscript-desktop          # Builds for macOS
build-sentry-gdscript-editor-desktop   # macOS editor target
build-sentry-gdscript-template-desktop # macOS template target
```

**Test Recipes (after task-360 rename):**
```
test-editor-*   # Godot editor (no Firebase)
test-macos-*    # Exported macOS .app
test-android-*  # Android export
```

## Proposed Rename

| Current | Proposed |
|---------|----------|
| `build-sentry-gdscript-desktop` | `build-sentry-gdscript-macos` |
| `build-sentry-gdscript-editor-desktop` | `build-sentry-gdscript-editor-macos` |
| `build-sentry-gdscript-template-desktop` | `build-sentry-gdscript-template-macos` |
| `_sentry-sync-macos-binaries` | ✅ Already correct |
| `sentry-sync-macos` | ✅ Already correct |

## Context

The SCons build targets are:
- `target=editor` - Editor build
- `target=template_release` - Release template build

Without a `platform=` flag, SCons builds for the current host (macOS).

The new sync recipes added today already use "macos" naming correctly.

## Files to Update
- `justfiles/justfile-gdscript-sentry.justfile`
- Help text in `justfile-sentry.justfile`
- Any references in other justfiles
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Rename build-sentry-gdscript-desktop to build-sentry-gdscript-macos
- [x] #2 Rename build-sentry-gdscript-editor-desktop to build-sentry-gdscript-editor-macos
- [x] #3 Rename build-sentry-gdscript-template-desktop to build-sentry-gdscript-template-macos
- [x] #4 Update help text in justfile-gdscript-sentry.justfile
- [x] #5 Update any references in other justfiles
- [x] #6 Test renamed recipes work correctly
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Completed 2025-12-27

Renamed all desktop references to macos:
- `build-sentry-gdscript-desktop` → `build-sentry-gdscript-macos`
- `build-sentry-gdscript-editor-desktop` → `build-sentry-gdscript-editor-macos`
- `build-sentry-gdscript-template-desktop` → `build-sentry-gdscript-template-macos`
- Updated help text and echo messages
- No references in other justfiles
- Dry run verified recipe works
<!-- SECTION:NOTES:END -->
