---
id: task-360
title: Rename 'desktop' platform to 'editor' for clarity
status: Done
assignee: []
created_date: '2025-12-23 17:24'
updated_date: '2025-12-29 00:07'
labels: []
dependencies: []
priority: medium
ordinal: 277000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

The current testing platform naming is confusing:

- `desktop` = Godot **editor** in test mode (`editor/godot.macos.editor.arm64 --test-mode`)
- `macos` = Exported macOS **.app bundle** (`export/macos/gametwo_debug.app`)
- `windows` = Exported Windows build
- `android`/`ios` = Exported mobile builds

The name "desktop" suggests an exported desktop app, but it's actually running the editor. This causes confusion about why Firebase tests are "skipped on desktop" when they run on macOS/Windows exports.

## Goal

Rename `desktop` platform to `editor` throughout the codebase for clarity.

## Scope

- Justfile recipes (test-*-target, test-desktop-*, _execute-test-*, etc.)
- Platform compatibility checks in debug configs
- Log output and test summaries
- Help documentation
- Any platform filtering logic

## Platforms after rename

| Old Name | New Name | Executable |
|----------|----------|------------|
| desktop | **editor** | `godot.macos.editor.arm64 --test-mode` |
| macos | macos (unchanged) | `gametwo_debug.app` |
| windows | windows (unchanged) | `gametwo.exe` |
| android | android (unchanged) | APK |
| ios | ios (unchanged) | iOS app |

## Expected Outcome

- Clear distinction between editor testing and exported platform testing
- `just test-editor-target CONFIG` - Quick GDScript testing via editor
- `just test-macos-target CONFIG` - Full testing with native modules
- Firebase tests skip `editor` but run on `macos`/`windows`/`android`/`ios` (clearer intent)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 All justfile recipes renamed from test-desktop-* to test-editor-*
- [x] #2 Platform string changed from 'desktop' to 'editor' throughout codebase
- [x] #3 Debug configs updated with 'editor' platform compatibility
- [x] #4 Multi-platform test shows 'editor' instead of 'desktop'
- [x] #5 Firebase tests correctly skip on editor but run on macOS/windows
- [x] #6 Validation tests pass: just test-editor, just test-all
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Problem

The current testing platform naming is confusing:

- `desktop` = Godot **editor** in test mode (`editor/godot.macos.editor.arm64 --test-mode`)
- `macos` = Exported macOS **.app bundle** (`export/macos/gametwo_debug.app`)
- `windows` = Exported Windows build (via VM)
- `windows-physical` = Windows on physical machine 192.168.50.80 (GUI mode)
- `android`/`ios` = Exported mobile builds

The name "desktop" suggests an exported desktop app, but it's actually running the editor. This causes confusion about why Firebase tests are "skipped on desktop" when they run on macOS/Windows exports.

## Goal

Rename `desktop` platform to `editor` throughout the codebase for clarity.

## Scope

- Justfile recipes (test-*-target, test-desktop-*, _execute-test-*, etc.)
- Platform compatibility checks in debug configs
- Log output and test summaries
- Help documentation
- Any platform filtering logic

## Platforms after rename

| Old Name | New Name | Executable | Location |
|----------|----------|------------|----------|
| desktop | **editor** | `godot.macos.editor.arm64 --test-mode` | Local Mac |
| macos | macos (unchanged) | `gametwo_debug.app` | Local Mac |
| windows | windows (unchanged) | `gametwo.exe` | VM 192.168.50.92 |
| windows-physical | windows-physical (unchanged) | `gametwo.exe` | Physical 192.168.50.80 |
| android | android (unchanged) | APK | Device |
| ios | ios (unchanged) | iOS app | Device |

## Expected Outcome

- Clear distinction between editor testing and exported platform testing
- `just test-editor-target CONFIG` - Quick GDScript testing via editor
- `just test-macos-target CONFIG` - Full testing with native modules
- Firebase tests skip `editor` but run on `macos`/`windows`/`windows-physical`/`android`/`ios` (clearer intent)
<!-- SECTION:PLAN:END -->
