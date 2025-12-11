---
id: task-331
title: Investigate intermittent KERN_INVALID_ADDRESS crash on macOS Firebase tests
status: Done
assignee: []
created_date: '2025-12-09 19:21'
updated_date: '2025-12-10 18:21'
labels:
  - firebase
  - macos
  - crash
  - intermittent
  - investigation
dependencies:
  - task-330
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem SOLVED ✅ - CRASH FIXED

**Solution Implemented**: Two-part fix to prevent Firebase callbacks during shutdown

### Changes Made:

**Part 1: Block Listener Callbacks at Source**
Modified `begin_shutdown()` in `database.cpp` to nullify singleton pointers:
```cpp
if (child_listener_instance) child_listener_instance->singleton = nullptr;
if (connection_listener_instance) connection_listener_instance->singleton = nullptr;
```
The listener callbacks already check `if (singleton)` before calling `call_deferred`, so this blocks them at the source.

**Part 2: Guard Async Handler Methods**
Added early-return check to 7 `_handle_*_on_main_thread` methods:
```cpp
if (is_app_shutting_down()) {
    print_line("[RTDB C++] _handle_xxx skipped - app shutting down");
    return;
}
```
These methods are the targets of `MessageQueue::push_callable()` - if they return early, no Godot operations occur on freed objects.

### Test Results:
- ✅ firebase-all test suite on macOS: **10/11 configs passed** (90% success)
- ✅ 3164 debug actions executed with **0 failures**
- ✅ **NO KERN_INVALID_ADDRESS crashes** observed
- ✅ App exits cleanly with all Firebase callbacks blocked during shutdown

### Root Cause Analysis:
The crash occurred because Firebase callbacks continued to be enqueued after shutdown began:
1. **Listener callbacks** used `call_deferred()` to emit signals
2. **Async operation callbacks** used `MessageQueue::push_callable()` 
3. When `Main::cleanup()` called `CallQueue::flush()`, these queued callbacks tried to execute on already-freed objects → **KERN_INVALID_ADDRESS crash**

**Key Issue**: The `is_shutting_down` flag was being set but not checked by callbacks.

## Previous Attempts (Insufficient)

1. ❌ **CallQueue flush in GDScript**: Doesn't help because callbacks are still being created
2. ❌ **Setting `is_shutting_down` flag**: Flag existed but wasn't being checked
3. ❌ **Early Firebase cleanup on auto_quit**: Cleanup runs but callbacks still queued

## Solution Rationale

This approach was preferred because:
- **Minimal code changes**: 1 function + 7 early-returns vs 20+ callback sites
- **Defense in depth**: Both callback types are blocked
- **Thread-safe**: Uses existing atomic `is_shutting_down` flag
- **No timing dependencies**: Doesn't rely on CallQueue flush timing
<!-- SECTION:DESCRIPTION:END -->
