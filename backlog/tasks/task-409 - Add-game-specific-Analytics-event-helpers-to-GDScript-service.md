---
id: task-409
title: Add game-specific Analytics event helpers to GDScript service
status: To Do
assignee: []
created_date: '2025-12-31 22:59'
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
Extend AnalyticsService with game-specific event tracking helpers (GDScript layer, not C++).

**Design Principle**: Game-specific helpers belong in GDScript, not C++. This allows iteration without rebuilding templates.

**Helpers to Add**:
```gdscript
# Battle events
func track_battle_start(battle_type: String, level: int) -> void
func track_battle_end(result: String, duration_ms: int) -> void
func track_card_played(card_id: String, card_name: String) -> void
func track_turn_completed(turn_number: int) -> void

# Progression events
func track_level_start(level_id: String, difficulty: String) -> void
func track_level_complete(level_id: String, stars: int) -> void
func track_xp_gained(amount: int, source: String) -> void

# Session events
func track_session_start() -> void
func track_session_end(duration_seconds: int) -> void

# Economy events (if needed)
func track_purchase(item_id: String, currency: String, amount: float) -> void
```

**Acceptance Criteria**:
- All helpers use log_event_params() internally
- Parameter validation follows Firebase naming rules
- Documented in AnalyticsService class reference
- Unit tests for each helper
<!-- SECTION:DESCRIPTION:END -->
