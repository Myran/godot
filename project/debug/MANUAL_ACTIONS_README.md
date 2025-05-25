# Manual Debug Actions System

The Manual Debug Actions system provides a flexible way to add custom debug functionality to the game without modifying core debug files. This system works alongside the existing DebugAction system for automated tests.

## Overview

Manual Debug Actions are simple, immediate actions that can be triggered from the debug menu. Unlike DebugActions (which are designed for automated testing), Manual Debug Actions are for quick developer tools, cheats, and game state modifications.

## Creating Manual Debug Actions

### Method 1: Using Callables (Recommended for simple actions)

```gdscript
# In any script, preferably during initialization
func _ready():
    if DebugManager.manual_actions:
        # With a group (creates submenu)
        DebugManager.manual_actions.register_callable(
            "Action Name",           # Display name
            func(): print("Hello"), # The action to execute
            "Category",             # Menu category
            "Group",                # Submenu group
            "Description",          # Tooltip description
            false                   # Requires confirmation?
        )
        
        # Without a group (appears directly under category)
        DebugManager.manual_actions.register_callable(
            "Quick Action",
            func(): print("Quick!"),
            "Category",             # Menu category
            "",                     # Empty string = no group
            "A quick action"
        )
```

### Method 2: Creating ManualDebugAction Resources

1. Create a `.tres` file in `res://debug/actions/manual/`
2. Set the resource type to `ManualDebugAction`
3. Configure the properties in the inspector

Example resource file:
```
[gd_resource type="Resource" script_class="ManualDebugAction" load_steps=2 format=3]

[ext_resource type="Script" path="res://debug/manual_debug_action.gd" id="1"]

[resource]
script = ExtResource("1")
action_name = "My Custom Action"
button_name = "my_custom_action"
category = "Custom"
group = "Tools"
description = "Does something useful"
requires_confirmation = false
```

### Method 3: Extending ManualDebugAction

For complex actions, create a custom class:

```gdscript
class_name MyCustomAction
extends ManualDebugAction

func _init() -> void:
    action_name = "My Complex Action"
    category = "Advanced"
    group = "Tools"
    description = "Performs complex operations"
    action_callable = _execute_complex_action

func _execute_complex_action() -> void:
    # Your complex logic here
    Log.info("Executing complex action...")
```

## Usage in Debug Menu

Manual actions appear alongside regular debug actions in the debug menu:
- They are organized by category and group
- A separator line distinguishes them from automated tests
- They execute immediately when clicked
- They can optionally require confirmation

## Examples

### Game Cheats (with groups)
```gdscript
registry.register_callable(
    "Max Health",
    func(): player.health = player.max_health,
    "Cheats", "Player"
)

registry.register_callable(
    "Add 1000 Gold",
    func(): player.gold += 1000,
    "Cheats", "Currency"
)
```

### Quick Actions (no groups)
```gdscript
registry.register_callable(
    "Toggle God Mode",
    func(): player.invincible = not player.invincible,
    "Quick Actions", ""  # No group - appears directly under category
)

registry.register_callable(
    "Reload Scene",
    func(): get_tree().reload_current_scene(),
    "Quick Actions", ""
)
```

### Mixed Organization
```gdscript
# Some database actions grouped, others not
registry.register_callable(
    "Clear All Caches",
    func(): data_source.clear_all_caches(),
    "Database", "Cache"  # In Cache group
)

registry.register_callable(
    "Print DB Stats",
    func(): data_source.print_statistics(),
    "Database", ""  # No group - appears directly
)
```

### Dynamic Actions
```gdscript
# Add ungrouped action for quick access
registry.register_callable(
    "Skip to Boss",
    func(): load_level("boss_fight"),
    current_level.category, ""  # Ungrouped for easy access
)
```

## Best Practices

1. **Organization**: Use consistent categories and groups
2. **Naming**: Use clear, descriptive action names
3. **Confirmation**: Use `requires_confirmation` for destructive actions
4. **Logging**: Always log the action execution for debugging
5. **Error Handling**: Check for null references and handle errors gracefully

## Integration with Legacy System

The system maintains backward compatibility with the old debug button system. Old button names are automatically converted to manual actions during initialization.

## Adding Actions at Runtime

You can add actions dynamically during gameplay:

```gdscript
# Add a context-specific debug action
if current_level == "boss_fight":
    DebugManager.manual_actions.register_callable(
        "Skip Boss Fight",
        func(): complete_boss_fight(),
        "Level", "Boss"
    )
```

## Limitations

- Manual actions don't return success/failure status (they just execute)
- They can't be used in automated test suites
- They don't support async operations directly (use DebugAction for that)

## Migration from Old System

To migrate from the old `debug_button_pressed` system:

1. Identify the action in the match statement
2. Create a manual action using `register_callable`
3. Remove the case from the match statement
4. The action will now appear in the organized debug menu

Old:
```gdscript
match button_name:
    "spawn_enemy":
        spawn_test_enemy()
```

New:
```gdscript
manual_actions.register_callable(
    "Spawn Enemy",
    spawn_test_enemy,
    "Gameplay", "Enemies"
)
```
