# Advanced Logger System Documentation

## System Architecture

The Advanced Logger system consists of several interconnected components that work together to provide flexible, tag-based logging:

1. **Logger Class** (`logger.gd`): Core singleton autoloaded as "Log" that provides methods for logging at different levels
2. **LoggerSettings** (`logger_settings.gd`): Handles configuration management and validation
3. **LoggerColors** (`logger_colors.gd`): Centralized color definitions using the Gruvbox Material palette
4. **LoggerDock** (`logger_dock.gd`): Editor UI for configuring logger settings and managing tags
5. **TagScanner** (`tag_scanner.gd`): Utility for scanning project files to discover tag usage
6. **Plugin** (`plugin.gd`): Handles plugin initialization and project settings registration

The system uses a config file (`settings.cfg`) to store persistent settings across editor sessions.

## Tag System Architecture

Tags in the Advanced Logger serve as metadata for log messages, enabling powerful filtering capabilities:

- **Logger Constants**: Core tags are defined as constants in `logger.gd` (e.g., `TAG_CACHE`, `TAG_DATABASE`)
- **Tag Categories**:
  - **Available Tags**: All discovered tags from code scanning or manual addition
  - **Active Tags**: When non-empty, only logs with these tags are shown
  - **Ignored Tags**: Logs with these tags are always hidden

### Log Method Signature

```gdscript
# Example of a typical log method
func info(message: String, context: Dictionary = {}, tags: Array[String] = []) -> void:
	if message.is_empty():
		push_warning("Empty log message provided")
		return
	_log(LogLevel.INFO, message, context, tags)
```

## Using the Logger

### Basic Usage

```gdscript
# Simple log with no tags
Log.info("Player connected")

# Log with context data
Log.warning("Failed to save game", {"attempt": 3, "error": "Disk full"})

# Log with tags for filtering
Log.error("Connection failed", {}, [Log.TAG_NETWORK])

# Log with context and tags
Log.debug("Cache hit ratio", {"hits": 45, "misses": 12}, [Log.TAG_CACHE, Log.TAG_PERFORMANCE])
```

### Log Levels

The system supports five standard log levels:
- `DEBUG`: Detailed information for debugging purposes
- `INFO`: General information about system operation
- `WARNING`: Potential issues that don't prevent normal operation
- `ERROR`: Problems that may impact functionality
- `CRITICAL`: Severe issues requiring immediate attention

## Tag Scanning Process

The tag scanning system has been enhanced to use two complementary approaches:

1. **Direct Extraction**: Pulls all `TAG_*` constants directly from `logger.gd`
2. **Code Scanning**: Searches through project files for:
   - Direct string tags in arrays: `Log.info("Message", {}, ["tag1", "tag2"])`
   - Constant references: `Log.debug("Message", {}, [Log.TAG_CACHE])`

This dual approach ensures complete tag discovery regardless of how tags are used in the codebase.

```gdscript
# The scanner first extracts constants from Logger class
var logger_tags = extract_tag_constants_from_logger()

# Then scans files for tag usage
scan_directory("res://", found_tags, exclude_dirs)
```

## Tag Filtering Rules

The system uses these rules to determine if a log should be displayed:

1. If any tag in a log message is in the ignored tags list, the message is hidden
2. If the active tags list is empty, all non-ignored messages are shown
3. If there are active tags but the message has no tags, it's hidden
4. If any tag in the message matches an active tag, the message is shown

## Advanced Logger Tag Handling Improvements

This section documents the recent improvements made to the tag handling system.

### Overview

The Advanced Logger's tag handling system has been enhanced to:
1. Filter out test-specific tags during normal development
2. Dynamically resize tag lists based on content
3. Detect and include tags defined as constants in source files
4. Improve tag scanning performance and reliability

### Key Improvements

#### Tag Filtering

- **Test Tag Exclusion**: The tag scanner now excludes the `tests/` directory during normal operation to prevent test-specific tags from cluttering the UI
- **Constant Tag Detection**: Added scanning of `TAG_*` constants from source files (specifically `data_source.gd`) to ensure important tags are included even if not directly used in Log calls
- **Configurable Inclusion**: Added parameter to control whether test tags should be included or excluded

