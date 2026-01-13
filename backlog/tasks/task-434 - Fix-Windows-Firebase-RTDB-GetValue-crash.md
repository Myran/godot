---
id: task-434
title: Fix Windows Firebase RTDB GetValue() crash
status: Open
assignee: []
created_date: '2025-01-13 14:35'
updated_date: '2026-01-13 16:43'
labels:
  - windows
  - firebase
  - sdk-bug
  - crash
  - rtdb
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Root Cause Identified**: Firebase C++ SDK bug in Windows RTDB

## Crash Location
The crash occurs **inside** `firebase::database::DatabaseReference::GetValue()` - a Firebase C++ SDK function, not our code.

## Evidence (from diagnostic logging)
```
[RTDB C++] get_value_async START - ReqID:1
[RTDB C++] inited=true database_instance=valid
[RTDB C++] GetValue ReqID:1 Path (GDScript Array): ["...", "cards_0"] -> URL: /*/cards_0
[RTDB C++] About to call ref.GetValue() - ref.is_valid()=true
[RTDB C++] ref.key()=cards_0
<crash - no further output>
```

## What Works on Windows
- Firebase App initialization ✅
- Firebase Auth initialization ✅  
- Firebase Database instance creation ✅
- DatabaseReference.is_valid() ✅
- DatabaseReference.url() ✅
- DatabaseReference.key() ✅

## What Crashes
- `DatabaseReference::GetValue()` - crashes inside the Firebase SDK call itself

## Key Facts
- All other platforms (Android, iOS, macOS, editor) work perfectly with the same code
- Firebase C++ SDK Windows RTDB is "Beta quality" per Google documentation
- SDK version: 12.2.0
- Crash is 100% reproducible

## Attempted Fixes (all failed)
1. Storing DatabaseReference in member variable - still crashes
2. Reverting to direct ref usage - still crashes
3. Verifying ref validity before call - still crashes

## Recommendations
1. **Short-term**: Force local data mode on Windows (`game/debug/force_local_data = true`)
2. **Medium-term**: Report to Firebase C++ SDK GitHub issues
3. **Long-term**: Monitor Firebase SDK updates for Windows RTDB fixes
<!-- SECTION:DESCRIPTION:END -->

# Windows Firebase RTDB GetValue() Crash

## Issue
Windows physical machine tests crash during `ref.GetValue()` call in Firebase RTDB module.

## Symptoms
- App exits after ~1 second
- Log shows: `[RTDB C++] Calling ref.GetValue() - DatabaseReference appears valid`
- Crash dumps generated in `C:\Users\matti\AppData\Local\CrashDumps\`
- 382 log lines, 0 actions collected
- Debug coordinator never starts (crash happens before)

## Investigation Steps Taken
1. ✅ Fixed hardcoded SCP paths in Windows justfile (committed)
2. ✅ Added `dbghelp.lib` linking for Firestore (release build now works)
3. ✅ Full Windows build completed successfully
4. ❌ Reverted UTF-8 CharString fix - issue persists
5. ❌ Fresh template deployment - issue persists

## Crash Dumps Location
```
\\192.168.50.80\matti\AppData\Local\CrashDumps\
gametwo_debug.exe.*.dmp
```

## Key Finding
The crash occurs at exactly this line in `database.cpp`:
```cpp
firebase::Future<firebase::database::DataSnapshot> future = ref.GetValue();
```

All Firebase initialization succeeds, but the `GetValue()` call crashes immediately.

## Potential Causes
1. Firebase SDK for Windows has a bug in `DatabaseReference::GetValue()`
2. Missing Windows system library dependency
3. Threading issue specific to Windows Firebase SDK
4. Firebase SDK initialization incomplete on Windows

## Next Steps
1. Analyze Windows crash dump (`.dmp` file)
2. Check Firebase SDK version on Windows vs other platforms
3. Test with Firebase SDK-only test (minimal reproduction)
4. Consider filing bug with Firebase C++ SDK

## Related
- task-433: Windows physical test early exit (original task)
- Commit c105d1ce: UTF-8 dangling pointer fix
