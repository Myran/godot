# CLAUDE.md

GameTwo is a sophisticated mobile game built with a custom Godot 4.3 engine featuring Firebase integration, advanced data management, and comprehensive debugging systems.

## 🚨 CRITICAL COMMANDS (Emergency Reference)

```bash
# Emergency Debugging (Use First) 
just logs-errors TEST_ID                   # Find errors fast (98% token savings)
just logs-text TEST_ID "search_term"       # ⭐ NEW: Simple text search - any string (99% token savings)
just logs-last                             # Latest test results (99% token savings)

# 🚨 CRITICAL: Full Android Log Inspection (Not Test Results)
just android-logs-search "search_term"    # ⭐ FULL Android logs - sees EVERYTHING including initialization
adb logcat -d | rg "search_term" -i       # Alternative direct approach for full log access

# ⚠️  IMPORTANT LOG DISTINCTION:
# - just logs-* TEST_ID          → FILTERED test results only (missing app initialization logs)
# - just android-logs-search     → FULL device logs (sees all app activity including startup)
# - When logs don't appear in test results, ALWAYS use android-logs-search for complete view

# 🚨 CRITICAL: Android Development Rule
just fastbuild-android                     # REQUIRED after ANY code changes before Android testing

# 📝 NEW: Complete Command Logging (Long-Running Commands)
just log-run test                          # Save complete test output to timestamped logs/ files
just log-run test-android firebase-all    # Log comprehensive testing with automatic timestamped filenames

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
just ci-validate                           # 🚨 CRITICAL: CI validation pipeline (format + lint + syntax)
just validate                              # Complete validation (format + syntax + runtime)
just fastbuild-android                     # 🚨 CRITICAL: Smart rebuild & deploy (15-60 sec) - REQUIRED after code changes
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

**Essential Development Pattern (OODA Loop Integration):**
```bash
# 🔄 OBSERVE → ORIENT → DECIDE → ACT Cycle
just ci-validate                # OBSERVE: Code quality, formatting, linting issues  
just log-run test               # OBSERVE: Complete test run with full logging (saves to logs/)
                               # 🚀 NOW INCLUDES: Gamestate validation as part of system-infrastructure
just logs-errors TEST_ID        # ORIENT: 98% token-efficient issue analysis
# → DECIDE: Strategic fixes based on feedback
just fastbuild-android          # ACT: REQUIRED after any GDScript/C++ changes  
just log-run test-android-target CONFIG # ACT: Automated testing with complete logging
# → Repeat cycle for continuous improvement

