# CLAUDE-ADVANCED.md

Advanced GameTwo development patterns, detailed workflows, and technical deep-dives.

**This file contains comprehensive details that supplement the essential daily reference in [CLAUDE.md](CLAUDE.md)**

> 📋 For daily GameTwo development, start with [CLAUDE.md](CLAUDE.md) - this file contains the deep-dive details.
> 
> 💡 **Claude can read `just help` commands directly** - use `just help`, `just help-debug`, `just help-logs`, etc. for detailed explanations that supplement both files.

## 🔧 Ripgrep Migration Guide

| Old grep command | New ripgrep equivalent | Notes |
|------------------|------------------------|-------|
| `grep -r "pattern" /path` | `rg "pattern" /path` | Recursive by default |
| `grep -o "pattern" file` | `rg -o "pattern" file` | Extract matches only |
| `grep -l "pattern" files` | `rg -l "pattern" files` | List matching files |
| `grep -c "pattern" file` | `rg -c "pattern" file` | Count matches |
| `grep -E "regex" file` | `rg "regex" file` | Extended regex default |
| `grep -i "pattern" file` | `rg -i "pattern" file` | Case insensitive |
| `grep -v "pattern" file` | `rg -v "pattern" file` | Invert match |
| `grep -A5 -B5 "pattern"` | `rg -A5 -B5 "pattern"` | Context lines |

### Ripgrep Advanced Features
```bash
# Compressed file search (not possible with grep)
rg -z "pattern" logs.gz

# JSON-structured output  
rg --json "pattern" file.log

# Smart case (case-insensitive unless uppercase in pattern)
rg -S "pattern" files

# File type filtering
rg "pattern" -t rust -t javascript

# Multiline pattern matching
rg -U "function.*{.*}" src/
```

## 🚀 Wildcard Pattern System Deep Dive

### Pattern Types & Examples

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

### Discovery Workflow Examples

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

### Advanced Pattern Tips

**Pattern Testing:**
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

## 📋 Git Workflow & Backlog Integration

### Backlog Task → Commit Workflow

**1. Reference task in commit message:**
```bash
git commit -m "$(cat <<'EOF'
feat: implement user authentication system

Add Firebase Auth integration with email/password and OAuth providers.
Includes user session management and profile synchronization.

Closes: task-045
Related: backlog/tasks/task-045 - Implement-user-authentication-system.md

🤖 Generated with [Claude Code](https://claude.ai/code)
Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

**2. Update backlog task with commit reference:**
```markdown
## Completion Summary

**Completed 2025-08-11**: Successfully implemented user authentication system.

**Commit**: `abc123def` - [feat: implement user authentication system](../../commit/abc123def)
```

### Git Best Practices

**Use `git commit --amend` for related updates:**
- When you forgot to include documentation updates
- When backlog task updates are part of the same logical change
- Before pushing to remote (clean history is better than preserving wrong hashes)

**Commit message format:**
```
type(scope): brief description

Detailed explanation of what was changed and why.
Include business context and technical decisions.

Closes: task-XXX
Related: backlog/tasks/task-XXX - Task-Title.md

