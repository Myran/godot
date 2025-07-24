# CLAUDE.md

GameTwo is a sophisticated mobile game built with a custom Godot 4.3 engine featuring Firebase integration, advanced data management, and comprehensive debugging systems.

## 🚨 CRITICAL COMMANDS (Emergency Reference)

```bash
# Emergency Debugging (Use First)
just logs-errors TEST_ID                   # Find errors fast (98% token savings)
just logs-last                             # Latest test results (99% token savings)

# Enhanced Testing with Automatic Validation (NEW)
just test-android-target CONFIG            # Automated testing with built-in error analysis & checksum validation
just test-desktop-target CONFIG            # Desktop automated testing with comprehensive validation

# Daily Workflow (Primary Commands)
just validate                              # Complete validation (format + syntax + runtime)
just fastbuild-android                     # Smart rebuild & deploy (15-60 sec)
just test-android development-workflow     # Daily development validation
just config-restart-android ACTION         # Ultra-fast testing (5 sec)

# Debug Decision Tree: logs-errors → logs-android/logs-desktop → logs-tags
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

**Progressive debugging sequence (token-efficient):**
1. `just logs-errors TEST_ID` (5 sec, <10 tokens)
2. `just logs TEST_ID [component]` (15 sec, <100 tokens) 
3. `just logs TEST_ID [component] [operation]` (<200 tokens)

### **Failure Pattern Quick Reference**
| Symptom | Debug Command | Fix Command |
|---------|---------------|-------------|
| Firebase timeout/auth | `logs-android-errors TEST_ID firebase` | `test-android 'system.network.*'` |
| Hash mismatch/validation | `logs TEST_ID battle determinism` | `test-android 'game.match.reset_level'` |
| Performance/timeouts | `logs-performance-tagged TEST_ID` | `test-android '*.*.performance'` |
| Startup/registry errors | `logs TEST_ID system startup` | `test-android 'system.debug.*'` |
| Checksum mismatch | `logs-android-errors TEST_ID checksum` | `test-android-update CONFIG` or investigate |

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
```bash
# Primary (Use First)
just logs-errors TEST_ID                   # Error-focused (98% savings)
just logs-last                             # Latest run (99% savings)
just logs TEST_ID [component]              # Component analysis (87-95% savings)

# Performance & Specialized  
just logs-performance-tagged TEST_ID [tags] # Performance data
just logs-desktop-errors                   # Desktop errors only
just logs-lifecycle-tagged TEST_ID [tags]  # App lifecycle events

# Full logs (avoid unless necessary)
just logs TEST_ID                          # Complete logs (high token cost)
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

# Standard workflows
just test-android development-workflow     # Daily development
just test-android pre-commit               # Pre-commit validation
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

### **⭐ NEW: Streamlined Configuration Management**
After cleanup of 122 legacy debug configs, only 16 semantic action configs remain for core testing.

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

**Performance analysis:**
```bash
just logs-performance-tagged TEST_ID [component] # Performance analysis
```

**For detailed help on any topic:**
```bash
just help                         # Main help with clickable commands
just help-debug                   # Debug & testing workflows  
just help-logs                    # Log analysis & token efficiency
just help-build                   # Build system architecture
## 🗂️ Project Architecture

**⭐ NEW: Enhanced Testing System:**
- **Unified Test Execution**: Cross-platform test wrapper with automatic validation
- **Built-in Error Analysis**: Automatic log parsing and failure detection (98% token savings)
- **Automatic Checksum Management**: Baseline creation and validation
- **Progressive Debugging**: Token-efficient error analysis workflow

**Core Systems:**
- **DataSource Pattern**: Unified Firebase RTDB + local storage backends
- **Debug Framework**: 55 debug actions across 7 categories  
- **Custom Engine**: Modified Godot 4.3 with Firebase/Facebook integration

**Key Directories:**
- `project/debug/actions/` - Debug actions by layer (cpp, backend, rtdb, system, game)
- `project/debug_configs/` - ⭐ **Streamlined: 16 semantic action configs** (down from 138)
- `project/test-lists/` - Workflow configurations
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