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

# Replay & interactive debugging
just logs TEST_ID replay complete interactive # Manual verification replay logs
just logs TEST_ID debug ui menu               # Debug interface hide/show events
just logs-errors-tagged TEST_ID replay        # Replay-specific errors

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

## 📱 Android Device Control

### **Screenshot Commands**
**Essential commands for AI-assisted debugging and analysis:**

```bash
# Take screenshots for AI analysis
just screenshot                          # Quick screenshot (saved as /tmp/screenshot.png)
just screenshot-android my-debug-screen  # Named screenshot (saved as /tmp/my-debug-screen.png)

# Workflow: Screenshot → Analyze
just screenshot                          # 1. Capture current state
# 2. Use Read tool with /tmp/screenshot.png for AI analysis
```

### **Screenshot Analysis Workflow**
```bash
# 1. Take screenshot during debugging
just screenshot-android error-state      # Capture problematic state

# 2. AI analyzes the screenshot
# Use Read tool: /tmp/error-state.png

# 3. Take corrective action based on analysis
just test-android 'system.*'             # Re-run tests

# 4. Verify fix with new screenshot
just screenshot-android fixed-state      # Capture fixed state
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

# Baseline Management (with fzf selectors)
just test-android-update [config]                # Force update baseline (shows fzf checksum selector if no config)
just test-android-reset [config]                 # Remove baseline (shows fzf checksum selector if no config)
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
just test-android                                 # Interactive fzf selector (all configs)
# Type "checksum" to filter → Shows: "Lineup Checksum Test - Validate lineup state..."

just test-android-update                          # Interactive fzf selector (checksum configs only)
# Shows: "📸 lineup-checksum-test (lineup_state) ✅ BASELINE SET - Lineup Checksum Test..."

# 2. First Time Setup
just test-android-target lineup-checksum-test    # Creates initial baseline automatically

# 3. Regular Validation
just test-android-target lineup-checksum-test    # Validates against baseline (PASS/FAIL)

# 4. When Features Change Legitimately (fzf or direct)
just test-android-update                          # Shows checksum-only fzf selector
just test-android-update lineup-checksum-test    # Direct update (same result)

# 5. Start Completely Fresh (fzf or direct)
just test-android-reset                           # Shows checksum-only fzf selector
just test-android-reset lineup-checksum-test     # Direct reset
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

## 🎬 Demo Recording & Cross-Platform Testing

### **Unified Demo System - Play Once, Test Everywhere**
**Seamless workflow: Play normally → Extract demo → Test on both platforms → Convert to permanent regression tests.**

### **📝 Demo Creation Workflow**

#### **🎮 Step 1: Play the Game (No Special Mode Needed)**
```bash
# Just play normally - semantic actions are automatically recorded
just run-desktop                    # Play on desktop
# OR
just run-android-debug             # Play on Android

# Semantic actions (draft.reroll, lineup.move_card, etc.) are logged automatically
```

#### **🎬 Step 2: Create Demo from Gameplay Session**
```bash
# Extract demo from what you just played
just create-demo-from-last-session my-battle-demo

# Alternative: Browse and select from recent sessions
just create-demo-interactive

# Alternative: Create from specific session ID
just create-demo-from-session SESSION_123 my-demo-name
```

#### **🎮 Step 3: Test Demo on Both Platforms**
```bash
# Test demo using existing test-android system (already works!)
just test-android my-battle-demo        # Test on Android
just test-desktop-target my-battle-demo # Test on Desktop

# Cross-platform validation
just demo-test-cross-platform my-battle-demo  # Test on both, compare results
```

#### **🧪 Step 4: Convert Demo to Regression Test (Optional)**
```bash
# Convert demo to permanent regression test with checksum validation
just demo-to-test my-battle-demo

# Now you have:
# - my-battle-demo.json (original demo for manual verification)
# - my-battle-demo-test.json (automated regression test with checksum)

# Test the regression test
just test-android-target my-battle-demo-test    # Creates baseline on first run
just test-desktop-target my-battle-demo-test    # Validates on desktop
```

### **🛠️ Demo Management Commands**
```bash
# Browse and select demos
just demo-select                    # Interactive fzf selection
just list-demos                     # List all available demos

