# Advanced Logger for Godot

## Overview

Advanced Logger is a robust logging system for Godot 4 that provides rich, colored output, circular buffering, retroactive log replay, tag filtering, and editor integration. It's designed to help developers track, diagnose, and debug their applications with minimal overhead.

## Key Features

- **Multiple Log Levels**: DEBUG, INFO, WARNING, ERROR, CRITICAL
- **Rich Formatted Output**: Colorized text with structured data presentation
- **Circular Buffer**: Maintain a configurable history of recent log entries
- **Retroactive Log Replay**: When errors occur, display recent logs for context
- **Tag Filtering**: Filter logs by custom tags for focused debugging
- **Testing Mode**: Simplified output format for automated testing
- **Editor Integration**: Dock panel for real-time configuration
- **Source Info**: Automatic inclusion of file, line, and function info

## Installation

1. Copy the `advanced_logger` directory to your project's `addons` folder
2. Enable the plugin in Godot's Project Settings → Plugins

## Basic Usage

The logger is automatically registered as the global singleton `Log` when the plugin is active.

```gdscript
# Basic logging at different levels
Log.debug("Detailed debug information")
Log.info("General information")
Log.warning("Warning message")
Log.error("Error occurred", {"error_code": 404})
Log.critical("Critical failure", {"error_code": 500, "details": "Server unavailable"})
```

## Log Levels

The logger supports five severity levels:

| Level | Description | Use Case |
|-------|-------------|----------|
| DEBUG | Detailed debug information | Development-time debugging |
| INFO | General information | Regular operational reporting |
| WARNING | Warning messages | Potential issues that don't interrupt operation |
| ERROR | Error conditions | Failures that affect operation but don't crash |
| CRITICAL | Critical failures | Severe errors that may lead to crashes |

You can set the minimum level to display:

```gdscript
# Only show logs of WARNING level and above
Log.set_level(Log.LogLevel.WARNING)
```

## Context Data

Pass additional structured data with your logs:

```gdscript
Log.info("Player joined", {
    "player_id": 12345,
    "username": "PlayerOne",
    "position": Vector2(100, 200)
})
```

## Tagging System

Tags allow you to categorize and filter logs:

```gdscript
# Add tags
Log.add_tag("player")
Log.add_tag("physics")

# Log with tags
Log.info("Player movement", {"speed": 10.5}, ["player", "physics"])

# Remove a tag
Log.remove_tag("physics")

# Clear all tags
Log.clear_tags()
```

When tags are active, only logs with matching tags will be displayed.

## Retroactive Log Replay

When an error or critical log is recorded, the logger automatically displays recent log entries that led up to the error, providing valuable context:

```gdscript
Log.debug("Processing player input")
Log.info("Calculating physics")
Log.debug("Applying movement")
# This will trigger retroactive display of the above logs
Log.error("Movement calculation failed", {"reason": "Invalid velocity"})
```

## Editor Configuration

The logger provides a dock panel in the editor for real-time configuration:

- Change log level
- Adjust buffer size
- Set retroactive window duration
- Manage tags
- Run self-tests

## Advanced Usage

### Enable/Disable Logging

```gdscript
# Disable all logging
Log.disable()

# Re-enable logging
Log.enable()
```

### Testing Mode

For automated tests or environments where rich formatting isn't supported:

```gdscript
# Enable testing mode for simplified output
Log.enable_testing_mode()

# Disable testing mode to return to rich output
Log.disable_testing_mode()
```

### Configuration Options

```gdscript
# Set buffer size (number of log entries to retain)
Log.set_buffer_size(2000)  # Min: 50, Max: 10000

# Set retroactive window (how far back in time to show logs on error)
Log.set_retroactive_window(600)  # In seconds, Min: 10, Max: 3600
```

## Implementation Details

### Log Entry Structure

Each log entry contains:
- Timestamp
- Log level
- Message
- Context data (optional)
- Tags (optional)
- Source information (file, line, function)

### Circular Buffer

The logger maintains a circular buffer of recent log entries, regardless of their level or tags. This allows the retroactive replay feature to show logs that weren't displayed at the time they were generated.

### Source Tracking

The logger automatically captures source information (file, line, function) for each log entry, allowing you to quickly locate the source of logs.

## Examples

### Complete Example

```gdscript
extends Node

func _ready():
    # Configure logger
    Log.set_level(Log.LogLevel.DEBUG)
    Log.set_buffer_size(500)
    Log.add_tag("startup")
    
    # Regular logging
    Log.debug("Game initializing", {}, ["startup"])
    
    # Logging with context
    var player_data = {
        "id": generate_player_id(),
        "position": Vector2(100, 100),
        "inventory": ["sword", "shield", "potion"]
    }
    Log.info("Player spawned", player_data, ["startup", "player"])
    
    # Warning with context
    Log.warning("Low memory available", {"available_mb": 128})
    
    # Error that will trigger retroactive display
    Log.error("Failed to load resource", {
        "path": "res://assets/textures/missing.png",
        "error": "File not found"
    })
    
    # Critical error
    Log.critical("Game initialization failed", {
        "reason": "Required system unavailable",
        "component": "AudioServer"
    })
    
    # Clean up
    Log.remove_tag("startup")

func generate_player_id() -> int:
    return randi() % 10000
```

