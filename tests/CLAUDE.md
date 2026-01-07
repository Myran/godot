# GameTwo Testing Infrastructure

**187 test configurations** - Comprehensive testing system for GameTwo mobile game.

This directory contains test configurations, debug configs, test lists, and gamestate snapshots for automated and manual testing.

---

## 📁 Directory Structure

```
tests/
├── configs/                   # (Legacy) Test configurations
├── debug_configs/             # Debug configurations (187 .json files)
│   └── archive/              # Archived/historical configs
├── sentry/                    # Sentry integration tests
├── test_lists/                # Test list definitions (multi-config orchestration)
├── test-lists/                # (Legacy) Test lists
│   ├── archive/              # Archived test lists
│   └── examples/             # Example test lists
└── test-states/               # Saved gamestate snapshots
```

---

## 🔧 Debug Configuration Format

### **Basic Config Structure**
```json
{
  "description": "Firebase authentication flow",
  "actions": [
    "backend.firebase.auth.sign_in",
    "backend.firebase.auth.check_status"
  ],
  "platforms": ["android", "ios"]
}
```

### **Config with Checksum Validation**
```json
{
  "description": "Battle determinism validation",
  "actions": [
    "game.battle.start",
    "game.battle.play_turn",
    "game.battle.end"
  ],
  "platforms": ["android", "editor"],
  "checksum_config": {
    "initial_seed": 12345,
    "state_type": "seed_validation"
  }
}
```

### **Config Fields**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `description` | string | ✅ | Human-readable config purpose |
| `actions` | array | ✅ | Debug actions to execute (in order) |
| `platforms` | array | ✅ | Supported platforms: `android`, `ios`, `editor`, `macos` |
| `checksum_config` | object | ❌ | Checksum validation settings |
| `checksum_config.initial_seed` | int | ❌ | RNG seed for determinism |
| `checksum_config.state_type` | string | ❌ | `seed_validation` or `gamestate_replay` |
| `metadata` | object | ❌ | Custom metadata for test context |
| `timeout` | int | ❌ | Test timeout in seconds (default: 300) |
| `retry_count` | int | ❌ | Number of retry attempts on failure (default: 0) |
| `tags` | array | ❌ | Tags for filtering/organization |

---

## 📋 Test List Format

### **Basic Test List**
```json
{
  "name": "Firebase Integration Tests",
  "description": "Complete Firebase operations testing",
  "configs": [
    "backend.firebase.auth.sign_in",
    "backend.firebase.database.read",
    "backend.firebase.database.write"
  ]
}
```

### **Test List with Commands**
```json
{
  "name": "Gamestate Validation with Commands",
  "description": "Config testing + command validation",
  "configs": ["gamestate-save-load-test"],
  "commands": [
    {
      "command": "test-save-load-cycle-editor",
      "platforms": ["editor"],
      "description": "Editor save/load consistency"
    },
    {
      "command": "test-save-load-cycle-android",
      "platforms": ["android"],
      "description": "Android save/load consistency"
    }
  ]
}
```

### **Test List Fields**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | ✅ | Test list name |
| `description` | string | ✅ | Purpose and scope |
| `configs` | array | ✅ | Config names to execute (in order) |
| `commands` | array | ❌ | Additional just commands to run |
| `commands[].command` | string | ✅ | Just command name |
| `commands[].platforms` | array | ✅ | Platform filter for command |
| `commands[].description` | string | ✅ | Command purpose |

**Platform Filtering**: Commands only execute on matching platforms during testing.

---

## 🎬 Replay Testing System

### **Workflow: Play → Generate → Test**

#### **Step 1: Play & Record**
```bash
just run-editor
# Play the game
# Session ID shown in logs: SESSION_12345
```

#### **Step 2: Generate Replay Config**
```bash
just replay-generate-editor SESSION_12345 my-battle-scenario
# Creates: tests/debug_configs/my-battle-scenario.json
```

#### **Step 3: Test Replay**
```bash
just test-android-target my-battle-scenario  # Automated with validation
just test-editor-target my-battle-scenario  # Cross-platform testing
```