# Demo testing
just test-android DEMO_NAME         # Test demo (uses existing test-android!)
just demo-test-cross-platform DEMO_NAME  # Cross-platform validation
just demo-validate-determinism DEMO_NAME # Multiple runs for consistency

# Demo conversion
just demo-to-test DEMO_NAME         # Convert to regression test
just demo-to-test-custom DEMO_NAME lineup  # Custom state capture (lineup, board)
```

### **🌐 Cross-Platform Benefits**
- ✅ **Platform-agnostic demos**: Same demo config works on desktop and Android
- ✅ **Unified log access**: `just logs-last` works on both platforms
- ✅ **Zero-friction recording**: No special "recording mode" - just play normally
- ✅ **Retroactive demos**: "That session I played 10 minutes ago was perfect - make it a demo"
- ✅ **Demo → Test pipeline**: Easy conversion to permanent regression tests
- ✅ **Deterministic validation**: Ensure identical behavior across platforms

### **📁 Demo File Structure**
```json
{
  "type": "demo",
  "description": "Demo from gameplay session: session_123 (5 actions)",
  "session_id": "session_123",
  "actions": [
    "system.debug.hide_menu",
    "game.draft.reroll_player", 
    "game.draft.upgrade_player",
    "system.debug.replay_complete"
  ],
  "metadata": {
    "can_convert_to_test": true,
    "replay_mode": "demo",
    "auto_quit": false
  }
}
```

### **Two-Mode Replay System for Different Use Cases**
**Complete workflow for capturing semantic player actions with intelligent mode selection for automated testing vs manual verification.**

### **🎭 Replay Modes**

#### **🤖 Automated Mode (CI/Testing)**
```bash
# Generate automated replay (includes quit action)
just replay-capture-and-generate my-ci-test            # Complete: capture → generate → auto-quit
just replay-generate SESSION_ID my-automated-test      # Generate from specific session

# Behavior: App quits automatically after replay completion
# Use for: CI/CD pipelines, automated testing, regression tests
```

#### **👁️ Manual Mode (Verification & Screenshots)**
```bash
# Generate manual verification replay (no quit action)
just replay-capture-and-generate-manual my-manual-test # Complete: capture → generate → no quit
just replay-generate-manual SESSION_ID my-manual-test  # Generate from specific session

# Behavior: App stays open with hidden debug interface for clean verification
# Use for: Manual testing, screenshots, user verification, demonstrations
```

### **🔧 Core Workflow Examples**

#### **Manual Verification Workflow (Recommended for Development)**
```bash
# 1. Generate manual verification replay
just replay-capture-and-generate-manual player-battle-demo development-workflow

# 2. Run replay without auto-quit  
just test-android-target player-battle-demo

# 3. Take screenshot of clean game interface
just screenshot

# 4. Manually verify results and close when ready
# App shows clean game interface without debug clutter
```

#### **Automated Testing Workflow (CI/CD)**
```bash
# 1. Generate automated replay
just replay-capture-and-generate ci-regression-test development-workflow

# 2. Run replay with auto-quit
just test-android-target ci-regression-test

# 3. App quits automatically - perfect for automation
```

### **🎯 Key Technical Features**

#### **Smart Debug Interface Management**
- **Complete Interface Hiding**: Uses `EVENT_CLOSE_DEBUG_MENU` to hide entire debug interface
- **Clean Game View**: Shows actual game interface without debug console clutter  
- **Automatic Restoration**: Manual mode keeps interface hidden for clean verification
- **Professional Presentation**: Perfect for screenshots, demonstrations, and user testing

#### **Intelligent Mode Selection**
- **Automated Mode**: Includes `system.debug.quit_application` for CI/automated testing
- **Manual Mode**: Includes `system.debug.replay_complete` for manual verification
- **Semantic Integration**: Both modes log completion events for recording system consistency
- **Metadata Tracking**: Replay configs include mode information for easy identification

#### **Developer Experience**
```bash
# Any manually run test stays open for verification - perfect for development
just test-android-target my-replay-config        # Stays open (manual verification)
just screenshot                                   # Take screenshots of clean interface

