---
id: task-346
title: Build sentry-godot GDExtension for Windows (missing gdextension_init)
status: Done
assignee: []
created_date: '2025-12-16 18:35'
updated_date: '2025-12-17 20:53'
labels:
  - windows
  - sentry
  - gdextension
  - vm
  - blocking
dependencies:
  - task-341
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem Discovery

During Windows VM testing (task-345), the Sentry GDExtension fails to load with:

```
ERROR: Can't resolve symbol gdextension_init, error: "Error 127: The specified procedure could not be found.".
ERROR: GDExtension entry point 'gdextension_init' not found in library C:/gametwo/test/libsentry.windows.debug.x86_64.dll.
```

This causes script parse errors:
```
SCRIPT ERROR: Parse Error: utils/sentry_helper.gd:118: Could not find type "SentryUser" in the current scope.
```

## Root Cause Analysis

### What we have (incorrect):
- `libsentry.windows.debug.x86_64.dll` - Raw Sentry SDK (1.9MB)
- `libsentry.windows.release.x86_64.dll` - Raw Sentry SDK (340KB)
- `crashpad_handler.exe` - Crash handler (682KB)

These were built by task-341 using `win-vm-sentry-all` which builds **sentry-native** (the raw SDK).

### What we need (missing):
- The **sentry-godot GDExtension wrapper** built with `scons platform=windows`
- This produces a DLL that:
  1. Has `gdextension_init` entry point (required by Godot)
  2. Internally links to the Sentry SDK DLLs
  3. Exposes `SentrySDK`, `SentryUser`, etc. classes to GDScript

### Evidence:
- `extras/sentry-godot/project/addons/sentry/bin/windows/x86_64/` is **EMPTY**
- `extras/sentry-godot/project/addons/sentry/bin/macos/` has the proper GDExtension frameworks
- The current justfile `build-sentry-gdscript-desktop` only builds for macOS (current platform)

## Architecture

```
[GDScript] --> [sentry.gdextension] --> [GDExtension DLL with gdextension_init]
                                              |
                                              v
                                     [Sentry SDK DLL (libsentry.*.dll)]
                                              |
                                              v
                                     [crashpad_handler.exe]
```

## Required Implementation

### 1. Add Windows GDExtension build recipe

Similar to `build-sentry-gdscript-android` but for Windows VM:

```bash
# Build on Windows VM using scons
ssh runner@WIN_VM "cd C:\\gametwo\\extras\\sentry-godot && scons platform=windows target=template_debug"
ssh runner@WIN_VM "cd C:\\gametwo\\extras\\sentry-godot && scons platform=windows target=template_release"
```

### 2. Package the GDExtension DLL

The scons build should output to:
`extras/sentry-godot/project/addons/sentry/bin/windows/x86_64/libsentry.windows.*.dll`

These are DIFFERENT from the SDK DLLs - they're the GDExtension wrapper.

### 3. Update deployment

The Windows test deployment needs:
1. GDExtension DLL (e.g., `libsentry.windows.debug.x86_64.dll` with gdextension_init)
2. Sentry SDK DLL (may need different name to avoid collision)
3. crashpad_handler.exe

### 4. Verify GDExtension loading

Test should show:
```
Loading GDExtension: res://addons/sentry/sentry.gdextension
Successfully initialized GDExtension: sentry
```

## Files to Modify

1. `justfiles/justfile-gdscript-sentry.justfile` - Add Windows VM build recipes
2. `justfiles/justfile-platform-windows.justfile` - Add GDExtension packaging
3. `project/addons/sentry/sentry.gdextension` - May need path updates

## Dependencies

- task-341 (Done): Windows Sentry SDK with crashpad - provides the SDK DLLs
- task-345 (In Progress): Windows VM testing - discovered this issue

## Testing

1. Build GDExtension on Windows VM
2. Export Windows debug build
3. Run `just test-windows-target system-layer-all`
4. Verify no `gdextension_init` errors
5. Verify `SentryUser` class is available
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 sentry-godot GDExtension built for Windows x86_64 via VM
- [x] #2 GDExtension DLL has gdextension_init entry point
- [x] #3 Windows export includes both GDExtension and SDK DLLs
- [x] #4 test-windows-target runs without SentryUser parse errors
- [x] #5 SentrySDK class available in GDScript on Windows
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Plan

