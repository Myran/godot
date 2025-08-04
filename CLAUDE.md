# CLAUDE.md

GameTwo is a sophisticated mobile game built with a custom Godot 4.3 engine featuring Firebase integration, advanced data management, and comprehensive debugging systems.

## 🚨 CRITICAL COMMANDS (Emergency Reference)

```bash
# Emergency Debugging (Use First) 
just logs-errors TEST_ID                   # Find errors fast (98% token savings)
just logs-last                             # Latest test results (99% token savings)

# 🚀 NEW: Wildcard Pattern Debugging (10x Faster)
just logs-tree TEST_ID                     # Explore log structure (2 sec)
just logs-pattern TEST_ID "*.error"        # All errors with precision
just logs-pattern TEST_ID "firebase.*"     # All Firebase operations
just help-wildcards                        # Complete pattern guide

# Enhanced Testing with Automatic Validation (NEW)
just test-android-target CONFIG            # Automated testing with built-in error analysis & checksum validation
just test-desktop-target CONFIG            # Desktop automated testing with comprehensive validation

# Daily Workflow (Primary Commands)
just validate                              # Complete validation (format + syntax + runtime)
just fastbuild-android                     # Smart rebuild & deploy (15-60 sec)
just test-android development-workflow     # Daily development validation
just config-restart-android ACTION         # Ultra-fast testing (5 sec)

# Debug Decision Tree: logs-tree → logs-pattern → logs-exclude → logs-errors (traditional backup)
```

## 🎯 Command System Overview

**Three-tier command structure: `test` (analysis) → `config` (iteration) → `logs` (debugging)**

### **Primary Commands (Daily Use)**
- `just validate` - Complete validation pipeline
- `just test-android TARGET` - Main testing interface (auto-detects patterns/configs)
- `just test-android-target CONFIG` - ⭐ **NEW: Enhanced automated testing with built-in validation**
- `just test-desktop-target CONFIG` - ⭐ **NEW: Desktop automated testing with comprehensive validation**
- `just config-restart-android ACTION` - 5-second iteration cycles
- `just logs-errors TEST_ID` - Token-efficient error detection

### **Secondary Commands (Weekly Use)**  
- `just test-android-target CONFIG` - Automated testing (quits after completion)
- `just replay-generate-desktop SESSION_ID NAME` - Create tests from gameplay
- `just fastbuild-android` - Smart rebuild system

### **Advanced Commands (As Needed)**
- `just build` - Complete source-to-device pipeline (46 min)

## 🔧 Debugging Workflow

**🚀 NEW: Wildcard Pattern Debugging (10x Faster & More Precise)**
1. `just logs-tree TEST_ID` (2 sec, explore structure)
2. `just logs-discover TEST_ID firebase` (3 sec, find domain tags)
3. `just logs-pattern TEST_ID "firebase.*"` (5 sec, precise filtering)
4. `just logs-exclude TEST_ID "firebase.*" "firebase.debug"` (refine results)

**Traditional Progressive debugging sequence (still available):**
1. `just logs-errors TEST_ID` (5 sec, <10 tokens)
2. `just logs-android TEST_ID [component]` or `just logs-desktop TEST_ID [component]` (15 sec, <100 tokens) 
3. `just logs-android TEST_ID [component] [operation]` or `just logs-desktop TEST_ID [component] [operation]` (<200 tokens)

### **🎯 Enhanced Failure Pattern Quick Reference (Wildcard + Traditional)**
| Symptom | Wildcard Debug Command (NEW) | Traditional Debug Command | Fix Command |
|---------|------------------------------|---------------------------|-------------|
| Firebase timeout/auth | `logs-pattern TEST_ID "firebase.*"` | `logs-android-errors TEST_ID firebase` | `test-android 'system.network.*'` |
| All error types | `logs-pattern TEST_ID "*.error"` | `logs-errors TEST_ID` | Investigate specific errors |
| Hash mismatch/validation | `logs-pattern TEST_ID "*.checksum"` | `logs-android TEST_ID battle determinism` | `test-android 'game.match.reset_level'` |
| Performance/timeouts | `logs-pattern TEST_ID "performance.*"` | `logs-performance TEST_ID` | `test-android '*.*.performance'` |
| Game system issues | `logs-pattern TEST_ID "game.*"` | `logs-android TEST_ID game` | `test-android 'game.*'` |
| Startup/registry errors | `logs-pattern TEST_ID "system.initialization"` | `logs-android TEST_ID system startup` | `test-android 'system.debug.*'` |
| Database issues | `logs-pattern TEST_ID "database.*"` | `logs-android TEST_ID database` | `test-android 'database.*'` |
| Network problems | `logs-multi TEST_ID "*.timeout" "*.error" "network.*"` | `logs-android TEST_ID network` | `test-android 'network.*'` |
| Checksum mismatch | `logs-pattern TEST_ID "*.checksum"` | `logs-android-errors TEST_ID checksum` | `test-android-update CONFIG` or investigate |

