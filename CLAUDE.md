# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GameTwo is a sophisticated mobile game built with a custom Godot 4.3 engine. The project features a custom-compiled Godot engine with specialized modules for Firebase integration, Facebook SDK, and advanced data management.

## Architecture

### Core Components
- **Data Abstraction Layer**: Unified interface supporting multiple backends (Firebase RTDB, local storage) via `DataSource` pattern
- **Debug System**: Comprehensive testing framework with config-driven automated testing and device deployment
- **Custom Godot Build**: Modified Godot 4.3 engine with integrated Firebase and Facebook modules
- **Mobile-First Design**: Optimized for 1080x1920 portrait orientation with touch controls

### Key Directories
- `project/` - Main Godot project files and game logic
- `godot/` - Custom Godot engine source code and build artifacts
- `firebase/` - Firebase configuration and integration files
- `export/` - Platform-specific export configurations (iOS/Android)
- `tools/` - Development utilities and helper scripts

## Essential Development Commands

### 🚀 Unified Testing Interface (NEW - PREFERRED)
**Single commands handle any target type with auto-detection!**
```bash
# 🎯 Unified Testing - Auto-detects patterns, configs, and test lists
just test-android 'backend.*'                          # Wildcard pattern
just test-android system-testing                       # Config file
just test-android comprehensive-test-all               # Test list

# 🔍 Enhanced Analysis - Detailed error categorization & performance tracking
just test-android-enhanced 'cpp.*'                     # Enhanced wildcard analysis
just test-android-enhanced performance-all             # Enhanced config analysis
just test-android-enhanced pre-commit                  # Enhanced test list analysis

# ⚡ Specialized Commands
just test-monitor-android 30                           # Pure log monitoring (no restarts)
just test-all-android                                  # Complete test suite
```

### 🔧 Quick Iteration Commands
```bash
# 🚀 Ultra-fast iteration (5-second cycles)
just config-restart-android 'cpp.firebase.error_handling'   # Instant action test + restart
just config-restart-ios 'system.network.rtdb_status'        # iOS equivalent
just fastbuild-android                                      # Rebuild after code changes

# ⚙️ Configuration Management
just config-set 'system.debug.print_info'                  # Set single action as default config
```

### 📊 Log Analysis (Aligned Interface)
```bash
# 📋 Unified Log Commands
just logs-android TEST_ID                              # Show logs for test
just logs-android-results TEST_ID                      # Show results only
just logs-android-errors TEST_ID                       # Show errors only
just logs-android-performance TEST_ID                  # Show performance breakdown
just logs-android-recent                               # Show recent test runs
just logs-android-cleanup 10                           # Clean up old logs
```

### 🎛️ Desktop & Discovery
```bash
just run-desktop                           # Instant local testing
just list-test-lists                       # Show available test lists
just help                                  # View all available commands
```

### ✅ Code Validation & Quality Assurance
```bash
# 🚀 Fast Syntax Validation (3 seconds)
just validate                              # Fast gdparse-based syntax checking
just format                                # Format all GDScript files

# 🔍 Runtime Validation (10-15 seconds)
just validate-godot                        # Runtime validation - errors only (default)
just validate-godot all                    # Runtime validation - full output  
just validate-godot "INFO.*debug"          # Custom filter patterns
just validate-godot "WARN"                 # Show warnings only

# 💡 Use Cases:
# - validate: Quick syntax check during development
# - validate-godot: Full runtime validation with game initialization
# - Custom filters: Focus on specific log types or components
```

### Engine Development
```bash
just godot-build-editor                   # Build custom Godot editor
just godot-build-templates               # Build export templates
```

## Data Architecture

The project uses a sophisticated data abstraction layer:

### DataSource Pattern
- `FirebaseDataSource` - Firebase Realtime Database backend
- `LocalDataSource` - Local storage backend  
- `DataSourceManager` - Handles backend switching and fallbacks

### Configuration System
- JSON-based configuration management
- Hot-swappable configs via debug system
- Environment-specific settings (testing/production)

## Debug System

Advanced testing infrastructure with:

### Automated Testing
- Config-driven test execution
- Device deployment automation
- Log analysis and result validation
- Cross-platform test consistency

### Debug Actions
Located in `project/debug/actions/`, includes:
- Real-time database operations
- Performance testing
- Network connectivity validation
- Data integrity checks

## 🚀 Unified vs Config Commands - Key Differences

### **Unified Commands (`test-android*`) - Smart Auto-Detection**
**Purpose**: Comprehensive testing with intelligent target detection
- 🎯 **Auto-Detection**: Automatically identifies patterns, configs, and test lists
- 📊 **Complete Analysis**: Full logs, pass/fail analysis, test IDs
- ⏱️ **Duration**: 30+ seconds for thorough testing
- 🧪 **Use case**: Primary testing interface for all scenarios