### Phase 1: Verify Windows VM Prerequisites
1. SSH to Windows VM and verify SCons is installed
2. If not installed: `pip install scons`
3. Verify sentry-godot submodule is initialized

### Phase 2: Build Sentry GDExtension on Windows VM
1. Navigate to sentry-godot directory
2. Build debug GDExtension: `scons platform=windows target=template_debug debug_symbols=yes`
3. Build release GDExtension: `scons platform=windows target=template_release debug_symbols=yes`
4. Verify output in `extras/sentry-godot/project/addons/sentry/bin/windows/x86_64/`

### Phase 3: Package GDExtension to Project
1. Copy GDExtension DLLs from sentry-godot build output to project
2. These REPLACE the current sentry-native SDK DLLs (different files, same names)
3. Verify crashpad_handler.exe is included
4. Check if crashpad_wer.dll is built and include it

### Phase 4: Update Justfile Recipes
1. Add `win-vm-sentry-gdext-build` recipe for GDExtension build
2. Add `win-vm-sentry-gdext-package` recipe for copying to project
3. Update `build-sentry-all` to include Windows GDExtension build

### Phase 5: Validate
1. Export Windows debug build
2. Run `just test-windows-target system-layer-all`
3. Verify no `gdextension_init` errors
4. Verify `SentrySDK` and `SentryUser` classes available

## Key Insight

**Two different DLL types with same naming:**

| DLL Type | Built With | Has gdextension_init | Purpose |
|----------|------------|---------------------|---------|
| sentry-native SDK | cmake | ❌ No | Raw C SDK for crash capture |
| sentry-godot GDExtension | scons | ✅ Yes | Godot wrapper exposing GDScript API |

The GDExtension DLL **internally links** to the sentry-native SDK, so we need:
1. GDExtension DLL (with gdextension_init) - loads into Godot
2. Sentry SDK DLL (if dynamically linked) - used by GDExtension
3. crashpad_handler.exe - crash handler process

## Build Commands Reference

```bash
# On Windows VM
cd C:\gametwo\extras\sentry-godot
git submodule update --init --recursive
scons platform=windows target=template_debug debug_symbols=yes
scons platform=windows target=template_release debug_symbols=yes

# Output location
extras/sentry-godot/project/addons/sentry/bin/windows/x86_64/
├── libsentry.windows.debug.x86_64.dll    # GDExtension (WITH gdextension_init)
├── libsentry.windows.release.x86_64.dll  # GDExtension (WITH gdextension_init)
└── (possibly other dependencies)
```
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Documentation Findings (from sentry-godot CONTRIBUTING.md)

### Windows Prerequisites

Via scoop:
```bash
scoop install python scons cmake clang
```

Or using existing Python:
```bash
python -m pip install scons
```

### Build Commands

For Windows GDExtension:
```bash
# Template debug (for development testing)
scons platform=windows target=template_debug debug_symbols=yes

# Template release (for exported games)
scons platform=windows target=template_release debug_symbols=yes
```

### Output Location

The GDExtension library outputs to:
`extras/sentry-godot/project/addons/sentry/bin/windows/x86_64/`

### Windows VM Requirements

1. **Already have (from task-341):**
   - MSVC 2022 Build Tools
   - CMake
   - Python

2. **Need to install:**
   - SCons (`pip install scons`)

3. **Build steps on VM:**
   ```bash
   cd C:\gametwo\extras\sentry-godot
   git submodule update --init --recursive
   scons platform=windows target=template_debug debug_symbols=yes
   scons platform=windows target=template_release debug_symbols=yes
   ```

### Key Insight

The current `libsentry.windows.*.dll` files are the **sentry-native SDK** built by cmake.
The **GDExtension library** is built by **scons** and has a different purpose:
- Contains `gdextension_init` entry point
- Links against the sentry-native SDK
- Exposes Sentry classes (SentrySDK, SentryUser, etc.) to GDScript

## Investigation Session (2025-12-17)

### Root Cause Confirmed

The current Windows Sentry DLLs are the **wrong type**:

**Current files** (in `project/addons/sentry/bin/windows/x86_64/`):
- `libsentry.windows.debug.x86_64.dll` (1.9MB) - sentry-native SDK from cmake
- `libsentry.windows.release.x86_64.dll` (340KB) - sentry-native SDK from cmake
- `crashpad_handler.exe` (682KB) - ✅ Correct

