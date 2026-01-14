# GameTwo GDScript Project

**256 GDScript files** - Core game implementation for GameTwo mobile game.

This directory contains all game logic, UI, Firebase integration, and Godot-specific implementations.

---

## ⚡ Quick Reference

**Anti-Patterns (FORBIDDEN)**:
- ❌ `await get_tree().process_frame` - Breaks determinism
- ❌ `await get_tree().create_timer(1.0).timeout` - Timing-based wait
- ❌ `async func my_function()` - Keyword doesn't exist
- ❌ `var data = {}` - No type annotation

**Correct Patterns (REQUIRED)**:
- ✅ `await signal_name` - Signal-driven async
- ✅ `var backend: FirebaseBackend = get_backend()` - Strong typing
- ✅ `var cards: Array[Card] = []` - Typed arrays
- ✅ `Logger.info("message", ["tag", "subtag"])` - Tag-based logging
- ✅ `var rng: DeterministicRNG = DeterministicRNG.get_singleton()` - Deterministic RNG

**Common Commands**:
- `just validate` - Complete validation
- `just ci-validate` - CI validation (MANDATORY before commits)
- `just deploy-android` - Deploy to Android (REQUIRED after changes)
- `just test-android-target CONFIG` - Automated Android testing
- `just run-editor-debug [verbose]` - Desktop debugging

---

## 🏗️ Project Architecture

### **Autoloads (Global Singletons)**
```
autoloads/
├── core.gd                    # Core game state manager
├── debug_manager.gd           # Debug coordinator (test actions, state capture)
├── deterministic_rng.gd       # Deterministic RNG for battle system
├── internet_status.gd         # Network connectivity monitoring
├── seeded_rng_singleton.gd    # Seeded RNG for reproducibility
└── ui.gd                      # Global UI controller
```

**Critical**: Autoloads are instantiated in project settings order. Use typed references:
```gdscript
var debug_mgr: DebugManager = DebugManager.get_singleton()
```

### **Core Systems**
```
core/
├── card/                      # Card system (battle units)
├── clicker/                   # Clicker game mechanics
├── events/                    # Event system
├── match_levels/              # Match progression logic
├── game_handler.gd            # Main game controller
├── lineup_handler.gd          # Team composition
├── gamestate_loader.gd        # Save/load system
└── block_factory.gd           # UI component factory
```

### **Data Layer**
```
data/
├── backends/
│   ├── backend_factory.gd           # Backend selection (Firebase/local)
│   ├── data_backend.gd              # Abstract backend interface
│   ├── firebase_service_backend.gd  # Firebase implementation
│   ├── local_json_backend.gd        # Local JSON implementation
│   └── json_path_navigator.gd       # JSON query utility
└── collections/                      # Data models
```

**Backend Pattern:**
```gdscript
var backend: DataBackend = BackendFactory.get_backend()
var result: NavigationResult = await backend.get_data("/users/123/profile")
if result.success:
    var profile: Dictionary = result.data
```

### **Firebase Integration**
```
firebase/
├── auth.gd                    # Authentication wrapper
├── database_service.gd        # Realtime Database operations
├── firebase_service.gd        # Core Firebase service
├── firebase_request.gd        # Request queueing system
├── firebase_rate_limiter.gd   # Rate limit management
└── firebase_auth_error.gd     # Error handling
```

**Critical**: Firebase operations are async and rate-limited:
```gdscript
var service: FirebaseService = FirebaseService.get_singleton()
var result: Dictionary = await service.database_get("/path")
# Always check result.success before accessing result.data
```

### **Debug System**
```
debug/
├── actions/                   # Debug actions (test scenarios)
├── saved_states/              # Gamestate snapshots
└── utilities/                 # Debug utilities
```

**Debug Actions**: Executed by `DebugManager` during automated testing
- Register via `DebugManager.register_action("action.name", callable)`
- Actions receive context: `{"config": {...}, "platform": "android"}`

### **Addons (Godot Plugins)**
```
addons/
├── advanced_logger/           # Runtime logging system (tag-based)
├── debug_startup/             # Debug initialization
├── gdLinter/                  # Code quality checks
├── godot_mcp/                 # MCP server integration
├── open-external-editor/      # External editor support
└── sentry/                    # Crash reporting
```