```bash
just test-android TARGET [DURATION]              # Unified testing with auto-detection
just test-android-enhanced TARGET [DURATION]     # Enhanced analysis with error categorization
just test-android-trace TARGET [DURATION]        # Shows detailed validation/config steps (debugging)
just test-monitor-android [DURATION]             # Pure log monitoring (no restarts)
just test-all-android                            # Complete test suite
```

### **Config Commands (`config-*`) - Fast Deployment**
**Purpose**: Configuration management and ultra-fast iteration
- ⚡ **Speed**: 2-5 seconds maximum 
- 🎯 **Focus**: Deploy configs and restart apps instantly
- 🔧 **Use case**: Development iteration cycles

```bash
just config-push-android <config>        # Push config (2 sec, no restart)
just config-restart-android <config>     # Push + restart (5 sec total)
just config-set <pattern>                # Update embedded config
just config-status-android               # Check current config
```

### **When to Use Each**
- **Primary Testing**: Use `test-android` for comprehensive testing with auto-detection
- **Enhanced Debugging**: Use `test-android-enhanced` for detailed error analysis
- **Quick Iteration**: Use `config-restart-android` for rapid 5-second deployment cycles
- **Monitoring**: Use `test-monitor-android` to observe ongoing activity
- **Validation**: Use `test-all-android` for comprehensive pre-commit checks

### **🔄 Smart Timer Reset Logic**
**Enhanced timeout behavior ensures reliable testing across multiple actions:**

- ⏱️ **Per-Action Reset**: Timer resets after each individual action completes (`DEBUG_TEST_SUCCESS`/`DEBUG_TEST_FAILURE`)
- 🔄 **No Cumulative Timeout**: Multiple actions can run sequentially without cumulative timeout issues
- ⚡ **Individual Action Window**: Each action gets the full timeout duration (e.g., 30 seconds)
- 🛡️ **Fail-Fast**: Only individual actions that exceed the timeout will fail

**Examples:**
```bash
# These run reliably regardless of action count:
just test-android 'cpp.*' 30                    # 9 actions, each gets 30s window
just test-android '*.firebase.*' 60             # 15+ actions, each gets 60s window  
just test-android comprehensive-test-all 30     # 40+ actions, timer resets per action
```

**Before vs After:**
- ❌ **Before**: Timer ran cumulatively → Tests with many actions would timeout
- ✅ **After**: Timer resets per action → Only slow individual actions timeout

### **🔍 Debug Trace Mode**
**Detailed visibility into how the testing system processes different input types:**

```bash
# Trace mode shows step-by-step validation and routing
just test-android-trace 'system.debug.registry_stats'    # Action detection steps
just test-android-trace 'system.*'                       # Wildcard pattern steps  
just test-android-trace 'system-testing'                 # Config file detection steps
just test-android-trace '@pre-*'                         # Test list wildcard steps
just test-android-trace 'invalid.name'                   # Error detection steps
```

**What trace mode shows:**
- 🔍 **Step-by-step validation**: Each detection path attempted
- ✅ **Match confirmation**: Which validation succeeded and why
- 📁 **File resolution**: Config file paths and contents preview
- 🔧 **Route selection**: Which execution path was chosen
- ❌ **Failure points**: Exactly where validation failed

**When to use trace mode:**
- 🐛 **Debugging issues**: Understanding why a test target isn't found
- 📚 **Learning the system**: See how auto-detection works internally
- 🔧 **Development**: Verify new patterns work as expected
- 🚨 **Troubleshooting**: Diagnose config or validation problems

## Development Workflow
0. **Planning**: Think through implementation and assess ways to improve quality and simplicity. Use planning tools and basic-memory. Assess if we should build tests in advance for Test driven Development
1. **Local Development**: Use `just run-desktop` for rapid iteration and use Godot tools
2. **Code Validation**: Use `just validate` for fast syntax checking during development
3. **🎯 Unified Testing**: Use `just test-android TARGET` for comprehensive testing (auto-detects patterns/configs/lists)
4. **Quick Iteration**: Use `just config-restart-android 'Action Name'` for ultra-fast 5-second cycles
5. **Enhanced Debugging**: Use `just test-android-enhanced TARGET` for detailed error analysis and performance tracking
6. **Build Updates**: Use `just fastbuild-android` to rebuild and transfer changes to Android device
7. **Pre-Commit Validation**: Run `just validate-godot` for runtime validation and `just test-all-android` before commits
8. **Engine Changes**: Rebuild with `just godot-build-*` commands when modifying Godot source

## 💪 Strong Typing & Code Quality

### Philosophy: Fail-Fast with Strong Typing

The codebase emphasizes **strong typing** and **fail-fast principles** to catch errors at compile time rather than runtime. This approach significantly improves code reliability, maintainability, and debugging efficiency.

### Core Typing Principles

