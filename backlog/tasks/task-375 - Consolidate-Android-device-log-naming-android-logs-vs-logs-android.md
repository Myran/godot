---
id: task-375
title: Consolidate Android device log naming (android-logs-* vs logs-android-*)
status: Done
assignee: []
created_date: '2025-12-23 23:01'
updated_date: '2025-12-29 00:07'
labels:
  - naming
  - android
  - logs
  - infrastructure
dependencies:
  - task-374
priority: medium
ordinal: 263000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

Android has two competing naming patterns for device log commands:

**Pattern 1: `logs-android-*` (newer, streamlined)**
- `logs-android-device` - Device log search
- `logs-android-errors` - Error-focused analysis
- `logs-android-health` - Buffer health
- `logs-android-status` - Device status
- `logs-android-clear` - Clear buffers

**Pattern 2: `android-logs-*` (older, more verbose)**
- `android-logs-errors` - Live error monitoring
- `android-logs-live` - Live log monitoring
- `android-logs-tagged` - Tag-based filtering
- `android-logs-performance` - Performance monitoring
- `android-logs-recent` - Recent logs
- `android-logs-monitor-*` - Background monitoring

## Analysis

These serve **different purposes**:
- `logs-android-*` = Saved test result analysis
- `android-logs-*` = Live device monitoring

## Solution

**Option A: Keep both but document distinction**
- Add clear documentation distinguishing the two patterns
- Update help commands to explain when to use each

**Option B: Consolidate naming (more work)**
- Rename `android-logs-*` → `logs-android-live-*`
- Examples: `logs-android-live-errors`, `logs-android-live-tagged`
- Add deprecation aliases

**Recommendation:** Option A first, then Option B if confusion persists.

## Reference

Part of platform parity analysis - Infrastructure/Cleanup.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Documentation distinguishes logs-android-* (saved) vs android-logs-* (live)
- [x] #2 Help commands updated to explain when to use each pattern
- [x] #3 Decision made: keep both patterns or consolidate naming
- [ ] #4 If consolidating: rename android-logs-* to logs-android-live-*
- [x] #5 Validation: just help-logs explains the distinction clearly
- [x] #6 Validation: All renamed commands work correctly with deprecation warnings
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Order: Wave 1 (After task-374)

Establish clean log naming pattern before adding iOS/Windows log commands.

## Decision Required
`logs-android-*` (saved test logs) vs `android-logs-*` (live device) - keep distinct or unify?

**Recommended**: Rename `android-logs-*` → `logs-android-live-*` for consistency.

## Chunked Validation (if renaming)

### Chunk 1: Live Error Monitoring
```bash
# Rename
android-logs-errors → logs-android-live-errors
# Validate
just logs-android-live-errors 10
# Verify old gone
just android-logs-errors 2>&1 | grep -q "not found"
```

### Chunk 2: Live Log Monitoring
```bash
android-logs-live → logs-android-live
android-logs-tagged → logs-android-live-tagged
# Validate each
just logs-android-live 10
just logs-android-live-tagged "firebase" 10
```

### Chunk 3: Background Monitoring
```bash
android-logs-monitor-* → logs-android-monitor-*
# Validate
just logs-android-monitor-background TEST_ID /tmp/test.log
```

### Chunk 4: Update Documentation
```bash
# Find stale references
rg "android-logs-" CLAUDE.md justfiles/
# Update all, validate none remain
```
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Implementation: Option A (Documentation)

Chose Option A (document distinction) rather than renaming for:

- Lower risk - no breaking changes

- Both patterns serve distinct purposes (saved vs live)

- Some deprecations already in place

Updated justfile-android-device-logs.justfile header with:

- Clear distinction between logs-android-* (saved test results) and android-logs-* (live monitoring)

- Usage guidance for when to use each pattern

- Complete command listings for both patterns

Validation: just --list confirms all commands still work
<!-- SECTION:NOTES:END -->
