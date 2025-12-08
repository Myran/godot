---
id: task-328
title: Integrate macOS into test system with aligned just recipes
status: To Do
assignee: []
created_date: '2025-12-08 18:46'
labels:
  - macos
  - testing
  - infrastructure
  - just-recipes
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add macOS platform support to the automated testing infrastructure, aligning with existing Android and desktop test patterns.

## Context
macOS export support was added in commit d2ba527f with:
- `justfile-platform-macos.justfile` - template building and export recipes
- `run-macos`, `run-macos-background`, `run-macos-release` - run commands
- `export-macos-debug`, `export-macos-release` - export commands

## Required Integration
Align macOS testing recipes with existing patterns:
- `test-android-target CONFIG` / `test-desktop-target CONFIG`
- `test-android-manual CONFIG` / `test-desktop-manual CONFIG`
- Cross-platform test orchestration in `justfile-cross-platform-testing.justfile`

## Scope
1. Add `test-macos-target CONFIG` - automated testing with validation
2. Add `test-macos-manual CONFIG` - manual testing mode
3. Integrate macOS into `just test` and `just test-all` cross-platform recipes
4. Add macOS log extraction recipes (`logs-macos TEST_ID`)
5. Consider macOS-specific checksum validation if needed
6. Update help documentation
<!-- SECTION:DESCRIPTION:END -->
