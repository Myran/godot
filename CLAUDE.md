# CLAUDE.md

GameTwo is a sophisticated mobile game built with a custom Godot 4.3 engine featuring Firebase integration, advanced data management, and comprehensive debugging systems.

## 🚀 Essential Development Workflow

### **Daily Development Cycle**
```bash
# 1. Code & Validate
just validate                              # Fast syntax check (3 sec)
just format                                # Format GDScript files

# 2. Test Changes (choose appropriate level)
just run-desktop                           # Instant local testing (0 sec)
just test-android 'system.*'              # Test system layer (30 sec)
just test-android-target lineup-checksum-test # Validate game state consistency (30 sec)
just test-android development-workflow     # Full development validation

# 3. Quick Debug (if issues)
just logs-errors-tagged TEST_ID            # Check for errors (98% token savings)
just logs TEST_ID [component]              # Component-focused analysis

# 4. Deploy Changes
just fastbuild-android                     # Rebuild & deploy (60 sec)
```

### **Pre-Commit Workflow**
```bash
just pre-commit                            # Complete pre-commit validation (format + syntax + runtime)
just test-android pre-commit               # Pre-commit test suite
just test-all-android                      # Complete validation (if needed)
```

## 🎯 Smart Debugging Decision Tree

**Follow this exact sequence for maximum efficiency:**

```
Issue Detected?
├── 🚨 Step 1: Quick Error Scan (5 sec, <10 tokens)
│   └── just logs-errors-tagged TEST_ID
│       ├── ✅ Errors found → Follow error patterns below
│       └── ❌ No errors → Go to Step 2
│
├── 🎯 Step 2: Component Analysis (15 sec, <100 tokens)
│   └── just logs TEST_ID [component]
│       ├── Firebase issues → just logs TEST_ID firebase
│       ├── Battle/Game issues → just logs TEST_ID battle  
│       ├── System issues → just logs TEST_ID system
│       ├── State validation → just logs TEST_ID checksum
│       └── Debug framework → just logs TEST_ID debug test
│
└── 🔬 Step 3: Precision Analysis (if needed, <200 tokens)
    └── just logs TEST_ID [component] [operation] [status]
```

## 🔧 Common Failure Patterns & Quick Fixes

### **🔥 Firebase Issues**
**Symptoms:** `Firebase timeout`, `Connection refused`, `Auth failed`  
**Debug:** `just logs-errors-tagged TEST_ID firebase`  
**Fix:** `just test-android 'system.network.*'`

### **🎯 Battle Determinism**
**Symptoms:** `expectedHash mismatch`, `VALIDATION MODE failed`  
**Debug:** `just logs TEST_ID battle determinism`  
**Fix:** `just test-android 'game.match.reset_level'`

### **⚡ Performance Issues**
**Symptoms:** Slow execution, timeouts  
**Debug:** `just logs-performance-tagged TEST_ID`  
**Fix:** `just test-android '*.*.performance'`

### **🔄 System Startup**
**Symptoms:** Initialization failures, registry errors  
**Debug:** `just logs TEST_ID system startup`  
**Fix:** `just test-android 'system.debug.*'`

### **🧪 State Validation**
**Symptoms:** `CHECKSUM_MISMATCH`, game state inconsistencies  
**Debug:** `just logs-errors-tagged TEST_ID checksum`  
**Fix:** `just test-android-update lineup-checksum-test` (legitimate changes) or investigate regression

## 🏷️ Token-Efficient Log Commands

**Use these instead of reading full logs (90-98% token savings):**

```bash
# Error-first debugging (recommended)
just logs-errors-tagged TEST_ID            # All errors (98% savings)
just logs-errors-tagged TEST_ID firebase   # Component-specific errors

# Most recent test run (ultra-efficient)
just logs-last                             # Latest run only (99% savings)

# Component-focused analysis  
just logs TEST_ID firebase                 # Firebase operations (87% savings)
just logs TEST_ID battle                   # Game mechanics (92% savings)
just logs TEST_ID system startup          # System initialization (95% savings)

# Performance analysis
just logs-performance-tagged TEST_ID       # All performance data
just logs-performance-tagged TEST_ID battle # Component performance

# Traditional commands (use sparingly)
just logs TEST_ID                          # Full logs (high token cost)
```

## ⚡ Core Command System: test, config, logs

