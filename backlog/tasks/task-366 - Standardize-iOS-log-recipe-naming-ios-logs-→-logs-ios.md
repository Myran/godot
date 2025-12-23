---
id: task-366
title: Standardize iOS log recipe naming (ios-*-logs-* → logs-ios-*)
status: To Do
assignee: []
created_date: '2025-12-23 22:59'
updated_date: '2025-12-23 23:43'
labels:
  - naming
  - ios
  - logs
  - phase-2
dependencies:
  - task-375
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

iOS log recipes use a completely different naming pattern from all other platforms.

**Current naming:**
- `logs-android-device`, `logs-android-errors`, `logs-android-health` ✅
- `logs-editor-errors`, `logs-macos-errors` ✅
- `ios-device-logs-iphone/ipad` ❌ (pattern: `ios-*-logs-*`)
- `ios-recent-logs-iphone/ipad` ❌
- `ios-search-logs-iphone/ipad` ❌
- `ios-retrieve-logs-iphone/ipad` ❌
- `ios-config-logs-iphone/ipad` ❌

## Impact

- Confusing command discovery (searching for `logs-ios-*` finds nothing)
- Breaks consistency across platforms
- Documentation harder to maintain

## Solution

Rename in `justfile-ios-device-logs.justfile`:
- `ios-device-logs-iphone` → `logs-ios-device-iphone`
- `ios-device-logs-ipad` → `logs-ios-device-ipad`
- `ios-recent-logs-iphone` → `logs-ios-recent-iphone`
- `ios-recent-logs-ipad` → `logs-ios-recent-ipad`
- `ios-search-logs-iphone` → `logs-ios-search-iphone`
- `ios-search-logs-ipad` → `logs-ios-search-ipad`
- `ios-retrieve-logs-iphone` → `logs-ios-retrieve-iphone`
- `ios-retrieve-logs-ipad` → `logs-ios-retrieve-ipad`
- `ios-config-logs-iphone` → `logs-ios-config-iphone`
- `ios-config-logs-ipad` → `logs-ios-config-ipad`

Keep old names as deprecated aliases for backwards compatibility.

## Reference

Part of platform parity analysis - Phase 2 Naming Standardization.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 All ios-*-logs-* recipes renamed to logs-ios-* pattern
- [ ] #2 All references updated in justfiles and documentation
- [ ] #3 Validation: just logs-ios-device-iphone executes correctly
- [ ] #4 Validation: just logs-ios-recent-ipad executes correctly
- [ ] #5 Validation: just ios-device-logs-iphone returns 'recipe not found'
- [ ] #6 Validation: just --list | grep logs-ios shows all renamed commands
- [ ] #7 Validation: rg 'ios-.*-logs-' justfiles/ returns empty
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Order: Wave 5 (Direct Renames) - After task-375

Wait for task-375 to establish Android naming pattern, then apply same to iOS.

## No Aliases - Direct Rename with Reference Updates

## Chunked Validation

### Chunk 1: Device Logs (2 recipes)
```bash
# Rename in justfile-ios-device-logs.justfile
ios-device-logs-iphone → logs-ios-device-iphone
ios-device-logs-ipad → logs-ios-device-ipad

# Validate
just logs-ios-device-iphone
just logs-ios-device-ipad

# Verify old names gone
just ios-device-logs-iphone 2>&1 | grep -q "not found"
```

### Chunk 2: Recent Logs (2 recipes)
```bash
ios-recent-logs-iphone → logs-ios-recent-iphone
ios-recent-logs-ipad → logs-ios-recent-ipad

# Validate
just logs-ios-recent-iphone
just logs-ios-recent-ipad
```

### Chunk 3: Search Logs (2 recipes)
```bash
ios-search-logs-iphone → logs-ios-search-iphone
ios-search-logs-ipad → logs-ios-search-ipad

# Validate
just logs-ios-search-iphone "test"
```

### Chunk 4: Retrieve Logs (2 recipes)
```bash
ios-retrieve-logs-iphone → logs-ios-retrieve-iphone
ios-retrieve-logs-ipad → logs-ios-retrieve-ipad
```

### Chunk 5: Config Logs (2 recipes)
```bash
ios-config-logs-iphone → logs-ios-config-iphone
ios-config-logs-ipad → logs-ios-config-ipad
```

### Chunk 6: Update All References
```bash
# Find and update all references
rg "ios-device-logs|ios-recent-logs|ios-search-logs|ios-retrieve-logs|ios-config-logs" \
   CLAUDE.md justfiles/ --files-with-matches

# Update each file
# Validate no stale refs remain
rg "ios-.*-logs-" CLAUDE.md justfiles/ | grep -v "logs-ios-"
# Should return empty
```
<!-- SECTION:PLAN:END -->
