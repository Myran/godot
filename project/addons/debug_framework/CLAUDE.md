# Debug Framework Addon

Reusable Godot 4.x addon providing debug menu and action system for game development.

## Architecture

```
debug_framework/
├── core/           # Core action system
│   ├── debug_action.gd         # Base class for all debug actions
│   ├── debug_action_registry.gd # Action registration and discovery
│   └── debug_action_result.gd   # Standardized result handling
├── output/         # Output formatting
│   ├── debug_output_service.gd  # Centralized output management
│   ├── debug_output_formatter.gd # Rich text formatting
│   └── format_utilities.gd      # Formatting helpers
├── ui/             # UI components
│   ├── debug_menu_controller.gd # Main menu logic
│   ├── popup_debug.gd           # Popup wrapper
│   └── menu_utilities.gd        # Menu helpers
├── scenes/         # Scene files
└── themes/         # UI theming
```

## Creating Debug Actions

```gdscript
class_name MyDebugAction
extends DebugAction

func _init() -> void:
    action_name = "my.custom.action"
    category = "Custom"
    group = "Testing"
    description = "Does something useful"

func execute() -> DebugActionResult:
    # Your action logic here
    return DebugActionResult.success("Action completed")
```

## Registering Actions

Actions are registered via `DebugRegistry` autoload:

```gdscript
func _ready() -> void:
    var action := MyDebugAction.new()
    DebugRegistry.register_action(action)
```

## Key Patterns

- **Strong typing required** - All variables and functions must be typed
- **DebugActionResult** - Always return result objects, never raw values
- **Signal-driven** - Use `status_updated` and `execution_completed` signals
- **Categorization** - Use `category.group.action` naming (e.g., `firebase.auth.sign_in`)

## Integration Points

- **DebugManager** (`res://autoloads/debug_manager.gd`) - Coordinates debug events
- **DebugStartupCoordinator** (`res://addons/debug_startup/`) - Handles test automation
- **Game-specific actions** remain in `project/debug/actions/` (not in addon)

## Enabling/Disabling

The addon only activates autoloads in debug builds (`OS.is_debug_build()`).
Disable via Project Settings > Plugins to completely remove from production.