### **🧪 Testing Commands - Primary Interface**
```bash
# Unified testing (auto-detects patterns, configs, test lists)
just test-android TARGET                   # Primary testing interface
just test-android-enhanced TARGET          # Enhanced error analysis + categorization
just test-android-trace TARGET             # Debug validation steps (troubleshooting)

# Essential test workflows
just test-android development-workflow     # Daily development test suite
just test-android pre-commit               # Pre-commit validation
just test-android production-ready         # Release validation
just test-all-android                      # Complete test suite
```

### **🔧 Config Commands - Ultra-Fast Iteration**
```bash
# 5-second development cycles
just config-restart-android ACTION         # Deploy + restart (5 sec total)
just config-push-android CONFIG            # Deploy config only (2 sec)
just config-set 'PATTERN'                  # Set as default embedded config

# Configuration management
just config-status-android                 # Check current config
just config-clear-android                  # Clear external config
just config-list                           # List available configs

# Android logger configuration (runtime changes)
just config-android-tags "active" "ignored" # Set active/ignored tags
just config-android-level LEVEL            # Set log level (DEBUG/INFO/WARNING/ERROR/CRITICAL)
just config-android-reset                  # Reset to project defaults
```

### **📋 Log Commands - Token-Efficient Analysis**
```bash
# Universal tag-filtered commands (90-98% token savings)
just logs TEST_ID [tags...]                # Universal log filtering
just logs-errors-tagged TEST_ID [tags...]  # Error-focused analysis
just logs-performance-tagged TEST_ID [tags...] # Performance analysis
just logs-lifecycle-tagged TEST_ID [tags...] # App lifecycle events

# Traditional commands (use sparingly)
just logs TEST_ID                          # Full logs (high token cost)
just logs-results-only TEST_ID             # Results summary only
just logs-list-recent                      # Recent test runs
```

### **🎯 Wildcard Patterns - Zero Maintenance Auto-Discovery**

**All commands support hierarchical wildcards: `layer.domain.operation`**

#### **Layer Wildcards**
```bash
# Test specific layers
just test-android 'cpp.*'                 # C++ Firebase SDK (8 actions)
just test-android 'backend.*'             # Backend Firebase (7 actions)
just test-android 'rtdb.*'                # RTDB API (19 actions)
just test-android 'system.*'              # System utilities (5 actions)
just test-android 'game.*'                # Game logic (12 actions)

# Config iteration for layers
just config-restart-android 'cpp.*'       # Test all C++ actions (5 sec)
just config-restart-android 'system.*'    # Test all system actions (5 sec)
```

#### **Domain Wildcards**
```bash
# Test across all layers by domain
just test-android '*.firebase.*'          # All Firebase operations
just test-android '*.debug.*'             # All debug utilities
just test-android '*.match.*'             # All game match functionality

# Config iteration for domains
just config-restart-android '*.firebase.*' # All Firebase tests
just config-restart-android '*.debug.*'   # All debug operations
```

#### **Operation Wildcards**
```bash
# Test specific operations across all layers
just test-android '*.*.error_handling'    # All error handling
just test-android '*.*.performance'       # All performance tests
just test-android '*.*.set_value'         # All data writing operations
just test-android '*.*.get_value'         # All data reading operations

# Config iteration for operations
just config-restart-android '*.*.error_handling' # Test error handling
```

### **🚀 Practical Workflow Examples**

#### **Rapid Development Iteration**
```bash
# 1. Test a specific component quickly
just config-restart-android 'system.debug.registry_stats'  # 5 seconds

# 2. Test entire layer after changes
just config-restart-android 'cpp.*'                        # 5 seconds

# 3. Full validation when ready
just test-android 'cpp.*'                                  # 30+ seconds with analysis
```

#### **Progressive Debugging**
```bash
# 1. Latest test results (ultra-fast)
just logs-last                                             # <5 tokens

# 2. Quick error check
just logs-errors-tagged TEST_ID                            # <10 tokens

# 3. Component-focused analysis  
just logs TEST_ID firebase                                 # ~100 tokens

# 4. Precision analysis with multiple tags
just logs TEST_ID firebase rtdb error                      # ~50 tokens
```

#### **Cross-Layer Testing**
```bash
# Test Firebase functionality across all layers
just test-android '*.firebase.*'           # All Firebase operations
just logs TEST_ID firebase                 # Analyze Firebase logs

# Test error handling across all systems
just test-android '*.*.error_handling'     # All error handling
just logs-errors-tagged TEST_ID            # Check for errors
```

### **💡 Command Auto-Detection & Integration**

