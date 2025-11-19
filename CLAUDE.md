# CLAUDE.md

GameTwo mobile game with custom Godot 4.3 engine, Firebase integration, and debugging systems.

## 🚨 CRITICAL COMMANDS

```bash
# Emergency Debugging
just logs-errors TEST_ID                   # Find errors (98% token savings)
just logs-text TEST_ID "search_term"       # Text search (99% token savings)
just logs-last                             # Latest results (99% token savings)

# Full Android Logs (Not Test Results)
just android-logs-search "search_term"    # Complete device logs including startup
adb logcat -d | rg "search_term" -i       # Direct full log access

# Log Types:
# - just logs-* TEST_ID      → Filtered test results only
# - just android-logs-search → Full device logs
# Missing logs? Use android-logs-search

# Android Development
just fastbuild-android                     # REQUIRED after ANY code changes

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
just test-android '/archive/generated-replays/'  # All battle replay configs
just test-android '/archive/generated-replays/merge-*'  # Merge scenarios

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

# Debug Flow: logs-tree → logs-pattern → logs-text → logs-errors
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
1. **Test Results**: `logs-tree` → `logs-pattern` → `logs-text` → `logs-errors`
2. **Full Android Logs**: `android-logs-search "term"` → `adb logcat -d | rg "term" -i`

**When to Use Full Android Logs:**
- Missing initialization logs? → `android-logs-search` (sees startup)
- Testing validation/fastbuild? → `android-logs-search` (non-debug logs)
- Specific test actions? → `logs-text TEST_ID` (focused)
- General debugging? → `android-logs-search` (complete view)

## 📋 Command Reference

**Testing:**
- `just test-android-target CONFIG` | `just test-desktop-target CONFIG` - Automated testing
- `just test-android TARGET` | `just test-desktop TARGET` - Manual testing
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
- `just logs-text TEST_ID "search_term"` - Text search

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

## 📝 Backlog Management

**Essential Commands:**
- `backlog tasks list --plain` - List tasks by status
- `backlog tasks view task-XXX --plain` - View task details
- `backlog tasks create "Title"` - Create task
- `backlog tasks edit task-XXX` - Edit task
- `backlog tasks edit task-XXX --status Done` - **Update status (REQUIRED for sync)**
- `backlog doc list` - List documents
- `backlog doc view DOC_ID` - View document
- `backlog board` - Kanban view
- `backlog overview` - Project statistics
- `backlog browser` - Interactive browser

**🚨 CRITICAL: Use CLI Commands, Not Direct File Editing**

Backlog maintains separate database that doesn't sync with direct markdown edits.

**Workflow:**
1. **Content Changes**: `backlog tasks edit task-XXX` (opens editor)
2. **Status Changes**: ALWAYS use `backlog tasks edit task-XXX --status Done`
3. **Bulk Updates**: `for task in 248 249 250; do backlog tasks edit task-$task --status Done; done`

**Task Creation & Linking:**
```bash
# Investigation → Documentation → Task Creation
just logs-errors TEST_ID
just logs-text TEST_ID "pattern"
backlog tasks create "Fix discovered issue"
# Add investigation context and links

# Link in commits
git commit -m "fix: description

Related: task-XXX
Analysis: /tmp/analysis_file.md"
```

**Task Frontmatter:**
```yaml
---
id: task-222
title: Fix Android Checksum Collection Race Condition
status: Open              # Open | In Progress | Done
priority: critical        # low | medium | high | critical
labels:
  - critical
  - test-framework
  - android
dependencies:
  - task-221
