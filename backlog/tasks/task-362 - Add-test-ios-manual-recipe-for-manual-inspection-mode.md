---
id: task-362
title: Add test-ios-manual recipe for manual inspection mode
status: To Do
assignee: []
created_date: '2025-12-23 22:58'
updated_date: '2025-12-23 23:42'
labels:
  - testing
  - parity
  - ios
  - phase-1
dependencies:
  - task-376
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

iOS platform is missing a manual testing mode that keeps the app running for inspection.

**Current state:**
- `test-android-manual CONFIG` ✅
- `test-macos-manual CONFIG` ✅
- `test-editor-manual CONFIG` ✅
- `test-windows-physical-manual CONFIG` ✅
- `test-ios-manual CONFIG` ❌ MISSING

iOS has device-specific variants (`test-ios-iphone`, `test-ios-ipad`) but no explicit manual mode.

## Impact

Cannot keep iOS app running for manual inspection and debugging after test execution.

## Solution

Add `test-ios-manual CONFIG` recipe in `justfile-validation-enhanced-testing.justfile` that:
1. Deploys config to iOS device
2. Launches app without auto-exit timeout
3. Stays open for manual inspection

## Reference

Part of platform parity analysis - Phase 1 Critical Parity.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Recipe test-ios-manual CONFIG implemented in justfile
- [ ] #2 Recipe deploys config to iOS device without auto-exit timeout
- [ ] #3 App stays running for manual inspection
- [ ] #4 Validation: just test-ios-manual battle-animated deploys and launches
- [ ] #5 Validation: App does not auto-exit after debug actions complete
- [ ] #6 Validation: Works with both iPhone and iPad devices
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Order: Wave 3 (iOS Parity)

## Shared Code Path
Reuse `_execute-test-manual` pattern if it exists, or follow test-android-manual implementation.

## Chunked Validation

### Chunk 1: Identify Manual Test Pattern
```bash
# Find existing manual implementation
rg "test-android-manual|test-macos-manual" justfiles/ -A15
# Look for shared helper
rg "_execute-test-manual" justfiles/
```

### Chunk 2: Implement test-ios-manual
```just
# In justfile-platform-ios.justfile or justfile-validation-enhanced-testing.justfile
test-ios-manual CONFIG:
    @echo "Starting iOS manual test: {{CONFIG}}"
    @just _deploy-ios-config {{CONFIG}}
    @# Launch without auto-exit timeout
    @just _launch-ios-app --no-timeout
    @echo "App running - manually inspect and close when done"
```

### Chunk 3: Validate
```bash
# Deploy and launch
just test-ios-manual battle-animated
# Verify: app stays open, doesn't auto-exit
# Manually close app

# Check it appears in list
just --list | grep "test-ios-manual"
```
<!-- SECTION:PLAN:END -->