**All test commands automatically detect input type:**
- **Single Actions**: `'system.debug.registry_stats'` → Direct action execution
- **Wildcard Patterns**: `'cpp.*'` → Auto-discovers matching actions  
- **Config Files**: `system-testing` → Loads predefined configuration
- **Test Lists**: `development-workflow` → Executes test suite
- **Wildcard Test Lists**: `'@pre-*'` → Pattern-matches test lists

### **🔥 Advanced Wildcard Workflow Patterns**

#### **Development by Layer (Recommended)**
```bash
# Focus development on specific architectural layers
just config-restart-android 'cpp.*'       # C++ Firebase SDK iteration
just config-restart-android 'backend.*'   # Backend Firebase iteration  
just config-restart-android 'rtdb.*'      # RTDB GDScript API iteration
just config-restart-android 'system.*'    # System utilities iteration
just config-restart-android 'game.*'      # Game logic iteration

# Full layer validation when ready
just test-android 'cpp.*'                 # Complete C++ layer testing
just logs TEST_ID cpp                     # Analyze C++ layer logs
```

#### **Feature-Driven Testing**
```bash
# Test all Firebase functionality across layers
just test-android '*.firebase.*'          # All Firebase operations
just logs TEST_ID firebase                # Firebase-focused log analysis
just logs-performance-tagged TEST_ID firebase # Firebase performance

# Test all error handling implementations  
just test-android '*.*.error_handling'    # Cross-layer error handling
just logs-errors-tagged TEST_ID           # Error-focused analysis
```

#### **Operation-Specific Debugging**
```bash
# Debug all data writing operations
just config-restart-android '*.*.set_value'   # Test all set operations
just logs TEST_ID set_value                    # Analyze set operations
just logs-performance-tagged TEST_ID set_value # Set operation performance

# Debug all data reading operations
just config-restart-android '*.*.get_value'   # Test all get operations  
just logs TEST_ID get_value                    # Analyze get operations
```

### **⚡ Ultra-Fast Development Cycles**

**The config commands enable 5-second iteration cycles:**
```bash
# Edit code → Test immediately (no rebuild needed)
just config-restart-android 'system.debug.registry_stats'  # 5 seconds
just config-restart-android 'cpp.*'                        # 5 seconds  
just config-restart-android '*.firebase.set_value'         # 5 seconds

# When ready for full analysis
just test-android 'system.*'                               # 30+ seconds with logs
just logs-errors-tagged TEST_ID                            # Quick error check
just logs TEST_ID system debug                             # Focused analysis
```

## 📱 Android Logger Configuration

### **Real-Time Logger Control**
Configure Android logger settings without rebuilding. Changes take effect after app restart.

```bash
# Focus on specific components, filter noise
just config-android-tags "firebase,battle" "cache,animation"

# Adjust log verbosity  
just config-android-level INFO                           # Reduce debug noise
just config-android-level DEBUG                          # Full debugging

# Reset to project defaults
just config-android-reset                                # Use project/addons/advanced_logger/settings.cfg

# Apply changes
just restart-android-app                                 # Restart to apply config
```

### **Logger Configuration Workflow**
```bash
# 1. Set focused debugging during development
just config-android-tags "firebase,error" "cache,debug" # Focus on Firebase errors
just config-android-level DEBUG                          # Enable all log levels
just restart-android-app                                 # Apply settings

# 2. Run tests with focused logging
just config-restart-android '*.firebase.*'              # Test Firebase layer
just logs-errors-tagged TEST_ID firebase                 # Check Firebase errors only

# 3. Adjust filtering as needed
just config-android-tags "firebase,rtdb" "cache"        # Expand to RTDB logs
just restart-android-app

# 4. Clean up when done
just config-android-reset                                # Reset to defaults
```

### **🎯 Command Integration Examples**

#### **Complete Feature Development Workflow**
```bash
# 1. Rapid iteration during development
just config-restart-android '*.firebase.set_value'        # 5 sec testing

# 2. Full feature validation
just test-android '*.firebase.*'                          # Complete Firebase test

# 3. Efficient debugging (if issues found)
just logs-errors-tagged TEST_ID firebase                  # <10 tokens error check
just logs TEST_ID firebase set_value                      # ~50 tokens focused analysis

# 4. Performance validation
just logs-performance-tagged TEST_ID firebase             # Performance analysis
```

