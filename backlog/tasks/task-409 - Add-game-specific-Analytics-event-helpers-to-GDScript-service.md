---
id: task-409
title: Add game-specific Analytics event helpers to GDScript service
status: Done
assignee: []
created_date: '2025-12-31 22:59'
updated_date: '2026-01-06 22:53'
labels:
  - firebase
  - analytics
  - gdscript
  - enhancement
dependencies:
  - task-402
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Revised: Add tracking constants and optional convenience wrappers. Use ONE core log_event_params() with constants (EVENT_*, PARAM_*), NOT multiple custom methods. Convenience wrappers like track_battle_start() are optional for readability only.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Revised Architecture (2026-01-06)

### Design Principle
Use ONE core tracking method with constants + data, NOT multiple custom methods.

### Architecture

### Implementation
1. Add missing tracking constants (event names, parameter names)
2. Add optional convenience wrapper methods for readability
3. Document how to use the core method directly

### Usage Pattern

### Constants to Add
- Event names: EVENT_TURN_COMPLETE, EVENT_SESSION_START, EVENT_SESSION_END, EVENT_XP_GAINED
- Parameter names: PARAM_DURATION_MS, PARAM_DIFFICULTY, PARAM_SOURCE, PARAM_TURN_NUMBER
<!-- SECTION:NOTES:END -->