created_date: '2025-10-15 19:45'
updated_date: '2025-10-15 19:45'
---
```

**Key Document:**
- `backlog doc view doc-002` - Build System Architecture & Workflows

## 🤖 Claude Code Preferences

**Essential Patterns:**
- Use `rg` instead of `grep` (10x faster)
- REQUIRED: `just fastbuild-android` after ANY GDScript/C++ changes before Android testing
- CRITICAL: Prefix long-running commands with `just log-run-silent` (saves tokens)
- Link tasks bidirectionally: Reference task in commit, commit in task
- Use Advanced OODA Loop Debugging (investigation-first with expert panel)

**🚨 FILE SAFETY:**
- NEVER remove/delete files without explicit permission
- ALWAYS ask before removing any files, even temporary ones

**Values:**
- **Simplicity**: Clean, readable code
- **Robustness**: Handle edge cases reliably

**MCP Tools:**
- **Repomix MCP**: Pack codebase once, search multiple times
- **Godot MCP**: Launch editor, run project, get debug output
- **Context7 MCP**: Get up-to-date docs for any library

**📚 Repomix Codebase Analysis (Complete Context Generation)**
```bash
# Generate comprehensive codebase XML for AI analysis
just generate-repofile                    # Creates repomix-output.xml (276+ files)
just generate-claude-context             # Optimized for Claude Code consumption
```

**What's Included in Repomix Output:**
- **Complete Firebase C++ Module**: SCsub, config.py, headers, implementations (13 files)
- **Advanced Logger System**: Runtime debugging infrastructure with UI components
- **Battle System**: Core game mechanics and combat logic (453+ references)
- **Gamestate System**: Save/load functionality and cross-platform state management
- **Checksum Validation**: Determinism testing and platform consistency
- **Core GDScript Systems**: 200+ game logic and utility files

**🎯 How to Leverage Repomix Output:**

**1. Complete Architecture Understanding**
- **Firebase Integration**: Full C++ SDK → GDScript → Game systems pipeline
- **Build System Mastery**: SCons module configuration, platform-specific library linking
- **Platform Build Strategy**: iOS/Android implementations, macOS exclusion patterns
- **Extension Points**: Where to add new modules or modify existing ones

**2. Cross-Platform Development Patterns**
- **Platform Detection Logic**: How systems adapt to iOS/Android/desktop
- **Library Linking Strategies**: Firebase SDK integration for each platform
- **Testing Infrastructure**: Advanced logger platform testing utilities
- **Gamestate Reproduction**: Cross-platform scenario capture and replay

**3. Debugging & Testing Infrastructure**
- **Advanced Logger**: Runtime debugging with tag filtering and platform detection
- **Checksum Validation**: Determinism testing across platforms (126+ references)
- **Gamestate System**: Scenario reproduction and state management (261+ references)
- **Battle Replay System**: Automated testing and regression detection (453+ references)

**4. Development Workflow Integration**
```bash
# Before major architectural changes:
just generate-repofile                    # Get complete current state
# Claude analyzes repomix-output.xml → provides expert recommendations
# Make informed decisions with full context

# For complex debugging:
just generate-repofile                    # Capture current system state
# Claude analyzes complete system → identifies root causes across components
# Provides comprehensive solutions affecting all affected systems

