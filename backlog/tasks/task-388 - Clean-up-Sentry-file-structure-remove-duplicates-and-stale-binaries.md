---
id: task-388
title: Clean up Sentry file structure - remove duplicates and stale binaries
status: To Do
assignee: []
created_date: '2025-12-26 21:59'
updated_date: '2025-12-27 10:07'
labels:
  - cleanup
  - sentry
  - build-system
  - ios
  - android
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Summary
Audit identified duplicate binaries, stale files, and excessive build artifacts in Sentry integration totaling **18.7 GB** of project footprint.

## File Assessment

### 🔴 IMMEDIATE ACTION - Exact Duplicates (Remove)

| File | Size | Location | Assessment |
|------|------|----------|------------|
| `sentry_android_godot_plugin.debug.aar` | 24 KB | `project/addons/sentry/` | **DUPLICATE** - Same as `bin/android/` copy (MD5: 888399226af0a69fbccbb91451cc1804) |
| `sentry_android_godot_plugin.release.aar` | 22 KB | `project/addons/sentry/` | **DUPLICATE** - Same as `bin/android/` copy (MD5: 16d7f62877366940d52ad903616c783e) |
| `test.xcframework` | 0 B | `project/addons/sentry/bin/ios/temp/` | **EMPTY** - Stale test artifact |

### 🟡 REVIEW NEEDED - Debug Symbols (151 MB)

| Directory | Size | Assessment |
|-----------|------|------------|
| `project/addons/sentry/bin/macos/dSYMs/` | 103 MB | Debug symbols - needed for crash symbolication but not for release builds |
| `project/addons/sentry/bin/ios/dSYMs/` | 48 MB | Debug symbols - only needed if shipping debug builds |

**Question**: Are dSYMs being correctly uploaded to Sentry during build, or shipped in app bundles?

### 🟡 REVIEW NEEDED - Extras Directory (5.9 GB)

| Directory | Size | Assessment |
|-----------|------|------------|
| `extras/sentry-godot/` | 5.9 GB | Complete separate Sentry-Godot build environment with own binaries, modules, and build artifacts |

**Question**: Is this still needed? Consider:
- Moving to separate repository if active development
- Removing if no longer used

### 🟢 BUILD ARTIFACTS - Safe to Clean (12.6 GB)

| Directory | Size | Assessment |
|-----------|------|------------|
| `export/ios/Build/` | 12 GB | Xcode build intermediates - ephemeral |
| `project/android/build/build/intermediates/` | 584 MB | Gradle build intermediates - ephemeral |

These are recreated during builds and can be cleaned with `just clean-builds` or similar.

### 🟢 CORRECT LOCATIONS - Source Binaries (78 MB)

| Directory | Size | Platform | Assessment |
|-----------|------|----------|------------|
| `project/addons/sentry/bin/macos/*.framework` | 20 MB | macOS | ✅ Correct - GDExtension source |
| `project/addons/sentry/bin/ios/*.xcframework` | 40 MB | iOS | ✅ Correct - GDExtension source |
| `project/addons/sentry/bin/android/*.so` | 13 MB | Android | ✅ Correct - ARM64 native libs |
| `project/addons/sentry/bin/windows/x86_64/` | 5.5 MB | Windows | ✅ Correct - DLLs + crashpad |

### 🟢 EXPECTED EXPORTS - Build Outputs

| Directory | Size | Assessment |
|-----------|------|------------|
| `export/macos/gametwo.app/Contents/Frameworks/` | 16 MB | ✅ Expected - release export |
| `export/macos/gametwo_debug.app/Contents/Frameworks/` | 17 MB | ✅ Expected - debug export |
| `export/ios/*.xcframework` | 41 MB | ✅ Expected - iOS export |
| `export/windows/*.dll` | 3.5 MB | ✅ Expected - Windows export |

## PCK Bundling Concern

**Investigate**: Are xcframework/framework binaries being included in PCK files?
- PCK should only contain game resources (scenes, scripts, textures)
- Native binaries should be in app bundle, NOT in PCK
- Check: `sentry.gdextension` file references and export settings

## Architecture Notes

Current Sentry binary flow:
```
Source: project/addons/sentry/bin/{platform}/
    ↓ (GDExtension loading)
Export: export/{platform}/ (copied during export)
    ↓ (build process)
Build: project/android/build/ or export/ios/Build/ (intermediates)
```

Potential issue: dSYM files (151 MB) may be getting copied unnecessarily.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Remove 2 duplicate AAR files from project/addons/sentry/ (keep bin/android/ copies)
- [x] #2 Remove empty temp/test.xcframework directory
- [ ] #3 Verify dSYMs are uploaded to Sentry, not shipped in app bundles
- [ ] #4 Decide on extras/sentry-godot/ directory - remove or move to separate repo
- [ ] #5 Verify PCK files do not contain native binaries (xcframework, framework, dll)
- [ ] #6 Document clean build artifact commands in justfile if not present
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Progress

**2025-12-26**: Added missing macOS sync to `justfile-gdscript-sentry.justfile`

### Root Cause
macOS binaries were built in submodule but never copied to main project because:
1. `build-sentry-gdscript-desktop` only built, didn't sync
2. iOS/Android had sync steps, macOS didn't
3. Tests only check "file exists" not "version matches"

### Fix Applied
- Added `_sentry-sync-macos-binaries` private recipe
- Added `sentry-sync-macos` public command
- Desktop build now auto-syncs after building
- Verified checksums match after sync

**2025-12-27**: Cleaned up duplicates
- Removed duplicate AAR files from `project/addons/sentry/` (46 KB)
- Removed empty `temp/test.xcframework` directory
- Fixed `build-sentry-gdscript-android-lib` to stop creating duplicate AARs

**2025-12-27 (continued)**: Added Android sync and cleaned submodule
- Added `_sentry-sync-android-binaries` private recipe (syncs .so, .so.debug, .aar)
- Added `sentry-sync-android` public command
- Android build now auto-syncs after building
- Removed duplicate AAR files from submodule `extras/sentry-godot/project/addons/sentry/`
- Updated help text with new sync commands
<!-- SECTION:NOTES:END -->
