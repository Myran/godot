---
id: task-346
title: Build sentry-godot GDExtension for Windows (missing gdextension_init)
status: To Do
assignee: []
created_date: '2025-12-16 18:35'
updated_date: '2025-12-16 18:35'
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
- [ ] #1 sentry-godot GDExtension built for Windows x86_64 via VM
- [ ] #2 GDExtension DLL has gdextension_init entry point
- [ ] #3 Windows export includes both GDExtension and SDK DLLs
- [ ] #4 test-windows-target runs without SentryUser parse errors
- [ ] #5 SentrySDK class available in GDScript on Windows
<!-- AC:END -->

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
<!-- SECTION:NOTES:END -->