#### **Cross-Layer Integration Testing**
```bash
# Test data flow: cpp → backend → rtdb
just test-android 'cpp.firebase.set_value'                # C++ layer
just test-android 'backend.firebase.set_value'            # Backend layer  
just test-android 'rtdb.database.set_value'               # RTDB layer

# Analyze results across all layers
just logs TEST_ID firebase set_value                      # Cross-layer analysis
just logs-performance-tagged TEST_ID firebase             # Performance comparison
```

## 💪 Strong Typing Requirements

**CRITICAL: Always use fail-fast typing to catch errors at compile time**

### **✅ Required Patterns**
```gdscript
# Strong typing with immediate failure
var firebase_backend: FirebaseBackend = get_backend()
var cards: Array[Card] = []
var success_rate: float = 0.8

func create_card(id: String, level: int = 1) -> Card:
    var card_info: Dictionary = await data_source.get_card(id)
    return card_scene.instantiate() as Card
```

### **❌ NEVER Use These**
```gdscript
# Type casting hides problems - use strong typing instead
if backend is FirebaseBackend:           # ❌ Runtime checking
    var fb = backend as FirebaseBackend  # ❌ Type casting

# Untyped variables delay problem discovery  
var data = {}                            # ❌ No type
var items = []                           # ❌ Generic array
```

### **Quality Validation**
```bash
just pre-commit                          # Complete validation pipeline (format + syntax + runtime)
just validate                            # Syntax check (3 sec)
just validate-godot                      # Runtime validation (15 sec)
just format                              # Code formatting

# Pre-commit validation pipeline
# - Checks if formatting is needed (fails if code requires formatting)
# - Runs syntax validation with full error reporting  
# - Runs runtime validation to catch type/compilation issues
# - Perfect for CI/CD and git pre-commit hooks (non-destructive)

# Custom validation patterns
just validate-godot "ERROR:"             # Focus on errors only
just validate-godot "WARN"               # Show warnings
just validate-godot "INFO.*debug"        # Custom filter patterns
```

## 📊 Efficiency Targets

### **Debugging Performance**
- **Error Detection:** < 30 seconds (`logs-errors-tagged`)
- **Root Cause:** < 5 minutes (progressive debugging)
- **Fix Validation:** < 1 minute (`config-restart-android`)

### **Token Efficiency**
- **Error Scan:** < 20 tokens (99% savings)
- **Component Analysis:** < 100 tokens (87-95% savings)  
- **Deep Investigation:** < 300 tokens (avoid full logs)

### **Development Velocity**
- **Code → Test:** < 60 seconds (`fastbuild-android`)
- **Issue → Fix:** < 10 minutes (decision tree + patterns)
- **Syntax Check:** < 5 seconds (`validate`)

## 🧪 Checksum Snapshot Testing

### **Automated State Validation**
**Validate game state consistency using MD5 checksums for regression testing:**

```bash
# Core Testing
just test-android-target lineup-checksum-test    # Run checksum test (auto-creates baseline on first run)

# Baseline Management
just test-android-update lineup-checksum-test    # Force update baseline (clear + regenerate)
just test-android-reset lineup-checksum-test     # Remove baseline (start fresh)
just test-android-list-checksum                  # List all checksum-enabled configs
```

### **How It Works**
1. **Populate Enemy**: Creates deterministic test data with `game.lineup.populate_enemy`
2. **Capture State**: Extracts lineup data and generates MD5 checksum with `game.lineup.capture_state`
3. **Auto-Restart**: System automatically restarts to validate after saving baseline
4. **Validate**: Compares against saved baseline with `system.checksum.validate`

### **Key Features**
- **Auto-baseline**: First run saves checksum to JSON config automatically
- **Auto-restart**: Automatic validation after baseline creation
- **Deterministic**: Uses existing `DictUtils.deterministic_hash()` for consistent results
- **Extensible**: Base class `CaptureActionBase` supports other game states (board, inventory, etc.)
- **Log Integration**: Uses structured logging with tags for token-efficient debugging

### **Naming Convention & Discovery**
```bash
# Recommended naming for checksum configs
*-checksum-test.json     # Primary pattern (e.g., lineup-checksum-test.json)
*-snapshot-test.json     # Alternative pattern (e.g., board-snapshot-test.json)

# IMPORTANT: Include "checksum" in description for fzf searchability
"description": "Your Feature CHECKSUM Test - Description with checksum keyword"

# Discovery commands
just test-android-list-checksum                  # List all checksum vs regular configs
just config-list                                 # List all available configs (checksum + regular)
just test-android                                # Interactive fzf selector (search "checksum")
```

