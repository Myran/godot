# Advanced Logger

A comprehensive logging system for Godot 4.x with tag filtering, configurable formatting, and editor integration.

## Features

- **Log Levels**: DEBUG, INFO, WARNING, ERROR, CRITICAL
- **Tag Filtering**: Filter logs by tags (e.g., "network", "database")
- **Editor Integration**: Configure logging options from the editor
- **Multiple Tag Setups**: Save and load different tag configurations
- **Formatting Options**: Customize timestamp, colors, source info
- **Tag Scanning**: Automatically find tags used in your project

## Directory Structure

```
advanced_logger/
├── core/          (core logging functionality)
│   ├── ilogger.gd        (logging interface)
│   ├── logger.gd         (main logger implementation)
│   ├── logger_colors.gd  (color definitions)
│   └── log_formatter.gd  (formatting utilities)
├── ui/            (UI components)
│   ├── drag_drop_helper.gd     (drag/drop utilities)
│   ├── setup_list_controller.gd (tag setup UI)
│   └── tag_list_controller.gd  (tag list UI)
├── utils/         (shared utilities)
│   ├── config_manager.gd      (config handling)
│   ├── tag_manager.gd         (tag operations)
│   ├── tag_scanner.gd         (project scanning)
│   └── tag_setup_manager.gd   (setup management)
└── tests/         (testing files)
```

## Usage

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

### Using the Editor Integration

1. Open the Advanced Logger panel in the editor (usually in the right dock)
2. Configure log levels, formatting options
3. Manage tags with drag-and-drop interface
4. Save and load tag setups for different scenarios

### Custom Tags

You can use any string as a tag, or use the built-in constants:

```gdscript
# Using built-in tag constants
Log.info("Database connected", {}, [Log.TAG_DB])

# Using custom tags
Log.info("Player movement", {}, ["movement", "player"])
```

## After Refactoring

If you encounter any issues with the Logger autoload after refactoring, you can:

1. Run the autoload helper script once to update project settings
2. Ensure all imports are using the new directory structure
3. Restart the Godot editor

## Development

To contribute or extend the Advanced Logger:

1. Review the code structure to understand the architecture
2. Use the ILogger interface for creating alternative implementations
3. Add tests for new functionality in the tests/ directory
4. Follow the existing patterns for consistency
