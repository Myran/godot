---
id: task-182
title: Fix polling loop anti-pattern in replay completion action sequencing
status: To Do
assignee: []
created_date: '2025-09-26 17:09'
labels:
  - code-quality
  - architecture
  - async
  - replay
dependencies: []
priority: high
---

## Description

Replace the temporary polling loop in _replay_complete() with proper signal-based await pattern for reliable action completion before quit.

## Context

This task was created as a follow-up to the successful architecture simplification in task-172.01. While the replay completion architecture was successfully simplified and is working (100% test pass rate), a temporary polling loop was implemented as a quick fix to resolve the missing `system.debug.registry_stats` success logging issue.

## Current Problem

**Location:** `project/debug/actions/registrations/system_actions.gd:432-433`

**Current Anti-Pattern Code:**
```gdscript
# Wait for queue to empty (all actions including registry_stats complete their success logging)
if game_node:
    while game_node._idle_action_queue.size() > 0:
        await Engine.get_main_loop().process_frame
```

**Issues with Current Implementation:**
1. **Polling is Anti-Pattern**: Uses inefficient `while` loop with `await process_frame`
2. **Code Quality**: Not the proper Godot/async pattern
3. **Reliability**: Potential race conditions and timing issues
4. **Performance**: Unnecessary frame polling when signals could be used

## Acceptance Criteria
- [ ] Replace polling loop with proper signal-based await mechanism
- [ ] Maintain 100% test pass rate across all platforms
- [ ] Ensure `system.debug.registry_stats` success logging continues to work
- [ ] No regression in replay completion timing or functionality
- [ ] Code follows Godot async best practices
- [ ] Solution is cross-platform compatible (Desktop + Android)

## Implementation Approach

**Target Area:** Game class action processing in `project/core/game.gd`
- **Current:** `_processing_idle_action` boolean flag
- **Goal:** Signal-based action completion notification

**Potential Solutions:**
1. **Create Custom Signal:** Add signal to Game class emitted when action processing completes
2. **Use Existing Signals:** Leverage any existing action completion signals
3. **Event-based Approach:** Use Godot's event system for action completion notification

**Files to Modify:**
- `project/debug/actions/registrations/system_actions.gd` - Update await mechanism
- `project/core/game.gd` - Add signal-based action completion (if needed)

## Related Work
- **task-172.01**: Successfully implemented replay completion architecture simplification
- **task-172**: Original queue sequencing stabilization work
- **Current Status**: Architecture working perfectly, only polling loop needs replacement

## Success Metrics
- Elimination of polling loop anti-pattern
- Maintained or improved test reliability
- Cleaner, more maintainable code
- Proper async/await patterns throughout