#### ✅ **Always Specify Types**
```gdscript
# ✅ Good - Explicit typing
var player_data: Dictionary = {}
var card_list: Array[Card] = []
var success_rate: float = 0.8

# ❌ Avoid - Untyped variables
var player_data = {}
var card_list = []
var success_rate = 0.8
```

#### ✅ **Use Typed Arrays**
```gdscript
# ✅ Good - Specific element types
var cards: Array[Card] = []
var player_names: Array[String] = []
var debug_results: Array[Dictionary] = []
var event_args: Array[Variant] = []  # When mixed types needed

# ❌ Avoid - Untyped arrays
var cards: Array = []
var player_names: Array = []
```

#### ✅ **Strong Function Signatures**
```gdscript
# ✅ Good - Complete type annotations
func create_card_from_id(id: String, level: int = 1) -> Card:
    var card_info: Dictionary = await data_source.cards.get_by_id(id, true)
    var card_scene: PackedScene = load(card_scene_name)
    var card_instance: Card = card_scene.instantiate() as Card
    card_instance.init_card(card_info, level)
    return card_instance

# ❌ Avoid - Missing return types or parameter types
func create_card_from_id(id, level = 1):
    # Implementation...
```

#### 🚫 **CRITICAL: Avoid 'as' and 'is' Constructs**

**Philosophy: Use strongly typed variables to catch problems at compile time, not runtime.**

```gdscript
# ✅ BEST - Strongly typed variables catch type errors immediately
func get_firebase_backend() -> FirebaseBackend:
    return _backend  # Will fail at compile time if wrong type

func process_backend() -> void:
    var firebase_backend: FirebaseBackend = get_firebase_backend()
    var available: bool = firebase_backend.is_available()

# ✅ Good - Direct assignment with strong typing (will crash fast if wrong)
var firebase_backend: FirebaseBackend = _backend
var available: bool = firebase_backend.is_available()

# ❌ BAD - Runtime type checking hides problems until runtime
if _backend is FirebaseBackend:
    var firebase_backend: FirebaseBackend = _backend as FirebaseBackend
    available = firebase_backend.is_available()

# ❌ BAD - Type casting masks design problems
var firebase_backend: FirebaseBackend = _backend as FirebaseBackend
```

**Why avoid 'as' and 'is'?**
- **'as' casting** hides type mismatches until runtime - problems should be caught at compile time
- **'is' checking** indicates weak type design - use proper type hierarchies instead
- **Runtime checks** delay problem discovery - fail fast at compile time instead
- **Type casting** suggests architectural issues - fix the design, don't mask it

#### ✅ **Prefer Specific Types over Variant**
```gdscript
# ✅ Good - Use specific types when possible
func process_card_data(card_info: Dictionary) -> bool:
    var card_id: String = card_info.get("id", "")
    var card_level: int = card_info.get("level", 1)
    return card_id != "" and card_level > 0

# ⚠️ Use Variant only when truly dynamic
func handle_debug_result(result: Variant) -> bool:
    # Acceptable when handling truly dynamic data
    if result is DebugAction.Result:
        return result.is_success()
    elif result is bool:
        return result
    return false
```

### Type Safety Patterns

#### **Collection Initialization**
```gdscript
# ✅ Initialize with proper types
var _rules: Dictionary = {}
var _cache: Dictionary = {}
var _actions: Array[DebugAction] = []
```

#### **Event Handler Parameters**
```gdscript
# ✅ Properly typed event handlers
func _on_debug_event(event_type: DebugManager.DebugEventType, args: Array[Variant] = []) -> void:
    match event_type:
        DebugManager.DebugEventType.EVENT_OPEN_DEBUG_MENU:
            show_debug_menu()
```

#### **Factory Methods**
```gdscript
# ✅ Strong typing in factory patterns
static func new_success(
    payload: Variant = null,
    duration_ms: int = 0,
    operation: String = "",
    metadata: Dictionary = {}
) -> DebugAction.Result:
    return DebugAction.Result.new(
        true, payload, "", "", ErrorCategory.NONE, duration_ms, operation, metadata
    )
```

### Validation & Quality Assurance

#### **Format & Validate Commands**
```bash
# Run these commands regularly to maintain code quality
just format        # Format all GDScript files
just validate       # Run type checking and validation
```

#### **Common Type Issues to Watch For (Priority Order)**

🚨 **CRITICAL - Fix Immediately:**
1. **'as' type casting** - Replace with strongly typed variables that fail fast
2. **'is' type checking** - Replace with proper type design and strong typing
3. **Untyped variables** - Always add explicit type annotations

⚠️ **HIGH PRIORITY:**
4. **Generic Arrays** - Specify element types: `Array[String]`, `Array[Dictionary]`
5. **Missing return types** - Add `-> Type` to all function declarations
6. **Variant overuse** - Use specific types when the data structure is known

