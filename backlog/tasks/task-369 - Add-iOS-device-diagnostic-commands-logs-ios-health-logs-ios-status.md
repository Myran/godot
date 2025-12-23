---
id: task-369
title: 'Add iOS device diagnostic commands (logs-ios-health, logs-ios-status)'
status: To Do
assignee: []
created_date: '2025-12-23 23:00'
updated_date: '2025-12-23 23:42'
labels:
  - logs
  - ios
  - parity
  - phase-3
dependencies:
  - task-375
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

iOS platform is missing device-level diagnostic commands that exist for Android.

**Current state:**
- `logs-android-health` ✅ (buffer health monitoring)
- `logs-android-status` ✅ (device & app diagnostics)
- `logs-android-device` ✅ (full device log search)
- `logs-ios-health` ❌ MISSING
- `logs-ios-status` ❌ MISSING
- `logs-ios-device` ❌ MISSING (has `ios-device-logs-*` variants)

## Impact

- Cannot monitor iOS log buffer health
- Cannot quickly check iOS device/app status
- Must use multiple commands for diagnostics

## Solution

Add recipes in `justfile-ios-device-logs.justfile`:
1. `logs-ios-health` - Check iOS log system health (if applicable to iOS logging)
2. `logs-ios-status` - Device and app status check
3. `logs-ios-device SEARCH_TERM` - Unified device log search (consolidate iphone/ipad variants)

Note: iOS logging architecture differs from Android logcat. Investigate iOS-specific equivalents:
- `log show` command capabilities
- Console.app log stream
- Device system log rotation

## Reference

Part of platform parity analysis - Phase 3 Feature Parity.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Recipe logs-ios-health implemented (or documented as N/A if iOS doesn't support)
- [ ] #2 Recipe logs-ios-status implemented
- [ ] #3 Recipe logs-ios-device SEARCH_TERM implemented (unified iphone/ipad)
- [ ] #4 Validation: just logs-ios-status shows connected iOS device info
- [ ] #5 Validation: just logs-ios-device 'firebase' returns matching logs
- [ ] #6 Validation: Commands work for both iPhone and iPad devices
- [ ] #7 Documentation updated with iOS log command reference
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Order: Wave 3 (iOS Parity) - After task-375

Wait for task-375 to establish naming pattern, then follow it for iOS.

## Shared Code Path
Follow exact pattern established by `logs-android-*` (or `logs-android-live-*` after task-375).

## Chunked Validation

### Chunk 1: Implement logs-ios-status
```just
logs-ios-status:
    @echo "=== iOS Device Status ==="
    @xcrun devicectl list devices 2>/dev/null || echo "No devices found"
    @echo ""
    @echo "=== App Status ==="
    @# Check if gametwo is installed/running
```
Validate: `just logs-ios-status` shows device info

### Chunk 2: Implement logs-ios-device
```just
# Unified search (auto-detects iPhone vs iPad)
logs-ios-device SEARCH_TERM LINES="100":
    @# Detect connected device type
    @# Call appropriate ios-device-logs-iphone or ios-device-logs-ipad
```
Validate: `just logs-ios-device "firebase" 50`

### Chunk 3: Implement logs-ios-health (if applicable)
```just
# iOS may not have buffer issues like Android
# Document if N/A
logs-ios-health:
    @echo "iOS logging does not have buffer limitations like Android"
    @echo "Use 'just logs-ios-status' for device health"
```

### Chunk 4: Verify Pattern Consistency
```bash
# Should match Android pattern
just --list | grep "logs-ios-"
just --list | grep "logs-android-"
# Patterns should align
```
<!-- SECTION:PLAN:END -->
