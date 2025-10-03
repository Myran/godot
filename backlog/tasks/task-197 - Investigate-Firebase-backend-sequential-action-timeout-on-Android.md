---
id: task-197
title: Investigate Firebase backend sequential action timeout on Android
status: To Do
assignee: []
created_date: '2025-10-03 06:20'
updated_date: '2025-10-03 08:52'
labels:
  - testing
  - firebase
  - android
  - sequential-actions
  - timeout
dependencies: []
priority: medium
---

## Description

Three Firebase backend test configs on Android are experiencing partial completion event detection:
1. **firebase-backend-batch-1**: 2/3 completion events detected
2. **firebase-backend-layer**: 2/3 completion events detected
3. **system-performance**: 4/5 completion events detected

All actions execute successfully (100% pass rate), but the test framework times out waiting for completion events that are not being emitted. This is distinct from task-196 (battle test hang) - these actions **complete successfully** but don't emit expected events.

## Evidence from Test Run (2025-10-03)

### Affected Configs

**firebase-backend-batch-1 (Android):**
- Expected: 3 sequential actions
- Detected: 2 completion events
- Missing: 1 completion event
- Actions: All passed

**firebase-backend-layer (Android):**
- Expected: 3 sequential actions
- Detected: 2 completion events
- Missing: 1 completion event
- Actions: All passed

**system-performance (Android):**
- Expected: 5 sequential actions
- Detected: 4 completion events
- Missing: 1 completion event
- Actions: All passed

## Potential Root Causes

### **Theory 1: Auto-Continue Flag Still Incorrect**
Some Firebase backend actions might still be registered with `auto_continue=true` when they should be `false`, causing them to skip completion event emission.

### **Theory 2: Firebase Backend Specific Event Handling**
Firebase backend actions might have different completion patterns that don't align with the sequential action completion event system.

### **Theory 3: Async Pattern Completion Race Condition**
Firebase backend async patterns might complete in a way that bypasses the completion event emission code path.

### **Theory 4: Android-Specific Firebase Threading**
Firebase SDK on Android might execute callbacks on different threads, causing event emission to fail or be missed.

## Investigation Strategy

**Step 1: Identify Missing Actions**
- Extract action sequence from test logs
- Determine which specific action(s) don't emit completion events
- Check if pattern is consistent across affected configs

**Step 2: Verify auto_continue Registration**
- Check Firebase backend action registrations
- Confirm `set_auto_continue(false)` is called for sequential actions
- Verify flag propagates correctly to dispatch

**Step 3: Review Firebase Backend Completion Patterns**
- Analyze how Firebase backend actions complete
- Check if they use different async patterns than battle actions
- Verify completion event emission code path is reached

**Step 4: Compare with Desktop (if exists)**
- Run same configs on Desktop if supported
- Compare completion event behavior
- Identify Android-specific differences

## Acceptance Criteria

- [ ] Specific missing actions identified for each config
- [ ] Root cause determined for missing completion events
- [ ] Firebase backend actions emit all expected completion events
- [ ] No 30s timeout warnings for firebase-backend-batch-1
- [ ] No 30s timeout warnings for firebase-backend-layer
- [ ] No 30s timeout warnings for system-performance

## ✅ Update (2025-10-03 08:52)

**Task-196 Resolved - This Issue Persists:**

Full test suite run (logs/20251003_085123_test.log) confirms:
- ✅ **battle-animated (Android)**: FIXED by CONNECT_DEFERRED (task-196)
- ❌ **firebase-backend-batch-1 (Android)**: Still 2/3 completion events
- ❌ **firebase-backend-layer (Android)**: Still 2/3 completion events
- ❌ **system-performance (Android)**: Still 4/5 completion events

**Key Finding:**
This is a **DIFFERENT root cause** from task-196:
- Task-196: Event-driven state transitions (battle tests) - RESOLVED
- Task-197: Firebase backend sequential actions - NOT FIXED by CONNECT_DEFERRED

Firebase backend actions don't use event-driven state transitions. They have a different completion pattern that's not emitting all expected SequentialActionCompleteEvent signals.

**Status**: Unblocked - ready for independent investigation.

## Dependencies

~~This task should wait for **task-196** resolution~~ - Task-196 resolved, but fix did not resolve Firebase backend issue. This requires separate investigation.

## Related Tasks

- **task-195**: Event-driven completion fix (Desktop working)
- **task-196**: Android battle test hang investigation (RESOLVED - different issue)
- **task-193**: Sequential action completion events (original implementation)