#### **Anti-Patterns to Eliminate**
```gdscript
# 🚨 ELIMINATE - These patterns hide problems
if node is Button:
    var button: Button = node as Button
    button.pressed.connect(callback)

if result is Dictionary:
    var data: Dictionary = result as Dictionary
    process_data(data)

# ✅ REPLACE WITH - Strong typing that fails fast
var button: Button = get_button_node()  # Fails immediately if wrong type
button.pressed.connect(callback)

var data: Dictionary = get_result_data()  # Clear, typed interface
process_data(data)
```

#### **Architectural Patterns to Replace 'as'/'is'**

**Instead of runtime type checking, use proper design:**

```gdscript
# ❌ BAD - Runtime type checking pattern
func handle_node(node: Node) -> void:
    if node is Button:
        var button: Button = node as Button
        button.text = "Clicked"
    elif node is Label:
        var label: Label = node as Label
        label.text = "Updated"

# ✅ GOOD - Polymorphic design with strong typing
func handle_button(button: Button) -> void:
    button.text = "Clicked"

func handle_label(label: Label) -> void:
    label.text = "Updated"

# ✅ BETTER - Factory pattern with strong typing
func create_ui_element(type: UIElementType) -> Control:
    match type:
        UIElementType.BUTTON:
            return create_button()  # Returns Button
        UIElementType.LABEL:
            return create_label()   # Returns Label
        _:
            assert(false, "Unknown UI element type")
            return Control.new()

# ✅ BEST - Interface-based design
class_name Clickable
extends RefCounted
# Define interface that both Button and custom controls implement

func handle_clickable(clickable: Clickable) -> void:
    clickable.on_click()  # No casting needed, interface guarantees method exists
```

**Key principle: If you need 'as' or 'is', redesign the architecture to use proper types.**

#### **Error Messages as Guidance**
The validation system provides detailed feedback:
- `Variable "name" has no static type` → Add type annotation
- `Array argument mismatch` → Use typed arrays
- `Casting "Variant" to "Type" is unsafe` → Strengthen type system

### Benefits Achieved

✅ **Compile-time error detection** - Issues caught before runtime  
✅ **Better IDE support** - Improved autocomplete and error highlighting  
✅ **Self-documenting code** - Types serve as inline documentation  
✅ **Refactoring safety** - Type system catches breaking changes  
✅ **Performance improvements** - Godot can optimize typed code better  
✅ **Debugging efficiency** - Clear error messages with specific type information  

### Integration with Development Workflow

**During Development:**
1. Write code with explicit types from the start
2. Use `just validate` to catch syntax and type issues early (3 seconds)
3. Run `just format` before commits to maintain consistency

**Before Commits:**
1. Run `just validate-godot` for comprehensive runtime validation (10-15 seconds)
2. Ensure all validation passes without type warnings
3. Run full test suite to verify type safety doesn't break functionality
4. Address any "has no static type" warnings in validation output

**Validation Command Summary:**
- `just validate`: Fast syntax checking during development
- `just validate-godot`: Runtime validation with game initialization
- `just validate-godot "ERROR:"`: Focus on typing errors (default)
- `just validate-godot all`: Full diagnostic output when needed

This strong typing approach creates a more robust, maintainable codebase that fails fast during development rather than at runtime in production.

## 🧠 Advanced Planning & Task Management

### When to Use Shrimp Task Manager MCP
**Use for complex technical planning requiring systematic breakdown:**
- Multi-component system design (like enhanced monitoring systems)
- Features requiring 5+ interconnected tasks  
- Architecture changes affecting multiple systems
- Technical debt reduction requiring coordinated changes
- Integration projects involving external libraries/SDKs

**Don't use for simple tasks:**
- Single file modifications
- Bug fixes with clear scope
- Adding individual debug actions
- Simple configuration changes
- Documentation updates

### Shrimp Task Manager Benefits vs. Basic TodoWrite
**Shrimp MCP provides:**
- ✅ **Systematic methodology**: Enforced planning phases (plan → analyze → reflect → split)
- ✅ **Quality validation**: Built-in architectural consistency checks and over-engineering prevention
- ✅ **Dependency management**: Automatic validation of task dependencies and execution order
- ✅ **Engineering best practices**: Guided toward maintainable, testable task breakdown
- ✅ **Senior architect review**: Acts like having an experienced reviewer check your planning

**Basic TodoWrite sufficient for:**
- ✅ Simple task tracking and progress monitoring
- ✅ Straightforward feature additions
- ✅ Bug fix workflows
- ✅ Daily development task management

### Planning Tool Selection Guide
```bash
# Complex system design - Use Shrimp Task Manager
Task: "Implement enhanced test monitoring with action-level granularity"
→ mcp__mcp-shrimp-task-manager__plan_task

# Simple feature addition - Use TodoWrite  
Task: "Add new debug action for data validation"
→ TodoWrite

# Medium complexity - Start with TodoWrite, escalate if needed
Task: "Refactor debug action execution flow"
→ TodoWrite first, then Shrimp if task grows complex
```

