# Advanced Logger for Godot 4.x
A flexible, feature-rich logging system for Godot projects with colored output, circular buffer, and retroactive log replay capabilities.

## Features
- 5 log levels (DEBUG, INFO, WARNING, ERROR, CRITICAL)
- Colored output using Gruvbox color scheme
- Circular buffer for log history
- Tag-based filtering
- Structured context data support
- Source code location tracking
- Retroactive log replay on errors
- Thread-safe operations
- Type-safe implementation

## For Developers

### Basic Setup
```gdscript
extends Node

var logger: Logger

func _ready() -> void:
    # Basic initialization
    logger = Logger.new()
    
    # Or with custom configuration
    var config := LoggerConfig.new(
        1000,  # buffer size
        LogLevel.INFO,  # default level
        -1,  # retroactive level limit
        300  # retroactive time window in seconds
    )
    logger = Logger.new(config)
```

### Basic Logging
```gdscript
# Different severity levels
logger.debug("Loading game assets...")
logger.info("Player connected: PlayerOne")
logger.warning("Low memory warning: 100MB remaining")
logger.error("Failed to load texture: missing_texture.png")
logger.critical("Database connection lost!")
```

### Structured Logging with Context
```gdscript
# Player event with context
logger.info(
    "Player joined the game",
    {
        "player_id": "12345",
        "level": 42,
        "health": 100,
        "position": Vector2(100, 200)
    }
)

# Error with technical details
logger.error(
    "Database query failed",
    {
        "query_id": "abc123",
        "duration_ms": 1500,
        "error_code": 500,
        "retries_left": 2
    }
)
```

### Tag-based Filtering
```gdscript
# Add tags for filtering
logger.add_tag("network")
logger.add_tag("physics")

# Log with tags
logger.info("Packet received", {"size": 1024}, ["network"])
logger.warning("High latency", {"ping_ms": 150}, ["network"])
logger.debug("Physics update", {"delta": 0.016}, ["physics"])

# Remove specific tag
logger.remove_tag("network")

# Clear all tags
logger.clear_tags()
```

### Configuration
```gdscript
# Adjust buffer size (50-10000)
logger.set_buffer_size(5000)

# Change log level
logger.set_level(LogLevel.DEBUG)  # Show all logs
logger.set_level(LogLevel.WARNING)  # Only WARNING and above

# Set retroactive window (10-3600 seconds)
logger.set_retroactive_window(600)  # 10 minutes

# Disable/Enable logging
logger.disable()
logger.enable()
```

### Practical Game Example
```gdscript
func handle_battle(player: Node, enemy: Node) -> void:
    logger.info("Battle started", {
        "player_level": player.level,
        "enemy_type": enemy.type
    }, ["combat"])
    
    if player.health < 20:
        logger.warning("Player health critical", {
            "health": player.health,
            "potions_left": player.potions
        }, ["combat", "player"])
        
    if enemy.is_defeated():
        logger.info("Battle won", {
            "exp_gained": 1000,
            "items_dropped": ["potion", "gold"],
            "battle_duration": 45
        }, ["combat", "loot"])
```

## For LLMs

### Understanding the Logger Structure

The logger consists of several key components:
1. Logger (main class)
2. LoggerConfig (configuration class)
3. LogEntry (log entry data structure)
4. CircularBuffer (thread-safe storage)

### Key APIs

```gdscript
# Logging methods signature
func debug(message: String, context: Dictionary = {}, tags: Array[String] = []) -> void
func info(message: String, context: Dictionary = {}, tags: Array[String] = []) -> void
func warning(message: String, context: Dictionary = {}, tags: Array[String] = []) -> void
func error(message: String, context: Dictionary = {}, tags: Array[String] = []) -> void
func critical(message: String, context: Dictionary = {}, tags: Array[String] = []) -> void
```

### Best Practices for Log Generation

1. **Log Level Selection**
   - DEBUG: Detailed information for debugging
   - INFO: General information about system operation
   - WARNING: Potential issues that don't affect core functionality
   - ERROR: Serious issues that affect functionality but don't crash the system
   - CRITICAL: System-breaking issues that require immediate attention

2. **Context Structure**
   ```gdscript
   # Good context example
   {
       "id": "unique_identifier",  # Always include relevant IDs
       "value": measurement,       # Include actual values
       "state": current_state,     # Include state information
       "duration_ms": time_taken   # Include timing when relevant
   }
   ```

3. **Tag Usage**
   - Use consistent, hierarchical tags
   - Combine system and subsystem tags
   - Examples: ["network", "connection"], ["physics", "collision"]

4. **Message Formatting**
   - Be concise but descriptive
   - Include action and subject
   - Use consistent terminology

### Example Response Patterns

When asked to add logging to code:

```gdscript
# Original code
func process_player_action(action: String) -> void:
    if action == "jump":
        player.jump()

# With logging added
func process_player_action(action: String) -> void:
    logger.debug("Processing player action", {
        "action": action,
        "player_position": player.position,
        "game_state": current_state
    }, ["input", "player"])
    
    if action == "jump":
        logger.info("Player initiated jump", {
            "height": player.jump_height,
            "stamina": player.stamina
        }, ["player", "physics"])
        player.jump()
```

### Integration Points

Common places to add logging:
1. Function entry/exit for important operations
2. State changes
3. Resource loading/unloading
4. Network operations
5. Error conditions
6. Performance-critical sections

### When to Use Retroactive Logging

The retroactive log replay feature activates when:
1. An ERROR or CRITICAL log is generated
2. Within the configured time window
3. For messages that wouldn't normally be shown at current log level

This is particularly useful for:
- Debugging race conditions
- Tracking down intermittent issues
- Understanding the sequence of events leading to an error

## Output Format

The logger produces colored output in the following format:
```
[Timestamp] [Level] [Tags] Message
    context_key: context_value
    another_key: another_value
    at: file.gd:123 (function_name)
```

When retroactive replay occurs:
```
=== Begin Retroactive Log Replay ===
[Previous log entries that led to the error]
=== End Retroactive Log Replay ===
```
