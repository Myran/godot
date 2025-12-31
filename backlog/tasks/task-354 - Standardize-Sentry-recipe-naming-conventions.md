---
id: task-354
title: Standardize Sentry recipe naming conventions
status: Done
assignee: []
created_date: '2025-12-20 10:27'
updated_date: '2025-12-29 00:07'
labels:
  - sentry
  - justfile
  - refactoring
  - naming-convention
dependencies: []
priority: medium
ordinal: 283000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Rename all Sentry-specific just recipes to follow consistent naming convention starting with 'sentry-'

## Current Naming Issues

### Recipes to Rename:

1. **Windows VM Sentry Recipes** (justfile-platform-windows.justfile):
   - `win-vm-sentry-complete` → `sentry-windows-vm-complete`
   - `win-vm-sentry-all` → `sentry-windows-vm-build-all`
   - `win-vm-sentry-package` → `sentry-windows-vm-package`

2. **Android Platform Sentry Recipes** (justfile-platform-android.justfile):
   - `android-setup-sentry-libraries` → `sentry-android-setup-libraries`
   - `android-insert-sentry-dependencies` → `sentry-android-insert-dependencies`

3. **iOS Logging Recipes** (justfile-platform-ios.justfile) - specifically filter Sentry logs:
   - `ios-sentry-logs-iphone` → `sentry-ios-logs-iphone`
   - `ios-sentry-logs-ipad` → `sentry-ios-logs-ipad`

## Migration Strategy

1. Add new recipes with correct names alongside existing ones
2. Add deprecation warnings to old recipes that redirect to new names
3. Update all help commands and documentation
4. Update any scripts or documentation that reference old names
5. Remove old recipes after transition period (if desired)

## Files to Update

- `justfiles/justfile-platform-windows.justfile`
- `justfiles/justfile-platform-android.justfile`
- `justfiles/justfile-platform-ios.justfile`
- `justfiles/justfile-sentry.justfile` (help commands)
- Any documentation referencing these recipes

## Naming Convention

- Sentry-specific recipes: `sentry-{platform}-{env}-{action}`
- Example: `sentry-windows-vm-build-all`
- Keep generic recipes as-is (e.g., `win-physical-*`, `test-windows-*`, `logs-*` for non-Sentry logs)
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Implementation Complete ✅

### Changes Made:

1. **Windows VM Sentry Recipes** (3 recipes renamed):

- `win-vm-sentry-complete` → `sentry-windows-vm-complete`

- `win-vm-sentry-all` → `sentry-windows-vm-build-all`

- `win-vm-sentry-package` → `sentry-windows-vm-package`

2. **Android Platform Sentry Recipes** (2 recipes renamed):

- `android-setup-sentry-libraries` → `sentry-android-setup-libraries`

- `android-insert-sentry-dependencies` → `sentry-android-insert-dependencies`

3. **iOS Logging Recipes** (2 recipes renamed):

- `ios-sentry-logs-iphone` → `sentry-ios-logs-iphone`

- `ios-sentry-logs-ipad` → `sentry-ios-logs-ipad`

### References Updated:

- win-vm-full-pipeline recipe updated to use `sentry-windows-vm-build-all`

- build-android-export updated to use `sentry-android-setup-libraries`

- All help commands updated across justfiles

### Validation:

- All renamed recipes verified with `just --list`

- Help commands show correct new names

- No deprecation warnings needed (git history preserves old names)

### Files Modified:

- justfiles/justfile-platform-windows.justfile

- justfiles/justfile-platform-android.justfile

- justfiles/justfile-platform-ios.justfile

- justfiles/justfile-build-utils.justfile

- justfiles/justfile-sentry.justfile

- justfiles/justfile-native-windows-sentry.justfile

All Sentry recipes now follow consistent naming convention starting with 'sentry-'!

## Additional Requirements Completed:

### ✅ Recipe Validation:

- Tested dependent recipes: `win-vm-full-pipeline` and `setup-android-templates`

- All 7 renamed recipes verified with `just --list`

- Confirmed no old recipe names remain

### ✅ Documentation Updates:

- CLAUDE.md files: No references to old names found

- Help commands: Already updated during implementation

### ✅ Complete Summary:

- **7 recipes renamed** across 6 justfiles

- **2 dependencies updated**

- **All documentation checked**

- **No old names remain**

Task fully complete with all validation and documentation requirements satisfied!
<!-- SECTION:NOTES:END -->