---

## 🚫 GDScript Anti-Patterns

### **NEVER Use Timing-Based Waits**
```gdscript
# ❌ FORBIDDEN - Breaks determinism, causes race conditions
await Engine.get_main_loop().process_frame
await get_tree().create_timer(1.0).timeout
await get_tree().physics_frame

# ✅ CORRECT - Use signals
signal operation_completed
await operation_completed

# ✅ CORRECT - Use callbacks
func _on_animation_finished() -> void:
    next_action()
```

**Rationale**: GameTwo uses:
- **Deterministic battle system** - Timing waits break replay integrity
- **Checksum validation** - Frame-dependent code causes cross-platform failures
- **Gamestate reproduction** - Must be reproducible across platforms

### **No `async` Keyword**
```gdscript
# ❌ FORBIDDEN - 'async' doesn't exist in GDScript
async func my_function() -> void:
    pass

# ✅ CORRECT - Functions become async when they await
func my_function() -> void:
    await some_signal  # Function is now implicitly async
    process_result()
```

### **Never Skip Signals**
```gdscript
# ❌ FORBIDDEN - Polling patterns
while not operation_complete:
    await get_tree().process_frame  # Forbidden wait

# ✅ CORRECT - Signal-driven
await operation_completed_signal
```

---

## 💪 Strong Typing (MANDATORY)

**Use fail-fast typing throughout:**

```gdscript
# ✅ REQUIRED - Typed variables
var firebase_backend: FirebaseBackend = get_backend()
var cards: Array[Card] = []
var player_data: Dictionary = {}
var level: int = 1
var name: String = "Player"

# ✅ REQUIRED - Typed function signatures
func create_card(id: String, level: int = 1) -> Card:
    var card: Card = card_scene.instantiate() as Card
    card.initialize(id, level)
    return card

func process_data(data: Dictionary) -> void:
    var health: int = data.get("health", 100)
    update_ui(health)

# ✅ REQUIRED - Typed class properties
class_name PlayerData
extends Resource

var player_id: String
var level: int
var experience: int
var cards: Array[Card]

# ❌ FORBIDDEN - Runtime type checking
if backend is FirebaseBackend:
    # This should be caught at compile time

# ❌ FORBIDDEN - Untyped variables
var data = {}  # No type
var items = []  # No type
var thing      # No type

# ❌ FORBIDDEN - Weak typing
func get_data():  # No return type
    return something
```

**Benefits:**
- **Compile-time error detection** - Catches bugs before runtime
- **Better IDE support** - Autocomplete, refactoring, navigation
- **Performance** - Typed code is faster (no runtime type checks)
- **Maintainability** - Clear contracts, easier to understand

### **Validation**
```bash
just validate              # Complete validation (format + syntax + runtime)
just show-warnings         # GDScript warnings analysis
just validate-gdscript     # Syntax validation only
```

**CI Requirement**: `just ci-validate` **MANDATORY** before commits

---

## 🔥 Firebase Integration Patterns

### **Authentication**
```gdscript
var auth: Auth = Auth.get_singleton()

# Sign in
var result: Dictionary = await auth.sign_in_with_email_and_password(email, password)
if result.has("error"):
    handle_error(result.error)
else:
    var user: Dictionary = result.user
    print("Signed in: ", user.uid)

# Sign out
await auth.sign_out()
```

### **Database Operations**
```gdscript
var db: DatabaseService = DatabaseService.get_singleton()

# Read data
var result: Dictionary = await db.get("/users/{uid}/profile")
if result.success:
    var profile: Dictionary = result.data

# Write data
var write_result: Dictionary = await db.set("/users/{uid}/profile", {
    "name": "Player",
    "level": 5
})

# Update data
var update_result: Dictionary = await db.update("/users/{uid}/stats", {
    "wins": 10,
    "losses": 3
})
```

### **Rate Limiting**

**Firebase Rate Limiter** (`firebase_rate_limiter.gd`) automatically manages request queuing:
- **Max concurrent requests**: 5 simultaneous operations
- **Queue processing**: FIFO (First-In-First-Out)
- **Inter-request delay**: 100ms between requests
- **Automatic retry**: Failed requests retry with exponential backoff