## 🔧 Unified Testing Interface (Debugging Superpower)

**Single commands handle any target type with intelligent auto-detection:**

### Core Unified Commands
```bash
# 🎯 Auto-Detection Testing (comprehensive analysis)
just test-android 'cpp.firebase.error_handling'          # Single action with full analysis
just test-android 'cpp.*'                                # All C++ layer tests
just test-android '*.firebase.set_value'                 # All set_value operations
just test-android system-testing                         # Config file
just test-android pre-commit                             # Test list

# 🔍 Enhanced Analysis (detailed error categorization)
just test-android-enhanced 'backend.firebase.performance'  # Enhanced single action analysis
just test-android-enhanced '*.*.error_handling'            # Enhanced cross-layer error analysis
just test-android-enhanced performance-all                 # Enhanced config analysis

# ⚡ Quick Iteration (5-second cycles)  
just config-restart-android 'cpp.firebase.error_handling' # Ultra-fast single action testing
just config-restart-android 'system.*'                    # Ultra-fast wildcard testing

# 👁️ Pure Monitoring
just test-monitor-android 30                              # Pure log monitoring (30 seconds)
just test-monitor-android 60                              # Extended monitoring (60 seconds)
```

### When to Use Each Method
- **Unified Testing**: 🎯 Primary interface for comprehensive testing with auto-detection
- **Enhanced Analysis**: 🔍 Detailed debugging with error categorization and performance tracking
- **Quick Iteration**: ⚡ Ultra-fast 5-second cycles for rapid development
- **Pure Monitoring**: 👁️ Observe ongoing activity without disruption

### Smart Command Detection
All commands automatically:
- ✅ Detect if argument is an action name vs config file
- ✅ Create temporary JSON configs for single actions  
- ✅ Clean up temporary files after operations
- ✅ Handle action names with spaces when properly quoted
- ✅ Provide immediate feedback on action availability

### 💡 Pro Tips for Unified Testing
```bash
# 1. Use unified commands for comprehensive analysis (auto-detects target type!)
just test-android 'cpp.firebase.error_handling'          # Single action with full analysis
just test-android 'cpp.*'                                # All C++ actions
just test-android '*.firebase.*'                         # All Firebase actions
just test-android system-testing                         # Config file
just test-android pre-commit                             # Test list

# 2. Enhanced analysis for detailed debugging
just test-android-enhanced 'cpp.*'                       # Enhanced C++ analysis with error categorization
just test-android-enhanced '*.*.error_handling'          # Enhanced cross-layer error analysis
just test-android-enhanced performance-all               # Enhanced performance analysis

# 3. Quick iteration for rapid development
just config-restart-android 'cpp.firebase.error_handling' # Ultra-fast 5-second cycles
just fastbuild-android && just config-restart-android 'system.*'  # Build + quick test

# 4. Monitor logs in real-time during development
just test-monitor-android 30                             # Monitor all activity (30 sec)
just test-monitor-android 60                             # Extended monitoring (60 sec)

# 5. Set frequently used patterns as default
just config-set '*.firebase.set_value'                   # All set_value operations
just config-set 'system.debug.*'                         # All debug utilities
```

### ⚠️ Choose the Right Tool for the Job
**Match your command to your debugging needs:**

```bash
# ✅ For comprehensive analysis - use unified commands
just test-android 'cpp.firebase.error_handling'          # Full analysis with auto-detection

# ✅ For enhanced debugging - use enhanced commands  
just test-android-enhanced 'cpp.*'                       # Error categorization + performance tracking

# ✅ For rapid iteration - use config commands
just config-restart-android 'cpp.firebase.error_handling' # Ultra-fast 5-second cycles

# ❌ Avoid mismatched tools
just test-android comprehensive-test-all                 # Overkill for single action debugging
just config-restart-android comprehensive-test-all       # Can't restart with test lists
```

**Why Unified Commands Are Better for Most Debugging:**
- 🎯 **Auto-detection** - handles any target type intelligently
- 📊 **Complete analysis** - full logs, pass/fail analysis, test IDs
- 🔍 **Enhanced options** - detailed error categorization available
- 🧠 **Smart feedback** - shows available options when target not found

## Firebase Integration

- Real-time database for live data synchronization
- Custom authentication flow
- Analytics and crash reporting
- Cloud functions for server-side logic

## Mobile Deployment

### Platform Requirements
- **Android**: API level 21+ (Android 5.0+)
- **iOS**: iOS 12.0+
- **Resolution**: Optimized for 1080x1920 portrait

