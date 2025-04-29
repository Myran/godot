# JSON Path Navigator Utilities

This module provides utilities for safely navigating and extracting data from nested JSON structures with proper type handling and error reporting.

## Classes

### JSONPathNavigator

A utility class for safely navigating nested JSON structures. It provides consistent error handling and type safety.

#### Key Methods

- `navigate(json_data, path, default_value = null)`: Navigate a JSON structure using a path array
- `get_value(json_data, path, default_value = null)`: Get a value by navigating a path
- `path_exists(json_data, path)`: Check if a path exists in the JSON structure
- Type-specific getters:
  - `get_dictionary(json_data, path, default_dict = {})`
  - `get_array(json_data, path, default_array = [])`
  - `get_string(json_data, path, default_str = "")`
  - `get_int(json_data, path, default_int = 0)`
  - `get_float(json_data, path, default_float = 0.0)`
  - `get_bool(json_data, path, default_bool = false)`

### NavigationResult

A class to encapsulate the result of a JSON structure navigation. Provides type-safe access to the navigation result.

#### Properties

- `found`: Whether the navigation was successful
- `value`: The value found at the path
- `path`: The path that was navigated
- `error_message`: Error message if navigation failed
- `context`: Additional context information for debugging
- `result_type`: The type of result (NOT_FOUND, DICTIONARY, ARRAY, VALUE)

#### Methods

- Type checks:
  - `is_dictionary()`: Check if the result is a dictionary
  - `is_array()`: Check if the result is an array
  - `is_value()`: Check if the result is a value (not a dictionary or array)
- Type-safe getters:
  - `as_dictionary(default_dict = {})`: Get the result as a dictionary
  - `as_array(default_array = [])`: Get the result as an array
  - `as_string(default_str = "")`: Get the result as a string
  - `as_int(default_int = 0)`: Get the result as an integer
  - `as_float(default_float = 0.0)`: Get the result as a float
  - `as_bool(default_bool = false)`: Get the result as a boolean
- `to_string()`: Get a human-readable representation of the result

## Usage Examples

### Basic Navigation

```gdscript
# Navigate to a simple path
var result = JSONPathNavigator.navigate(data, ["settings", "graphics", "resolution"])
if result.found:
    print("Resolution: ", result.value)
else:
    print("Error: ", result.error_message)
```

### Type-Specific Getters

```gdscript
# Get values with specific types and defaults
var level = JSONPathNavigator.get_int(data, ["players", 0, "stats", "level"], 1)
var name = JSONPathNavigator.get_string(data, ["players", 0, "name"], "Unknown")
var skills = JSONPathNavigator.get_array(data, ["players", 0, "stats", "skills"], [])
```

### Array Navigation

```gdscript
# Navigate through arrays
var player_count = JSONPathNavigator.get_array(data, ["players"]).size()
var first_player = JSONPathNavigator.get_dictionary(data, ["players", 0])
```

### Error Handling

```gdscript
# Handle missing paths gracefully
var result = JSONPathNavigator.navigate(data, ["players", 5, "name"])
if not result.found:
    print("Error: ", result.error_message)
    print("Context: ", result.context)  # Contains helpful debugging info
```

### Safe Type Conversion

```gdscript
# Handles type conversion automatically
var level_string = JSONPathNavigator.get_string(data, ["players", 0, "stats", "level"])
var level_int = JSONPathNavigator.get_int(data, ["players", 0, "stats", "level"])
```

## Integration with LocalJSONBackend

The `LocalJSONBackend.get_data()` method has been refactored to use the `JSONPathNavigator` for reliable path navigation, providing:

- Consistent error messages
- Proper type handling
- Better debuggability with context information
- Special case handling for the sheets data structure

## Testing

Use the `json_path_navigator_test.gd` script to validate the functionality of these utilities.
