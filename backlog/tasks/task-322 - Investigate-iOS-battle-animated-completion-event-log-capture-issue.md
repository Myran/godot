---
id: task-322
title: Investigate iOS battle-animated completion event log capture issue
status: To Do
assignee: []
created_date: '2025-11-29 21:36'
updated_date: '2025-11-29 21:36'
labels:
  - ios
  - test-framework
  - battle
priority: high
dependencies:
  - task-321
---

## Description

iOS battle-animated test detects only 1/2 completion events (missing the battle action completion event), while Android properly detects 2/2 events.

## Problem

**iOS Behavior:**
- Test config: `battle-animated` (3 actions)
- Expected: 2 sequential completion events (populate_enemy + test_determinism_animated)
- Actual: Only 1 completion event detected (populate_enemy)
- Result: Test times out after 45s waiting for second event

**Android Behavior (Working):**
- Same config: `battle-animated`
- Detects: 2/2 completion events properly
- Test passes in ~9 seconds

## Evidence

### Test Results
- Android test ID: `battle-animated_android_1764451633` - PASSED
- iOS test ID: `battle-animated_ios_1764451988` - FAILED (timeout)

### Logs Location
- Full iOS test log: `logs/20251129_223308_test-ios-ipad_battle-animated.log`
- iOS device log: `/Users/mattiasmyhrman/Library/Application Support/Godot/app_userdata/gametwo/logs/ios_battle-animated_ios_1764451988.log`

### Key Findings
From iOS logs, only `populate_enemy` completion event is captured:
```
[INFO] [debug, sequential, completion, unified] Sequential action completed - emitting completion event { "action": "game.lineup.populate_enemy", "success": true, "category": "Gameplay", "auto_continue": false, "completion_event": "SequentialActionCompleteEvent", "test_id": "battle-animated_ios_1764451988" }
```

Missing: `test_determinism_animated` completion event (should appear but doesn't in iOS logs)

## Investigation Areas

1. **iOS Log Buffering/Timing**
   - iOS may buffer logs differently than Android
   - Battle action takes ~6 seconds on Android - iOS log capture may miss timing window
   - Check if log extraction happens before battle completion event is flushed

2. **Log Capture Method**
   - Review iOS log extraction timing in justfile
   - Compare with Android's successful capture method
   - May need different timing/buffering strategy for iOS

3. **Event Emission Verification**
   - Verify battle action actually emits completion event on iOS (not just log capture issue)
   - Check if `game_action_core.gd:828-832` executes on iOS
   - Add additional diagnostic logging before/after event emission

## Context

This issue was discovered during task-321 validation. Task-321 fixes (unified timeouts, fail on timeout) are working correctly - the timeout now properly fails the test. However, the underlying issue of missing iOS completion events remains.

## Success Criteria

- [ ] iOS battle-animated test detects 2/2 completion events
- [ ] Test completes without timeout (within 45s)
- [ ] Behavior matches Android (both platforms consistent)

## Related

- Closes: task-321 (partial - timeout behavior fixed, log capture issue remains)
- Commit: 6b7d4b2b (task-321 fixes)