## 📋 Log Commands (Two Distinct Types)

### **📱 Real-Time Android Device Logs (Live adb logcat, Token-Efficient)**
```bash
just android-logs-errors 30               # Live device error monitoring (filtered)
just android-logs-status                  # Device & app status check  
just android-logs-tagged "firebase" 30 50 # Live tag-filtered monitoring (30s, max 50 lines)
just android-logs-performance 60 30       # Live performance monitoring (60s, max 30 lines)
just android-logs-live 60 "*:I" 100       # Live monitoring (60s, INFO level, max 100 lines)
```

**💡 All Android device log commands include smart filtering:**
- **Filter out noise**: OpenGL, font loading, VSYNC, touch events
- **Focus on relevance**: Firebase, debug, errors, tests, performance data
- **Configurable limits**: Default 20-50 lines, but adjustable as last parameter

### **📄 Saved Test Result Analysis (Token-Efficient)**

**🚀 NEW: Wildcard Pattern System (10x Productivity Boost)**
```bash
# Pattern Discovery & Structure Exploration  
just logs-tree TEST_ID                     # Show hierarchical tag structure (most efficient start)
just logs-discover TEST_ID PREFIX          # Find all tags with prefix (e.g., firebase)
just logs-suggest TEST_ID PARTIAL          # Auto-complete suggestions

# Advanced Pattern Matching (Ultra-Precise)
just logs-pattern TEST_ID PATTERN          # Single pattern: firebase.*, *.error, game.*.start
just logs-multi TEST_ID PATTERN1 PATTERN2  # Multiple patterns (OR logic)
just logs-exclude TEST_ID PATTERN EXCLUDE  # Include/exclude: firebase.* but not firebase.debug

# Pattern Examples (Copy-Paste Ready)
just logs-pattern TEST_ID "firebase.*"     # All Firebase operations
just logs-pattern TEST_ID "*.error"        # All error operations  
just logs-pattern TEST_ID "game.*.start"   # All start events
just logs-pattern TEST_ID "database.query" # Exact match
just logs-exclude TEST_ID "firebase.*" "firebase.debug" # Firebase without debug noise

# Pattern Help
just help-wildcards                        # Complete pattern system guide
just help-wildcard-quick                   # Quick reference
```

**Traditional Commands (Still Available)**
```bash
# Primary (Use First)
just logs-errors TEST_ID                   # Error-focused (98% savings)
just logs-last                             # Latest run (99% savings)
just logs-android TEST_ID [component] or just logs-desktop TEST_ID [component]  # Component analysis (87-95% savings)

# Performance & Specialized  
just logs-performance TEST_ID              # Performance data
just logs-desktop-errors TEST_ID           # Desktop errors only
just logs-lifecycle TEST_ID                # App lifecycle events

# Full logs (avoid unless necessary)
just logs-android TEST_ID or just logs-desktop TEST_ID  # Complete logs (high token cost)
```

## ⚡ Core Commands Reference