```gdscript
# Firebase operations are automatically rate-limited
# NEVER bypass rate limiting - causes backend throttling

# ✅ CORRECT - Let rate limiter handle queuing
for i in range(100):
    await firebase.database_get("/data/" + str(i))
    # Rate limiter automatically:
    # - Queues requests when at capacity
    # - Processes with 100ms delay between requests
    # - Retries failures with exponential backoff

# ❌ FORBIDDEN - Manual retry loops
while not success:
    var result = await firebase.database_get("/data")
    if not result.success:
        await get_tree().create_timer(0.1).timeout  # Forbidden + bad pattern
```

**Rate Limit Exceeded**: If backend returns rate limit error, increase inter-request delay in `firebase_rate_limiter.gd`

### **Error Handling**
```gdscript
var result: Dictionary = await firebase_service.database_get("/path")

if result.has("error"):
    match result.error.code:
        "PERMISSION_DENIED":
            show_error("Access denied")
        "NETWORK_ERROR":
            show_error("Check internet connection")
        "RATE_LIMITED":
            # Rate limiter should prevent this - log if it occurs
            Logger.error("Rate limit hit unexpectedly", ["firebase"])
        _:
            show_error("Unknown error: " + result.error.message)
else:
    var data: Dictionary = result.data
    process_data(data)
```

---

## 🎮 Scene & Node Patterns

### **Scene Instantiation**
```gdscript
# ✅ CORRECT - Typed instantiation
@export var card_scene: PackedScene

func create_card() -> Card:
    var card: Card = card_scene.instantiate() as Card
    add_child(card)
    return card

# ❌ FORBIDDEN - Untyped
var card = card_scene.instantiate()  # No type safety
```

### **Node References**
```gdscript
# ✅ CORRECT - Typed node references
@onready var health_bar: ProgressBar = $HealthBar
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
    health_bar.max_value = 100
    health_bar.value = 50

# ✅ CORRECT - Safe node access
func get_player() -> Player:
    var player_node: Node = get_node_or_null("Player")
    if player_node:
        return player_node as Player
    return null

# ❌ FORBIDDEN - Unsafe access
var player = get_node("Player")  # Crashes if not found
```

### **Signal Connections**
```gdscript
# ✅ CORRECT - Typed signal connections
signal health_changed(new_health: int)
signal card_played(card: Card)

func _ready() -> void:
    health_changed.connect(_on_health_changed)
    card_played.connect(_on_card_played)

func _on_health_changed(new_health: int) -> void:
    update_health_ui(new_health)

func _on_card_played(card: Card) -> void:
    animate_card(card)
```

---

## 🧪 Testing Integration

### **Debug Actions**
```gdscript
# Debug actions are callable functions registered with DebugManager
# Executed during automated testing via test configs

func _ready() -> void:
    if DebugManager.is_active():
        DebugManager.register_action("game.battle.start", _debug_start_battle)
        DebugManager.register_action("game.battle.end", _debug_end_battle)

func _debug_start_battle(context: Dictionary) -> void:
    # Context contains: config, platform, test_id, session_id
    var config: Dictionary = context.get("config", {})
    start_battle(config)

func _debug_end_battle(context: Dictionary) -> void:
    end_battle()
```

**Debug Action Naming:**
- Format: `layer.system.action`
- Examples:
  - `cpp.firebase.auth.sign_in`
  - `system.network.connectivity_check`
  - `game.battle.start_match`
  - `game.card.play_card`

### **Gamestate Capture**
```gdscript
# Gamestate system captures complete game state for reproduction
# Automatically integrated with save/load system

func save_game_state() -> Dictionary:
    return {
        "player": player.serialize(),
        "cards": cards.map(func(c): return c.serialize()),
        "level": current_level,
        "rng_state": DeterministicRNG.get_state()
    }

func load_game_state(state: Dictionary) -> void:
    player.deserialize(state.player)
    cards = state.cards.map(func(c): return Card.deserialize(c))
    current_level = state.level
    DeterministicRNG.set_state(state.rng_state)
```

---

## 📦 Resource Management