### **Workflow Examples**
```bash
# 1. Discovery & Selection
just test-android                                 # Interactive fzf selector
# Type "checksum" to filter → Shows: "Lineup Checksum Test - Validate lineup state..."

# 2. First Time Setup
just test-android-target lineup-checksum-test    # Creates initial baseline automatically

# 3. Regular Validation
just test-android-target lineup-checksum-test    # Validates against baseline (PASS/FAIL)

# 4. When Features Change Legitimately
just test-android-update lineup-checksum-test    # Updates baseline automatically

# 5. Start Completely Fresh
just test-android-reset lineup-checksum-test     # Clears baseline only
just test-android-target lineup-checksum-test    # Creates new baseline
```

### **Debugging Checksum Issues**
```bash
# Quick checksum validation check
just logs-errors-tagged TEST_ID checksum          # Check for checksum failures (98% savings)
just logs TEST_ID checksum                         # Detailed checksum analysis
just logs TEST_ID checksum capture                # Focus on capture phase
just logs TEST_ID checksum validation             # Focus on validation phase

# Performance analysis
just logs-performance-tagged TEST_ID checksum     # Checksum performance data
```

### **Creating New Checksum Configs**
```json
{
  "description": "Board CHECKSUM Test - Validate board state consistency using checksums",
  "actions": [
    "game.board.setup_initial_state",
    "game.board.capture_state",
    "system.checksum.validate"
  ],
  "checksum_config": {
    "state_type": "board_state",
    "expected_checksum": ""
  }
}
```

### **Creating New Capture Actions**
```gdscript
# Extend CaptureActionBase for new game states
class_name BoardCaptureAction extends CaptureActionBase

func capture_data() -> Dictionary:
    # Extract relevant game state (board, inventory, etc.)
    return {"board": extract_board_data()}

func get_state_type() -> String:
    return "board_state"
```

## 🧠 Advanced Planning

### **When to Use Shrimp Task Manager**
**Use for complex technical planning requiring systematic breakdown:**
- Multi-component system design
- Features requiring 5+ interconnected tasks  
- Architecture changes affecting multiple systems

**Don't use for simple tasks:**
- Single file modifications, bug fixes, adding individual debug actions

### **Basic-Memory Integration**
```bash
# Document debugging insights for future reference
mcp__basic-memory__write_note "Firebase Debug Pattern" "
Symptom: Firebase timeouts during network transitions
Solution: Test system.network.* first, increase timeout config
Commands: logs-errors-tagged TEST_ID firebase
" "debugging-patterns"
```

## 🏗️ Build & Engine Development

### **Essential Build Commands**
```bash
# Custom engine builds (when modifying Godot source)
just godot-build-editor           # Build custom Godot editor
just godot-build-templates        # Build export templates
just build-all-android            # Full Android build (20 min)
just build-all-ios                # Full iOS build (20 min)

# Quick development builds
just fastbuild-android            # Fast rebuild & deploy (60 sec)
```

### **Production Deployment**
```bash
just deploy-android               # Deploy to Play Store (requires AAB)
just deploy-ios                   # Deploy to App Store
just help-production              # Complete deployment guide
```

## 🗂️ Project Architecture

### **Core Systems**
- **DataSource Pattern**: Unified interface for Firebase RTDB + local storage backends
- **Debug Framework**: 55 debug actions across 7 categories with device deployment
- **Custom Engine**: Modified Godot 4.3 with integrated Firebase/Facebook modules

### **Key Directories**
- `project/` - Godot project and game logic
- `godot/` - Custom engine source and build artifacts
- `firebase/` - Firebase config and integration  
- `export/` - Platform export configurations
- `project/debug/actions/` - Debug actions by layer (cpp, backend, rtdb, system, game)
- `project/debug/actions/capture_action_base.gd` - Base class for checksum capture actions
- `project/debug/actions/lineup_capture_action.gd` - Lineup state capture implementation
- `project/debug_configs/` - Individual test configurations with checksum baselines
- `project/test-lists/` - Test configurations for different workflows

### **Data Backend Architecture**
- **FirebaseDataSource**: Real-time database backend (production)
- **LocalDataSource**: Local storage backend (development/fallback)
- **DataSourceManager**: Automatic backend switching based on connectivity

## 🎯 Platform Targets
- **Mobile**: 1080x1920 portrait, Android 5.0+/iOS 12.0+
- **Engine**: Custom Godot 4.3 with Firebase/Facebook SDK integration
- **Backend**: Firebase RTDB with intelligent local fallback