🤖 Generated with [Claude Code](https://claude.ai/code)
Co-Authored-By: Claude <noreply@anthropic.com>
```

## 🗂️ Project Architecture

**Enhanced Testing System:**
- **Unified Test Execution**: Cross-platform test wrapper with automatic validation
- **Built-in Error Analysis**: Automatic log parsing and failure detection (98% token savings)
- **Automatic Checksum Management**: Baseline creation and validation
- **Progressive Debugging**: Token-efficient error analysis workflow
- **Manual Test Modes**: Both Android and editor support manual inspection modes

**Core Systems:**
- **DataSource Pattern**: Unified Firebase RTDB + local storage backends
- **Debug Framework**: 55 debug actions across 7 categories  
- **Custom Engine**: Modified Godot 4.3 with Firebase/Facebook integration

**Key Directories:**
- `project/debug/actions/` - Debug actions by layer (cpp, backend, rtdb, system, game)
- `tests/debug_configs/` - 9 core configs (organized by layer)
- `tests/test-lists/` - 13+ workflow configurations
- `tests/debug_configs/archive/generated-replays/` - 25+ battle replay configs
- `justfiles/justfile-validation-enhanced-testing.justfile` - Enhanced testing system

## 🔬 Repomix MCP Best Practices for GameTwo

**Strategic use of Repomix MCP for GameTwo's 248-file, 420k+ token codebase:**

### Optimal Pack Strategy

**1. Strategic Use of `compress` Parameter**
```javascript
// For large GameTwo analysis - use compression (70% token reduction)
pack_codebase({
  directory: "/Users/mattiasmyhrman/repos/gametwo",
  compress: true,  
  includePatterns: "project/**/*.gd,justfiles/**/*.justfile"
})

// For focused analysis - skip compression (keep implementation details)
pack_codebase({
  directory: "/Users/mattiasmyhrman/repos/gametwo", 
  compress: false,  
  includePatterns: "project/debug/actions/**/*.gd"
})
```

**2. Smart Pattern Filtering for GameTwo Systems**
```javascript
// Focus on Firebase integration layers
{
  "includePatterns": "project/debug/actions/firebase_*/**/*.gd,project/data/backends/*.gd",
  "ignorePatterns": "**/*test*.gd,**/*.log,project/addons/**"
}

// Justfile testing system analysis
{
  "includePatterns": "justfiles/justfile-*testing*.justfile,justfiles/justfile-*validation*.justfile",
  "ignorePatterns": "justfiles/justfile-help.justfile"
}
```

**3. Incremental Analysis Workflow**
```javascript
// Step 1: Pack once with optimal patterns
const outputId = await pack_codebase({
  directory: "/Users/mattiasmyhrman/repos/gametwo",
  includePatterns: "project/**/*.gd,justfiles/**/*.justfile"
})

// Step 2: Multiple focused searches on same packed output
await grep_repomix_output(outputId, "extends DebugAction", {contextLines: 2})
await grep_repomix_output(outputId, "Firebase.*Backend", {contextLines: 1}) 
await grep_repomix_output(outputId, "just.*test-android", {ignoreCase: true})
```

### GameTwo-Specific Analysis Prompts

**Architecture Analysis:**
```text
This Repomix file contains GameTwo, a Godot 4.3 mobile game with Firebase integration.

Context: 248 GDScript files, 55 debug actions across 5 layers (cpp/backend/rtdb/system/game)

Analyze the debug action architecture:
1. How are the debug actions organized by layer?
2. What patterns ensure consistent FirebaseBackend integration?
3. Which justfile commands provide the most efficient testing workflow?
4. Identify architectural improvements for the sophisticated testing infrastructure

Focus on maintainability and the 420k+ token codebase optimization.
```

**Performance Analysis:**
```text
Analyze GameTwo's performance bottlenecks in this Repomix file:
- Firebase async patterns and DirectAwait implementations
- Debug action execution efficiency across 5 layers
- Justfile build system optimization opportunities  
- GDScript strong typing and memory management patterns

Provide specific optimizations with before/after code examples.
```

### Token Optimization Strategy

**Your GameTwo heavy files:**
- `justfile-validation-enhanced-testing.justfile` (31.4k tokens) 
- `justfile-semantic-replay-commands.justfile` (24.8k tokens)
- `justfile-testing-core.justfile` (14.8k tokens)

**Optimization approaches:**
```javascript
// For justfile analysis - target specific heavy files
{
  "includePatterns": "justfiles/justfile-testing-core.justfile,justfiles/justfile-validation*.justfile"
}

// For GDScript analysis - exclude heavy justfiles 
{
  "includePatterns": "project/**/*.gd",
  "ignorePatterns": "justfiles/**"
}
```

### Productivity Benefits

**Repomix vs Traditional File Reading:**
- **Architecture Understanding**: 10x faster than individual file reads
- **Pattern Discovery**: Instant cross-system relationships 
- **Debug Action Analysis**: Find all actions + relationships in one search
- **Firebase Integration**: Map Firebase Backend references instantly
- **Testing System**: Discover test command patterns systematically

**Daily Development Workflow:**
1. **Pack focused subsystem** (debug actions, Firebase backend, specific justfiles)
2. **Use grep_repomix_output** for pattern discovery across packed content
3. **Leverage compressed packs** for high-level architectural decisions
4. **Incremental analysis** - avoid re-packing, maximize search efficiency

## 📊 Enhanced Debugging Reference Tables

### Failure Pattern Quick Reference

| Symptom | Best Debug Command | Alternative Commands | Fix Command |
|---------|-------------------|---------------------|-------------|
| Firebase timeout/auth | `logs-search TEST_ID "firebase"` | `logs-pattern TEST_ID "firebase.*"` | `test-android 'system.network.*'` |
| All error types | `logs-search TEST_ID "error"` | `logs-pattern TEST_ID "*.error"` | Investigate specific errors |
| Hash mismatch/validation | `logs-search TEST_ID "checksum"` | `logs-pattern TEST_ID "*.checksum"` | `test-android 'game.match.reset_level'` |
| Performance/timeouts | `logs-search TEST_ID "timeout"` | `logs-pattern TEST_ID "performance.*"` | `test-android '*.*.performance'` |
| Integration failures | `logs-search TEST_ID "integration"` | `logs-pattern TEST_ID "*.integrity"` | Fix specific integration issue |
| System warnings | `logs-search TEST_ID "warning"` | `logs-pattern TEST_ID "*.warning"` | Investigate warnings |
| Database issues | `logs-search TEST_ID "database"` | `logs-pattern TEST_ID "database.*"` | `test-android 'database.*'` |
| Network problems | `logs-search TEST_ID "network"` | `logs-multi TEST_ID "*.timeout" "*.error"` | `test-android 'network.*'` |

### Complete Command Reference

**Testing Commands:**
```bash
just test-android TARGET                   # Main interface - AUTOMATIC MODE
just test-editor TARGET                    # Editor interface - AUTOMATIC MODE
just test-android-target CONFIG            # Enhanced automated mode with built-in validation
just test-editor-target CONFIG             # Enhanced editor automated testing
just test-android-enhanced TARGET          # Enhanced error analysis

# Manual testing (stays open for inspection)
just test-android-manual CONFIG            # Android manual mode
just test-editor-manual CONFIG             # Editor manual mode

# Standard workflows
just test-android development-workflow     # Daily development
just test-android pre-commit               # Pre-commit validation

# Enhanced Timeout Support
just test-android TARGET DURATION          # Custom timeout
just test-android-target CONFIG DURATION   # Custom timeout for automated tests
just test-editor-target CONFIG DURATION    # Custom timeout for editor tests

# Environment Variables for Timeout Control
# ANDROID_TEST_MAX_TIMEOUT=300              # Max timeout (default: 120s)
# ANDROID_TEST_ACTIVITY_TIMEOUT=90          # Activity timeout (default: 60s)
# EDITOR_TEST_MAX_TIMEOUT=180               # Editor max timeout (default: 120s)
```

**Real-Time Android Device Log Commands:**
```bash
# Live device monitoring (actual adb logcat, smart filtered)
just android-logs-errors 30               # Live error monitoring (filtered, 30s)
just android-logs-live 60 "*:I" 100       # Live log monitoring (60s, INFO level, max 100 lines)
just android-logs-status                  # Device & app status check
just android-logs-recent 50               # Recent device logs (filtered, max 50 lines)

# Tag-based filtering (noise filtered, configurable limits)
just android-logs-tagged "firebase" 30 50  # Custom tag monitoring (30s, max 50 lines)
just android-logs-performance 60 30       # Live performance monitoring (60s, max 30 lines)
just android-logs-monitor-restart 120 20  # App restart monitoring (120s, max 20 lines)

# Device management (NEW CONSOLIDATED)
just logs-android-device "SEARCH_TERM"   # Device log search (replaces android-logs-search)
just logs-android-clear                    # Clear device buffers (consolidated)
just logs-android-health                   # Buffer health monitoring (new)
just logs-android-status                    # Device & app diagnostics (new)
```

**Smart Filtering Details:**
- **Filters out**: OpenGL, fonts, VSYNC, touch events, buffer dumps
- **Focuses on**: Firebase, debug, errors, tests, performance, startup events
- **Flexible limits**: Default sensible limits, adjustable as final parameter

**Saved Test Result Analysis:**
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

# Core Commands (Streamlined)
just logs-errors TEST_ID                   # Error-focused (98% savings)
just logs-search TEST_ID "search_term"     # Simple text search (replaced logs-text)
just logs-android TEST_ID [component]      # Component analysis (87-95% savings)
just logs-editor TEST_ID [component]       # Editor component analysis
just logs-ios TEST_ID [component]          # iOS component analysis (NEW)
just logs-macos TEST_ID [component]        # macOS component analysis (NEW)

# Performance & Specialized
just logs-performance TEST_ID              # Performance data
just logs-android-errors TEST_ID           # Android errors only
just logs-editor-errors TEST_ID             # Editor errors only
just logs-ios-errors TEST_ID                # iOS errors only (NEW)
just logs-macos-errors TEST_ID              # macOS errors only (NEW)
just logs-lifecycle TEST_ID                # App lifecycle events

# Full logs (avoid unless necessary)
just logs-android TEST_ID                  # Complete logs (high token cost)
just logs-editor TEST_ID                   # Complete logs (high token cost)
just logs-ios TEST_ID                      # Complete logs (high token cost) (NEW)
just logs-macos TEST_ID                    # Complete logs (high token cost) (NEW)
```

## 📁 Detailed Test Organization

### @ Symbol Test List References

**Automatically include configs from other test lists:**

```bash
# Direct test list references
"@system-all"              # Include all configs from system-all.json
"@firebase-all"            # Include all configs from firebase-all.json  
"@battle-all"              # Include all configs from battle-all.json

# Wildcard test list references  
"@*-all"                   # Include configs from ALL test lists ending with "-all"
"@firebase-*"              # Include configs from ALL test lists starting with "firebase-"
"@*-validation"            # Include configs from ALL test lists ending with "-validation"
```

**Example Test List with @ References:**
```json
{
  "name": "All Test Suites",
  "description": "Run all *-all test suites automatically",
  "configs": [
    "@*-all"
  ]
}
```

**Built-in Test Lists Using @ References:**
- `test-all` - Automatically runs ALL `*-all` test suites using `@*-all` pattern
- Automatically prevents circular references and deduplicates configs
- Supports unlimited nesting depth with cycle detection

**Key Benefits:**
- ✅ **Automatic Discovery**: New `*-all` lists are automatically included
- ✅ **No Duplication**: Configs appearing in multiple lists are deduplicated  
- ✅ **Circular Protection**: Built-in circular dependency detection
- ✅ **Easy Maintenance**: Add new test suites without updating master lists

### /folder/ Syntax for Battle Replay Integration

**Automatically include configs from folders:**

```bash
# Folder references
"/archive/generated-replays/"         # Include ALL replay configs from folder
"/archive/generated-replays/merge-*"  # Wildcard pattern within folder  
"/archive/experimental/firebase-*"    # Subfolder with pattern
"/templates/"                         # All configs in templates folder
```

**Available Folders (Relative to /tests/debug_configs/):**
- `/archive/generated-replays/` - 25+ battle replay configs (merge-*, draft-*, locked-*, etc.)
- `/archive/experimental/` - Experimental test configurations  
- `/templates/` - Config templates and examples
- `/` - Direct debug_configs folder access

**Folder Pattern Examples:**
```bash
# All generated battle replays (25+ configs)
just test-android "/archive/generated-replays/"

# Just merge scenarios (merge-20 through merge-25) 
just test-android "/archive/generated-replays/merge-*"

# Draft scenarios 10-14
just test-android "/archive/generated-replays/draft-1*"

# Mix patterns in test-lists
just test-android replay-testing  # Uses folder + @ + direct configs
```

**Key Benefits:**
- ✅ **Instant Replay Access**: All 25+ existing replays immediately available
- ✅ **Auto-Discovery**: New replay configs automatically included
- ✅ **Pattern Matching**: Powerful wildcard support within folders
- ✅ **Mixed Syntax**: Combine `/folder/`, `@symbols`, and direct configs
- ✅ **Error Handling**: Clear messages for missing folders/patterns

### Input Auto-Detection

Commands automatically detect input type:
- **Actions**: `'system.debug.registry_stats'` → Direct execution
- **Wildcards**: `'cpp.*'` → Auto-discovery
- **Configs**: `system-testing` → Load configuration  
- **Test Lists**: `development-workflow` → Execute suite
- **Folder Patterns**: `'/archive/generated-replays/merge-*'` → Folder expansion

### Wildcard Patterns (Hierarchical: layer.domain.operation)

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

## 📱 Complete Android Configuration

### Android Checksum Validation

Resolved critical environment variable propagation issue that was causing Android checksum validation to silently fail. Tests now properly validate all checksums on both Android and editor platforms.

### Complete Debug Configs & Test Lists

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

### Logger Control (Runtime)
```bash
just config-android-tags "firebase,battle" "cache,animation" # Focus/filter components
just config-android-level DEBUG                             # Set log verbosity  
just config-android-reset                                   # Reset to defaults
just restart-android-app                                    # Apply changes
```

## 🎮 Complete Gamestate System Details

### Implementation Details
- **Captures**: Complete game state (units, lineup, level, RNG) via existing StateExtractor
- **Storage**: JSON files in `project/debug/saved_states/` 
- **Loading**: Restores RNG state + recreates cards + applies board state
- **Integration**: Works seamlessly with existing debug action system
- **Performance**: Save <100ms, Load <50ms on target platforms

### Common Use Cases
```bash
# Complex bug reproduction
just run-editor → reproduce bug → save state → capture-gamestate "bug_scenario" 
# → Load state repeatedly for testing different fixes

# Feature testing from specific conditions
just run-editor → set up scenario → save state → capture-gamestate "feature_test"
# → Load state → test different feature variations

# Battle testing from exact lineup
just run-editor → configure lineup → save state → capture-gamestate "battle_setup"
# → Load state → test battle scenarios with deterministic RNG
```

### Key Benefits for Development
- **90% faster scenario reproduction** (minutes → seconds)
- **Cross-platform support** - capture from Android, load on editor or vice versa
- **Instant access** to any captured game state from any platform
- **Perfect replay integration** - loaded states work as recording starting points
- **Zero setup** - leverages existing StateExtractor + DeterministicRNG systems
- **Platform-specific commands** - explicit control over editor vs Android workflows

## 🎮 Godot MCP Integration for GameTwo

**Direct Godot 4.3 Engine Integration:**

### Core Godot MCP Functions
```bash
# Project Management
mcp__godot__launch_editor(projectPath)     # Launch Godot editor for GameTwo
mcp__godot__run_project(projectPath)       # Run GameTwo project with output capture
mcp__godot__get_debug_output()             # Get current debug output and errors
mcp__godot__stop_project()                 # Stop running GameTwo project

# Project Information
mcp__godot__get_project_info(projectPath)  # Get GameTwo project metadata
mcp__godot__get_godot_version()            # Get installed Godot version
mcp__godot__list_projects(directory)       # List Godot projects in directory
```

### GameTwo-Specific Godot Workflows
```bash
# Development Workflow Integration
1. Use mcp__godot__launch_editor to open GameTwo in editor
2. Use mcp__godot__run_project for testing scenarios
3. Use mcp__godot__get_debug_output for error analysis
4. Combine with just commands for comprehensive debugging

# Scene Management (if needed)
mcp__godot__create_scene(projectPath, scenePath, rootNodeType)
mcp__godot__add_node(projectPath, scenePath, nodeType, nodeName)
mcp__godot__save_scene(projectPath, scenePath)
```

### Benefits for GameTwo Development
- **Direct engine integration** - No shell command overhead
- **Real-time debug output** - Capture Godot logs directly
- **Scene manipulation** - Programmatic scene editing if needed
- **Project validation** - Verify project structure and settings

## 📚 Context7 MCP for GameTwo Libraries

**Up-to-date documentation for GameTwo's tech stack:**

### Core Context7 Functions
```bash
# Library Resolution
mcp__Context7__resolve-library-id(libraryName)  # Find Context7-compatible library ID
mcp__Context7__get-library-docs(libraryId)      # Fetch comprehensive documentation
```

### GameTwo Library Documentation Patterns
```bash
# Firebase Integration
resolve-library-id("Firebase SDK")              # Get Firebase library ID  
get-library-docs("/firebase/firebase", tokens=5000, topic="realtime-database")

# Godot Framework
resolve-library-id("Godot")                     # Get Godot documentation
get-library-docs("/godotengine/godot", tokens=8000, topic="GDScript")

# Mobile Development
resolve-library-id("Android SDK")               # Android development docs
resolve-library-id("iOS SDK")                   # iOS development docs
```

### Benefits for GameTwo Development
- **Always current** - Up-to-date library documentation
- **Contextual help** - Focus on specific topics (Firebase, GDScript, mobile)
- **Best practices** - Latest patterns and recommendations
- **Problem solving** - Current solutions for integration issues

## 📋 Backlog Management with MCP Agent

**Project-manager-backlog agent for GameTwo task management:**

### Core Backlog Functions
The project-manager-backlog agent uses the backlog.md CLI tool for structured task management:

```bash
# Task Management
backlog task list                    # List all tasks in backlog
backlog task create "task description" # Create new properly formatted task
backlog task edit task-123           # Edit existing task
backlog task status task-123 done    # Update task status

# Task Guidelines  
- Tasks must be atomic, independent units of work
- Follow backlog.md formatting standards
- Include proper priority and estimation
- Link to related GameTwo components (GDScript files, configs, etc.)
```

### GameTwo-Specific Task Patterns
```bash
# Firebase Integration Tasks
backlog task create "Fix Firebase authentication timeout in cpp layer"
backlog task create "Optimize Firebase RTDB connection pooling for mobile"

# Debug System Tasks  
backlog task create "Add new debug action for battle state validation"
backlog task create "Enhance logs-pattern command with regex support"

# Testing Infrastructure Tasks
backlog task create "Create automated test for checksum validation system"
backlog task create "Add battle replay config for merge-scenario testing"
```

### Integration with Git Workflow
```bash
# Bidirectional linking (as mentioned in main CLAUDE.md)
1. Reference task in commit: "Closes: task-123"
2. Update task with commit hash when completed
3. Use backlog agent to ensure proper task format and dependencies
```

## 🔧 MCP Tools Integration Strategy

**Optimal workflow combining all MCP tools:**

### Development Workflow Integration
```bash
# 1. Architectural Analysis (Repomix MCP)
pack_codebase({directory: "GameTwo", includePatterns: "project/**/*.gd"})
grep_repomix_output(outputId, "Firebase.*Backend")

# 2. Engine Testing (Godot MCP)  
mcp__godot__run_project("/Users/mattiasmyhrman/repos/gametwo")
mcp__godot__get_debug_output()

# 3. Documentation Research (Context7 MCP)
resolve-library-id("Firebase Realtime Database")
get-library-docs(libraryId, topic="error-handling-patterns")

# 4. Task Management (Backlog MCP Agent)
backlog task create "Implement Firebase error handling improvements"
```

### Problem-Solving Workflow
```bash
# Complex Firebase integration issue:
1. Use Repomix MCP to analyze all Firebase-related code patterns
2. Use Context7 MCP to get latest Firebase documentation and solutions  
3. Use Godot MCP to test fixes in real-time with debug output
4. Use Backlog agent to create properly structured follow-up tasks
5. Combine insights with just logs-pattern for comprehensive debugging
```

### Benefits of Combined Approach
- **10x faster problem resolution** - Multiple analysis vectors
- **Comprehensive context** - Code + docs + runtime behavior + task management
- **Up-to-date solutions** - Latest patterns and documentation
- **Structured workflow** - All tools work together with just commands and backlog management