# For feature development:
just generate-repofile                    # Understand existing patterns
# Claude identifies integration points, suggests implementation approaches
# Ensures new features follow established architectural patterns
```

**5. Advanced Use Cases**
- **C++ Module Development**: Complete Firebase build configuration understanding
- **Platform Expansion**: Add new platforms using existing iOS/Android patterns
- **Performance Optimization**: Identify bottlenecks across complete system architecture
- **Testing Enhancement**: Leverage sophisticated checksum/gamestate testing frameworks
- **Documentation Generation**: Auto-generate system architecture documentation

**Key Benefits:**
- **Complete Context Visibility**: 276+ files in single searchable XML
- **Cross-Reference Capability**: See how Firebase integrates with game systems
- **Pattern Recognition**: Identify established architectural patterns
- **Impact Analysis**: Understand ripple effects of changes across systems
- **Knowledge Transfer**: Rapid onboarding for complex system architectures

**💡 Pro Tip**: The repomix output is especially valuable when:
- Starting work on unfamiliar system components
- Planning major architectural changes
- Debugging complex cross-platform issues
- Documenting system architecture for team collaboration
- Onboarding new developers to complex codebase

**Git workflow:**
- Use `git commit --amend` for related documentation updates
- Include "Closes: task-XXX" and "Related: backlog/tasks/..." in commits
- Exception: Use `grep` only for pipeline scripts requiring exact compatibility

## 🔄 OODA Loop Development

**OBSERVE:**
- `just ci-validate` - Code quality, formatting, linting
- `just test` - Cross-platform functionality
- `just logs-errors TEST_ID` - Runtime issues (98% efficiency)

**ORIENT:**
- CI results → Code standards assessment
- Test results → Platform compatibility
- Error analysis → Technical issues

**DECIDE:**
- CI pass/fail → Commit readiness
- Test pass/fail → Feature stability
- Performance → Architectural decisions

**ACT:**
- Failed CI → Fix → `just ci-validate` → Repeat
- Failed tests → `just logs-errors TEST_ID` → Debug → `just fastbuild-android` → Re-test
- All pass → Continue

**Critical Pattern:**
```bash
just ci-validate           # Must pass
just fastbuild-android     # Required after code changes
just test-android CONFIG   # Validate on platform
just logs-errors TEST_ID   # Debug efficiently
```

## 🎯 Advanced OODA Debugging

**Evidence-First Investigation (OBSERVE):**
```bash
just android-logs-search "SEARCH_TERM"     # Full device logs
just logs-errors TEST_ID                   # 98% efficient analysis
just logs-text TEST_ID "specific_term"     # Targeted search
```

**🚨 CRITICAL**: Gather current evidence, not rely on stale documentation.

**Expert Panel Evaluation (ORIENT):**

**Virtual Expert Panel** for complex issues:
- **Systems Architect** - Mobile/game engine expertise
- **Platform Specialist** - Android/Firebase/GDScript integration
- **Test Infrastructure Lead** - Testing patterns, CI/CD impact
- **Performance Engineer** - Timing, threading, optimization
- **Debt Reviewer** - Architecture decisions, maintainability

**Core Questions:**
1. "What would this expert think is the REAL problem?"
2. "What would this expert warn against fixing?"
3. "What evidence would this expert demand?"
4. "What dangerous oversimplification exists?"

**Investigation-First Decisions:**
❌ Avoid: Symptom-based fixes that break working systems
✅ Prefer: Evidence-gathering reveals true state

**Priority:**
1. Investigation (always start here)
2. Targeted Fix (only after understanding)
3. Architecture Review (last resort)
4. Workarounds (avoid - creates debt)

**Minimal Risk Implementation:**
1. Add targeted logging
2. Test and gather evidence
3. Analyze with expert panel mindset
4. Apply minimal fix based on evidence
5. Remove investigation code
6. Document with evidence

**Key Insights:**
- Investigation-first prevents fixing working code
- Error messages show symptoms, not root causes
- Evidence reveals reality vs. assumptions
- Time: 4-6h investigation vs 20-40h risky changes

**Expert Panel Validation:**
Before complex fixes, require unanimous agreement from all expert perspectives on architectural compatibility.

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

## 🚨 Android Log Buffer Limitations

**Root Cause**: Android logcat uses circular buffers (~50KB each) that overwrite older entries when full, causing misdiagnosis.

**Real-World Impact (Task-242)**:
- Investigation showed 2/16 successful Firebase operations
- Reality: 14/16 successful (proven by historical logs)
- Buffer overwrote 12 success entries with newer data
- Cost: 4-6h wasted investigating non-existent regression

**Buffer Status Indicators:**
- **🟢 Safe**: <30,000 lines (≤60% usage)
- **🟡 Caution**: 30,000-50,000 lines (60-90% usage)
- **🔴 Critical**: >50,000 lines (>90% usage)

**Buffer-Safe Investigation:**

**Phase 1: Assessment**
```bash
just android-logs-search "search_term"  # Check buffer status first
```

**Phase 2: Cross-Validation (if saturation detected)**
```bash
find logs/ -name "*.log" -exec grep -l "search_term" {} \;  # Historical logs
just logs-last | grep "search_term"                           # Recent results
```

**Phase 3: Fresh Collection**
```bash
just android-logs-clear                    # Clear buffer
just test-android-target CONFIG           # Re-run test
just android-logs-live 30 "*:I" 50       # Live monitoring
```

**Decision Tree:**
- **Buffer Safe (<60%)** → Use live buffer tools
- **Buffer Caution (60-90%)** → Cross-validate required
- **Buffer Critical (>90%)** → Use historical logs only

**Prevention:**
```bash
just android-logs-clear                    # Clear before testing
just log-run-silent test-android CONFIG   # Save complete output
```

**Red Flags (Buffer Issues):**
- Expected logs missing
- Fewer entries than expected
- Historical patterns disappeared
- Unusually poor performance data

**Response Protocol:**
1. Stop investigation (findings may be misleading)
2. Check buffer saturation
3. Switch to historical sources if critical
4. Re-run tests with cleared buffer

**Golden Rule**: Cross-validate with historical logs when in doubt. Live buffer data may be incomplete.

## 📋 Android Device Logs

**Live Monitoring:**
- `just android-logs-errors 30` - Error monitoring (30s)
- `just android-logs-tagged "firebase" 30 50` - Tag filtering
- `just android-logs-status` - Device & app status

## 🔧 Testing Modes

**Automated:**
- `just test-android-target CONFIG` - Enhanced with validation
- `just test-desktop-target CONFIG` - Cross-platform testing

**Manual:**
- `just test-android-manual CONFIG` - Android inspection
- `just test-desktop-manual CONFIG` - Desktop inspection

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
- ❌ Never use `just run-desktop` (skips state capture)

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

## 🚫 GDScript Anti-Patterns

**NEVER use timing-based waits:**
```gdscript
# ❌ FORBIDDEN
await Engine.get_main_loop().process_frame
await get_tree().create_timer(1.0).timeout