# 📝 LOGGING WORKFLOW: Use log-run for long commands that might break partway
just log-run test-android firebase-all    # Complete Firebase testing with timestamped logs
just log-run test-android test-all        # Comprehensive testing (15+ configs) with full capture
# Results saved to: logs/YYYYMMDD_HHMMSS_command-name.log
```

**🚨 CRITICAL CI/Build Rules:**
- **`just ci-validate`** - MANDATORY before commits (prevents technical debt)
- **`just fastbuild-android`** - MANDATORY after ANY code changes before Android testing
- **Failure in CI** → Fix immediately → Re-validate → Proceed
- **CI success** → Proceed to testing phase with confidence

**Debug Decision Tree:**
1. **Test Results**: `logs-tree` → `logs-pattern` → `logs-text` → `logs-errors` (fallback)
2. **Full Android Logs**: `android-logs-search "term"` → `adb logcat -d | rg "term" -i`

**🚨 CRITICAL: When to Use Full Android Logs vs Test Results**
- **Missing initialization logs?** → Use `android-logs-search` (sees app startup, game._ready(), etc.)
- **Testing validation/fastbuild?** → Use `android-logs-search` (test results filter out non-debug logs)
- **Debugging specific test actions?** → Use `logs-text TEST_ID` (focused on test actions only)
- **General app debugging?** → Use `android-logs-search` (complete device log view)

## 📋 Command Quick Reference

**Testing Commands:**
- `just test-android-target CONFIG` | `just test-desktop-target CONFIG` - Enhanced automated testing
- `just test-android TARGET` | `just test-desktop TARGET` - Manual testing (stays open)
- `just validate` - Complete validation (format + syntax + runtime)

**🚀 Command Integration in Test Lists (NEW):**
- Test lists now support `commands` array for just command execution
- Commands run after configs with platform filtering (desktop/android)
- Context inheritance: TEST_ID and session data passed to commands  
- `just test-command-integration` - Demo with platform filtering
- `just help-command-integration` - Complete integration guide

**🎯 Test List Structure & @ References:**
- `configs` array: Individual test configurations or @ references
- `commands` array: Platform-filtered just command execution  
- `@gamestate-system-validation` - Reference to gamestate test list
- `@system-infrastructure` - Now includes gamestate validation
- `just help-at-symbols` - Complete @ reference and /folder/ pattern guide

**Debugging Commands:**
- `just log-run COMMAND` - **📝 NEW: Run any command with timestamped logging (saves to logs/)**
- `just logs-errors TEST_ID` - Error-focused analysis (98% token savings)
- `just logs-tree TEST_ID` - Explore log structure (2 sec)
- `just logs-pattern TEST_ID "firebase.*"` - Pattern matching
- `just logs-text TEST_ID "search_term"` - Simple text search

**Build Commands:**
- `just ci-validate` - **🚨 CI validation pipeline (format + lint + syntax) - MANDATORY before commits**
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
- `just test-save-load-cycle-with-test-capture-50-desktop` - CLI wrapper for testing
- `just test-save-load-cycle-with-test-capture-50-android` - Android CLI wrapper

> 📚 **For detailed command help**: Use `just help` and `just help-[topic]` - Claude can read these outputs directly for comprehensive explanations and examples.

## 🤖 Claude Code Preferences

**Essential GameTwo patterns:**
- **Always use `rg` instead of `grep`** - 10x faster, better regex engine
- **REQUIRED: `just fastbuild-android`** after ANY GDScript/C++ changes before Android testing
- **Link tasks bidirectionally**: Reference task in commit, commit in task
- **🎯 CRITICAL: Use Advanced OODA Loop Debugging Methodology** - Investigation-first approach with expert panel evaluation (see below)

**MCP Tools for GameTwo Development:**
- **Repomix MCP**: Pack codebase once, search multiple times - ideal for architectural analysis
- **Godot MCP**: Launch editor, run project, get debug output - direct Godot 4.3 integration  
- **Context7 MCP**: Get up-to-date docs for any library - resolve library patterns and fetch documentation

**Git workflow:**
- Use `git commit --amend` for related documentation updates
- Include "Closes: task-XXX" and "Related: backlog/tasks/..." in commits

**Exception**: Use `grep` only for pipeline scripts requiring exact compatibility.

## 🔄 OODA Loop Integration (Critical for GameTwo Development)

**Why `just ci-validate` and `just test` are Essential:**

### **🔍 OBSERVE Phase**
- **`just ci-validate`** - Observes code quality, formatting, and linting issues in real-time
- **`just test`** - Observes functional behavior across desktop/Android platforms  
- **`just logs-errors TEST_ID`** - Observes runtime issues with 98% token efficiency

### **🧠 ORIENT Phase**  
- **CI validation results** - Orient to code standards and maintainability requirements
- **Cross-platform test results** - Orient to Android/desktop compatibility requirements
- **Error analysis** - Orient to specific technical issues requiring fixes

### **⚡ DECIDE Phase**
- **CI pass/fail** - Drives immediate decisions on code quality and commit readiness
- **Test pass/fail** - Informs decisions about feature stability and deployment  
- **Performance metrics** - Guides architectural decisions and optimization priorities

### **🚀 ACT Phase**
- **Failed CI** → Immediate code fixes → `just ci-validate` → Repeat until pass
- **Failed tests** → `just logs-errors TEST_ID` → Debug → Fix → `just fastbuild-android` → Re-test
- **All validation passes** → Proceed confidently to next development phase

**🎯 Critical Success Pattern:**
```bash
just ci-validate           # ✅ Must pass before proceeding
just fastbuild-android     # ✅ Required after any code changes  
just test-android CONFIG   # ✅ Validates changes work on target platform
just logs-errors TEST_ID   # 🔧 If issues found - 98% token-efficient debugging
```

## 🎯 Advanced OODA Loop Debugging Methodology

**Critical GameTwo debugging approach discovered through TASK-132/131 resolution:**

### **🔍 OBSERVE Phase - Evidence-First Investigation**
```bash
# Step 1: Gather empirical evidence before forming theories
just android-logs-search "SEARCH_TERM"     # Full device logs - sees everything
just logs-errors TEST_ID                   # 98% token-efficient issue analysis  
just logs-text TEST_ID "specific_term"     # Targeted search with context
```

**🚨 CRITICAL**: Always gather actual current evidence, not rely on stale documentation or assumptions.

### **🧠 ORIENT Phase - Expert Panel Evaluation**

**Assemble Virtual Expert Panel** for complex issues:
- **Senior Systems Architect** - Mobile/game engine expertise
- **Platform Integration Specialist** - Android/Firebase/GDScript  
- **Test Infrastructure Lead** - Testing patterns and validation
- **Performance Engineer** - Timing, race conditions, threading
- **Technical Debt Reviewer** - Architecture decisions and intent

**Panel Evaluation Framework**:
1. **Historical Context Analysis** - `git log --oneline --grep="PATTERN" -n 20`
2. **Architectural Intent Review** - Recent commits show design decisions
3. **Cross-Option Impact Assessment** - Each solution's effect on existing systems
4. **Risk vs Benefit Analysis** - Preserve working functionality

### **⚡ DECIDE Phase - Investigation-First Approach** 

**NEVER fix without investigation**:

❌ **Avoid**: Symptom-based fixes that might break working systems
✅ **Prefer**: Evidence-gathering that reveals true current state

**Decision Priority**:
1. **Option 1: Investigation** - Always start here for complex issues
2. **Option 2: Targeted Fix** - Only after understanding root cause  
3. **Option 3: Architecture Review** - Last resort for systemic issues
4. **Option 4: Platform Workarounds** - Avoid - creates technical debt

### **🚀 ACT Phase - Minimal Risk Implementation**

**Critical Success Pattern**:
```bash
# 1. Add targeted logging (investigation code)
# 2. Test and gather evidence  
# 3. Analyze results with expert panel mindset
# 4. Apply minimal fix based on evidence
# 5. Remove investigation code
# 6. Document resolution with evidence
```

### **💡 Key Methodology Insights**

**From TASK-132/131 Resolution**:
- ✅ **Investigation revealed both issues already resolved** by previous architectural improvements
- ✅ **Expert panel prevented destructive "fixes"** to working systems
- ✅ **Evidence-based conclusions** contradicted stale task documentation  
- ✅ **Timeout architecture improvements** (commits 51090009, 2ff19647) had resolved underlying causes
- ✅ **Android platform achieved 100% parity** with Desktop functionality

**Critical Learning**: 
> *"Sometimes the best debugging reveals that systematic architectural improvements have already solved the problems. Investigation-first methodology prevents fixing working code."*

**Time Investment**: 4-6 hours investigation vs 20-40+ hours architectural changes that risk breaking proven systems.

### **🏆 Expert Panel Validation Checklist**

Before implementing any complex fix, ask:
- [ ] **Systems Architect**: Does this align with recent architectural decisions?
- [ ] **Integration Specialist**: Will this break platform compatibility patterns?  
- [ ] **Test Lead**: Does this preserve existing test infrastructure?
- [ ] **Performance Engineer**: Are we solving the actual bottleneck?
- [ ] **Debt Reviewer**: Does this contradict recent architectural investments?

**Unanimous expert agreement required** for architectural changes.

## 🔧 Common Issues Quick Fix

**Debugging pattern (token-efficient):**
1. `just logs-errors TEST_ID` (98% token savings - start here)
2. `just logs-text TEST_ID "firebase"` (specific search)  
3. `just logs-pattern TEST_ID "firebase.*"` (pattern matching)

**⚠️  If logs are missing or incomplete:**
4. `just android-logs-search "search_term"` (FULL device logs - sees initialization, startup, everything)
5. `adb logcat -d | rg "search_term" -i` (direct approach for complete log access)

**🎯 Quick Rule**: Missing logs in test results? → Use `android-logs-search` for complete view

**Common fixes:**
- Firebase issues: `just test-android 'system.network.*'`
- Checksum failures: `just test-android 'game.match.reset_level'`
- Performance issues: `just test-android '*.*.performance'`
- **Fastbuild validation**: `just android-logs-search "FASTBUILD_VALIDATION_TEST"`

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

# ✅ Use proper signal-based completion instead
await some_operation_completed
await signal_emitted
```

