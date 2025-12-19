---
id: task-341
title: Use native Windows VM Sentry build with crashpad backend
status: Done
assignee: []
created_date: '2025-12-14 15:40'
updated_date: '2025-12-18 10:37'
labels:
  - windows
  - sentry
  - build-system
  - vm
dependencies: []
priority: medium
ordinal: 5000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The Windows Sentry build is currently using MinGW cross-compilation with `inproc` backend, but we now have native Windows VM builds available that can use the superior `crashpad` backend.

## Current State
- `build-sentry-all` calls `build-sentry-native-windows-release` (MinGW cross-compile)
- Uses `-DSENTRY_BACKEND=inproc` (no crashpad_handler.exe)
- Located in: `justfiles/justfile-native-windows-sentry.justfile`

## Target State  
- Use `windows-native-sentry-release` from `justfiles/justfile-windows-native.justfile`
- Uses `-DSENTRY_BACKEND=crashpad` with MSVC
- Produces crashpad_handler.exe for native crash handling

## Benefits of crashpad over inproc
- **Out-of-process crash handling**: More reliable crash capture
- **Process isolation**: Handler survives even if main process is corrupted
- **Windows Error Reporting (WER) integration**: Better integration with Windows crash dialogs

## Implementation Plan
1. Update `build-sentry-all` in `justfile-sentry.justfile` to call Windows VM native build
2. Create wrapper recipe that invokes `windows-native-sentry-all` on VM
3. Copy crashpad_handler.exe back to macOS project directory
4. Update validation to check for crashpad_handler.exe
5. Test Windows export with crashpad backend
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Windows Sentry built with crashpad backend via VM
- [x] #2 crashpad_handler.exe present in project/addons/sentry/bin/windows/x86_64/
- [x] #3 build-sentry-all uses native Windows VM build
- [x] #4 Validation passes without crashpad warning
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Update `build-sentry-all` in `justfile-sentry.justfile` to call Windows VM native build
2. Create wrapper recipe that invokes `windows-native-sentry-all` on VM
3. Copy crashpad_handler.exe back to macOS project directory
4. Update validation to check for crashpad_handler.exe
5. Test Windows export with crashpad backend
<!-- SECTION:DESCRIPTION:END -->
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Completion Summary (2025-12-15)

Successfully implemented native Windows VM Sentry build with crashpad backend.

### Key Changes:
1. **justfile-windows-native.justfile**: Added cmake toolchain file approach to force x64 target on ARM64 Windows VM
2. **justfile-platform-windows.justfile**: Fixed SCP path format for Windows file transfers
3. **justfile-sentry.justfile**: Updated `build-sentry-windows-vm` to use VM native build with crashpad

### Technical Challenges Resolved:
- ARM64 to x64 cross-compilation on Windows VM required cmake toolchain file with `CMAKE_SYSTEM_PROCESSOR=AMD64`
- SCP path format for Windows requires `/C:` prefix format
- Crashpad assembly files selection based on target architecture

### Build Outputs:
- `libsentry.windows.release.x86_64.dll` (340KB)
- `libsentry.windows.debug.x86_64.dll` (1.9MB)
- `crashpad_handler.exe` (682KB)

All validation checks pass.

## Full Validation Results (2025-12-15)

All impacted justfile recipes validated successfully:

### Recipe Validation Summary

| Recipe | Status | Details |
|--------|--------|--------|
| `win-vm-verify` | ✅ PASS | SSH connection OK, MSVC/Python/SCons/Git/Firebase/Godot all found |
| `win-vm-sync` | ✅ PASS | Synced to 76531ceb, submodules initialized including sentry-godot |
| `win-vm-sentry-all` | ✅ PASS | Clean rebuild: Release + Debug DLLs + crashpad_handler.exe built |
| `win-vm-sentry-package` | ✅ PASS | All 3 files copied: release DLL (340KB), debug DLL (1.9MB), crashpad_handler.exe (682KB) |
| `build-sentry-windows-vm` | ✅ PASS | Skip logic works when already built |
| `validate-sentry-all` | ✅ PASS | All platforms validated: iOS, GDScript, Windows (crashpad) |
| `status-sentry-quick` | ✅ PASS | Shows crashpad backend status correctly |
| `win-vm-sentry-complete` | ✅ PASS | Full workflow: verify → build → package |
| `sentry-windows-status` | ✅ PASS | Shows both DLLs as built |

### Build Configuration Verified
- **Compiler**: MSVC 19.44.35222.0 (Visual Studio 2022 Build Tools 17.14.22)
- **Target**: x64 (cross-compiled from ARM64 VM)
- **Assembler**: ml64.exe (x64 MASM)
- **Backend**: crashpad (out-of-process crash handling)
- **Transport**: winhttp

### File Artifacts
```
project/addons/sentry/bin/windows/x86_64/
├── crashpad_handler.exe     (682,496 bytes)
├── libsentry.windows.debug.x86_64.dll   (1,923,584 bytes)
└── libsentry.windows.release.x86_64.dll (340,480 bytes)
```

## Windows Build Validation Results (2025-12-15)

### Full Windows Export Validated ✅

**Export Method**: `just export-windows-debug`

**Export Contents** (export/windows/):
- `crashpad_handler.exe` - 682,496 bytes (crashpad backend)
- `gametwo_debug.exe` - 158,457,032 bytes (game executable)
- `libsentry.windows.debug.x86_64.dll` - 1,923,584 bytes (Sentry debug)
- `libsentry.windows.release.x86_64.dll` - 462,753 bytes (Sentry release)

### GDExtension Fix Applied ✅

**Issue Found**: Missing Windows crashpad_handler.exe dependency in `sentry.gdextension`

**Fix Applied**:
```
windows.x86_64 = {
	"res://addons/sentry/bin/windows/x86_64/crashpad_handler.exe" : ""
}
```

This ensures crashpad_handler.exe is included in Windows exports alongside the Sentry DLLs.

### Integration Summary

| Component | Status | Details |
|-----------|--------|--------|
| Native MSVC Build | ✅ | ARM64→x64 cross-compile with crashpad backend |
| GDScript GDExtension | ✅ | DLLs load via sentry.gdextension |
| Crashpad Handler | ✅ | Included via windows.x86_64 dependency |
| Export Integration | ✅ | All files present in export directory |

### Files Modified
- `project/addons/sentry/sentry.gdextension` - Added Windows crashpad_handler dependency
<!-- SECTION:NOTES:END -->
