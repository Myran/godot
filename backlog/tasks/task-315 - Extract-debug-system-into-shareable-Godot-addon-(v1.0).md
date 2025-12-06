---
id: task-315
title: Extract debug system into shareable Godot addon (v1.0)
status: Done
assignee: []
created_date: '2025-11-26 09:49'
updated_date: '2025-12-06 09:52'
labels:
  - architecture
  - addon
  - open-source
  - debug-system
dependencies: []
priority: high
---

## Description

Extract the debug menu and debug action system as a reusable Godot addon that can be:
1. **Open-sourced** for community use
2. **Easily disabled** in production builds by not including the addon

## Research Findings (2025-12-05)

### Viability Assessment: HIGH

The debug system is well-architected for extraction. Clean separation exists between:
- **Core framework** (extractable) - Base classes, registry, UI
- **Game-specific actions** (stays in project) - Firebase, battle, card actions

### Current System Statistics

| Component | Files | Lines | Extractable |
|-----------|-------|-------|-------------|
| Core Infrastructure | 11 | ~3,000 | Yes |
| Action Implementations | 70+ | ~15,000 | No (game-specific) |
| Registration Modules | 7 | ~1,500 | No (game-specific) |
| Total Debug System | 96 | ~20,000 | Partial |

### Extractable Core Components (~11 files)

**Base Classes:**
- `debug_action.gd` (~800 lines) - Base class for all actions
- `debug_action_result.gd` (~226 lines) - Result wrapper
- `debug_action_registry.gd` (~240 lines) - Action discovery & registration

**Output System:**
- `debug_output_service.gd` - Action output formatting
- `debug_output_formatter.gd` - Rich text formatting
- `format_utilities.gd` - Text helpers

**Menu UI:**
- `debug_menu_controller.gd` (~800 lines) - Main controller
- `menu_utilities.gd` - UI generation helpers
- `menu_list_item_data.gd` - Menu item metadata
- `scene_debug.tscn` - UI scene
- `theme_debugmenu.tres` (20MB) - Theme resource

**Utilities:**
- `ui_constants.gd` - Color & font constants
- `performance_analyzer.gd` - Metrics visualization

### Non-Extractable Components (Game-Specific)

**Why not extractable:**
- Direct references to `CardController`, `BattleSystem`, `DraftSystem`
- Uses `core` autoload (game state machine)
- References `Cards` namespace and card database
- Integrates with `StateExtractor` for game state checksums

**Action Categories (80 total actions):**
- `cpp.*` - C++ Firebase SDK tests
- `backend.*` - Firebase service layer
- `rtdb.*` - Realtime Database API
- `system.*` - System utilities
- `game.*` - Game mechanics

### Production Exclusion Options

**Option 1: .gdignore (Simplest)**
```
addons/debug_framework/.gdignore
```
- Excludes entire addon folder from exports
- Editor still loads for development

**Option 2: Feature Flags**
```gdscript
if OS.is_debug_build() and ProjectSettings.get_setting("debug_framework/enabled"):
    setup_debug_features()
```

**Option 3: Conditional Autoload (Current Pattern)**
```gdscript
# plugin.gd
func _enter_tree() -> void:
    if OS.is_debug_build():
        add_autoload_singleton("DebugRegistry", REGISTRY_PATH)
```

**Option 4: Separate Export Preset**
- Production preset excludes `addons/debug_framework/`
- Debug preset includes all addons

### Recommended Addon Structure

```
addons/
  debug_framework/
    plugin.cfg
    plugin.gd                    # EditorPlugin entry
    core/
      debug_action.gd          # Base class
      debug_action_result.gd   # Result wrapper
      debug_action_registry.gd # Registry
    output/
      debug_output_service.gd
      debug_output_formatter.gd
      format_utilities.gd
    ui/
      debug_menu_controller.gd
      menu_utilities.gd
      menu_list_item_data.gd
      ui_constants.gd
      performance_analyzer.gd
    scenes/
      debug_menu.tscn
    themes/
      debug_theme.tres
```

### Extension Pattern for Games

Games would extend the addon by:

**1. Create game-specific actions:**
```gdscript
# project/debug/actions/my_game_action.gd
extends DebugAction  # From addon

func _init() -> void:
    action_name = "game.my_action"
    category = "game"
    group = "testing"

func _execute() -> Dictionary:
    # Game-specific logic
    return {"success": true}
```

**2. Register actions at startup:**
```gdscript
# project/autoloads/game_debug_setup.gd
func _ready() -> void:
    if Engine.has_singleton("DebugRegistry"):
        var registry = Engine.get_singleton("DebugRegistry")
        registry.register_action(MyGameAction.new())
```

### Dependencies to Abstract

| Current Dependency | Addon Solution |
|--------------------|----------------|
| `Log` (advanced_logger) | Optional integration via interface |
| `core` autoload | Remove - games provide their own |
| `StateExtractor` | Optional extension point |
| `SessionManager` | Include in addon or optional |
| `DebugConfigReader` | Include in addon |

### Effort Estimate

| Phase | Description | Complexity |
|-------|-------------|------------|
| 1 | Extract core framework | Medium |
| 2 | Abstract game dependencies | Medium |
| 3 | Create extension points | Low |
| 4 | Documentation & examples | Low |
| 5 | Production exclusion setup | Low |

**Total: ~3-5 days of focused work**

### Benefits

1. **Open Source**: Community contribution & adoption
2. **Maintainability**: Single source of truth for debug framework
3. **Clean Production**: Zero debug code in production builds
4. **Reusability**: Use in future projects immediately
5. **Testing**: Isolated addon easier to test

### Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Breaking existing workflow | Phased migration, backwards compatibility |
| Feature divergence | Clear versioning, changelog |
| Community maintenance | Clear contribution guidelines |
| Theme size (20MB) | Optimize or make theme optional |

### Open Questions

1. Should `SessionManager` be part of addon or game-specific?
2. Include test configuration system (`DebugConfigReader`)?
3. Keep semantic logging integration or make optional?
4. License choice (MIT recommended for Godot addons)?

## Acceptance Criteria

- [ ] Core debug framework extracted as standalone addon
- [ ] Addon can be installed in fresh Godot project
- [ ] GameTwo works with debug system as addon (no regression)
- [ ] Production builds exclude addon completely
- [ ] Documentation for addon usage and extension
- [ ] Example project demonstrating addon usage
- [ ] GitHub repository ready for open source release

## Related

- `project/debug/` - Current debug system location
- `project/addons/advanced_logger/` - Reference addon implementation
- `project/addons/debug_startup/` - Debug coordinator addon
