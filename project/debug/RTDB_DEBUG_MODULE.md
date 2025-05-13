# Firebase RTDB Debug Module Documentation

## Overview

The Firebase RTDB Debug Module provides a comprehensive interface for testing and debugging Firebase Realtime Database functionality in the GameTwo project. This module features a dynamic menu system that automatically generates test categories and functions based on method naming conventions.

## Key Features

1. **Automated Signal Connections** - Connections to Firebase RTDB signals are managed automatically.
2. **Dynamic Menu Generation** - Test menus are created dynamically based on method naming conventions.
3. **Multiple Test Categories** - Support for different Firebase modules (RTDB, Auth, Config).
4. **Sequential Test Runner** - Ability to run all tests in a category sequentially.
5. **Strong Type Safety** - Comprehensive type hints throughout the codebase.

## Method Naming Conventions

To add a new test function, follow this naming pattern:

```
_test_[module]_[group_name]_[test_description]
```

For example:
- `_test_rtdb_basic_set_value` - RTDB module, "Basic" group, "Set Value" test
- `_test_auth_login_anonymous` - Auth module, "Login" group, "Anonymous" test
- `_test_config_fetch_settings` - Config module, "Fetch" group, "Settings" test

The dynamic menu system will automatically detect these methods and add them to the appropriate menus.

## Module Architecture

### Core Components

1. **Signal Connection System** - `_connect_rtdb_signals_dynamically()`
   - Automatically connects to all RTDB signals
   - Maps signals to handler methods by convention

2. **Dynamic Menu Creation** - `_build_dynamic_menu_from_prefix()`
   - Creates popup menus for test categories
   - Groups tests by the group name in their method name
   - Creates submenus for each group

3. **Request/Response Flow** - `_make_rtdb_request()`, `_handle_rtdb_response()`
   - Manages async Firebase requests using Signals
   - Tracks pending requests for completion

4. **Generic Test Runner** - `_run_all_tests_by_prefix()`
   - Runs all tests for a specific module
   - Provides test statistics

### Class Definitions

- **PendingRequestData** - Tracks request metadata for async operations
  - `operation`: String - The operation being performed
  - `path`: Array[String] - The database path
  - `completion_signal`: Signal - Signal emitted when request completes

## Usage Guide

### Adding New Test Methods

1. Create a new method following the naming convention:

```gdscript
async func _test_rtdb_new_group_test_name() -> Array:
    Log.debug("RTDB Test: Test Description", {}, ["test"])
    # Test implementation
    return await _make_rtdb_request("operation_name", ["path"], [args])
```

2. Ensure your method:
   - Is async
   - Returns an Array with two elements: [success(bool), result(Variant)]
   - Uses descriptive logging

3. The menu system will automatically detect your method and add it to the appropriate group.

### Extending to New Firebase Modules

To add support for a new Firebase module:

1. Add a new prefix constant:
```gdscript
const _NEW_MODULE_TEST_PREFIX: String = "_test_newmodule_"
```

2. Create UI elements in the scene:
```gdscript
@onready var new_module_tests_button: Button = %NewModuleTestsButton
```

3. Set up the test menu in `_setup_additional_test_menus()`:
```gdscript
if is_instance_valid(new_module_tests_button):
    # Create popup menu
    # Connect button
    # Build menu
```

4. Add module instance check in `_run_all_tests_by_prefix()`:
```gdscript
match module_name:
    "newmodule":
        module_instance = new_module_instance
```

5. Create placeholder test methods using the new prefix:
```gdscript
async func _test_newmodule_basic_test() -> Array:
    # Implementation
    return [true, {"result": "Success"}]
```

## Best Practices

1. **Consistent Naming** - Follow the naming convention strictly for automatic discovery
2. **Clear Grouping** - Use logical group names to organize tests
3. **Explicit Type Hints** - Always use explicit typing (Array[String], etc.)
4. **Node Validation** - Always check with `is_instance_valid()` before accessing nodes
5. **Proper Async Pattern** - Use Signals for async operations and await them properly

## Troubleshooting

- **Menu Items Not Appearing** - Check method naming pattern
- **Signal Handlers Not Called** - Verify signal naming in `rtdb_signals_to_connect`
- **UI Elements Missing** - Ensure scene has all required %NodeName references
- **Tests Failing** - Check request/response flow and async handling

## Example Workflow

```gdscript
# 1. Create a test method
async func _test_rtdb_example_new_test() -> Array:
    # Implementation
    return await _make_rtdb_request(...)

# 2. Run the test
# The test automatically appears in the "Example" group under RTDB Tests
```

The module will automatically:
1. Discover the method
2. Add it to the appropriate menu
3. Connect the menu item to the method
4. Handle async operations and results