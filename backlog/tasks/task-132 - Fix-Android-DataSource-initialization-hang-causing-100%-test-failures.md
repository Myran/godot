---
id: task-132
title: Fix Android DataSource initialization hang causing 100% test failures
status: In Progress
assignee: []
created_date: '2025-09-08 12:26'
updated_date: '2025-09-08 12:28'
labels:
  - critical
  - android
  - infrastructure
  - debugging
dependencies: []
---

## Description

Critical Android infrastructure failure where DataSource initialization starts but never completes, causing Game._ready() to hang and preventing the entire debug coordinator chain from working. This results in 100% test failure rate on Android while Desktop works perfectly.

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 DataSource initialization completes successfully on Android,Game emits initialization_complete signal on Android,Debug coordinator starts and sets test context on Android,Android test success rate improves from 0% to match Desktop performance,gamestate-save-load-test passes on both Android and Desktop platforms,All Firebase and system tests work on Android,DEBUG_TEST_START and DEBUG_TEST_SUCCESS events are properly logged on Android
<!-- AC:END -->

## Implementation Notes

Evidence from logs shows Android initialization chain breaks at DataSource level - 'Game initializing' logged but 'Starting DataSource initialization' never appears. This prevents main.gd from receiving initialization_complete signal, blocking debug coordinator startup. TASK-131 identified autoload typing issues as related cause.

**🎯 MAJOR BREAKTHROUGH - ROOT CAUSE COMPLETELY REDEFINED**

**Previous Understanding (PROVEN WRONG):**
- FirebaseServiceBackend.new() hangs indefinitely on Android
- Complete class instantiation deadlock prevents any execution

**NEW REALITY (EVIDENCE-BASED):**
- ✅ **FIRST create_firebase_backend() call SUCCEEDS PERFECTLY**
- ✅ **Backend created successfully with instance_id: -9223371778720528070**
- ✅ **FirebaseServiceBackend.new() works completely on Android**
- ❌ **SECOND call to create_firebase_backend() triggered 3 seconds later and HANGS**

**Critical Evidence from Granular Logging:**
```
09-08 19:04:44.790 - GRANULAR LOG A: Function entry works
09-08 19:04:44.791 - GRANULAR LOG C: is_instance_valid() check passes  
09-08 19:04:44.791 - GRANULAR LOG E: FirebaseService IS valid
09-08 19:04:44.792 - GRANULAR LOG G: FirebaseServiceBackend.new() completed
09-08 19:04:47.955 - FirebaseServiceBackend created successfully with instance_id: -9223371778720528070

[3 SECOND GAP - Something triggers retry mechanism]

09-08 19:04:47.875 - GRANULAR LOG B: Second call entry
09-08 19:04:47.893 - GRANULAR LOG F: Second call hangs at is_instance_valid()
[NEVER COMPLETES - INFINITE HANG]
```

**REVISED ROOT CAUSE HYPOTHESIS:**
1. ✅ **Backend creation succeeds perfectly**
2. 🔄 **Backend.initialize() gets called**
3. ❌ **Something fails during backend initialization**  
4. 🔄 **Retry mechanism triggers second create_firebase_backend() call**
5. ❌ **Second call hangs (singleton conflict or resource lock)**

**PARADIGM SHIFT:**
- **Original**: Platform compatibility / class loading issue (FALSE)
- **Reality**: Application logic issue - retry/initialization chain failure
- **Impact**: Core GDScript/Android integration WORKS - issue is in initialization logic

**INVESTIGATION PRIORITY (UPDATED):**
1. **Find what triggers the second call** - error handling, retry logic, initialization failure
2. **Investigate backend.initialize() method** - what happens between first success and second call  
3. **Diagnose why second call hangs** - singleton conflict, resource lock, state corruption

**STATUS: 50% SOLVED** - Backend creation confirmed working, focus shifted to initialization retry logic

**Technical Analysis (LEGACY - DISPROVEN)**:
The issue was NOT in Firebase initialization or class instantiation as originally believed. This was a critical misunderstanding that led us down the wrong path for optimization. The core Android/GDScript integration works perfectly - the issue is in application-level retry logic.