# ✅ Use signals
await some_operation_completed
```

**No `async` keyword:**
```gdscript
# ❌ FORBIDDEN - async doesn't exist
async func my_function() -> void:

# ✅ CORRECT
func my_function() -> void:
    await some_signal  # Function becomes async
```

## 💪 Strong Typing

**Use fail-fast typing:**
```gdscript
# ✅ Required
var firebase_backend: FirebaseBackend = get_backend()
var cards: Array[Card] = []
func create_card(id: String, level: int = 1) -> Card:
    return card_scene.instantiate() as Card

# ❌ Forbidden
if backend is FirebaseBackend:  # Runtime checking
var data = {}                   # No type
```

**Validation:**
- `just validate` - Complete pipeline
- `just show-warnings` - GDScript warnings

## 🎬 Replay Testing

**Workflow: Play → Generate → Test**
1. `just run-desktop` (shows session ID)
2. `just replay-generate-desktop SESSION_ID my-test`
3. `just test-android-target my-test` (automated)

## 🧪 Checksum Testing

**Automatic validation:**
- `just test-android-target CONFIG` - Auto-creates baseline + validates
- `just test-android-update CONFIG` - Update baseline
- `just logs-errors TEST_ID` - Debug failures

**RNG Determinism:** Seeds auto-initialize from debug configs.

**Config seed format:**
```json
{
  "checksum_config": {
    "initial_seed": 12345,
    "state_type": "seed_validation"
  }
}
```

**Never use:** `"game.battle.set_seed"` action

## 🎮 Gamestate System

**Scenario reproduction:**
1. Play → Debug menu → "Save State" → Exit
2. `just capture-gamestate-desktop "scenario_name"`
3. Run → Debug menu → "Saved States" → Load scenario

**Management:**
- `just list-saved-states` - Show states
- `just clean-saved-states` - Remove all states
- `just capture-gamestate-android NAME` - Android extraction

**Test Integration:**
- `just test` - Includes gamestate validation
- `just test-desktop-target gamestate-system-validation` - Complete validation
- `just test-android-target gamestate-system-validation` - Cross-platform testing

**90% faster scenario reproduction - capture Android, load desktop.**

## 🔧 Advanced Features

**Desktop debugging:**
- `just run-desktop-debug` - Normal debug
- `just run-desktop-debug verbose` - ObjectDB leak detection

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

## 📖 Advanced Topics

**See [CLAUDE-ADVANCED.md](CLAUDE-ADVANCED.md) for:**
- Wildcard pattern system deep dive
- Git workflow & backlog integration
- Repomix MCP best practices
- Project architecture & structure
- Performance optimization strategies
- Complete command reference

**Key Documents:**
- **Build System**: `backlog doc view doc-002` - Complete build flows and timing

**MCP Tools:**
- **Repomix MCP**: Strategic codebase analysis for GameTwo's architecture
- **Godot MCP**: Direct Godot 4.3 integration and project management
- **Context7 MCP**: Library documentation for Firebase and GDScript

**For complex tasks:**
- `just generate-claude-context` - Optimized project context (250k tokens)
- Creates `claude-project-context.xml` for full codebase analysis

---

*This CLAUDE.md focuses on daily GameTwo development essentials.*