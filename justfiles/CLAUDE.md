# Justfile Commands Reference

@./ARCHITECTURE.md

<!-- ARCHITECTURE.md provides deep dive into 39 justfile modules, dependency graph, and recipe selection matrix -->

Complete reference for GameTwo justfile commands, patterns, and workflows.

## 🎯 Checksum Baseline Management

**Essential Commands for Baseline Updates:**
- `just test-android-update CONFIG_NAME` - Update Android checksum baseline
- `just test-editor-update CONFIG_NAME` - Update Editor/Desktop checksum baseline
- `just test-ios-update CONFIG_NAME` - Update iOS checksum baseline
- `just test-macos-update CONFIG_NAME` - Update macOS checksum baseline
- `just test-windows-update CONFIG_NAME` - Update Windows VM checksum baseline
- `just test-windows-physical-update CONFIG_NAME` - Update Windows Physical checksum baseline
- `just test-android-reset CONFIG_NAME` - Reset Android baseline (start fresh)
- `just test-editor-reset CONFIG_NAME` - Reset Editor/Desktop baseline
- `just test-ios-reset CONFIG_NAME` - Reset iOS baseline
- `just test-macos-reset CONFIG_NAME` - Reset macOS baseline
- `just test-windows-reset CONFIG_NAME` - Reset Windows VM baseline
- `just test-windows-physical-reset CONFIG_NAME` - Reset Windows Physical baseline

**When to Update vs Reset:**
- ✅ **Update** (`test-*-update`): Legitimate system/card changes, new features, balance updates, engine optimizations
- 🔄 **Reset** (`test-*-reset`): Starting over, baseline corruption, major refactoring

**Common Update Scenarios:**
```bash
# Card/Balance Changes
just test-android-update battle-animated      # After card stat changes
just test-android-update battle-logic-only    # After ability changes
just test-desktop-update battle-animated       # Cross-platform consistency

# System Changes
just test-android-update firebase-backend-layer  # After Firebase changes
just test-android-update system-performance     # After system optimizations

# Replay Tests
just test-android-update merge-20              # After replay system changes
just test-android-update draft-10              # After draft system modifications
```

**Interactive Usage:**
```bash
just test-android-update          # Shows menu of available configs
just test-editor-update           # Shows menu of available configs
just test-ios-update              # Shows menu of available configs
just test-macos-update            # Shows menu of available configs
just test-windows-update          # Shows menu of available configs
just test-windows-physical-update # Shows menu of available configs
```

**Workflow Integration:**
1. **Run test with changes** → Detects checksum mismatch
2. **Review changes** → Confirm they're legitimate
3. **Update baseline** → `just test-android-update CONFIG_NAME`
4. **Re-run test** → Validates new baseline
5. **Commit** → Both code and updated baseline

## 🚨 CRITICAL COMMANDS

```bash
# Emergency Debugging
just logs-errors TEST_ID                   # Find errors (98% token savings)
just logs-search TEST_ID "search_term"     # Text search (99% token savings - replaced logs-text)

# Platform-specific log retrieval
just logs-android TEST_ID [TAGS]          # Android logs with optional tag filtering
just logs-desktop TEST_ID [TAGS]          # Desktop logs with optional tag filtering
just logs-ios TEST_ID [TAGS]              # iOS logs with optional tag filtering (NEW)
just logs-macos TEST_ID [TAGS]            # macOS logs with optional tag filtering (NEW)

# Platform-specific error analysis
just logs-android-errors TEST_ID         # Android errors with tag filtering
just logs-desktop-errors TEST_ID         # Desktop errors with tag filtering
just logs-ios-errors TEST_ID             # iOS errors with tag filtering (NEW)
just logs-macos-errors TEST_ID           # macOS errors with tag filtering (NEW)

# Full Android Logs (Not Test Results)
just logs-android-device "search_term"    # Complete device logs including startup (consolidated)
adb logcat -d | rg "search_term" -i       # Direct full log access

# Log Types:
# - just logs-* TEST_ID      → Filtered test results only
# - just logs-android-device → Full device logs (replaced android-logs-search)
# Missing logs? Use logs-android-device

# Android Development
just fastbuild-android                     # REQUIRED after ANY code changes

# Deploy (Development - export → install → run)
just deploy-android                        # Deploy to Android device
just deploy-ios                            # Deploy to iOS (default: iPad)
just deploy-ios-iphone                     # Deploy to iPhone
just deploy-ios-ipad                       # Deploy to iPad
just deploy-windows                        # Deploy to Windows physical machine

# Ship (Production - App Store)
just ship-android                          # Ship to Play Store
just ship-ios                              # Ship to App Store

# Command Logging (Long-Running)
just log-run-silent COMMAND                # Silent logging (saves context tokens)
just log-run COMMAND                       # Verbose logging
# Saves to: logs/YYYYMMDD_HHMMSS_command-name.log

# Pattern Debugging
just logs-tree TEST_ID                     # Explore log structure
just logs-pattern TEST_ID "pattern"        # Pattern matching
just help-wildcards                        # Pattern guide
just help                                  # Interactive command browser

# Testing
just test-android-target CONFIG            # Automated testing with validation
just test-desktop-target CONFIG            # Desktop automated testing
just test-macos-target CONFIG              # macOS automated testing
just test-windows-physical-target CONFIG   # Windows physical machine (GUI mode)
just test-android '/archive/generated-replays/'  # All battle replay configs
just test-android '/archive/generated-replays/merge-*'  # Merge scenarios

# Windows Physical Machine (192.168.50.80)
just win-physical-status                   # Check machine status
just win-physical-wake                     # Wake via Wake-on-LAN
just win-physical-deploy                   # Deploy Windows export
just test-windows-physical-target CONFIG   # Run test with GUI
just logs-windows-physical TEST_ID         # Retrieve logs

# Daily Workflow
just ci-validate                           # CI validation (format + lint + syntax)
just validate                              # Complete validation (format + syntax + runtime)
just test-android development-workflow     # Daily validation
just config-restart-android ACTION         # Quick testing (5 sec)
just development                           # Complete workflow (fastbuild-android + ci-validate + test)

# Gamestate System
just capture-gamestate-desktop NAME       # Desktop extraction
just capture-gamestate-android NAME       # Android extraction
just list-saved-states                    # Show saved states
just help-gamestate                       # Workflow guide

# Debug Flow: logs-tree → logs-pattern → logs-search → logs-errors
```

