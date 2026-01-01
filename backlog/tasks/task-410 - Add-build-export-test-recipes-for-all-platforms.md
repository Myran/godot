---
id: task-410
title: Add build-export-test recipes for all platforms
status: Done
assignee: []
created_date: '2026-01-01 12:57'
updated_date: '2026-01-01 13:01'
labels: []
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create unified build-export-test recipes that rebuild templates, export, and test on all platforms.

**Platform-specific recipes (optional CONFIG argument):**
- `build-export-test-android [CONFIG]` - Android
- `build-export-test-ios [CONFIG]` - iOS
- `build-export-test-macos [CONFIG]` - macOS
- `build-export-test-windows [CONFIG]` - Windows

**Cross-platform:**
- `build-export-test-all [CONFIG]` - All platforms

Each recipe should:
1. Rebuild templates with Firebase C++ module (reuse existing rebuild recipes)
2. Export platform app
3. Deploy (if applicable)
4. Run tests (full suite or specific CONFIG)

**Implementation notes:**
- **Android**: Reuse `just build-all-android` (templates + export)
- **iOS**: Reuse `just rebuild-all-ios` or `templates-ios + build-ios-app`
- **macOS**: Reuse `just macos-build-template + package-macos-template`
- **Windows**: VM workflow - `win-vm-sync → win-vm-template-debug → win-vm-templates-package → export-windows-debug`

**File to create:** `justfiles/justfile-build-export-test.justfile`
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 build-export-test-android recipe exists and runs full rebuild + test
- [x] #2 build-export-test-ios recipe exists and runs full rebuild + test
- [x] #3 build-export-test-macos recipe exists and runs full rebuild + test
- [x] #4 build-export-test-windows recipe exists and runs full rebuild + test (VM workflow)
- [x] #5 build-export-test-all recipe executes all platforms
- [x] #6 All recipes accept optional CONFIG argument for specific tests
- [x] #7 Windows properly handles VM sync + rebuild + package workflow
- [x] #8 Recipes reuse existing rebuild recipes (DRY principle)
<!-- AC:END -->