### **Testing Commands**
```bash
just test-android TARGET                   # Main interface (auto-detects patterns/configs/lists)
just test-android-target CONFIG            # ⭐ Enhanced automated mode with built-in validation
just test-desktop-target CONFIG            # ⭐ Enhanced desktop automated testing
just test-android-enhanced TARGET          # Enhanced error analysis

# Manual testing (stays open for inspection)
just test-android-manual CONFIG            # Android manual mode (app stays open)
just test-desktop-manual CONFIG            # Desktop manual mode (app stays open)

# Standard workflows
just test-android development-workflow     # Daily development
just test-android pre-commit               # Pre-commit validation

# ⭐ NEW: Enhanced Timeout Support
just test-android TARGET DURATION          # Custom timeout (e.g., just test-android config 300)
just test-android-target CONFIG DURATION   # Custom timeout for automated tests
just test-desktop-target CONFIG DURATION   # Custom timeout for desktop tests

# Environment Variables for Timeout Control
# ANDROID_TEST_MAX_TIMEOUT=300              # Max timeout (default: 120s)
# ANDROID_TEST_ACTIVITY_TIMEOUT=90          # Activity timeout (default: 60s)
# DESKTOP_TEST_MAX_TIMEOUT=180              # Desktop max timeout (default: 120s)
```

### **Config Commands (5-second iterations)**
```bash
just config-restart-android ACTION         # Deploy + restart (5 sec)
just config-push-android CONFIG            # Deploy config only (2 sec)
just config-list                           # List available configs
just config-android-tags "active" "ignored" # Runtime log filtering
```

### **Wildcard Patterns (Hierarchical: layer.domain.operation)**

```bash
# Layer wildcards
just test-android 'cpp.*'                 # C++ Firebase SDK
just test-android 'backend.*'             # Backend Firebase  
just test-android 'rtdb.*'                # RTDB API
just test-android 'system.*'              # System utilities
just test-android 'game.*'                # Game logic

# Domain wildcards (cross-layer)
just test-android '*.firebase.*'          # All Firebase operations
just test-android '*.debug.*'             # All debug utilities

# Operation wildcards (cross-layer + domain)
just test-android '*.*.error_handling'    # All error handling
just test-android '*.*.performance'       # All performance tests
```

### **Input Auto-Detection**
Commands automatically detect input type:
- **Actions**: `'system.debug.registry_stats'` → Direct execution
- **Wildcards**: `'cpp.*'` → Auto-discovery
- **Configs**: `system-testing` → Load configuration  
- **Test Lists**: `development-workflow` → Execute suite

## 🚨 CRITICAL: Debug Action Execution

**ALWAYS use `test-*` commands for debug actions:**
- ✅ `just test-desktop CONFIG` - Enables debug coordinator
- ❌ `just run-desktop` - Skips debug coordinator (editor mode)

**Impact**: State capture, checksum validation, semantic logging require debug actions.

## 📱 Android Configuration

### **⭐ FIXED: Android Checksum Validation**
Resolved critical environment variable propagation issue that was causing Android checksum validation to silently fail. Tests now properly validate all checksums on both Android and desktop platforms.

**⭐ NEW: Streamlined Configuration Management**
After comprehensive cleanup, only 9 core debug configs remain (46 archived) organized by layer:

**Core Debug Configs (9 active):**
- `battle-animated` - Battle system with full animations
- `battle-logic-only` - Battle logic without visual effects  
- `firebase-backend-layer` - Backend Firebase operations
- `firebase-cpp-layer` - C++ Firebase SDK layer
- `firebase-network-connectivity` - Network connectivity testing
- `firebase-rtdb-layer` - Real-time Database layer
- `system-error-handling` - Error handling validation
- `system-layer-all` - Complete system utilities (system.*)
- `system-performance` - Performance monitoring

**Test Lists (13 active workflows):**
- `production-ready` - Release readiness validation
- `pre-commit` - Essential pre-commit checks
- `firebase-all` - Complete Firebase testing
- `battle-all` - Battle system comprehensive testing
- `system-all` - System layer validation
- `comprehensive-with-determinism` - Full deterministic testing
- `recording-system-integrity` - Replay system validation
- `wildcard-discovery` - Pattern discovery workflow

### **Logger Control (Runtime)**
```bash
just config-android-tags "firebase,battle" "cache,animation" # Focus/filter components
just config-android-level DEBUG                             # Set log verbosity  
just config-android-reset                                   # Reset to defaults
just restart-android-app                                    # Apply changes
```