### Export Process
- Automated builds via justfile commands
- Platform-specific configurations in `export/` directory
- Integrated signing and provisioning
#### Tools
- Use Godot tools to start editor , run project and read output quickly if current iteration is not device specific
- Validate changes in gdscript with 'just format' and 'just validate'
- run all tests after a change is complete to verify integrity


## Testing Philosophy

The project emphasizes rapid iteration with comprehensive validation:
- 5-second config testing cycles for immediate feedback
- Automated device deployment eliminates manual steps
- Configuration-driven testing ensures consistency
- Configurable test lists in `project/test-lists/` for flexible test organization
- Retroactive log analysis enables thorough debugging

### Test List System (Focused & Streamlined)
Test configurations are organized into essential test lists:
- `default-all.json` - Complete test suite (used by `test-all-android`)
- `development-workflow.json` - Daily development cycle testing
- `pre-commit.json` - Pre-commit validation tests
- `production-ready.json` - Release readiness validation
- `wildcard-discovery.json` - Wildcard pattern demonstration

Create custom test lists by adding JSON files to `project/test-lists/` with the format:
```json
{
  "name": "Custom Test Suite",
  "description": "Description of what this test suite covers",
  "configs": ["config1", "config2", "config3"]
}
```

## 🎯 Advanced Wildcard System

The debug system features a comprehensive wildcard pattern matching system for both debug actions and test lists, enabling zero-maintenance auto-discovery and powerful pattern-based testing.

### 🔥 Debug Action Wildcards

#### Hierarchical Action Naming
All debug actions follow the `layer.domain.operation` format:
- **Layers**: `cpp`, `backend`, `rtdb`, `system`, `game`
- **Domains**: `firebase`, `debug`, `match`, etc.
- **Operations**: `set_value`, `get_value`, `error_handling`, `performance`, etc.

#### Wildcard Patterns
```bash
# Layer-specific wildcards
"cpp.*"                    # All C++ Firebase SDK tests
"backend.*"                # All Backend Firebase tests  
"rtdb.*"                   # All RTDB GDScript API tests
"system.*"                 # All system utility tests
"game.*"                   # All game logic tests

# Domain-specific wildcards  
"*.firebase.*"             # All Firebase tests across all layers
"*.debug.*"                # All debug utilities across all layers
"*.match.*"                # All match functionality tests

# Operation-specific wildcards
"*.*.set_value"            # All set_value operations across all layers
"*.*.get_value"            # All get_value operations across all layers
"*.*.error_handling"       # All error handling tests across all layers
"*.*.performance"          # All performance tests across all layers

# Cross-layer combinations
"*.firebase.set_value"     # Set value operations across Firebase layers
"cpp.firebase.*"           # All C++ Firebase operations
"backend.*.performance"    # All Backend performance tests
```

#### Example Config Files
```json
{
  "description": "Cross-layer Firebase testing",
  "actions": [
    "*.firebase.set_value",
    "*.firebase.get_value", 
    "*.*.error_handling"
  ]
}
```

### 📋 Test List Wildcards and Nesting

#### Nested Test Lists (@listname syntax)
Test lists can include other test lists using `@listname` syntax:
```json
{
  "name": "Comprehensive Testing",
  "description": "Combines multiple test suites",
  "configs": [
    "@quick-validation",      // Include entire quick-validation test list
    "@firebase-basic",        // Include entire firebase-basic test list
    "performance-all",        // Include specific config
    "@firebase-advanced"      // Include entire firebase-advanced test list
  ]
}
```

#### Wildcard Test List Matching
Reference multiple test lists using wildcard patterns:
```json
{
  "name": "All Firebase Tests",
  "description": "Auto-discovers all firebase-* test lists",
  "configs": [
    "@firebase-*",            // All test lists starting with 'firebase-'
    "@*-validation",          // All test lists ending with '-validation'
    "smoke-test"              // Plus specific configs
  ]
}
```

#### Advanced Examples
```json
{
  "name": "Smart Auto-Discovery",
  "description": "Combines nested lists and wildcards",
  "configs": [
    "@quick-*",               // All quick-* test lists
    "@*-firebase-*",          // All *-firebase-* test lists  
    "@development-*",         // All development-* test lists
    "integration-test"        // Plus specific tests
  ]
}
```

### 🚀 Practical Usage Examples

#### Development Workflow
```bash
# Quick iteration with wildcards
just config-restart-android '*.firebase.set_value'    # Test all set_value operations
just config-restart-android 'cpp.*'                   # Test entire C++ layer
just config-restart-android '*.*.error_handling'      # Test all error handling

# Smart test list usage (unified interface)
just test-android development-workflow                 # Direct test list execution
just test-android '@pre-*'                            # Wildcard test list patterns
just test-android '@*-workflow'                       # All workflow test lists
```

#### ✨ **NEW: Direct Wildcard Test List Execution**
**Test list wildcards are now fully integrated into the unified testing interface!**