## 🎯 Daily Workflow

**OODA Loop Development Pattern:**
```bash
# OBSERVE → ORIENT → DECIDE → ACT
just ci-validate                # Code quality, formatting, linting
just log-run-silent test        # Complete test with silent logging
just logs-errors TEST_ID        # Issue analysis (98% token savings)
just fastbuild-android          # REQUIRED after GDScript/C++ changes
just log-run-silent test-android-target CONFIG  # Automated testing
```

**🚨 CRITICAL Rules:**
- **`just ci-validate`** - MANDATORY before commits
- **`just fastbuild-android`** - MANDATORY after code changes before Android testing
- **`just development`** - REQUIRED before GDScript commits (fastbuild-android + ci-validate + test)

**Debug Decision Tree:**
1. **Test Results**: `logs-tree` → `logs-pattern` → `logs-search` → `logs-errors`
2. **Full Android Logs**: `logs-android-device "term"` → `adb logcat -d | rg "term" -i`

**When to Use Full Android Logs:**
- Missing initialization logs? → `logs-android-device` (sees startup)
- Testing validation/fastbuild? → `logs-android-device` (non-debug logs)
- Specific test actions? → `logs-search TEST_ID` (focused)
- General debugging? → `logs-android-device` (complete view)

## 📋 Command Reference

**Testing:**
- `just test-android-target CONFIG` | `just test-desktop-target CONFIG` | `just test-macos-target CONFIG` - Automated testing
- `just test-android TARGET` | `just test-desktop TARGET` | `just test-macos TARGET` - Manual testing
- `just validate` - Complete validation (format + syntax + runtime)

**Test Lists:**
- Test lists support `commands` array for platform-filtered execution
- Context inheritance: TEST_ID and session data passed to commands
- `@gamestate-system-validation` - Reference to gamestate test list
- `just help-at-symbols` - Complete @ reference guide

**Debugging:**
- `just log-run-silent COMMAND` - Silent logging (saves tokens)
- `just log-run COMMAND` - Verbose logging
- `just logs-errors TEST_ID` - Error analysis (98% savings)
- `just logs-tree TEST_ID` - Explore log structure
- `just logs-pattern TEST_ID "pattern"` - Pattern matching
- `just logs-search TEST_ID "search_term"` - Text search (replaced logs-text)

**Build:**
- `just development` - Complete workflow (MANDATORY before GDScript commits)
- `just cpp-dev` - C++ workflow (build + install + fastbuild)
- `just ci-validate` - CI validation (MANDATORY before commits)
- `just fastbuild-android` - Smart rebuild (15-60 sec, REQUIRED)
- `just build-all-android` - Android pipeline (3-25 min)
- `just build` - Complete pipeline (46 min)

**Config:**
- `just config-restart-android ACTION` - Deploy + restart (5 sec)
- `just config-push-android CONFIG` - Deploy config (2 sec)
- `just config-list` - List configs

**Gamestate:**
- `just capture-gamestate-desktop NAME` | `just capture-gamestate-android NAME`
- `just list-saved-states` | `just clean-saved-states`

> 📚 **For detailed help**: Use `just help` and `just help-[topic]` - Claude can read these directly

## 🔧 Common Issues Quick Fix

**Debugging pattern (token-efficient):**
1. `just logs-errors TEST_ID` (98% token savings - start here)
2. `just logs-search TEST_ID "firebase"` (specific search - replaced logs-text)
3. `just logs-pattern TEST_ID "firebase.*"` (pattern matching)

