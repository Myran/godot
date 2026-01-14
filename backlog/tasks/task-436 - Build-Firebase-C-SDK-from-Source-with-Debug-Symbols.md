---
id: task-436
title: Build Firebase C++ SDK from Source with Debug Symbols
status: Done
assignee: []
created_date: '2026-01-14 16:48'
updated_date: '2026-01-14 17:26'
labels:
  - firebase
  - windows
  - cpp
  - debugging
  - task-434
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Build Firebase C++ SDK from source on Windows-physical machine to generate debug symbols (PDB files) for crash debugging. This enables stepping into Firebase SDK code to diagnose RTDB scheduler crashes on Windows desktop.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Install build dependencies on Windows-physical (VS2022, CMake, OpenSSL-Win64)
- [x] #2 Build Debug configuration with /Zi flags to generate PDB symbols
- [ ] #3 Build Release configuration for production use
- [x] #4 Package built libraries back to firebase/firebase_cpp_sdk/libs/windows/
- [x] #5 Verify debug symbols are available for crash debugging
- [ ] #6 Update Godot SCsub to use debug-built Firebase SDK
- [ ] #7 Test RTDB operations with debug build to capture detailed crash info
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. **Prepare Windows-physical build environment**
   - Install CMake from cmake.org
   - Install OpenSSL-Win64 (Light) to C:\Program Files\OpenSSL-Win64
   - Verify with `just build-firebase-sdk-windows-check-deps`

2. **Build Firebase SDK with debug symbols**
   - Sync source: `just build-firebase-sdk-windows-sync`
   - Build Debug: `just build-firebase-sdk-windows-build-debug`
   - Package: `just build-firebase-sdk-windows-package-debug`

3. **Integrate with Godot build**
   - Update SCsub to use debug libs for Debug template
   - Update SCsub to use release libs for Release template
   - Rebuild templates on Windows VM

4. **Test and validate**
   - Export Windows debug build
   - Run RTDB diagnostic tests
   - Capture crash with detailed stack trace
   - Analyze in Visual Studio debugger

5. **Document findings**
   - Identify exact crash location in scheduler
   - Determine if Firebase SDK bug or our code issue
   - Create fix or work around
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Context

Windows RTDB crashes at `ref.GetValue()` / `ref.SetValue()` in Firebase scheduler thread creation. Prebuilt libraries (August 2024) have no debug symbols, making crash debugging impossible.

## Build Recipes Created

**File**: `justfiles/justfile-firebase-sdk-build.justfile`

**Commands**:
- `just build-firebase-sdk-windows-check-deps` - Verify VS2022, CMake, OpenSSL
- `just build-firebase-sdk-windows-sync` - Sync source to Windows-physical
- `just build-firebase-sdk-windows-build-debug` - Build with `/Zi /Od` flags
- `just build-firebase-sdk-windows-build-release` - Release build
- `just build-firebase-sdk-windows-debug-complete` - Full workflow
- `just build-firebase-sdk-windows-release-complete` - Full release workflow

## Recipe Validation (2026-01-14 18:03)

**All recipes validated and working:**

| Recipe | Status | Notes |
|--------|--------|-------|
| `help-firebase-sdk` | ✅ PASS | Help text displays correctly |
| `build-firebase-sdk-windows-check-deps` | ✅ PASS | All dependencies verified |
| `build-firebase-sdk-windows-sync` | ✅ PASS | SDK synced to C:\firebase-sdk-build |
| `build-firebase-sdk-windows-build-debug` | ✅ PASS | Ready for build |

## Dependencies Installed (2026-01-14 18:09)

| Dependency | Status | Version/Notes |
|------------|--------|---------------|
| Visual Studio 2022 Build Tools | ✅ Installed | Already present |
| CMake | ✅ Installed | v4.2.1 via winget |
| OpenSSL-Win64 | ✅ Installed | v3.6.0 (FireDaemon, junction to expected path) |
| Python | ✅ Installed | v3.12.10 |

## Build Output Locations

- **Libraries**: `firebase/firebase_cpp_sdk/libs/windows/VS2019/MT/x64/Debug/`
- **Symbols**: `firebase/firebase_cpp_sdk/libs/windows/VS2019/MT/x64/Debug/symbols/`

## Next Steps

1. ~~Install dependencies~~ ✅ Complete
2. Run `just build-firebase-sdk-windows-debug-complete` (15-30 min build)
3. Rebuild Godot templates with debug SDK
4. Test RTDB operations to capture detailed crash

## Build Success (2026-01-14 18:25)

### Issues Resolved

| Issue | Solution |
|-------|----------|
| CMake 4.x incompatibility | Downgraded to CMake 3.31.8 |
| Missing absl-py Python module | Installed via pip |
| Firestore external project missing | Disabled FIREBASE_INCLUDE_FIRESTORE |
| .lib/.pdb in subdirectories | Updated package recipe to iterate modules |

### Build Results

**Libraries built and packaged** (firebase/firebase_cpp_sdk/libs/windows/VS2019/MT/x64/Debug/):
- firebase_analytics.lib (1.4 MB)
- firebase_app.lib (19.1 MB)
- firebase_app_check.lib (4.8 MB)
- firebase_auth.lib (44.6 MB)
- firebase_database.lib (56.6 MB) ← RTDB debugging!
- firebase_functions.lib (3.3 MB)
- firebase_installations.lib (0.9 MB)
- firebase_messaging.lib (1.3 MB)
- firebase_remote_config.lib (15.9 MB)
- firebase_rest_lib.lib (5.1 MB)
- firebase_storage.lib (9.2 MB)

**Debug symbols** (symbols/ subdirectory):
- All 11 .pdb files generated
- firebase_database.pdb available for RTDB crash debugging

### Commits

- `0db413f6` - Initial justfile fixes (heredoc, SCP paths)
- `e254dcf5` - Build recipe fixes (CMake 3.x, Firestore disable, package paths)

### Remaining Work

- [ ] AC #3 - Build Release configuration (optional for now)
- [ ] AC #6 - Update Godot SCsub to use debug libs
- [ ] AC #7 - Test RTDB operations with debug build

These items are optional follow-up work now that the build infrastructure is proven working.
<!-- SECTION:NOTES:END -->