# Background automation includes quit for unattended operation  
# (Used internally by CI/CD systems)
```

### **🎯 Key Developer Benefit**
**Manual test runs via `just` commands automatically stay open without quitting**, allowing developers to:
- Take screenshots of clean game interface (no debug UI clutter)
- Manually verify game state and functionality
- Interact with the game after replay completion
- Close the app when ready, not when the system decides

This solves the core problem: **"When I run a test manually, I want to see and verify the results, not have the app quit immediately."**

### **🎯 System Integrity Validation (Critical for Production)**

### **🔧 Integrity Testing Commands**
```bash
# System integrity validation (prevents missing component issues)
just recording-integrity-test                          # Complete system validation with full reporting
just recording-health-check                            # Quick health check (30 sec)
just recording-regression-check                        # Detect missing components like action_recorder.gd

# Component-specific validation
just validate-semantic-mapping                         # Validate semantic action mapping system
just validate-replay-generation                        # Validate config generation workflow

# Pre-commit integration
just recording-pre-commit                              # Pre-commit validation for recording system

# Performance & debugging
just recording-performance-analysis TEST_ID            # Analyze recording system performance
just debug-recording-system TEST_ID                    # Debug recording system issues
just list-recording-integrity-results                  # List recent integrity test results
```

### **Core Recording/Replay Commands**
```bash
# Main Workflows
just replay-capture-and-generate CONFIG_NAME           # Complete: capture → generate → ready for testing
just replay-generate SESSION_ID [CONFIG_NAME]          # Generate from specific semantic session
just replay-list                                       # List available replay configs with metadata
just replay-validate CONFIG_NAME                       # Validate config format and actions
just replay-clean [DAYS]                               # Clean old configs (default: 7 days)

# End-to-end testing
just replay-test-e2e                                  # End-to-end validation of complete workflow
```

### **System Architecture & Components**
- **SemanticActionMapper**: Maps semantic actions (draft.reroll) to debug actions (game.draft.reroll_player)
- **Session Management**: Tracks player sessions and action sequences with unique session IDs
- **Config Generation**: Creates executable test configurations from captured semantic logs
- **Integrity Validation**: Comprehensive testing of all recording/replay components
- **Regression Detection**: Prevents missing component issues from reaching production

### **How the System Works**
1. **Record**: Player actions automatically logged as semantic actions with session tracking
2. **Parse**: System extracts semantic actions from logs using session IDs  
3. **Generate**: Creates replay config mapping semantic actions to debug actions via SemanticActionMapper
4. **Validate**: Runs replay config with automatic checksum validation
5. **Integrity Check**: Validates all components work correctly together and detects regressions

### **Generated Test Structure**
```json
{
  "description": "Generated replay from semantic session: test_session_123",
  "session_id": "test_session_123", 
  "actions": [
    "system.debug.registry_stats",
    "game.lineup.populate_enemy",
    "game.draft.reroll_player",
    "game.draft.upgrade_player",
    "system.debug.quit_application"
  ],
  "test_metadata": {
    "created_by": "semantic_replay_system",
    "source_session": "test_session_123"
  }
}
```

### **Integrity Testing Configurations**
```bash
# Available integrity test configs
just test-android-target replay-system-e2e-test        # End-to-end system validation
just test-android-target semantic-logging-complete-test # Semantic logging validation
just test-android-target developer-workflow-validation  # Common dev scenarios validation
```

### **Integration with Test System**
```bash
# Replay configs work with all test commands
just test-android my-replay                            # Standard test execution
just test-android-enhanced my-replay                   # Enhanced error analysis
just config-restart-android my-replay                  # Quick 5-second iteration

# Checksum validation for regression testing
just test-android-target my-replay                     # Auto-creates baseline on first run
just test-android-update my-replay                     # Update baseline for legitimate changes
```

### **Token-Efficient Debugging with Integrity Context**
```bash
# Recording/replay system specific debugging (90-98% token savings)
just logs-errors-tagged TEST_ID recording replay       # Recording/replay specific errors
just logs TEST_ID integrity                            # System integrity validation logs
just logs-performance-tagged TEST_ID recording         # Recording system performance data

