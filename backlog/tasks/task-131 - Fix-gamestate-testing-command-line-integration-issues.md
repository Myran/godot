---
id: task-131
title: Fix gamestate testing command-line integration issues
status: In Progress
assignee: []
created_date: '2025-09-07 08:39'
updated_date: '2025-09-07 20:15'
labels:
  - testing
  - integration
  - gamestate
dependencies: []
priority: high
---

## Description

Address command-line parsing and platform-specific issues in gamestate testing integration while preserving the working core functionality from commit 7f04aaee. The underlying gamestate testing system works correctly - this task focuses on fixing the integration layer issues that prevent seamless usage.

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] @ symbol reference parsing works correctly in test commands (just test-target @reference works)
- [x] Command execution script error is resolved (return statement outside function)
- [ ] **Android DataSource/Firebase backend initialization works correctly** - CURRENT STATUS: ❌ Still hangs, never completes
- [x] Desktop gamestate testing works completely via command-line
- [ ] **Android gamestate test action collection functions properly** - CURRENT STATUS: Still "Actions collected: 0"
- [ ] **Android debug coordinator properly emits DEBUG_TEST_SUCCESS events** - CURRENT STATUS: Debug coordinator never starts due to Game initialization hang
- [ ] **Both desktop and Android platforms execute gamestate tests successfully** - CURRENT STATUS: Desktop ✅ perfect, Android ❌ broken
- [ ] All existing gamestate functionality continues to work without regression
<!-- AC:END -->

## BREAKTHROUGH: Root Cause Found ✅

### Issue #1: RESOLVED ✅
**Problem**: `ProjectSettings.get_setting()` returns `Variant`, not `bool`  
**Location**: `BackendFactory.create_backend()` line 100  
**Fix**: `bool(ProjectSettings.get_setting("game/debug/force_local_data", false))`  
**Result**: Platform detection now works correctly

### Issue #2: CRITICAL DISCOVERY ✅  
**Problem**: `var game: Game` in `project/autoloads/core.gd` breaks DataSource initialization  
**Root Cause**: Strong typing reference to `Game` class during autoload phase causes validation failure  
**Impact**: `call_deferred("_initialize")` never executes → DataSource never completes → Game hangs → No gamestate testing  
**Evidence**: Stashing this single line fixed DataSource initialization completely  
**Before**: "Actions collected: 0", DataSource._initialize() never called  
**After**: "Starting DataSource initialization" ✅, Backend selection works ✅, Firebase backend creation works ✅

### Current Status (Updated January 2025):
- ✅ **Desktop gamestate testing**: **PERFECT** - Actions collected: 2, DEBUG_TEST_SUCCESS events logged, checksum validation working
- ❌ **Android DataSource/Firebase**: **STILL BROKEN** - DataSource initialization hangs, never completes
- ❌ **Android Game initialization**: **CRITICAL** - Game._ready() hangs waiting for DataSource, initialization_complete signal never emitted
- ❌ **Android debug coordinator**: **NEVER STARTS** - main.gd waits forever for Game initialization, debug coordinator never called
- ❌ **Android test result collection**: **BROKEN** - Actions collected: 0, no DEBUG_TEST_SUCCESS events due to missing test context
- ✅ **Android action execution**: **WORKS** - Actions run successfully (visible in logs) but results not captured
- ✅ **@ Symbol parsing**: Fixed in justfile validation  
- ✅ **Command script errors**: Fixed

### Next Steps (Critical Priority):
1. **URGENT: Fix Android DataSource initialization hang** - Root cause of entire issue chain
2. **Ensure Game initialization completes** - Must emit initialization_complete signal on Android
3. **Verify debug coordinator starts** - Should be called after Game initialization completes
4. **Validate DEBUG_TEST_SUCCESS logging** - Should work once test context is properly set
5. **The core autoload initialization issue persists** - Original problem not fully resolved

### Methodology Validation:
- Iterative stashing approach was perfect - found exact problematic line in one iteration
- Strong typing validation failures cause silent issues in GDScript autoloads  
- Uncommitted typing changes were indeed the root cause as initially suspected