**CRITICAL: GDScript doesn't have `async` keyword:**

```gdscript
# ❌ FORBIDDEN - async keyword doesn't exist in GDScript
async func my_function() -> void:

# ✅ CORRECT - Functions that await are automatically async
func my_function() -> void:
    await some_signal
    # Function becomes async when it contains await
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

**🚀 NEW: Test List Integration & Validation:**
- `just test-save-load-cycle-with-test-capture-50-desktop` - CLI wrapper for testing
- `just test-save-load-cycle-with-test-capture-50-android` - Android CLI wrapper
- `just test-desktop-target gamestate-system-validation` - Complete gamestate validation via test lists
- `just test-android-target gamestate-system-validation` - Cross-platform consistency testing

**📁 File Organization:**
- `./project/debug/saved_states/` - User-created gamestate saves (runtime)
- `tests/test-states/` - **NEW**: Dedicated directory for test gamestate files
- `tests/test-states/test-capture-50.json` - Reference test state for validation

**🎯 Main Test Suite Integration:**
- `just test` - **NOW INCLUDES** gamestate validation as part of system-infrastructure testing
- Automatic save-load cycle validation ensures gamestate integrity in daily development

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

## 🚀 Test List Command Integration Example

**Enhanced test lists now support command execution:**

```json
{
  "name": "Gamestate Validation with Commands",
  "description": "Config testing + command validation",
  "configs": [
    "gamestate-save-load-test"
  ],
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
- `just test-desktop-target my-enhanced-test` - Runs configs + desktop commands
- `just test-android-target my-enhanced-test` - Runs configs + android commands
- Platform filtering: Only compatible commands execute automatically
- Context inheritance: Commands receive TEST_ID and session data

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