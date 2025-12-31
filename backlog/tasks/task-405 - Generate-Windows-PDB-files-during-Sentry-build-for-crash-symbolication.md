---
id: task-405
title: Generate Windows PDB files during Sentry build for crash symbolication
status: Done
assignee: []
created_date: '2025-12-31 00:09'
updated_date: '2025-12-31 00:31'
labels:
  - sentry
  - windows
  - build-system
  - crash-reporting
dependencies:
  - task-390
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Summary
Windows crash reports in Sentry show raw memory addresses instead of function names because PDB (Program Database) debug symbol files are not being generated during the Sentry GDExtension build on the Windows VM.

## Current State
- Windows Sentry DLLs are built successfully on VM (192.168.50.92)
- DLLs are copied to Mac via `build-sentry-native-windows-vm-package`
- **No .pdb files are generated** during the SCons build
- Upload recipe exists (`just sentry-upload-symbols-windows`) but has nothing to upload

## Investigation Needed
1. Check SCons build configuration in `extras/sentry-godot/SConstruct`
2. Determine if MSVC debug flags are being set (`/Zi`, `/DEBUG`)
3. Check if PDB files are generated but in a different location
4. Verify crashpad backend build also generates debug symbols

## Implementation
1. Update SCons build to generate PDB files:
   - Add `/Zi` compiler flag for debug info
   - Add `/DEBUG` linker flag to embed PDB reference
   - Ensure PDB files are output alongside DLLs

2. Update `build-sentry-native-windows-vm-package` recipe to copy PDB files:
   ```bash
   # Copy PDB files
   if ssh {{WIN_VM_USER}}@{{WIN_VM_HOST}} "if exist ${WIN_CMD_PATH}\\*.pdb echo exists" | grep -q exists; then
       scp "{{WIN_VM_USER}}@{{WIN_VM_HOST}}:${WIN_SENTRY_PATH}/*.pdb" project/addons/sentry/bin/windows/x86_64/
   fi
   ```

3. Test upload with `just sentry-upload-symbols-windows`

## Related
- Parent task: task-390 (Sentry dSYM upload)
- Recipe location: `justfiles/justfile-platform-windows.justfile`
- Build location: `extras/sentry-godot/SConstruct`
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 SCons build generates .pdb files for debug and release DLLs
- [x] #2 PDB files are copied from VM to Mac during package step
- [x] #3 just sentry-upload-symbols-windows successfully uploads PDB files
- [x] #4 Windows crash reports in Sentry show symbolicated stack traces
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Implementation Complete (2025-12-31)

**Root Cause Found:** The SCons build commands were missing `debug_symbols=yes` flag.

**Changes Made:**

1. **`justfiles/justfile-windows-native.justfile`:**
   - Added `debug_symbols=yes` to both release and debug SCons commands
   - Added PDB file copy commands with proper quoting
   - Fixed paths for PDB files

2. **`justfiles/justfile-platform-windows.justfile`:**
   - Added PDB file copy steps in `build-sentry-native-windows-vm-package` recipe

**Results:**
- ✅ PDB files generated (18.3 MB release, 18.5 MB debug)
- ✅ PDBs copied to Mac via `build-sentry-native-windows-vm-package`
- ✅ Successfully uploaded 4 debug files to Sentry:
  - crashpad_wer.dll
  - crashpad_handler.exe  
  - libsentry.windows.release.x86_64.pdb
  - libsentry.windows.debug.x86_64.pdb
<!-- SECTION:NOTES:END -->