```bash
# 🎯 Wildcard Test List Patterns (direct execution)
just test-android '@pre-*'                            # All test lists starting with 'pre-'
just test-android '@*-workflow'                       # All test lists ending with '-workflow'  
just test-android '@*-validation'                     # All test lists ending with '-validation'
just test-android '@*-all'                            # All test lists ending with '-all'

# 🔍 Enhanced analysis works with wildcard test lists too
just test-android-enhanced '@pre-*'                   # Enhanced analysis on wildcard test lists

# 💡 Discovery and validation
just list-test-lists-matching "pre-*"                 # Find matching test lists
just list-test-lists-matching "*-workflow"            # Discover workflow test lists
```

**How it works:**
- ✅ **Auto-Detection**: `test-android` recognizes `@pattern` syntax
- ✅ **Multiple Execution**: Finds all matching test lists and runs them sequentially  
- ✅ **Error Handling**: Clear messages when no matches found
- ✅ **Enhanced Support**: Works with `test-android-enhanced` for detailed analysis

#### Config Creation Strategy
```bash
# Layer-based configs - zero maintenance
"cpp.*", "backend.*", "rtdb.*", "system.*", "game.*"

# Domain-based configs - auto-discover new functionality  
"*.firebase.*", "*.debug.*", "*.match.*"

# Operation-based configs - cross-layer validation
"*.*.set_value", "*.*.get_value", "*.*.performance"
```

### 🛡️ Safety Features

#### Circular Reference Detection
The system automatically detects and prevents circular references in nested test lists:
```
❌ Circular reference detected in test list: list-a
Visit chain: list-a,list-b -> list-a
```

#### Self-Reference Prevention
Test lists cannot reference themselves through wildcard patterns, preventing infinite recursion.

### 📊 Benefits

#### Zero-Maintenance Auto-Discovery
- ✅ **Add new tests** → Automatically included via wildcards
- ✅ **Rename tests** → Pattern matching continues to work
- ✅ **Organize tests** → Hierarchical naming enables powerful filtering
- ✅ **Scale testing** → No manual config file updates needed

#### Powerful Pattern Matching
- 🎯 **Cross-layer testing** → `*.firebase.*` tests all Firebase layers
- 🔍 **Functionality focus** → `*.*.error_handling` tests all error handling
- ⚡ **Layer isolation** → `cpp.*` tests only C++ layer
- 🧪 **Operation validation** → `*.*.set_value` tests all set operations

#### Smart Test Organization
- 📋 **Nested composition** → Build complex suites from simple components
- 🔄 **Reusable sublists** → Create once, use everywhere
- 🎯 **Wildcard discovery** → Auto-include related test lists
- 🏗️ **Hierarchical structure** → Organize by complexity and scope

## 🎯 Enhanced Test Suite Commands

The project now includes flexible test suite commands that leverage the full wildcard system capabilities.

### **Enhanced Test Suites**

#### **Essential Test Workflows (Streamlined)**
```bash
# Core workflows - focused & maintainable
just test-smoke-android                                 # Quick smoke test (30 seconds)
just test-development-android                           # Daily development workflow
just test-production-android                            # Comprehensive release validation
just test-all-android                                  # Complete test suite

# Power user - any pattern, config, or test list (unified interface)
just test-android wildcard-discovery                   # Test list execution
just test-android '@*-all'                             # Wildcard test list patterns
```

#### **Instant Wildcard Testing (No Config Files Needed!)**
```bash
# Layer-specific testing (instant)
just test-config-android 'cpp.*'                       # All C++ layer tests
just test-config-android 'backend.*'                   # All Backend layer tests  
just test-config-android 'rtdb.*'                      # All RTDB layer tests
just test-config-android 'system.*'                    # All System layer tests

# Cross-layer testing (instant)
just test-config-android 'firebase.*'                  # All Firebase functionality
just test-config-android '*.*.performance'             # All performance tests
just test-config-android '*.*.error_handling'          # All error handling tests

# Domain-specific testing (instant)
just test-config-android '*.firebase.set_value'        # All set_value operations
just test-config-android 'system.debug.*'              # All debug utilities
```

### **Test List Discovery Commands**

#### **Pattern-Based List Discovery**
```bash
# Find test lists by wildcard patterns
just list-test-lists-matching "firebase-*"             # All Firebase test lists
just list-test-lists-matching "*-testing"              # All testing suites
just list-test-lists-matching "*-validation"           # All validation suites
just list-test-lists-matching "system-*"               # All system-related lists
just list-test-lists-matching "*-focus"                # All focused test suites
```

#### **Complete List Discovery**
```bash
# List all available test lists
just list-test-lists                                   # Complete test list catalog
```

### **Smart Test Suite Workflows**

