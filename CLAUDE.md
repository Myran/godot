# CLAUDE.md

GameTwo is a sophisticated mobile game built with a custom Godot 4.3 engine featuring Firebase integration, advanced data management, and comprehensive debugging systems.

## 🚨 CRITICAL COMMANDS (Emergency Reference)

```bash
# Emergency Debugging (Use First) 
just logs-errors TEST_ID                   # Find errors fast (98% token savings)
just logs-text TEST_ID "search_term"       # ⭐ NEW: Simple text search - any string (99% token savings)
just logs-last                             # Latest test results (99% token savings)

# 🚨 CRITICAL: Android Development Rule
just fastbuild-android                     # REQUIRED after ANY code changes before Android testing

# 🚀 NEW: Wildcard Pattern Debugging (10x Faster)
just logs-tree TEST_ID                     # Explore log structure (2 sec)
just logs-pattern TEST_ID "*.error"        # All errors with precision
just logs-pattern TEST_ID "firebase.*"     # All Firebase operations
just help-wildcards                        # Complete pattern guide
just help                                  # Interactive command browser (Claude can read directly)

# Enhanced Testing with Automatic Validation (NEW)
just test-android-target CONFIG            # Automated testing with built-in error analysis & checksum validation
just test-desktop-target CONFIG            # Desktop automated testing with comprehensive validation

# 🚀 NEW: Battle Replay Integration (Instant Access)
just test-android '/archive/generated-replays/'        # All 25+ battle replay configs
just test-android '/archive/generated-replays/merge-*' # Merge scenarios (merge-20 through merge-25)
just test-android comprehensive-with-replays           # Full regression + replay validation

# Daily Workflow (Primary Commands)
just validate                              # Complete validation (format + syntax + runtime)
just fastbuild-android                     # Smart rebuild & deploy (15-60 sec)
just test-android development-workflow     # Daily development validation
just config-restart-android ACTION         # Ultra-fast testing (5 sec)

# 🎮 NEW: Cross-Platform Gamestate Save/Load System (Instant Scenario Reproduction)
just capture-gamestate-desktop NAME      # Desktop-specific extraction from logs
just capture-gamestate-android NAME      # Android-specific extraction from logs (auto-detects TEST_ID)
just list-saved-states                   # Show all available saved states
just help-gamestate                      # Complete cross-platform workflow guide
# Desktop: Debug menu → "Save State" → Exit → capture-gamestate-desktop NAME → Load via debug menu
# Android: Manual test → Debug menu → "Save State" → Exit → capture-gamestate-android NAME

# Debug Decision Tree: logs-tree → logs-pattern → logs-text → logs-exclude → logs-errors (traditional backup)
```

## 🎯 GameTwo Daily Workflow

**Essential Development Pattern:**
```bash
# Code Changes → Testing Pipeline
just fastbuild-android          # REQUIRED after any GDScript/C++ changes  
just test-android-target CONFIG # Automated testing with validation
just logs-errors TEST_ID        # If tests fail - start here (98% token savings)
```

**Debug Decision Tree:**
`logs-tree` → `logs-pattern` → `logs-text` → `logs-errors` (fallback)

## 📋 Command Quick Reference

**Testing Commands:**
- `just test-android-target CONFIG` | `just test-desktop-target CONFIG` - Enhanced automated testing
- `just test-android TARGET` | `just test-desktop TARGET` - Manual testing (stays open)
- `just validate` - Complete validation (format + syntax + runtime)

**Debugging Commands:**
- `just logs-errors TEST_ID` - Error-focused analysis (98% token savings)
- `just logs-tree TEST_ID` - Explore log structure (2 sec)
- `just logs-pattern TEST_ID "firebase.*"` - Pattern matching
- `just logs-text TEST_ID "search_term"` - Simple text search

**Build Commands:**
- `just fastbuild-android` - Smart rebuild (15-60 sec) **REQUIRED after code changes**
- `just build` - Complete pipeline (46 min)
- `just build-status` - Check what would be rebuilt

