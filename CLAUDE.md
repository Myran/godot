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

## Development Workflow
0. **Planning**: Think through implementation and assess ways to improve quality and simplicity. Use planning tools and basic-memory. Assess if we should build tests in advance for Test driven Development
1. **Local Development**: Use `just run-desktop` for rapid iteration and use Godot tools
2. **🎯 Unified Testing**: Use `just test-android TARGET` for comprehensive testing (auto-detects patterns/configs/lists)
3. **Quick Iteration**: Use `just config-restart-android 'Action Name'` for ultra-fast 5-second cycles
4. **Enhanced Debugging**: Use `just test-android-enhanced TARGET` for detailed error analysis and performance tracking
5. **Build Updates**: Use `just fastbuild-android` to rebuild and transfer changes to Android device
6. **Full Validation**: Run `just test-all-android` before commits
7. **Engine Changes**: Rebuild with `just godot-build-*` commands when modifying Godot source

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

# Smart test list usage
just test-list-android development-workflow            # Uses nested @quick-validation
just test-list-android all-firebase-tests             # Uses @firebase-* wildcards
```

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

# Power user - any pattern or custom test list
just test-suite-android wildcard-discovery             # Custom: demo of wildcard patterns
just test-suite-android PATTERN                        # Custom: any test list name
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

# Use custom test lists when needed
just test-suite-android wildcard-discovery             # Wildcard pattern demo
just test-suite-android CUSTOM_LIST                    # Any custom test list
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