### **Real-Time Android Device Log Monitoring (Token-Efficient)**
```bash
# Live device monitoring (actual adb logcat, smart filtered)
just android-logs-errors 30             # Live error monitoring (filtered, 30s)
just android-logs-live 60 "*:I" 100     # Live log monitoring (60s, INFO level, max 100 lines)
just android-logs-status                # Device & app status check
just android-logs-recent 50             # Recent device logs (filtered, max 50 lines)

# Tag-based filtering (noise filtered, configurable limits)
just android-logs-tagged "firebase" 30 50  # Custom tag monitoring (30s, max 50 lines)
just android-logs-performance 60 30     # Performance monitoring (60s, max 30 lines)
just android-logs-monitor-restart 120 20 # App restart monitoring (120s, max 20 lines)

# Device management
just android-logs-clear                 # Clear device log buffer
```

**🎯 Smart Filtering + Configurable Limits:**
- **Filters out**: OpenGL, fonts, VSYNC, touch events, buffer dumps
- **Focuses on**: Firebase, debug, errors, tests, performance, startup events
- **Flexible limits**: Default sensible limits, adjustable as final parameter

### **Screenshots (AI Analysis)**
```bash
just screenshot-android                  # Quick screenshot (/tmp/screenshot.png)
just screenshot-android error-state      # Named screenshot (/tmp/error-state.png)
```

## 🚫 FORBIDDEN PATTERNS (GDScript Anti-Patterns)

**NEVER use timing-based waits or delays - they create race conditions and non-deterministic behavior:**

```gdscript
# ❌ FORBIDDEN - Never use these patterns
await Engine.get_main_loop().process_frame
await Engine.get_main_loop().create_timer(0.3).timeout
await get_tree().create_timer(1.0).timeout
await get_tree().process_frame

# ❌ These cause:
# - Non-deterministic test results
# - Race conditions between actions  
# - Checksum validation failures
# - Unreliable async synchronization
```

**✅ Use proper async completion instead:**
```gdscript
# ✅ Wait for actual completion signals
await some_operation_completed
await async_function_call()
# ✅ Use proper state-based synchronization
```

## 💪 Strong Typing Requirements

**CRITICAL: Always use fail-fast typing to catch errors at compile time**

```gdscript
# ✅ Required patterns
var firebase_backend: FirebaseBackend = get_backend()
var cards: Array[Card] = []
func create_card(id: String, level: int = 1) -> Card:
    return card_scene.instantiate() as Card

# ❌ Never use these  
if backend is FirebaseBackend:           # Runtime checking
var data = {}                            # No type
```

**Validation commands:**
```bash
just validate                             # Complete pipeline (format + syntax + runtime)
just validate-gdscript                  # Fast syntax check (3 sec)
```

## 🎬 Replay Testing (Automated from Gameplay)

### **Simple Workflow: Play → Generate → Test**
```bash
# 1. Play normally (automatic session tracking)
just run-desktop                    # Shows session ID when finished

# 2. Create test with one command
just replay-generate-desktop SESSION_ID my-test

# 3. Test with validation
just test-android-target my-test    # Automated mode (quits after validation)
just test-android my-test          # Manual mode (stays open for inspection)
```

## 🧪 Checksum Testing (State Validation)

**⭐ NEW: Automatic baseline management in enhanced testing:**
```bash
# Enhanced testing commands now include automatic checksum validation
just test-android-target lineup-checksum-test    # Auto-creates baseline on first run + validates
just test-desktop-target semantic-action-simple-test  # Cross-platform checksum validation
just test-android-update CONFIG                 # Update baseline (legitimate changes)
just test-desktop-update CONFIG                 # Update baseline (legitimate changes)
just logs-android-errors TEST_ID checksum       # Debug checksum failures
```

**Key improvements:**
- Automatic baseline creation and validation
- Cross-platform checksum extraction (Android + Desktop)
- Built-in error analysis with checksum validation
- Progressive failure detection and reporting

**🎲 RNG Determinism**: The RNG system autonomously initializes seeds from debug configs during autoload phase, ensuring cross-platform deterministic behavior without explicit seed actions.

### **Adding Seeds to Debug Configs**
When creating deterministic tests, add seeds using the `checksum_config` structure:
```json
{
  "description": "Test description",
  "actions": ["action1", "action2"],
  "checksum_config": {
    "initial_seed": 12345,
    "state_type": "seed_validation",
    "expected_checksums": []
  }
}
```
**Never use:** `"game.battle.set_seed"` action (obsolete - causes timing issues)  
**Always use:** `checksum_config.initial_seed` field (autonomous - no timing dependencies)