# Component-specific debugging
just logs TEST_ID semantic                             # Semantic action logging
just logs TEST_ID replay generation                    # Config generation process
```

### **Regression Protection Features**
The integrity testing system prevents issues like missing components from reaching production by:
- **Component Validation**: Checks all critical recording system files exist
- **Integration Testing**: Validates SemanticActionMapper and workflow components work together
- **Workflow Testing**: Tests complete record → generate → replay cycle  
- **Regression Detection**: Identifies broken integrations and missing dependencies

### **Best Practices for Development**
- **Integrity First**: Run `just recording-health-check` when troubleshooting recording/replay issues
- **Regular Validation**: Include `just recording-regression-check` in development workflow
- **Component Testing**: Use integrity tests to validate changes to recording system components
- **Performance Monitoring**: Track recording system performance with dedicated analysis commands
- **Pre-commit Safety**: Use `just recording-pre-commit` to catch issues before they reach main branch

### **Complete Development Workflow**
```bash
# 1. Validate system health before starting
just recording-health-check                            # Quick system validation

# 2. Create replay test from gameplay session
just replay-capture-and-generate player-battle-scenario development-workflow
# → Captures semantic actions, generates player-battle-scenario.json

# 3. Test the generated replay with integrity validation
just test-android-target player-battle-scenario        # Test replay config
just recording-integrity-test                          # Validate system after any changes

# 4. Add to regression test suite
just test-android-update player-battle-scenario        # Config now validates consistency

# 5. Use in development workflow
just config-restart-android player-battle-scenario    # Quick iteration (5 seconds)
just test-android player-battle-scenario               # Full validation with analysis

# 6. Debug if issues arise (comprehensive tools)
just logs-errors-tagged TEST_ID recording replay       # Quick error scan
just debug-recording-system TEST_ID                    # Comprehensive debugging
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

### **Smart Rebuild System - Optimized for Maximum Efficiency**
**Intelligent build system that automatically detects changes and rebuilds only what's necessary:**

```bash
# Smart rebuild commands (auto-detects changes)
just fastbuild-android            # Smart Android rebuild (15-60 sec depending on changes)
just fastbuild-ios                # Smart iOS rebuild (15-60 sec depending on changes)
just fastbuild-all                # Smart rebuild for both platforms

# Build optimization modes
just fastbuild-android-force      # Force full rebuild (ignores change detection)
just fastbuild-ios-force          # Force full iOS rebuild (ignores change detection)
just fastbuild-check              # Check what would be rebuilt (dry run)
```

### **Build Performance Optimization**
**The smart rebuild system optimizes build times by:**
- **Change Detection**: Only rebuilds modified components (GDScript, assets, configs)
- **Incremental Builds**: Preserves build artifacts when possible
- **Platform Caching**: Maintains separate build caches for Android and iOS
- **Dependency Analysis**: Rebuilds only affected modules and dependencies

### **Build Time Expectations**
```bash
# Typical build times with smart rebuilds
just fastbuild-android            # 15-20 sec (code changes only)
                                  # 30-45 sec (assets + code changes)
                                  # 60 sec (full rebuild needed)

just fastbuild-ios                # 15-20 sec (code changes only)
                                  # 30-45 sec (assets + code changes)
                                  # 60 sec (full rebuild needed)
```

### **Legacy Build Commands (Full Rebuilds)**
```bash
# Full platform builds (when smart rebuild isn't sufficient)
just build-all-android            # Full Android build (20 min)
just build-all-ios                # Full iOS build (20 min)
just build-all                    # Full rebuild for both platforms

# Custom engine builds (when modifying Godot source)
just godot-build-editor           # Build custom Godot editor
just godot-build-templates        # Build export templates
```

### **Build Debugging & Analysis**
```bash
# Build system debugging
just build-status                 # Check build system health
just build-clean                  # Clean build artifacts (forces full rebuild)
just build-analyze                # Analyze build performance and bottlenecks
just build-logs                   # View recent build logs and errors
```

### **Development Workflow Integration**
```bash
# Integrated development workflow
just validate                     # Syntax check (3 sec)
just fastbuild-android            # Smart rebuild & deploy (15-60 sec)
just test-android development-workflow # Test on device

# Pre-commit workflow with smart builds
just pre-commit                   # Format + validate + smart rebuild + test
just fastbuild-check              # Preview what will be rebuilt
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