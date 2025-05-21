# Debug System Refactoring Plan

## Overview
The current debug system has grown organically, resulting in "God Classes" that violate core software design principles. This refactoring aims to create a modular, extensible debug system following SOLID principles:

- **Single Responsibility Principle (SRP)**: Each class should have one reason to change
- **Open/Closed Principle (OCP)**: Software entities should be open for extension but closed for modification
- **Don't Repeat Yourself (DRY)**: Avoid duplicate code
- **KISS**: Keep It Simple

## Current Issues
- `scene_debug.gd`: A "God Class" handling UI management, Firebase module management, test execution, signal handling, and test navigation
- `debug.gd`: An event bus with UI interaction logic and a large match statement for button presses (violates OCP)

## Proposed Structure
1. **DebugAction.gd** (Resource): Define single debug actions or tests
2. **DebugActionRegistry.gd** (Node or Autoload): Discover and store DebugAction resources
3. **DebugMenuController.gd** (was scene_debug.gd): Manage the main debug UI
4. **DebugManager.gd** (was debug.gd - Autoload): Global event bus for debug system-wide events

## Implementation Tasks

| Task | Status | Notes |
|------|--------|-------|
| 1. Create `DebugAction.gd` resource script | Not Started | Resource defining the action interface |
| 2. Create sample `DebugAction` implementation | Not Started | Example: RTDBSetSimpleValueAction |
| 3. Create `DebugActionRegistry.gd` | Not Started | Manages action discovery and access |
| 4. Refactor `debug.gd` to `DebugManager.gd` | Not Started | Clean event bus implementation |
| 5. Refactor `scene_debug.gd` to `DebugMenuController.gd` | Not Started | UI controller for debug menu |
| 6. Update `main.gd` (or equivalent) | Not Started | Proper instancing and integration |
| 7. Optional: Refactor legacy popup controller | Not Started | If keeping the simple popup |
| 8. Testing: Verify all original functionality works | Not Started | Compare against original behavior |
| 9. Documentation: Update as needed | In Progress | This document is part of documentation |

## File Paths to Create/Modify
- New: `/Users/mattiasmyhrman/repos/gametwo/project/debug/actions/debug_action.gd`
- New: `/Users/mattiasmyhrman/repos/gametwo/project/debug/actions/rtdb/rtdb_set_simple_value_action.gd`
- New: `/Users/mattiasmyhrman/repos/gametwo/project/debug/debug_action_registry.gd`
- Modify: `/Users/mattiasmyhrman/repos/gametwo/project/autoloads/debug.gd` -> `debug_manager.gd`
- Modify: `/Users/mattiasmyhrman/repos/gametwo/project/debug/scene_debug.gd` -> `debug_menu_controller.gd`
- Modify: `/Users/mattiasmyhrman/repos/gametwo/project/main.gd` (if needed)

## Progress Tracking
- Refactoring Started: [Date]
- Current Progress: 0%
- Estimated Completion: [Date]

## Testing Strategy
1. Catalog all current debug actions and their expected behavior before refactoring
2. Create a simple checklist to verify each action works post-refactoring
3. Test both UI navigation and action execution for each action
4. Verify event handling works across the system

## Notes and Resources
- [Refactoring Plan Details](memory://projects/game-two-refactoring-plan)
- [Type Safety Guidelines](memory://projects/game-two-type-safety-guidelines)