### Common Patterns

#### System Initialization

```gdscript
Log.info("System initializing", {"version": "1.2.3"})
Log.debug("Loading configuration", {"path": "user://config.cfg"})

# Later
Log.info("System initialized successfully", {"startup_time_ms": 235})
```

#### Function Entry/Exit Tracing

```gdscript
func process_data(data):
    Log.debug("Entering process_data", {"data_size": data.size()})
    
    # Processing logic
    
    Log.debug("Exiting process_data", {"result_size": result.size()})
    return result
```

#### Error Handling

```gdscript
func load_file(path):
    Log.debug("Loading file", {"path": path})
    
    var file = File.new()
    var error = file.open(path, File.READ)
    
    if error != OK:
        Log.error("Failed to open file", {
            "path": path,
            "error_code": error
        })
        return null
    
    var content = file.get_as_text()
    file.close()
    
    Log.debug("File loaded successfully", {"size_bytes": content.length()})
    return content
```

## For AI/LLM Integration

When integrating with AI systems or LLMs, consider the following:

1. **Log Verbosity Control**: In AI-intensive sections, you may want to temporarily increase or decrease log verbosity.

```gdscript
# Store original level
var original_level = Log.get_current_level()

# Set to more verbose for AI processing
Log.set_level(Log.LogLevel.DEBUG)

# Perform AI operations with detailed logging
ai_system.process_input(data)

# Restore original level
Log.set_level(original_level)
```

2. **Structured Data for Analysis**: When logging data that might be analyzed by AI, use consistent structured formats:

```gdscript
# Good for AI analysis
Log.info("AI decision made", {
    "decision": "path_north",
    "confidence": 0.87,
    "alternatives": ["path_south", "path_east"],
    "factors": {
        "enemy_presence": 0.2,
        "resource_availability": 0.8,
        "terrain_difficulty": 0.3
    }
})
```

3. **Tag-based Filtering for AI Subsystems**: Use consistent tags for different AI subsystems:

```gdscript
# Add tags for different AI subsystems
Log.add_tag("ai_pathfinding")
Log.add_tag("ai_combat")
Log.add_tag("ai_dialogue")

# Later, to focus on just dialogue logs
Log.clear_tags()
Log.add_tag("ai_dialogue")
```

4. **Retroactive Analysis**: Use the retroactive feature to analyze decision chains:

```gdscript
# This sequence will be available in retroactive replay
Log.debug("AI perception update", {"entities_visible": 5})
Log.debug("AI evaluating options", {"options_count": 3})
Log.debug("AI selecting target", {"target_id": "enemy_2"})

# Trigger retroactive display for analysis
Log.error("AI combat decision unexpected", {
    "decision": "retreat",
    "expected": "attack"
})
```

## Technical Limitations

- Rich formatting is only visible in environments that support it (like the Godot console)
- The maximum buffer size is 10,000 entries
- The maximum retroactive window is 1 hour (3600 seconds)

## Troubleshooting

### Common Issues

**No logs appearing:**
- Check if logger is enabled with `Log.enable()`
- Verify current log level is not higher than your logs
- Ensure no tags are active if your logs don't use tags

**Missing context in retroactive display:**
- Increase retroactive window with `Log.set_retroactive_window(seconds)`
- Increase buffer size with `Log.set_buffer_size(count)`

**Performance concerns:**
- Reduce buffer size for memory-constrained environments
- Use higher log level in production (WARNING or above)

## API Reference

### Core Methods

| Method | Parameters | Description |
|--------|------------|-------------|
| `debug` | message: String, context: Dictionary = {}, tags: Array[String] = [] | Log debug message |
| `info` | message: String, context: Dictionary = {}, tags: Array[String] = [] | Log info message |
| `warning` | message: String, context: Dictionary = {}, tags: Array[String] = [] | Log warning message |
| `error` | message: String, context: Dictionary = {}, tags: Array[String] = [] | Log error message and trigger retroactive display |
| `critical` | message: String, context: Dictionary = {}, tags: Array[String] = [] | Log critical message and trigger retroactive display |

### Configuration Methods

| Method | Parameters | Description |
|--------|------------|-------------|
| `set_level` | level: LogLevel | Set minimum log level to display |
| `set_buffer_size` | size: int | Set circular buffer size |
| `set_retroactive_window` | seconds: int | Set retroactive replay time window |
| `add_tag` | tag: String | Add a tag filter |
| `remove_tag` | tag: String | Remove a tag filter |
| `clear_tags` | | Remove all tag filters |
| `enable` | | Enable logging |
| `disable` | | Disable logging |
| `enable_testing_mode` | | Enable simplified output format |
| `disable_testing_mode` | | Disable simplified output format |

## Extending the Logger

The logger can be extended with custom functionality by inheriting from the `Logger` class:

```gdscript
extends Logger
class_name CustomLogger

# Add custom log methods
func network(message: String, context: Dictionary = {}, tags: Array[String] = []):
    var network_context = context.duplicate()
    network_context["client_id"] = multiplayer.get_unique_id()
    _log(LogLevel.INFO, "NETWORK: " + message, network_context, tags)
```

---

This documentation is designed to help both humans and AI systems understand and effectively use the Advanced Logger system. For further assistance, consult the source code or run the self-tests from the Logger dock panel.