### **Replay Config Structure**
```json
{
  "description": "Generated from session SESSION_12345",
  "actions": [
    "game.battle.load_replay",
    "game.battle.execute_replay"
  ],
  "platforms": ["android", "editor"],
  "replay_data": {
    "session_id": "SESSION_12345",
    "actions": [...],  # Recorded player actions
    "seed": 67890
  },
  "checksum_config": {
    "initial_seed": 67890,
    "state_type": "gamestate_replay"
  }
}
```

**Benefits:**
- **Bug reproduction** - Capture exact scenario that caused issue
- **Regression testing** - Ensure bug fix doesn't break later
- **Cross-platform validation** - Same replay on Android/editor/iOS

---

## 🧪 Checksum Testing System

### **Purpose**
Validates **deterministic execution** across:
- Multiple runs on same platform
- Different platforms (Android, iOS, editor)
- Different build configurations

### **Automatic Validation Workflow**

```bash
# First run: Creates baseline
just test-android-target battle-logic-test
# Output: Created baseline checksum for battle-logic-test

# Subsequent runs: Validates against baseline
just test-android-target battle-logic-test
# ✅ Output: Checksum validation passed
# ❌ Output: Checksum mismatch detected (shows diff)
```

### **Update Baseline**
```bash
# When game logic changes intentionally:
just test-android-update battle-logic-test
# Updates baseline checksum to match current run
```

### **Debug Checksum Failures**
```bash
# Quick error scan
just logs-errors TEST_ID

# Detailed checksum analysis
just logs-checksum-detail TEST_ID

# View checksum events
just logs-pattern TEST_ID "checksum.*"
```

### **Checksum Config Requirements**

**Required for checksum validation:**
```json
{
  "checksum_config": {
    "initial_seed": 12345,        # RNG seed (must be consistent)
    "state_type": "seed_validation"  # or "gamestate_replay"
  }
}
```

**RNG Determinism:**
- Seeds auto-initialize from `checksum_config.initial_seed`
- ❌ **NEVER** use `game.battle.set_seed` action (deprecated)
- ✅ **ALWAYS** use `checksum_config.initial_seed` in config

### **What Causes Checksum Mismatches?**

**Common causes:**
1. **Timing-based waits** - Using `await get_tree().process_frame`
2. **Non-deterministic RNG** - Using `RandomNumberGenerator` instead of `DeterministicRNG`
3. **Platform-specific behavior** - Different float precision, threading
4. **Race conditions** - Async operations completing in different order
5. **Frame-dependent logic** - Logic that depends on frame timing

**Fix pattern:**
```gdscript
# ❌ FORBIDDEN - Causes checksum mismatches
await get_tree().create_timer(1.0).timeout
var random_value = randf()  # Non-deterministic

# ✅ CORRECT - Deterministic behavior
signal battle_phase_completed
await battle_phase_completed

var rng: DeterministicRNG = DeterministicRNG.get_singleton()
var random_value: int = rng.randi_range(1, 100)
```

---

## 🎮 Gamestate System

### **Purpose**
Capture complete game state for:
- **Scenario reproduction** - Load exact game state for debugging
- **Cross-platform testing** - Capture on Android, test on editor (90% faster)
- **Regression testing** - Verify game state consistency

### **Capture Gamestate Workflow**

#### **Step 1: Save State (In-Game)**
```
1. Play game to interesting scenario
2. Open debug menu
3. Click "Save State"
4. Exit game
```

#### **Step 2: Extract to Host**
```bash
# Editor (already on host)
just capture-gamestate-editor "critical-bug-scenario"

# Android (extract from device)
just capture-gamestate-android "critical-bug-scenario"

# iOS (extract from device)
just capture-gamestate-ios "critical-bug-scenario"
```

**Saved to:** `tests/test-states/critical-bug-scenario/`

#### **Step 3: Load State (In-Game)**
```
1. Launch game
2. Open debug menu
3. Navigate to "Saved States"
4. Select "critical-bug-scenario"
5. Game loads to exact captured state
```

