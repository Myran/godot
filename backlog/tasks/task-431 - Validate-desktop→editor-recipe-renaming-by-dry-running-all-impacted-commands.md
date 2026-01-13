---
id: task-431
title: Validate desktop→editor recipe renaming by dry-running all impacted commands
status: Done
assignee: []
created_date: '2026-01-12 21:36'
updated_date: '2026-01-12 21:45'
labels:
  - justfile
  - validation
  - testing
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
We've renamed 'desktop' platform to 'editor' across 19 justfile modules. Need to validate all impacted recipes work correctly by running or dry-running them.

## Impacted Recipes to Validate

### Testing Recipes
- `test-editor-target CONFIG` - automated testing
- `test-editor-manual CONFIG` - manual testing mode
- `test-editor-update CONFIG` - checksum baseline update
- `test-editor-reset CONFIG` - checksum baseline reset

### Cache Clearing Recipes
- `clear-test-editor` - clear editor test config
- `clear-editor-test-cache` - alias for consistency

### Gamestate Recipes
- `capture-gamestate-editor NAME` - state capture
- `capture-lineup-allied-editor NAME` - allied lineup capture
- `capture-lineup-enemy-editor NAME` - enemy lineup capture
- `test-save-load-cycle-with-state-editor` - save/load consistency

### Replay Recipes
- `replay-generate-from-last-session-editor CONFIG` - replay from last session

### Log Commands (with platform detection)
- `logs-errors TEST_ID` - auto-detects editor_* TEST_ID
- `logs-search TEST_ID "TERM" [PLATFORM]` - platform parameter
- `logs-pattern TEST_ID PATTERN` - auto-detects platform

## Validation Approach
1. Use `just --list | grep editor` to verify all recipes exist
2. Dry-run commands that don't require actual execution
3. Test platform auto-detection with editor_* TEST_ID patterns
4. Verify no orphaned references to `clear-test-desktop` or other removed aliases

## Files Changed
- justfiles/justfile-core-config.justfile
- justfiles/justfile-gamestate-capture.justfile
- justfiles/justfile-log-filter-commands.justfile
- justfiles/justfile-platform-ios.justfile
- justfiles/justfile-run.justfile
- justfiles/justfile-semantic-replay-commands.justfile
- justfiles/justfile-validation-enhanced-testing.justfile
- justfiles/justfile-wildcard-commands.justfile
- justfiles/CLAUDE.md
- justfiles/ARCHITECTURE.md
- Plus 9 more modules
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Validation Complete ✅

All renamed recipes verified working:

### Testing Recipes ✅
- `test-editor-target CONFIG` - automated testing
- `test-editor-manual CONFIG` - manual testing mode
- `test-editor-update CONFIG` - checksum baseline update
- `test-editor-reset CONFIG` - checksum baseline reset

### Cache Clearing Recipes ✅
- `clear-test-editor` - clear editor test config
- `clear-editor-test-cache` - alias for consistency

### Gamestate Recipes ✅
- `capture-gamestate-editor NAME` - state capture
- `capture-lineup-allied-editor NAME` - allied lineup capture
- `capture-lineup-enemy-editor NAME` - enemy lineup capture
- `test-save-load-cycle-with-state-editor` - save/load consistency

### Replay Recipes ✅
- `replay-generate-editor SESSION_ID CONFIG` - replay generation
- `replay-generate-from-last-session-editor CONFIG` - from last session

### Log Commands ✅
- `logs-editor TEST_ID [TAGS]` - platform-specific logs
- `logs-editor-errors TEST_ID [TAGS]` - platform-specific errors
- `logs-errors TEST_ID [PLATFORM]` - with editor auto-detection
- `logs-search TEST_ID "TERM" [PLATFORM]` - with editor auto-detection

### Platform Auto-Detection ✅
- `elif [[ "$TEST_ID" == editor_* ]]; then PLATFORM="editor"` works correctly

### Orphaned References ✅
- No orphaned references to removed aliases (`clear-test-desktop`, `clear-desktop-test-cache`)

Documentation Validation Complete ✅

All help and markdown documentation updated:

### Root Documentation

- ✅ CLAUDE.md - Updated

- ✅ CLAUDE-ADVANCED.md - Updated 14 references (test-desktop, logs-desktop, DESKTOP_TEST_MAX_TIMEOUT)

### Project-Specific Documentation

- ✅ project/CLAUDE.md - Updated test-desktop-target → test-editor-target

- ✅ tests/CLAUDE.md - Updated 8 references (test-desktop-manual, test-prepare-desktop, etc)

### Justfile Documentation

- ✅ justfiles/CLAUDE.md - Updated 3 references

- ✅ justfiles/ARCHITECTURE.md - Updated 2 references

**Total: 23 files changed** (19 justfiles + 2 test configs + 4 documentation files)
<!-- SECTION:NOTES:END -->