## 🏗️ Build System

**Smart three-tier build system:**
```bash
just build                        # Complete pipeline: source to device (46 min)
just fastbuild-android            # Smart rebuild (15-60 sec depending on changes)
just build-status                 # Check what would be rebuilt
```

## 🔧 Advanced Features

**Desktop debugging with ObjectDB leak detection:**
```bash
just run-desktop-debug                      # Normal debug mode
just run-desktop-debug verbose             # Verbose mode (shows ObjectDB leak details)
```

**Performance analysis:**
```bash
just logs-performance TEST_ID               # Performance analysis
```

**For detailed help on any topic:**
```bash
just help                         # Main help with clickable commands
just help-debug                   # Debug & testing workflows  
just help-logs                    # Log analysis & token efficiency
just help-build                   # Build system architecture
## 🚀 Wildcard Pattern System Deep Dive

**Transform your debugging with hierarchical pattern matching - providing 10x productivity improvement over traditional log analysis.**

### **🎯 Pattern Types & Examples**

**1. Prefix Patterns (`domain.*`)**
```bash
just logs-pattern TEST_ID "firebase.*"     # All Firebase operations
just logs-pattern TEST_ID "database.*"     # All database operations  
just logs-pattern TEST_ID "performance.*"  # All performance monitoring
```

**2. Suffix Patterns (`*.operation`)**
```bash
just logs-pattern TEST_ID "*.error"        # All error operations
just logs-pattern TEST_ID "*.timeout"      # All timeout events
just logs-pattern TEST_ID "*.start"        # All start operations
```

**3. Middle Wildcards (`layer.*.operation`)**
```bash
just logs-pattern TEST_ID "game.*.start"   # All game start events
just logs-pattern TEST_ID "system.*.init"  # All system initialization
just logs-pattern TEST_ID "firebase.*.error" # All Firebase errors
```

**4. Exact Matches (`specific.tag`)**
```bash
just logs-pattern TEST_ID "firebase.auth"      # Firebase authentication only
just logs-pattern TEST_ID "database.query"     # Database queries only
just logs-pattern TEST_ID "game.battle.end"    # Battle end events only
```

### **🔍 Discovery Workflow Examples**

**Scenario: Investigating Firebase Issues**
```bash
# 1. Explore what Firebase tags exist
just logs-tree TEST_ID                          # See full hierarchy

# 2. Discover Firebase-specific tags  
just logs-discover TEST_ID firebase             # Find all firebase.* tags

# 3. Get broad Firebase overview
just logs-pattern TEST_ID "firebase.*"          # All Firebase operations

# 4. Focus on Firebase errors only
just logs-pattern TEST_ID "firebase.*.error"    # Firebase errors across all modules

# 5. Exclude noisy debug logs
just logs-exclude TEST_ID "firebase.*" "firebase.debug"  # Firebase without debug noise
```

**Scenario: Game System Debugging**
```bash
# 1. See all game-related activity
just logs-pattern TEST_ID "game.*"              # All game operations

# 2. Focus on battle system
just logs-pattern TEST_ID "game.battle.*"       # Battle system only

# 3. Find all start/end events across game systems
just logs-multi TEST_ID "game.*.start" "game.*.end"  # All game lifecycle events

# 4. Investigate specific battle phases
just logs-pattern TEST_ID "game.battle.phase"   # Battle phase transitions
```

**Scenario: Performance Analysis**
```bash
# 1. All performance data
just logs-pattern TEST_ID "performance.*"       # All performance monitoring

# 2. Memory-specific issues
just logs-pattern TEST_ID "*.memory"            # Memory-related logs across all systems

# 3. Multi-system performance view
just logs-multi TEST_ID "performance.*" "*.timeout" "*.slow"  # Performance + issues

