---
id: task-329
title: Rename run-desktop to run-editor for semantic clarity
status: Done
assignee: []
created_date: '2025-12-08 23:42'
updated_date: '2025-12-29 00:07'
labels:
  - refactoring
  - just-recipes
  - developer-experience
dependencies: []
priority: low
ordinal: 62.5
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Rename `run-desktop` to `run-editor` to accurately reflect what the command does.

## Context
- `run-desktop` actually runs the **Godot editor**, not an exported desktop build
- `run-macos` runs the **exported .app bundle**, which is the actual desktop build
- The current naming is confusing since both are "desktop" platforms

## Semantic Clarity
| Command | What it Runs | Better Name |
|---------|--------------|-------------|
| `run-desktop` | Godot editor | `run-editor` |
| `run-macos` | Exported .app bundle | (correct) |

## Scope
- ~15 files need updates (5 justfiles, ~9 markdown docs)
- Full rename without backwards compatibility alias
- Update all documentation references

## Files to Update
**Justfiles:**
- `justfile-run.justfile` - Main definition
- `justfile-gamestate-capture.justfile` - 8 occurrences
- `justfile-semantic-replay-commands.justfile` - 4 occurrences
- `justfile-help.justfile` - 2 occurrences
- `justfile-cross-platform-testing.justfile` - 2 occurrences

**Documentation:**
- `CLAUDE.md`, `CLAUDE-ADVANCED.md`
- `project/CLAUDE.md`, `tests/CLAUDE.md`
- `justfiles/CLAUDE.md`, `justfiles/ARCHITECTURE.md`
- Backlog tasks referencing the command
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 All `run-desktop` references renamed to `run-editor` in justfiles
- [ ] #2 All documentation updated (CLAUDE.md files, ARCHITECTURE.md)
- [ ] #3 Backlog tasks referencing `run-desktop` updated
- [ ] #4 `just run-editor` works correctly
- [ ] #5 `just run-editor-debug` works correctly (if renamed)
- [ ] #6 No broken references remain (`rg run-desktop` returns empty)
<!-- AC:END -->
