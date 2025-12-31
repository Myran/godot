---
id: task-356
title: Revert Sentry build system to build all platforms from source
status: Done
assignee: []
created_date: '2025-12-20 10:49'
updated_date: '2025-12-29 00:07'
labels:
  - sentry
  - build-system
  - scons
  - all-platforms
  - source-build
dependencies: []
priority: high
ordinal: 281000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Currently using prebuilt Sentry binaries (commit d0e7b9c0). Need to revert to previous recipes that built all platforms from source using SCons.

## Background
- Commit d0e7b9c0 switched to prebuilt binaries for all platforms
- Previously had recipes to build all platforms from source
- Now that we have proper Windows VM build, we can build ALL platforms from source

## Required Changes

### 1. Restore justfile-gdscript-sentry.justfile
From commit before d0e7b9c0, recipes to restore:
- `build-sentry-gdscript-all` - Build all platforms
- `build-sentry-gdscript-desktop` - Desktop builds (editor + template)
- `build-sentry-gdscript-android` - Android builds (lib + editor + template)
- `build-sentry-gdscript-ios` - iOS builds (editor + template)

### 2. Remove Prebuilt Dependencies
- Remove or update `download-sentry-gdscript` recipe
- Update `sentry-android-setup-libraries` to build from source
- Update all platform-specific copy recipes

### 3. Build Commands
All platforms use SCons in extras/sentry-godot:
```bash
cd extras/sentry-godot && scons target=<target> platform=<platform> [flags]
```

### 4. Platform-Specific Flags
- Desktop: `target=editor|template_release`
- Android: `platform=android build_android_lib=yes`
- iOS: `platform=ios arch=arm64 ios_simulator=no`
- Windows: `platform=windows arch=x86_64` (already implemented)

## Files to Modify
- justfiles/justfile-gdscript-sentry.justfile (restore from git history)
- justfiles/justfile-sentry.justfile (update download/build logic)
- justfiles/justfile-platform-android.justfile (update setup recipe)

## Benefits
- Full control over Sentry builds
- Consistent build process across all platforms
- No dependency on prebuilt binaries
- Can apply custom patches/modifications
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implementation complete. Restored SCons build recipes from git history and updated Android setup to build from source.

## Full Validation Plan:

### 1. Build Validation:
```bash
# Build all platforms
just build-sentry-gdscript-desktop
just build-sentry-gdscript-android  
just build-sentry-gdscript-ios
just sentry-native-android-complete
just build-sentry-all

# Verify binary placement:
# Desktop: project/addons/sentry/bin/macos/libsentry.macos.*.dylib
# Android: project/addons/sentry/bin/android/libsentry.android.*.so
# iOS: export/ios/libsentry.ios.*.xcframework
# Windows: project/addons/sentry/bin/windows/x86_64/sentry.dll
```

### 2. Runtime Validation:
Run tests on each platform and verify Sentry integration:

**Desktop:**
```bash
just fastbuild-android
just test-desktop-target production-ready
just logs-errors TEST_ID
# Look for: "Sentry initialized", "Sentry crash handler installed"
```

**Android:**
```bash
just fastbuild-android
just test-android-target production-ready
just logs-errors TEST_ID
# Look for: "Sentry Android SDK initialized", "Sentry native integration loaded"
```

**iOS:**
```bash
just build-install-ios
just test-ios production-ready
just logs-errors TEST_ID
# Look for: "Sentry iOS SDK initialized", "Sentry native crash handler active"
```

**Windows:**
```bash
just win-physical-deploy
just test-windows-physical-target production-ready
just logs-windows-physical-errors TEST_ID
# Look for: "Sentry Windows SDK initialized", "Crashpad handler started"
```

### 3. Integration Validation:
- Verify Sentry captures errors in logs
- Check Sentry dashboard for test events
- Confirm native crash handlers are loaded
- Validate all platforms send crash reports
<!-- SECTION:NOTES:END -->