### **Gamestate Management**
```bash
# List all saved states
just list-saved-states

# Remove all saved states
just clean-saved-states
```

### **Test Integration**
```bash
# Automated gamestate validation
just test-editor-target gamestate-system-validation
just test-android-target gamestate-system-validation

# Complete test suite (includes gamestate)
just test
```

### **Cross-Platform Workflow (90% Faster)**

**Problem:** Android testing is slow (build + deploy + run)
**Solution:** Capture on Android, test on editor

```bash
# 1. Capture interesting state on Android (real platform)
just test-android-target capture-battle-state
just capture-gamestate-android "battle-bug"

# 2. Iterate rapidly on desktop (instant iteration)
just run-editor
# Load state: Debug menu → Saved States → battle-bug
# Test fix
# Repeat instantly (no build/deploy)

# 3. Validate fix on Android (final confirmation)
just test-android-target battle-bug-fix
```

**Time savings:**
- Android iteration: 2-5 minutes per test
- Editor iteration: 5-10 seconds per test
- **90% time reduction**

### **Gamestate File Structure**
```
tests/test-states/scenario-name/
├── gamestate.json           # Complete game state
├── metadata.json            # Capture info (platform, timestamp, version)
└── checksums.json           # State checksums for validation
```

---

## 🎯 Pattern Examples

### **Test Organization Patterns**

**Layer Patterns:**
```json
// C++ Firebase SDK operations
{"actions": ["cpp.*"]}

// System-level utilities
{"actions": ["system.*"]}

// Game logic operations
{"actions": ["game.*"]}
```

**Cross-Layer Patterns:**
```json
// All Firebase operations (any layer)
{"actions": ["*.firebase.*"]}

// All error handling (any layer/system)
{"actions": ["*.*.error_handling"]}

// All start events
{"actions": ["game.*.start"]}
```

**Specific Navigation:**
```json
// Specific Firebase auth operations
{"actions": ["cpp.firebase.auth.*"]}

// Specific battle events
{"actions": ["game.battle.*"]}
```

### **@ References (Test Lists)**

```bash
# Reference specific test list
just test-android "@system-all"

# Reference all test lists ending with "-all"
just test-android "@*-all"

# Reference test list by pattern
just test-android "@gamestate-*"
```

### **Folder References**

```bash
# All replay configs in folder
just test-android "/archive/generated-replays/"

# Pattern-matched configs
just test-android "/archive/generated-replays/merge-*"

# All configs in folder recursively
just test-android "/debug_configs/**/*.json"
```

### **Auto-Detection**

```bash
# Direct action execution (detected as action)
just test-android "system.debug.registry_stats"

# Wildcard pattern (detected as pattern)
just test-android "cpp.*"

# Config name (detected as config file)
just test-android "system-testing"
```

---

## 🔧 Testing Modes

### **Automated Testing**
```bash
# Android automated with checksum validation
just test-android-target CONFIG

# Editor automated with validation
just test-editor-target CONFIG

# macOS automated with validation
just test-macos-target CONFIG

# Benefits:
# - Automatic checksum validation
# - Error analysis included
# - Baseline management
# - Clean exit after test
```

### **Manual Testing**
```bash
# Android manual (stays open for inspection)
just test-android-manual CONFIG

# Editor manual (stays open)
just test-desktop-manual CONFIG

# macOS manual (stays open)
just test-macos-manual CONFIG

# Benefits:
# - Inspect game state after test
# - Manual interaction
# - Debug menu access
# - Visual verification
```

### **Cross-Platform Testing**
```bash
# Unified summary across platforms
just test-all [CONFIG]

# Platform-specific
just test-android CONFIG
just test-desktop CONFIG

# Benefits (test-all):
# - Single unified report
# - Cross-platform consistency check
# - Parallel execution
# - Comprehensive coverage
```

---

## 📊 Test Debugging Workflow

### **Progressive Debugging**