**Config Commands:**
- `just config-restart-android ACTION` - Deploy + restart (5 sec)
- `just config-push-android CONFIG` - Deploy config only (2 sec)
- `just config-list` - List available configs

**Gamestate Commands:**
- `just capture-gamestate-desktop NAME` | `just capture-gamestate-android NAME`
- `just list-saved-states` | `just clean-saved-states`

> 📚 **For detailed command help**: Use `just help` and `just help-[topic]` - Claude can read these outputs directly for comprehensive explanations and examples.

## 🤖 Claude Code Preferences

**Essential GameTwo patterns:**
- **Always use `rg` instead of `grep`** - 10x faster, better regex engine
- **REQUIRED: `just fastbuild-android`** after ANY GDScript/C++ changes before Android testing
- **Link tasks bidirectionally**: Reference task in commit, commit in task

**MCP Tools for GameTwo Development:**
- **Repomix MCP**: Pack codebase once, search multiple times - ideal for architectural analysis
- **Godot MCP**: Launch editor, run project, get debug output - direct Godot 4.3 integration  
- **Context7 MCP**: Get up-to-date docs for any library - resolve library patterns and fetch documentation

**Git workflow:**
- Use `git commit --amend` for related documentation updates
- Include "Closes: task-XXX" and "Related: backlog/tasks/..." in commits

**Exception**: Use `grep` only for pipeline scripts requiring exact compatibility.

## 🔧 Common Issues Quick Fix

**Debugging pattern (token-efficient):**
1. `just logs-errors TEST_ID` (98% token savings - start here)
2. `just logs-text TEST_ID "firebase"` (specific search)
3. `just logs-pattern TEST_ID "firebase.*"` (pattern matching)

**Common fixes:**
- Firebase issues: `just test-android 'system.network.*'`
- Checksum failures: `just test-android 'game.match.reset_level'`
- Performance issues: `just test-android '*.*.performance'`

## 📋 Android Device Logs

**Live device monitoring:**
- `just android-logs-errors 30` - Live error monitoring (30s, filtered)
- `just android-logs-tagged "firebase" 30 50` - Tag filtering (30s, 50 lines)
- `just android-logs-status` - Device & app status

**All commands filter out noise and focus on Firebase, debug, errors, performance.**

## 🔧 Testing Modes

**Automated (quits after completion):**
- `just test-android-target CONFIG` - Enhanced with validation
- `just test-desktop-target CONFIG` - Cross-platform testing

**Manual (stays open):**
- `just test-android-manual CONFIG` - Android inspection mode
- `just test-desktop-manual CONFIG` - Desktop inspection mode

**Workflows:**
- `just test-android development-workflow` - Daily development
- `just test-android pre-commit` - Pre-commit validation

## 🎯 Pattern Examples

**Layer patterns:**
- `'cpp.*'` - C++ Firebase SDK
- `'system.*'` - System utilities  
- `'game.*'` - Game logic

**Cross-layer patterns:**
- `'*.firebase.*'` - All Firebase operations
- `'*.*.error_handling'` - All error handling

## 📁 Test Organization

**@ Symbol references:**
- `"@system-all"` - Include all configs from system-all.json
- `"@*-all"` - Include ALL test lists ending with "-all"

**Folder references:**
- `"/archive/generated-replays/"` - All 25+ battle replay configs
- `"/archive/generated-replays/merge-*"` - Specific replay patterns

**Input auto-detection:**
- Actions: `'system.debug.registry_stats'` → Direct execution
- Wildcards: `'cpp.*'` → Auto-discovery  
- Configs: `system-testing` → Load configuration

## 🚨 Critical Safety Rules

**Debug Actions:**
- ✅ Use `just test-*` commands (enables debug coordinator)
- ❌ Never use `just run-desktop` (skips state capture, validation)

**Android Development:**
- **MANDATORY**: `just fastbuild-android` after ANY code changes before testing
- **Why**: Android uses compiled/cached code that doesn't auto-update

## 📱 Android Configuration