**⚠️  If logs are missing or incomplete:**
4. `just logs-android-device "search_term"` (FULL device logs - sees initialization, startup, everything)
5. `adb logcat -d | rg "search_term" -i` (direct approach for complete log access)

**🎯 Quick Rule**: Missing logs in test results? → Use `logs-android-device` for complete view

**Common fixes:**
- Firebase issues: `just test-android 'system.network.*'`
- Checksum failures: `just test-android 'game.match.reset_level'`
- Performance issues: `just test-android '*.*.performance'`
- **Fastbuild validation**: `just logs-android-device "FASTBUILD_VALIDATION_TEST"`

## 📋 Android Device Logs

**Live Monitoring:**
- `just android-logs-errors 30` - Error monitoring (30s)
- `just android-logs-tagged "firebase" 30 50` - Tag filtering
- `just android-logs-status` - Device & app status

## 🔧 Testing Modes

**Automated:**
- `just test-android-target CONFIG` - Enhanced with validation
- `just test-desktop-target CONFIG` - Cross-platform testing
- `just test-macos-target CONFIG` - macOS testing (exported app)
- `just test-windows-physical-target CONFIG` - Windows physical (GUI mode)

**Manual:**
- `just test-android-manual CONFIG` - Android inspection
- `just test-desktop-manual CONFIG` - Desktop inspection
- `just test-macos-manual CONFIG` - macOS inspection
- `just test-windows-physical-manual CONFIG` - Windows physical inspection

## 🎯 Pattern Examples

**Layer patterns:**
- `'cpp.*'` - C++ Firebase SDK
- `'system.*'` - System utilities
- `'game.*'` - Game logic

**Cross-layer patterns:**
- `'*.firebase.*'` - All Firebase operations
- `'*.*.error_handling'` - All error handling

## 📁 Test Organization

**@ References:**
- `"@system-all"` - All configs from system-all.json
- `"@*-all"` - All test lists ending with "-all"

**Folder references:**
- `"/archive/generated-replays/"` - All battle replay configs
- `"/archive/generated-replays/merge-*"` - Merge scenarios

**Auto-detection:**
- Actions: `'system.debug.registry_stats'` → Direct execution
- Wildcards: `'cpp.*'` → Auto-discovery
- Configs: `system-testing` → Load configuration

## 🚨 Safety Rules

**Debug Actions:**
- ✅ Use `just test-*` commands (enables debug coordinator)
- ❌ Never use `just run-editor` (skips state capture) (Task-329)

**Android Development:**
- **MANDATORY**: `just fastbuild-android` after ANY code changes before testing
- **Reason**: Android uses compiled/cached code that doesn't auto-update

## 📱 Android Configuration

**Debug configs (9 active):**
- `battle-logic-only` - Battle without effects
- `firebase-cpp-layer` - C++ Firebase SDK
- `system-layer-all` - Complete system utilities
- `production-ready` - Release validation
- Use `just config-list` for complete list

**Logger control:**
- `just config-android-tags "firebase,battle" "cache"` - Focus/filter
- `just config-android-level DEBUG` - Set verbosity
- `just config-android-reset` - Reset defaults

**Screenshots:**
- `just screenshot-android` - Quick screenshot
- `just screenshot-android error-state` - Named screenshot

## 🔧 Advanced Features

**Editor debugging:**
- `just run-editor-debug` - Normal debug (Task-329)
- `just run-editor-debug verbose` - ObjectDB leak detection (Task-329)

**Command help:**
- `just help` - Interactive browser
- `just help-debug` - Debug workflows
- `just help-logs` - Log analysis
- `just help-build` - Build system
- `just help-workflows` - Workflow patterns

> 💡 **Claude can read `just help` output directly** - use for detailed explanations.

## 🚀 Test List Command Integration

**Test lists support command execution:**

```json
{
  "name": "Gamestate Validation with Commands",
  "description": "Config testing + command validation",
  "configs": ["gamestate-save-load-test"],
  "commands": [
    {
      "command": "test-save-load-cycle-desktop",
      "platforms": ["desktop"],
      "description": "Desktop save/load consistency"
    },
    {
      "command": "test-save-load-cycle-android",
      "platforms": ["android"],
      "description": "Android save/load consistency"
    }
  ]
}
```

**Usage:**
- `just test-desktop-target my-test` - Runs configs + desktop commands
- `just test-android-target my-test` - Runs configs + android commands
- Platform filtering: Only compatible commands execute
- Context inheritance: Commands receive TEST_ID and session data

---

**See Also:**
- `justfiles/ARCHITECTURE.md` - Deep justfile module architecture (39 modules)
- `project/CLAUDE.md` - GDScript patterns and game code
- `tests/CLAUDE.md` - Testing infrastructure
- `godot/modules/firebase/CLAUDE.md` - Firebase C++ module
- Root `CLAUDE.md` - Overall project workflows

---

*Complete justfile command reference for GameTwo development.*
