# Debug System Documentation

## Overview

The GameTwo debug system has been refactored to follow SOLID principles, making it more maintainable, extensible, and easier to use. This document explains how to use the new system and how to create custom debug actions.

## Architecture

The debug system consists of several components:

1. **DebugManager** - Global event bus for debug-related events
2. **DebugActionRegistry** - Discovers and manages DebugAction resources
3. **DebugMenuController** - Manages the UI for the debug menu
4. **DebugAction** - Base class for individual debug actions

## Usage

### Accessing the Debug Menu

There are several ways to open the debug menu:

1. Press the Escape key
2. Call `DebugManager.action(DebugManager.DebugEventType.EVENT_OPEN_DEBUG_MENU)`
3. Connect to the DebugManager's debug_event signal

### Creating Custom Debug Actions

To create a custom debug action:

1. Create a new script that extends DebugAction:

```gdscript
# my_custom_action.gd
@tool
class_name MyCustomAction
extends DebugAction

func _init():
    action_name = "My Custom Action"
    category = "My Category"
    group = "My Group"
    description = "Description of what this action does."

func execute(target_node: Node = null) -> Array:
    # Your debug action code here
    _update_status(target_node, "Running my custom action...")
    
    # Perform your action
    var result = perform_some_operation()
    
    # Return success or failure
    if result:
        return _success({"data": result})
    else:
        return _failure("Operation failed", {"details": "Error details"})
```

2. Create a resource file for your action:

- In the Godot editor, right-click in the FileSystem panel
- Select "New Resource..."
- Choose your action script class (e.g., MyCustomAction)
- Save it in the `res://debug/actions/` directory (in a subdirectory matching your category)

### Running Debug Actions

1. Open the debug menu
2. Navigate to your category and group
3. Select your action to run it
4. You can also run all actions in a group or category using the "Run All" button

## Components Reference

### DebugManager

The DebugManager is an autoload that serves as an event bus for the debug system. It emits and handles debug events.

```gdscript
# To emit a debug event:
DebugManager.action(DebugManager.DebugEventType.EVENT_OPEN_DEBUG_MENU)

# To listen for debug events:
DebugManager.debug_event.connect(_on_debug_event)

func _on_debug_event(event_type, args: Array = []):
    # Handle the event
    pass
```

### DebugAction

Base class for all debug actions. It provides a standard interface for executing debug actions and helper methods.

```gdscript
# Key methods:
func execute(target_node: Node = null) -> Array:
    # Override this method in your custom action
    pass

func _update_status(target_node: Node, text: String, is_error: bool = false):
    # Updates the status display in the debug menu

func _success(payload: Variant = null) -> Array:
    # Helper to return a success result

func _failure(error_message: String, details: Dictionary = {}) -> Array:
    # Helper to return a failure result
```

## Backward Compatibility

The old debug system is still accessible through the `debug` singleton, which now forwards calls to the new system. This ensures that existing code continues to work while new code can use the improved API.

## Best Practices

1. **Organize by Category and Group**: Keep related actions together
2. **Meaningful Names**: Use clear, descriptive names for your actions
3. **Status Updates**: Use `_update_status()` to keep the user informed
4. **Clean Up**: If your action creates resources or connections, clean them up properly
5. **Logging**: Use the Log system to record important information

## Scene Structure Requirements

The debug menu system requires a specific scene structure to function correctly:

1. **Required UI Elements**:
   - `DebugRichTextLabel`: A RichTextLabel for displaying status and results
   - `DebugItemList`: An ItemList node for category/group/action navigation
   - `RunAllButton`: A Button for running all tests in a category or group
   - `Panel`: A Panel that responds to input for tap-to-close functionality

2. **Unique Names**:
   - All these nodes must be uniquely named with the **%** prefix in the scene tree
   - For example: `%DebugRichTextLabel` instead of just `DebugRichTextLabel`

3. **Script Attachment**:
   - The `DebugMenuController.gd` script should be attached to a node that has access to all these UI elements
   - Typically this should be the root node or a parent of all the UI elements

## Directory Structure

The debug action system expects a specific directory structure:

```
/project
  /debug
    /actions           # Root directory for all debug actions
      /core            # Category directory
        log_system_info_action.gd
        log_system_info.tres
      /rtdb            # Another category directory
        rtdb_set_simple_value_action.gd
        rtdb_set_simple_value.tres
      debug_action.gd  # Base resource class
    debug_action_registry.gd
    debug_menu_controller.gd
    ...
```

Make sure these directories exist and are properly structured.

## Troubleshooting

### Common Issues

1. **"DebugActionRegistry not found" error**:
   - This is the most common error and happens when the DebugRegistry autoload cannot be properly initialized
   - Causes include missing directory structure, incorrect registry script, or autoload registration issues
   - Solution: Add defensive programming to check for the registry before attempting to use it
   - Make sure the `/debug/actions/` directory and subdirectories exist
   - Check that a valid DebugAction resource is present in the directory structure