**Core debug configs (9 active):**
- `battle-logic-only` - Battle without visual effects
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

## 🚫 FORBIDDEN PATTERNS (GDScript Anti-Patterns)

**NEVER use timing-based waits - they create race conditions:**

```gdscript
# ❌ FORBIDDEN - Never use these patterns
await Engine.get_main_loop().process_frame
await Engine.get_main_loop().create_timer(0.3).timeout
await get_tree().create_timer(1.0).timeout

# ✅ Use proper async completion instead
await some_operation_completed
await async_function_call()
```

## 💪 Strong Typing Requirements

**Always use fail-fast typing:**

```gdscript
# ✅ Required patterns
var firebase_backend: FirebaseBackend = get_backend()
var cards: Array[Card] = []
func create_card(id: String, level: int = 1) -> Card:
    return card_scene.instantiate() as Card

# ❌ Never use runtime checking or untyped variables
if backend is FirebaseBackend: # Runtime checking
var data = {}                  # No type
```

**Validation:**
- `just validate` - Complete pipeline (format + syntax + runtime)
- `just show-warnings` - GDScript warnings with file:line

## 🎬 Replay Testing

**Simple workflow: Play → Generate → Test**
1. `just run-desktop` (shows session ID when finished)
2. `just replay-generate-desktop SESSION_ID my-test`
3. `just test-android-target my-test` (automated with validation)

## 🧪 Checksum Testing

**Automatic validation:**
- `just test-android-target CONFIG` - Auto-creates baseline + validates  
- `just test-android-update CONFIG` - Update baseline (legitimate changes)
- `just logs-errors TEST_ID` - Debug checksum failures

**RNG Determinism:** Seeds auto-initialize from debug configs during autoload.

**Adding seeds to configs:**
```json
{
  "checksum_config": {
    "initial_seed": 12345,
    "state_type": "seed_validation"
  }
}
```
**Never use:** `"game.battle.set_seed"` action (causes timing issues)

## 🎮 Cross-Platform Gamestate System

**Quick workflow for scenario reproduction:**
1. Play game → Debug menu → "Save State" → Exit  
2. `just capture-gamestate-desktop "scenario_name"`
3. `just run-desktop` → Debug menu → "Saved States" → Load scenario

**Management:**
- `just list-saved-states` - Show available states
- `just clean-saved-states` - Remove all states  
- `just capture-gamestate-android NAME` - Android extraction (auto-detects TEST_ID)

**90% faster scenario reproduction - capture from Android, load on desktop or vice versa.**

## 🔧 Advanced Features

**Desktop debugging:**
- `just run-desktop-debug` - Normal debug mode
- `just run-desktop-debug verbose` - ObjectDB leak detection

**For comprehensive command details:**
- `just help` - **Interactive command browser with clickable links**
- `just help-debug` - Complete debug & testing workflows  
- `just help-logs` - Token efficiency & log analysis guide
- `just help-build` - Build system architecture & timing
- `just help-workflows` - Detailed workflow patterns & best practices

> 💡 **Claude can read `just help` output directly** - use these commands to get detailed explanations and examples for any GameTwo workflow.

## 📖 Advanced Topics

**See [CLAUDE-ADVANCED.md](CLAUDE-ADVANCED.md) for detailed information on:**
- Wildcard pattern system deep dive & examples
- Git workflow & backlog integration patterns  
- Repomix MCP best practices for GameTwo
- Project architecture & directory structure
- Performance optimization strategies
- Complete command reference with examples

**MCP Tools Integration:**
- **Repomix MCP**: Strategic codebase analysis patterns for GameTwo's 248-file architecture
- **Godot MCP**: Direct Godot 4.3 engine integration and project management
- **Context7 MCP**: Library documentation for Firebase, GDScript, and mobile development patterns

**For complex development tasks:**
- `just generate-claude-context` - Generate optimized project context (250k tokens)
- Creates `claude-project-context.xml` for full codebase analysis

**This CLAUDE.md focuses on daily GameTwo development essentials.**