#### **Streamlined Development Workflows**
```bash
# Daily development cycle
just test-smoke-android                                 # 30-second essential validation
just test-development-android                           # Full development cycle (core layers)

# Pre-commit validation  
just test-config-android '*.basic.*'                   # Basic operations across all layers
just test-config-android '*.*.error_handling'          # Error handling validation

# Release preparation
just test-production-android                            # Comprehensive release validation
just test-all-android                                  # Complete test suite
```

#### **Power User: Instant Custom Testing**
```bash
# Create any test combination instantly (no config files!)
just test-config-android 'firebase.*'                  # All Firebase tests
just test-config-android '*.*.performance'             # All performance tests  
just test-config-android 'cpp.* backend.*'             # Multiple patterns (future)

# Use custom test lists and wildcard test list patterns
just test-android wildcard-discovery                   # Test list execution
just test-android '@wildcard-*'                        # Wildcard test list patterns
just test-android '@*-validation'                      # All validation test lists
```

### **Benefits of Enhanced Test Suites**

#### **Streamlined & Focused**
- ✅ **Essential workflows only** → 3 core commands for 90% of use cases
- ✅ **Instant wildcard testing** → No config file maintenance needed
- ✅ **Clear overview** → Only 5 test lists, 8 debug configs total
- ✅ **Zero maintenance** → Wildcard patterns handle edge cases automatically

#### **Maximum Power with Minimum Clutter**
- 🚀 **30-second smoke test** → `test-smoke-android` for instant validation
- 🔧 **Development workflow** → `test-development-android` for daily cycle  
- 🚀 **Production validation** → `test-production-android` for releases
- ⚡ **Instant custom testing** → `'firebase.*'`, `'*.*.performance'` patterns

## 🎯 **Complete Testing Interface Summary**

**The unified `test-android` command now supports ALL testing variants with smart auto-detection:**

| **Test Type** | **Syntax** | **Example** | **Description** |
|---------------|------------|-------------|-----------------|
| **🎯 Direct Actions** | `'action.name'` | `'system.debug.registry_stats'` | Single action execution |
| **🔀 Layer Wildcards** | `'layer.*'` | `'cpp.*'`, `'backend.*'`, `'system.*'` | All actions in layer |
| **🔀 Domain Wildcards** | `'*.domain.*'` | `'*.firebase.*'`, `'*.debug.*'` | Cross-layer domain testing |
| **🔀 Operation Wildcards** | `'*.*.operation'` | `'*.*.set_value'`, `'*.*.error_handling'` | Cross-layer operation testing |
| **📋 Config Files** | `config-name` | `system-testing`, `smoke-test` | Pre-defined configurations |
| **📝 Test Lists** | `list-name` | `pre-commit`, `development-workflow` | Multi-config test suites |
| **🆕 Wildcard Test Lists** | `'@pattern'` | `'@pre-*'`, `'@*-workflow'`, `'@*-all'` | Pattern-based test list execution |

**Enhanced Analysis** (all variants above work with `test-android-enhanced`):
- 🔍 **Error Categorization**: Firebase, Network, Validation errors
- 📈 **Performance Tracking**: Action-level timing analysis  
- 💡 **Debugging Recommendations**: Actionable insights

**Timer Behavior**:
- ⏱️ **Per-Action Reset**: Timer resets after each action completion
- 🔄 **No Cumulative Timeout**: Multiple actions run reliably
- 🛡️ **Fail-Fast**: Only slow individual actions timeout

**Key Benefits**:
- ✅ **Zero-Maintenance**: Wildcard patterns auto-discover new actions
- ✅ **Smart Auto-Detection**: One command handles all input types
- ✅ **Complete Coverage**: From single actions to comprehensive test suites
- ✅ **Enhanced Analysis**: Detailed debugging for any test variant

# important-instruction-reminders
Do what has been asked; nothing more, nothing less.
NEVER create files unless they're absolutely necessary for achieving your goal.
ALWAYS prefer editing an existing file to creating a new one.
NEVER proactively create documentation files (*.md) or README files. Only create documentation files if explicitly requested by the User.

## Strong Typing Requirements
ALWAYS enforce strong typing in GDScript code with FAIL-FAST approach:

### 🚨 CRITICAL - NEVER use these constructs:
- NEVER use `as` for type casting - use strongly typed variables instead
- NEVER use `is` for type checking - design proper type hierarchies instead
- These patterns hide problems until runtime - we want compile-time failures

### ✅ ALWAYS do this instead:
- Create strongly typed variables that fail immediately: `var typed_var: SpecificType = source`
- Use explicit type annotations: `var name: String = ""`
- Use typed arrays: `Array[Type]` instead of `Array`
- Add return type annotations: `func name() -> Type:`
- Prefer specific types over `Variant` when possible

### 🔧 Quality Assurance:
- Run `just format` and `just validate` after making changes
- Address ALL "has no static type" warnings in validation output
- Replace any `as` or `is` usage with proper type design
- Make the code fail fast at compile time, not hide problems until runtime