2. **No actions available in the debug menu**:
   - Check if the `/debug/actions/` directory exists
   - Verify there are `.tres` resources in the actions directory
   - Look for errors in the console related to file scanning
   - Ensure the DebugRegistry autoload is properly registered
   - Run with the `--verbose` flag to see detailed autoload initialization

3. **Missing UI elements errors**:
   - Verify the UI nodes exist in scene_debug.tscn
   - Check that they have unique names with % prefix
   - Ensure DebugMenuController is attached to the correct node
   - Examine the scene tree structure to ensure paths are correct

4. **Logger errors**:
   - Make sure all Log calls use the ALogger format
   - Check if required tags like ["debug", "system"] are being used
   - Ensure Log is properly registered as an autoload

5. **Actions not executing**:
   - Test with a simple action like LogSystemInfoAction
   - Verify the execute() function is properly implemented
   - Check for errors in the console during execution
   - Make sure signals and callbacks are properly connected

### Defensive Programming Best Practices

When working with the debug system, always use these defensive programming practices:

1. **Check for autoload availability**:
   ```gdscript
   if not Engine.has_singleton("DebugRegistry"):
       Log.error("DebugRegistry not available", {}, ["debug", "system", "error"])
       return
   ```

2. **Safe singleton access**:
   ```gdscript
   # Instead of direct access
   # var categories = DebugRegistry.get_categories()
   
   # Use this pattern
   if Engine.has_singleton("DebugRegistry"):
       var registry = Engine.get_singleton("DebugRegistry")
       var categories = registry.get_categories()
   ```

3. **Informative error messages**:
   - Always update the UI with clear error messages when a component isn't available
   - Include the specific component that failed in the message
   - Consider adding a "Check" button to help users diagnose issues

4. **Ensure directory structure**:
   - The registry now automatically creates the actions directory if it doesn't exist
   - However, it's good practice to verify subdirectories as well
   - When creating custom actions, ensure you place them in the correct category directory

### Running Validation

Use the validation script to check your setup:

```gdscript
# From the Godot console or a script
var validator = load("res://debug/validation_script.gd").new()
validator._run_validation()
```

This will check for:
- Required files and directories
- Proper class interfaces
- Autoload registration
- Component interface structure

## Current Implementation Status

The debug system has been successfully refactored and is working in its basic form. Here's the current status:

### Implemented Components:
- ✅ **DebugAction** base class for modular debug actions
- ✅ **DebugActionRegistry** autoload for discovering and managing actions
- ✅ **DebugManager** event bus for system-wide events
- ✅ **DebugMenuController** UI controller for the debug menu
- ✅ **Compatibility Layer** in debug.gd for backward compatibility

### Existing Debug Actions:
- ✅ **LogSystemInfoAction** for displaying system information
- ✅ **test_action.tres** for validation purposes
- ✅ **SimpleTestAction** for a reliable test action that always succeeds

### Recent Improvements:
- ✅ **Defensive Programming** added throughout the system to prevent crashes
- ✅ **Auto-creation of directories** if they don't exist
- ✅ **Improved error messages** for better diagnostics
- ✅ **Better singleton handling** using Engine.has_singleton() consistently

### Outstanding Items:
- 🔄 Additional debug actions needed for common operations
- 🔄 Comprehensive testing to ensure all interactions work correctly
- 🔄 Type safety warnings to address

## Development Guide - Next Steps

### Creating New Debug Actions
We need to create more debug actions to rebuild all the functionality from the old system. Here's how to do it:

1. Identify a debug operation from the original system
2. Create a new script extending DebugAction in the appropriate category subfolder
3. Create a .tres resource file using that script
4. Test the action in the debug menu

### Example Action Implementation

```gdscript
@tool
class_name YourNewAction
extends DebugAction

func _init():
    action_name = "Descriptive Action Name"
    category = "Your Category"  # e.g., "System", "RTDB", "Auth"
    group = "Your Group"  # e.g., "Diagnostics", "Basic", "Advanced"
    description = "What this action does in detail."

func execute(target_node: Node = null) -> Array:
    _update_status(target_node, "Starting operation...")
    
    # Your implementation here
    var result = "Operation completed"
    
    _update_status(target_node, "Operation complete!")
    return _success({"result": result})
    # Or for errors: return _failure("Error message", {"details": error_details})
```

### Important File Locations

All debug actions should be placed in category-specific directories:
```
/debug/actions/
  /core/          # System and core actions
  /rtdb/          # Realtime database actions
  /auth/          # Authentication actions
  /config/        # Configuration actions
  ... etc ...
```

## Examples

See the existing debug actions in `res://debug/actions/` for examples of how to implement custom actions.

### Example Scene Structure

```
Root (Control) - Attach DebugMenuController here
 |
 ├── %Panel (Panel) - For background and tap-to-close
 |    |
 |    ├── %DebugRichTextLabel (RichTextLabel) - For status display
 |    |
 |    └── %DebugItemList (ItemList) - For navigation
 |
 └── %RunAllButton (Button) - For batch execution
```

### Validation

Run the validation script from the Godot editor or from code to verify your changes:

```gdscript
var validator = load("res://debug/validation_script.gd").new()
validator._run_validation()
```