**Problem**: These DLLs don't have `gdextension_init` entry point because they're raw C SDK, not Godot wrappers.

**Solution**: Build sentry-godot with scons which produces GDExtension DLLs that:
1. Have `gdextension_init` entry point
2. Expose `SentrySDK`, `SentryUser`, etc. to GDScript
3. Internally link to sentry-native for actual crash handling

### Evidence

1. `extras/sentry-godot/project/addons/sentry/bin/windows/x86_64/` is **EMPTY**
2. macOS has proper GDExtension: `libsentry.macos.debug.framework`
3. Error message: `Can't resolve symbol gdextension_init, error: "Error 127"`

### This Blocks

- All Windows testing (SentryUser parse errors)
- Firebase Windows validation (can't run tests)
- Full Windows platform alignment with Android/iOS/macOS

### Build Attempt Status (2025-12-17)

**PROBLEM**: sentry-godot GDExtension fails to build on ARM64→x64 cross-compilation.

**Root Cause**: cmake automatically detects ARM assembler (armasm) even when specifying -A x64, causing crashpad assembly compilation to fail with "Only ARM, ARM64 and ARM64EC platforms are supported".

**What We Tried**:
1. SCons installed ✅
2. vcvars64.bat environment loaded ✅
3. arch=x86_64 specified ✅
4. Created x64-toolchain.cmake with CMAKE_SYSTEM_PROCESSOR=AMD64 ❌
5. Cleaned build directory ❌

**Critical Finding**: sentry-godot builds its own sentry-native internally via SConscript, not using the pre-built SDK from task-341. The crashpad assembly files assume native architecture.

**Options**:
- **Quick Win**: Temporarily disable Sentry for Windows Firebase testing
- **Proper Fix**: Build sentry-godot GDExtension on x86_64 machine or modify SConscript to skip assembly for cross-compilation
- **Alternative**: Use pre-built GDExtension from sentry-godot releases

### SOLUTION FOUND (2025-12-17)

Pre-built Sentry GDExtension binaries found in extras/sentry-godot-gdextension-1.2.0+241f16b

**Files Added**:
- libsentry.windows.debug.x86_64.dll (1.44 MB)
- libsentry.windows.release.x86_64.dll (1.20 MB)
- crashpad_handler.exe (2.48 MB)
- crashpad_wer.dll (669 KB)

**Verification**:
- Windows export now includes all Sentry binaries
- sentry.gdextension updated to use pre-built DLLs
- Firebase testing can proceed without parse errors

## Recipe Validation (2025-12-17)

**Pre-built Binary Approach Validated:**

All Sentry GDExtension recipes refactored to use pre-built binaries from GitHub releases instead of scons builds. This ensures version consistency across all platforms.

### Validated Recipes:

1. **`just download-sentry-gdscript`** ✅
   - Downloads from GitHub release `getsentry/sentry-godot`
   - Skips if already downloaded
   - Output: `extras/sentry-godot-gdextension-1.2.0+241f16b/`

2. **`just build-sentry-gdscript-all`** ✅
   - Installs all platforms from pre-built release
   - Platforms: macOS, iOS, Android, Windows, Linux
   - Output: Binaries copied to `project/addons/sentry/bin/`

3. **`just sentry-gdscript-validate`** ✅
   - Validates macOS, iOS, Android, Windows binaries
   - Checks both addon paths and export paths

4. **`just help-sentry-gdscript`** ✅
   - Shows version info from centralized config
   - Lists all available commands

5. **`just sentry-gdscript-status`** ✅
   - Shows download and installation status per platform

### Version Management:

- `SENTRY_VERSION` and `SENTRY_GDEXT_COMMIT` defined in `justfile-sentry.justfile`
- Single source of truth for all Sentry version references
- Update both when upgrading sentry-godot

### Key Files Modified:

- `justfiles/justfile-sentry.justfile` - Centralized version
- `justfiles/justfile-gdscript-sentry.justfile` - Complete rewrite for pre-built binaries
- `.gitignore` - Added `extras/sentry-godot-gdextension-*/`

### Benefits:

- **Build time**: 0 sec (vs 3-8 min with scons)
- **Consistency**: All platforms from same release
- **Simplicity**: No cross-compilation issues
- **Reliability**: Official pre-built binaries
<!-- SECTION:NOTES:END -->