### **Preloading**
```gdscript
# ✅ CORRECT - Preload for editor-time loading
const CARD_SCENE: PackedScene = preload("res://core/card/card.tscn")
const CARD_DATA: Resource = preload("res://data/cards.tres")

# ✅ CORRECT - load() for runtime loading
var texture: Texture2D = load("res://assets/ui/button_" + button_type + ".png")
```

### **Resource Cleanup**
```gdscript
func _exit_tree() -> void:
    # Clean up signals
    if some_signal.is_connected(_on_signal):
        some_signal.disconnect(_on_signal)

    # Free manually allocated resources
    if texture:
        texture = null

    # Queue free children if needed
    for child in get_children():
        child.queue_free()
```

---

## 🔧 Advanced Logger Integration

**Tag-based logging system** - Essential for debugging and analysis

```gdscript
# Logger is globally available through advanced_logger addon
func _ready() -> void:
    Logger.info("Game started", ["game", "lifecycle"])
    Logger.debug("Player data loaded", ["game", "player"], {"player_id": "123"})

# Tag hierarchy: layer.system.component
Logger.info("Firebase auth started", ["cpp", "firebase", "auth"])
Logger.info("Card played", ["game", "card", "action"], {"card_id": "fireball"})
Logger.error("Battle ended", ["game", "battle", "error"], {"reason": "timeout"})

# Available log levels:
# - DEBUG: Detailed information
# - INFO: General information
# - WARN: Warning messages
# - ERROR: Error conditions
# - CRITICAL: Critical failures
```

**Tag Conventions:**
- **cpp**: C++ module operations (Firebase SDK)
- **system**: System-level operations (network, storage)
- **game**: Game logic operations (battle, card, clicker)
- **ui**: UI-related operations

**Metadata**: Include relevant context in metadata dictionary for debugging

---

## 🚨 Safety & Best Practices

### **Memory Management**
```gdscript
# ✅ CORRECT - Use queue_free() for nodes
node.queue_free()  # Deferred deletion, safe

# ❌ FORBIDDEN - Never use free() on nodes
node.free()  # Immediate deletion, unsafe

# ✅ CORRECT - Check before accessing
if is_instance_valid(node):
    node.do_something()
```

### **Deterministic RNG**
```gdscript
# ✅ CORRECT - Use DeterministicRNG for battle logic
var rng: DeterministicRNG = DeterministicRNG.get_singleton()
var damage: int = rng.randi_range(10, 20)

# ❌ FORBIDDEN - Never use RandomNumberGenerator for battle logic
var rng = RandomNumberGenerator.new()  # Breaks determinism
```

### **Platform Detection**
```gdscript
func get_platform() -> String:
    if OS.has_feature("android"):
        return "android"
    elif OS.has_feature("ios"):
        return "ios"
    elif OS.has_feature("windows"):
        return "windows"
    elif OS.has_feature("macos"):
        return "macos"
    elif OS.has_feature("linux"):
        return "linux"
    else:
        return "unknown"

# Use for platform-specific logic
if OS.has_feature("mobile"):
    enable_touch_controls()
else:
    enable_keyboard_controls()
```

---

## 📖 Additional Resources

**Validation Commands:**
```bash
just validate              # Complete validation pipeline
just ci-validate           # CI validation (MANDATORY before commits)
just format                # Auto-format code
just lint                  # Code quality checks
just show-warnings         # GDScript warnings
```

**Testing:**
```bash
just test-editor-target CONFIG    # Editor testing
just test-android-target CONFIG   # Android testing
just run-editor-debug [verbose]  # Debug mode with leak detection
```

**See Also:**
- `tests/CLAUDE.md` - Testing systems (replay, checksum, gamestate)
- `godot/modules/firebase/CLAUDE.md` - Firebase C++ module implementation
- `justfiles/CLAUDE.md` - Complete command reference
- Root `CLAUDE.md` - Overall project workflows

---

**Key Principles:**
- ✅ **Strong typing everywhere** - Fail fast, catch errors at compile time
- ✅ **Signal-driven architecture** - Never use timing-based waits
- ✅ **Deterministic battle system** - Use DeterministicRNG, avoid randomness
- ✅ **Proper error handling** - Always check async operation results
- ✅ **Tag-based logging** - Use Logger with appropriate tags for debugging

*This project follows strict patterns to ensure cross-platform consistency, deterministic behavior, and maintainability.*
