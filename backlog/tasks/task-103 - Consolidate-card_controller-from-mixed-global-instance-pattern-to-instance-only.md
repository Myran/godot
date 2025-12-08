---
id: task-103
title: Consolidate card_controller from mixed global/instance pattern to instance-only
status: In Progress
priority: medium
labels:
  - architecture
  - refactoring
  - technical-debt
created_date: '2025-08-27'
updated_date: '2025-08-27'
---

# Task-103: Consolidate card_controller from mixed global/instance pattern to instance-only

**Status**: 🔄 In Progress
**Priority**: Medium (Architectural Debt)
**Effort**: 3-4 days
**Created**: 2025-08-27  

## Problem Statement

GameTwo currently has a problematic mixed pattern for `card_controller` access:
- **Global Autoload**: Defined in `project.godot` as singleton 
- **16 files** using global `card_controller.*` calls
- **1 file** using instance-based `game.card_controller.*` calls  
- **No actual card_controller property** in Game class (works via Godot's autoload access)

This creates architectural confusion and inconsistency:
```gdscript
# Confusing - which card_controller am I getting?
var card1 = card_controller.create_unit_from_id("1", 1)  # Global singleton
var card2 = game.card_controller.create_unit_from_id("1", 1)  # Same global via node access
```

## Solution Overview

**Decision**: Remove global autoload, consolidate to instance-based pattern only.

**Rationale**: 
- Card state should be tied to specific game instances for better isolation
- Improves testability and supports multiple game instances
- Makes dependencies explicit and reduces architectural confusion
- Future-proof for game modes or multi-instance scenarios

## Implementation Plan

### Phase 1: Game Class Enhancement ⏳
- [ ] Add `@export var card_controller: CardController` to Game class
- [ ] Wire up card_controller instance in Game.tscn scene
- [ ] Update Game._ready() initialization to properly set up card_controller
- [ ] Add property accessor methods if needed

### Phase 2: Global Reference Migration 📝
**Files requiring `card_controller.*` → `game.card_controller.*` conversion:**

**Core System Files (8 files):**
- [ ] `core/lineup_handler.gd` - 1 reference
- [ ] `core/clicker/clicker.gd` - 2 references (setup + create_unit_from_id)  
- [ ] `core/clicker/level_controller.gd` - 1 reference
- [ ] `core/card/card.gd` - 1 reference
- [ ] `core/clicker/blocks/block_base_card.gd` - 3 references

**Debug System Files (3 files):**
- [ ] `debug/utilities/session_manager.gd` - 2 references
- [ ] `debug/actions/registrations/game_action_player.gd` - 1 reference
- [ ] `debug/actions/registrations/game_action_core.gd` - 4 references

### Phase 3: Special Cases & Complex Migrations 🔧
- [ ] Handle `core/clicker/clicker.gd:15` - `card_controller.setup()` with game context
- [ ] Evaluate `card_controller.get_card_image_name()` calls - determine if should stay global
- [ ] Debug actions without direct game access - implement dependency injection
- [ ] Files that need Game instance parameter passing

### Phase 4: Global Autoload Removal 🗑️
- [ ] Remove `card_controller="*res://autoloads/card_controller.tscn"` from project.godot
- [ ] Update any remaining autoload singleton references
- [ ] Clean up autoload directory if needed

### Phase 5: Testing & Validation ✅
- [ ] Run complete validation pipeline (`just ci-validate`)
- [ ] Test save/load functionality specifically (our recent fixes)
- [ ] Run comprehensive test suite (`just test-android development-workflow`)
- [ ] Validate cycle-test-capture-33 still works correctly
- [ ] Performance benchmarking before/after

## Files Affected

**Direct Changes Required:**
- `project/project.godot` - Remove autoload
- `project/core/game.gd` - Add card_controller property
- `project/core/game.tscn` - Wire up card_controller node
- 16 files with global card_controller references

**Potential Ripple Effects:**
- Any files that indirectly depend on global card_controller access
- Test files that might reference card_controller globally

## Success Criteria

✅ **Single Pattern**: All card_controller access uses `game.card_controller.*` pattern  
✅ **No Global Autoload**: card_controller removed from project.godot autoload section  
✅ **All Tests Pass**: Complete validation pipeline passes without regressions  
✅ **Save/Load Works**: cycle-test-capture-33 validation continues to work  
✅ **Performance Maintained**: No significant performance degradation  

## Benefits

✅ **Cleaner Architecture**: Single consistent pattern for card_controller access  
✅ **Better Testability**: Each game instance has its own isolated card_controller  
✅ **Reduced Confusion**: Clear, explicit dependency pattern  
✅ **Future-Proof**: Supports multiple game instances or specialized game modes  
✅ **Explicit Dependencies**: Makes component dependencies visible and manageable  

## Risks & Mitigation

⚠️ **Risk**: Breaking changes across many files  
🛡️ **Mitigation**: Staged implementation with comprehensive testing at each phase

⚠️ **Risk**: Performance impact from dependency injection  
🛡️ **Mitigation**: Benchmark before/after (expected to be negligible)

⚠️ **Risk**: Missed global references causing runtime errors  
🛡️ **Mitigation**: Thorough code search and systematic validation

## Related Tasks

- Related to recent save/load state fixes (Tasks 101-102)
- Part of broader architectural cleanup and technical debt reduction
- Foundation for potential future multi-instance or game mode features

## Completion Criteria

Task is complete when:
1. All card_controller access uses instance-based pattern
2. Global autoload is removed from project configuration  
3. Complete validation pipeline passes (`just ci-validate`)
4. Core functionality tests pass (save/load, card creation, game flow)
5. No performance regressions detected
6. Code review confirms architectural consistency

---

**Notes**: This task builds on the recent save/load state improvements and represents a significant architectural cleanup that will improve code maintainability and testability going forward.