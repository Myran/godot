---
id: task-358
title: Refactor platform test commands to share config resolution logic
status: Done
assignee: []
created_date: '2025-12-21 15:33'
updated_date: '2025-12-29 00:07'
labels:
  - testing
  - windows
  - infrastructure
  - bug
dependencies: []
priority: medium
ordinal: 279000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The platform test commands (`test-android-target`, `test-desktop-target`, `test-macos-target`, `test-windows-physical-target`) have divergent implementations for config resolution. This causes bugs where some platforms support features others don't.

**Current Problem:**
`test-windows-physical-target` doesn't support test lists, only direct debug configs - causing full-pipeline failures.

**Error observed:**
```
🖥️  Windows Physical Machine Testing: main
✅ Machine online after 30s
❌ Config not found: tests/debug_configs/main.json
```

**Root cause - Code duplication:**
Each platform has its own config resolution logic instead of sharing a common implementation:
- `test-android-target` - supports test lists, @ references, folder patterns
- `test-desktop-target` - supports test lists, @ references, folder patterns
- `test-macos-target` - supports test lists, @ references, folder patterns
- `test-windows-physical-target` - ❌ only supports direct debug configs

**Architectural fix:**
Extract config resolution into a shared helper recipe (e.g., `_resolve-test-config`) that all platform test commands use. This ensures:
1. Feature parity across all platforms
2. Single point of maintenance
3. Consistent behavior
4. Bugs fixed once, fixed everywhere

**Config resolution features to share:**
- Direct debug config lookup (`tests/debug_configs/`)
- Test list resolution (`tests/test-lists/`)
- `@` symbol references (`@system-all`)
- Folder patterns (`/archive/generated-replays/`)
- Wildcard expansion (`cpp.*`)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Create shared _resolve-test-config helper recipe
- [ ] #2 Refactor test-android-target to use shared helper
- [ ] #3 Refactor test-desktop-target to use shared helper
- [ ] #4 Refactor test-macos-target to use shared helper

- [ ] #5 Refactor test-windows-physical-target to use shared helper
- [ ] #6 All platforms support: direct configs, test lists, @ references, folder patterns
- [ ] #7 full-pipeline runs successfully on all platforms
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Implementation Complete (2025-12-21)

**Changes Made:**
1. Refactored `test-windows-physical-target` to use shared `_execute-test-with-analysis`
2. Added `windows-physical` case to all platform switches in justfile-validation-enhanced-testing.justfile:
   - Test execution switch (~line 2920)
   - Checksum validation switch (~line 607)
   - Log reading switch (~line 1574)
   - Log extraction switch (~line 949)
   - Platform validation switch (~line 1248)
   - Error debug command switch (~line 1430)
3. Created shared helpers in justfile-platform-windows.justfile:
   - `_deploy-config-windows-physical`
   - `_execute-test-windows-physical`

**Validation:**
- Full test pipeline completed successfully
- windows-physical now resolves test lists correctly
- All windows-physical tests passed (💻 icon in summary)
- Shared code path with other platforms confirmed working
<!-- SECTION:NOTES:END -->