```bash
# 1. QUICK ERROR SCAN (98% token savings)
just logs-errors TEST_ID

# 2. TEXT SEARCH (99% token savings)
just logs-search TEST_ID "firebase"
just logs-search TEST_ID "checksum"

# 3. PATTERN MATCHING
just logs-pattern TEST_ID "game.battle.*"
just logs-pattern TEST_ID "*.error"

# 4. EXPLORE STRUCTURE
just logs-tree TEST_ID  # Discover tag hierarchy
just logs-discover TEST_ID firebase  # Find firebase tags

# 5. FULL DEVICE LOGS (if missing data)
just logs-android-device "SEARCH_TERM"
```

### **Checksum Debugging**
```bash
# Detailed checksum comparison
just logs-checksum-detail TEST_ID

# Checksum events
just logs-pattern TEST_ID "checksum.*"

# Performance analysis (timing issues)
just logs-performance TEST_ID
```

### **Gamestate Debugging**
```bash
# Test lifecycle events
just logs-lifecycle TEST_ID

# State capture/load events
just logs-pattern TEST_ID "gamestate.*"

# Saved state verification
just list-saved-states
```

---

## 🚨 Critical Testing Rules

### **Build Requirements**
1. **MANDATORY**: `just fastbuild-android` after ANY code changes before Android testing
2. **Reason**: Android uses compiled/cached code that doesn't auto-update
3. **Desktop**: Auto-reloads scripts, no build needed

### **Debug Actions Safety**
```bash
# ✅ CORRECT - Use test commands (enables debug coordinator)
just test-android-target CONFIG
just test-editor-target CONFIG
just test-macos-target CONFIG

# ❌ FORBIDDEN - Don't use run commands for test actions
just run-android    # Debug actions won't execute
just run-editor    # Skips state capture system
just run-macos      # Debug actions won't execute
```

### **Inter-Config Delay**
**Required**: 5-second delay between configs

**Reason**: Firebase resource drainage - prevents:
- Rate limiting
- Resource starvation
- State pollution between tests

**Handled automatically** by `just test-*-target` commands.

### **Cache Clearing**
**Required**: Clear caches before testing

**Handled automatically** by test commands:
- `just test-android-target` - Clears Android cache
- `just test-editor-target` - Clears desktop cache

**Manual clearing** (if needed):
```bash
just test-prepare-android  # Clear Android cache only
just test-prepare-desktop  # Clear desktop cache only
```

---

## 📖 Additional Resources

**Testing Commands:**
```bash
# Automated testing
just test-android-target CONFIG
just test-editor-target CONFIG
just test-macos-target CONFIG
just test-all [CONFIG]

# Manual testing
just test-android-manual CONFIG
just test-desktop-manual CONFIG
just test-macos-manual CONFIG

# Validation
just validate                    # Complete validation
just ci-validate                 # CI validation (MANDATORY)

# Replay system
just replay-generate-editor SESSION_ID NAME
just replay-generate-android SESSION_ID NAME

# Gamestate system
just capture-gamestate-editor NAME
just capture-gamestate-android NAME
just list-saved-states
just clean-saved-states

# Debugging
just logs-errors TEST_ID
just logs-search TEST_ID "search"
just logs-pattern TEST_ID "pattern"
just logs-checksum-detail TEST_ID
```

**See Also:**
- `project/CLAUDE.md` - GDScript patterns and game code
- `godot/modules/firebase/CLAUDE.md` - Firebase C++ module
- `justfiles/CLAUDE.md` - Complete command reference
- Root `CLAUDE.md` - Overall project workflows

---

**Key Principles:**
- ✅ **Deterministic testing** - Use checksum validation for reproducibility
- ✅ **Cross-platform consistency** - Test on multiple platforms
- ✅ **Automated validation** - Use `test-*-target` commands
- ✅ **Replay-driven debugging** - Capture and reproduce exact scenarios
- ✅ **Gamestate reproduction** - 90% faster iteration (capture Android, test desktop)

*This testing infrastructure ensures GameTwo's quality, determinism, and cross-platform consistency.*