# 4. Exclude low-priority performance logs
just logs-exclude TEST_ID "performance.*" "performance.debug"  # Performance without debug
```

### **⚡ Productivity Comparison**

| Task | Traditional Method | Wildcard Pattern Method | Time Savings |
|------|-------------------|-------------------------|--------------|
| Find Firebase errors | `logs-android TEST_ID firebase` → manual scan | `logs-pattern TEST_ID "firebase.*.error"` | **90% faster** |
| All error types | Multiple `logs-android/logs-desktop` commands | `logs-pattern TEST_ID "*.error"` | **95% faster** |
| System exploration | Manual browsing | `logs-tree TEST_ID` | **98% faster** |
| Cross-system patterns | Multiple separate commands | `logs-multi TEST_ID pattern1 pattern2` | **85% faster** |
| Noise filtering | Manual filtering | `logs-exclude TEST_ID include exclude` | **90% faster** |

### **💡 Advanced Tips**

**Pattern Testing Before Use:**
```bash
# Test your pattern against sample tags first
just logs-test-pattern "firebase.*" firebase.auth firebase.connect database.error
# ✅ firebase.auth  ✅ firebase.connect  ❌ database.error
```

**Performance Optimization:**
```bash
# Benchmark pattern performance
just logs-benchmark TEST_ID "firebase.*"
# See timing and optimization suggestions
```

**Auto-completion:**
```bash
# Get suggestions for partial matches
just logs-suggest TEST_ID fire
# Suggests: firebase.auth, firebase.connect, firebase.timeout...
```

**Pattern Caching:**
- Patterns are automatically cached for faster repeated use
- Complex patterns are compiled once and reused
- Cache is persistent across sessions

## 🗂️ Project Architecture

**⭐ FIXED: Enhanced Testing System:**
- **Unified Test Execution**: Cross-platform test wrapper with automatic validation ✅ **WORKING**
- **Built-in Error Analysis**: Automatic log parsing and failure detection (98% token savings) ✅ **WORKING**
- **Automatic Checksum Management**: Baseline creation and validation ✅ **FIXED - Android validation working**
- **Progressive Debugging**: Token-efficient error analysis workflow ✅ **WORKING**
- **Manual Test Modes**: Both Android and desktop support manual inspection modes

**Core Systems:**
- **DataSource Pattern**: Unified Firebase RTDB + local storage backends
- **Debug Framework**: 55 debug actions across 7 categories  
- **Custom Engine**: Modified Godot 4.3 with Firebase/Facebook integration

**Key Directories:**
- `project/debug/actions/` - Debug actions by layer (cpp, backend, rtdb, system, game)
- `project/debug_configs/` - ⭐ **Streamlined: 9 core configs** (46 archived, organized by layer)
- `project/test-lists/` - 13 active workflow configurations
- `project/debug_configs/archive/` - Archived configs (duplicates, experimental, generated-replays)
- `justfiles/justfile-validation-enhanced-testing.justfile` - ⭐ **NEW: Enhanced testing system**

## 📖 Integration with Just Help System

**CLAUDE.md focuses on AI-optimized quick reference. For comprehensive details, use:**

```bash
just help                         # Interactive command browser with clickable links
just help-debug                   # Complete debug & testing workflows
just help-logs                    # Full log analysis guide with examples  
just help-build                   # Build system architecture & timing
just help-workflows               # Detailed workflow patterns & best practices
```

## 🤖 Project Context for Claude Code

**For complex development tasks requiring deep codebase understanding:**

```bash
just generate-claude-context      # Generate optimized project context (250k tokens)
# Creates: claude-project-context.xml
```

**Generated context includes:**
- **CLAUDE.md** - This instruction file
- **Core GDScript files** - Main game logic and systems
- **Debug configurations** - Test configs and workflows
- **Firebase integration** - C++/Objective-C++ backend code
- **Build configurations** - Platform export settings

**Usage with Claude Code:**
1. **CLAUDE.md** - Daily reference (this file)
2. **`just help-[topic]`** - Detailed human-readable workflows  
3. **`claude-project-context.xml`** - Full codebase context for complex analysis

**Context file benefits:**
- **Token-optimized** (250k vs 1M+ tokens) with compression and comment removal
- **Security-checked** - No credentials or sensitive data included
- **Filtered content** - Excludes test files, logs, and build artifacts
- **Structured format** - XML with clear file boundaries for AI parsing

This three-tier approach maximizes both AI efficiency and human usability.