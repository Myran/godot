---
id: task-397
title: >-
  Fix battle-animated Android test failure - game.lineup.populate_enemy action
  failing
status: Done
assignee: []
created_date: '2025-12-30 13:57'
updated_date: '2025-12-30 14:05'
labels:
  - android
  - test-failure
  - battle-system
  - pipeline-blocker
dependencies: []
priority: high
ordinal: 294000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Issue:**
During pipeline-rebuild-ship test run, the `battle-animated` config failed on Android.

**Error:**
```
| `game.lineup.populate_enemy` | Gameplay | ❌ **FAILED** | 153ms |
❌ TEST FAILED: Not all actions passed (1/2 failed)
```

**Context:**
- Test ID: battle-animated_android_1767100052
- Platform: Android only (passed on editor, macos, windows, windows-physical)
- The `game.lineup.populate_enemy` action is failing while `game.battle.test_determinism_animated` may not be reached

**Investigation needed:**
1. Check logs for specific error in populate_enemy action
2. Determine if this is a timing issue, race condition, or logic error
3. Compare with working platforms to identify Android-specific behavior

**Commands:**
```bash
just logs-errors battle-animated_android_1767100052
just logs-search battle-animated_android_1767100052 "populate_enemy"
just logs-android battle-animated_android_1767100052
```
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Root Cause Analysis (OODA Loop)

**OBSERVE:**
- Firebase RTDB request for `cards_0` timed out after 45 seconds
- Other platforms (editor, macOS, Windows) loaded cards in <300ms
- Previous Android runs (Dec 28-29) succeeded in ~500ms

**ORIENT:**
| Platform | Duration | Result |
|----------|----------|--------|
| Android Dec 28 | 486ms | ✅ |
| Android Dec 29 | 498ms | ✅ |
| Android Dec 30 (failed) | 45,067ms | ❌ Timeout |
| Android Dec 30 (re-run) | 3,652ms | ✅ |

**DECIDE:**
Transient network issue, not a code defect.

**ACT:**
Re-ran test - passed successfully.

**Root Cause:** Intermittent Firebase RTDB network timeout on Android device. The 45-second timeout indicates a complete network stall, likely due to WiFi connectivity issues or cellular handoff.

**Resolution:** No code changes required. Test passes under normal network conditions.
<!-- SECTION:NOTES:END -->