#### User Interface Improvements

- **Simplified Button Interface**:
  - The "Update Tags" button in the Available Tags section now uses project settings to determine tag inclusion
  - Removed the "Update All Tags" button for a cleaner interface
- **Project Settings Integration**:
  - Added a project setting "advanced_logger/include_test_tags" to control test tag inclusion
  - When set to true, the "Update Tags" button will include test tags (useful for testing/debugging)
  - When set to false (default), test tags are excluded for normal development
- **Dynamic Resizing**:
  - Tag lists now resize based on content to show more tags when available
  - Lists maintain a minimum size for easy drag and drop operations
  - List heights are proportional to the number of tags they contain

#### Code Organization

- **Improved Scanner**: Enhanced tag scanner with directory exclusion functionality
- **Better Tag Management**: More robust handling of tag categories (available, active, ignored)
- **Consistent Sorting**: Tags are now sorted alphabetically for easier finding

### Validation and Testing

Added comprehensive test suite to verify tag handling functionality:

1. **validate_tag_scanning.gd**: Validates that tag scanning finds all appropriate tags
2. **validate_tag_filtering.gd**: Verifies that test tags are correctly filtered out during normal operation
3. **validate_tag_resizing.gd**: Tests the dynamic resizing of tag lists
4. **validate_tag_rescan.gd**: Ensures that tag rescanning works correctly with different parameters

All tests can be run using the justfile commands:
- `just test-tag-scanning`
- `just test-tag-filtering`
- `just test-tag-resizing`
- `just test-tag-rescan`
- `just test-standalone` (runs all tests)

### Usage Notes

- **For Normal Development**: The "Update Tags" button scans for tags while excluding test-specific tags
- **For Testing/Validation**: Set the project setting "advanced_logger/include_test_tags" to true before scanning
- **Configuration via Project Settings**:
  - Go to Project → Project Settings → Advanced Logger
  - Toggle "include_test_tags" setting to control test tag visibility
- **Manual Tag Management**: You can still manually drag tags between the Available, Active, and Ignored lists

### Next Steps

Potential future improvements to consider:
- Add ability to define additional directories to exclude
- Implement tag categories or grouping
- Add tag search functionality for large projects
- Create a tag documentation system

## Best Practices

1. **Use Constants for Common Tags**: Always use the predefined `Log.TAG_*` constants for consistency
2. **Create Tag Constants for New Categories**: When adding new tag categories, add them as constants to the Logger class
3. **Meaningful Tag Names**: Use descriptive tag names that represent functional areas or subsystems
4. **Tag Granularity**: Balance between too many tags (overwhelming) and too few (ineffective filtering)
5. **Contextual Data**: Use the context parameter for variable data rather than concatenating into messages
6. **Multiple Tags**: Apply multiple tags when a log applies to several categories
7. **Log Levels**: Use the appropriate log level based on severity, not visibility preference

## UI Workflow

1. **Initial Setup**: After installation, run "Update Tags" to scan your project
2. **Filtering**: Drag tags to "Active Tags" to show only those tags (or leave empty to see all)
3. **Excluding**: Drag tags to "Ignored Tags" to hide all logs with those tags
4. **Management**: Double-click on tags to move them between categories
5. **Rescanning**: After adding new tags to your code, click "Update Tags" to refresh

## Internal Data Flow

1. Logger receives a log request with message, context, and tags
2. It checks the log level against the current threshold
3. It validates the tags and checks if they pass filtering rules
4. If the log should be shown, it formats the message with timestamps, colors, and tags
5. The formatted log is output using `print_rich()` for editor console display

## Tag Format and Validation

Tags must follow these rules:
- Cannot be empty
- Must contain only alphanumeric characters, underscores, or hyphens
- Must be valid according to `LoggerSettings._is_valid_tag()`

Example of valid tags:
- `database`
- `http_client`
- `user-auth`
- `gameplay_level_1`
