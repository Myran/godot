---
id: task-389
title: 'Rename Sentry build recipes: desktop → macos for consistency'
status: Done
assignee: []
created_date: '2025-12-27 10:00'
updated_date: '2025-12-27 14:51'
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
Sentry build recipes use inconsistent naming. Need to unify for consistency.

## Changes Required

### 1. Desktop → macOS Rename ✅ DONE
**Current → Proposed:**
- `build-sentry-gdscript-desktop` → `build-sentry-gdscript-macos`
- `build-sentry-gdscript-editor-desktop` → `build-sentry-gdscript-editor-macos`
- `build-sentry-gdscript-template-desktop` → `build-sentry-gdscript-template-macos`

### 2. Windows VM Recipes Rename ⏳ PENDING
**Current → Proposed:**
- `sentry-windows-vm-build-all` → `build-sentry-native-windows-vm-build-all`
- `sentry-windows-vm-package` → `build-sentry-native-windows-vm-package`
- `sentry-windows-vm-complete` → `build-sentry-native-windows-vm-complete`

### 3. Add Native macOS Sentry ⏳ PENDING
Create `justfile-native-macos-sentry.justfile` matching iOS/Android pattern.

## Files to Update
- `justfiles/justfile-gdscript-sentry.justfile`
- `justfiles/justfile-sentry.justfile`
- `justfiles/justfile-native-macos-sentry.justfile`
- `justfiles/justfile-native-windows-sentry.justfile`
- `justfiles/justfile-platform-windows.justfile`
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Rename build-sentry-gdscript-desktop to build-sentry-gdscript-macos
- [x] #2 Rename build-sentry-gdscript-editor-desktop to build-sentry-gdscript-editor-macos
- [x] #3 Rename build-sentry-gdscript-template-desktop to build-sentry-gdscript-template-macos
- [x] #4 Update help text in justfile-gdscript-sentry.justfile
- [x] #5 Update any references in other justfiles
- [x] #6 Test renamed recipes work correctly

- [ ] #7 [x] #1 Rename build-sentry-gdscript-desktop to build-sentry-gdscript-macos
- [ ] #8 [x] #2 Rename build-sentry-gdscript-editor-desktop to build-sentry-gdscript-editor-macos
- [ ] #9 [x] #3 Rename build-sentry-gdscript-template-desktop to build-sentry-gdscript-template-macos
- [ ] #10 [x] #4 Update help text in justfile-gdscript-sentry.justfile
- [ ] #11 [x] #5 Create justfile-native-macos-sentry.justfile
- [x] #12 [x] #6 Rename Windows VM recipes to build-sentry-native-windows-vm-* pattern
- [x] #13 [x] #7 Update all references in other justfiles
- [x] #14 [x] #8 Test renamed recipes work correctly
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
["## Native Windows Sentry Testing Assessment (2025-12-27)", "", "### All Recipe Tests: ✅ PASSED", "", "1. help-sentry-native-windows ✅ - Shows comprehensive help", "2. sentry-native-windows-status ✅ - Queries VM for .lib files (MSVC format)", "3. build-sentry-native-windows-debug ✅ - Smart rebuild, SCons via SSH", "4. build-sentry-native-windows-release ✅ - Smart rebuild, SCons via SSH", "5. build-sentry-native-windows-all ✅ - Builds debug+release sequentially", "6. sentry-native-windows-complete ✅ - Builds + validates in one workflow", "7. sentry-native-windows-validate ✅ - Validates both builds on VM", "8. sentry-native-windows-clean ✅ - Cleans artifacts via SSH", "", "### Integration Tests: ✅ PASSED", "", "- build-sentry-all: Now includes native Windows (iOS→Android→macOS→Windows→GDScript)", "- validate-sentry-all: Validates native Windows via SSH to VM", "", "### Architecture Verified:", "", "- VM-based builds (192.168.50.92) via SSH with vcvars64.bat", "- Native Sentry: Compiled INTO template (.lib) captures C++ crashes", "- GDExtension: Runtime DLL (.dll) captures script crashes", "", "### Assessment:", "", "All recipes working correctly. Native Windows Sentry is now fully integrated into the Sentry build system with consistent naming patterns matching iOS/Android/macOS platforms."]
<!-- SECTION:NOTES:END -->
