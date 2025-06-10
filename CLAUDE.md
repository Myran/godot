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

### ⚡ Individual Action Testing (PREFERRED for debugging)
**Test any single debug action instantly - no JSON config files needed!**
```bash
# 🚀 Quick iteration (5-second cycles)
just config-restart-android 'C++ Error Handling Test'   # Instant action test + restart
just config-restart-ios 'Firebase Status Check'         # iOS equivalent

# 🔍 Debugging & Development  
just test-config-android 'C++ Set Value Test'           # Full automated test with results
just test-monitor-android 'Backend Performance Test'    # Real-time log monitoring
just fastbuild-android                                  # Rebuild after code changes

# ⚙️ Configuration Management
just config-set 'Print Debug Info'                      # Set single action as default config
```

### Traditional Config Testing
```bash
just run-desktop                           # Instant local testing
just config-restart-android testing        # Push JSON config + restart on device
just config-restart-ios testing           # iOS equivalent
```

### Full Testing
```bash
just test-all-android                     # Comprehensive Android testing (all configs)
just test-list-android <test-list>        # Run specific test list
just list-test-lists                      # Show available test lists
just help                               # View all available commands
```

### Test List Shortcuts
```bash
just test-suite-firebase-android          # Firebase-focused tests only
just test-suite-quick-android             # Quick validation tests
just test-suite-performance-android       # Performance testing suite
just test-suite-minimal-android           # Minimal smoke test
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

## Development Workflow
0. **Planning**: Think through implementation and assess ways to improve quality and simplicity. Use planning tools and basic-memory. Assess if we should build tests in advance for Test driven Development
1. **Local Development**: Use `just run-desktop` for rapid iteration and use Godot tools
2. **🎯 Individual Action Testing**: Use action names directly: `just config-restart-android 'Action Name'` (FASTEST debugging method)
3. **Device Testing**: Use `just config-restart-[platform] testing` for quick device validation of full test configs
4. **Build Updates**: Use `just fastbuild-android` to rebuild and transfer changes to Android device
5. **Full Validation**: Run `just test-all-[platform]` before commits
6. **Engine Changes**: Rebuild with `just godot-build-*` commands when modifying Godot source

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

## 🔧 Individual Action Testing (Debugging Superpower)

**Instead of creating JSON config files, test any debug action directly by name:**

### Core Commands
```bash
# 🚀 Instant Testing (5-second iteration cycles)
just config-restart-android 'C++ Error Handling Test'      # Single action
just config-restart-android 'cpp.*'                       # All C++ layer tests
just config-restart-android '*.firebase.set_value'        # All set_value operations
just config-restart-ios 'Firebase Connection Test'

# 🔍 Advanced Testing & Monitoring  
just test-config-android 'Large Data Performance Test'    # Single action with detailed results
just test-config-android '*.*.error_handling'             # All error handling tests
just test-monitor-android '*.firebase.*'                  # Monitor all Firebase operations
just test-monitor-android 'system.debug.*'                # Monitor system debug actions
```

### When to Use Each Method
- **Individual Actions**: 🎯 Debugging specific issues, developing new features, isolating problems
- **Config Files**: 📋 Running test suites, comprehensive validation, CI/CD pipelines
- **Full Test Lists**: 🧪 Pre-commit validation, integration testing, release verification

### Smart Command Detection
All commands automatically:
- ✅ Detect if argument is an action name vs config file
- ✅ Create temporary JSON configs for single actions  
- ✅ Clean up temporary files after operations
- ✅ Handle action names with spaces when properly quoted
- ✅ Provide immediate feedback on action availability

### 💡 Pro Tips for Debugging
```bash
# 1. Isolate problematic actions immediately (saves hours of debugging!)
just test-config-android 'Failing Action Name'            # Single action
just test-config-android 'cpp.*'                         # All C++ actions
just test-config-android '*.firebase.*'                  # All Firebase actions

# 2. Monitor logs in real-time during development
just test-monitor-android 'New Feature Action'           # Single action monitoring
just test-monitor-android '*.*.performance'              # All performance tests
just test-monitor-android 'backend.*'                    # All backend operations

# 3. Quick validation after code changes
just fastbuild-android && just config-restart-android '*.basic.*'     # All basic operations
just config-restart-android '*.*.error_handling'         # All error handling

# 4. Set frequently used patterns as default
just config-set '*.firebase.set_value'                   # All set_value operations
just config-set 'system.debug.*'                         # All debug utilities
```

### ⚠️ Common Debugging Mistake: Don't Use Full Test Suites for Single Issues
**AVOID**: Running full test configs when debugging specific problems
```bash
# ❌ Slow - runs 8 actions when only 1 is broken
just config-restart-android cpp-firebase-comprehensive-test

# ✅ Fast - targets exact problem in 5 seconds  
just config-restart-android 'C++ Error Handling Test'
```

**Why Individual Actions Are Better for Debugging:**
- 🚀 **5x faster iteration** - no waiting for unrelated actions
- 🎯 **Precise isolation** - pinpoint exact failure location  
- 📝 **Cleaner logs** - easier to spot issues without noise
- 🔄 **Rapid testing** - fix and verify in seconds, not minutes

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

### Test List System
Test configurations are organized into reusable test lists:
- `default-all.json` - Complete test suite (used by `test-all-android`)
- `firebase-only.json` - Firebase-focused testing
- `quick-validation.json` - Essential tests for rapid development cycles
- `performance-focus.json` - Performance and stress testing
- `minimal-smoke.json` - Basic functionality verification

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

#### **Category-Based Test Suites**
```bash
# Firebase testing with flexible patterns
just test-suite-firebase-android                        # Uses firebase-basic (default)
just test-suite-firebase-android firebase-comprehensive # Advanced Firebase tests
just test-suite-firebase-android firebase-only          # Complete Firebase coverage

# Performance testing
just test-suite-performance-android                     # Uses performance-focus (default)
just test-suite-performance-android advanced-operations-all # Advanced performance tests

# Error handling testing
just test-suite-error-android                          # Uses error-testing (default)

# System testing
just test-suite-system-android                         # Uses system-testing (default)
just test-suite-system-android layer-testing           # Cross-layer system tests

# Minimal/smoke testing
just test-suite-minimal-android                        # Uses minimal-smoke (default)
```

#### **Generic Wildcard Test Suite**
```bash
# Run any test list or pattern
just test-suite-android comprehensive-wildcard-demo     # Complex wildcard demo
just test-suite-android development-workflow           # Development cycle tests
just test-suite-android quick-validation               # Fast validation tests
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

#### **Development Cycle Testing**
```bash
# Quick validation during development
just test-suite-minimal-android                        # Fast smoke tests
just test-suite-android quick-validation               # Essential validations

# Feature-specific testing
just test-suite-firebase-android firebase-basic        # Core Firebase functionality
just test-suite-system-android layer-testing           # Cross-layer validation

# Comprehensive testing before commits
just test-suite-android development-workflow           # Full development cycle
just test-all-android                                  # Complete test suite
```

#### **Discovery-Driven Testing**
```bash
# Discover available test categories
just list-test-lists-matching "*-testing"              # Find all testing categories

# Run discovered categories
just test-suite-android error-testing                  # Error handling tests
just test-suite-android system-testing                 # System functionality tests
just test-suite-android layer-testing                  # Architectural layer tests
```

### **Benefits of Enhanced Test Suites**

#### **Flexibility & Customization**
- ✅ **Default patterns** → Quick access to common test suites
- ✅ **Custom patterns** → Override with any test list name
- ✅ **Pattern discovery** → Find test lists by wildcard patterns
- ✅ **Zero maintenance** → New test lists automatically work

#### **Development Workflow Integration**
- 🚀 **Fast iteration** → `test-suite-minimal-android` for quick validation
- 🔍 **Focused testing** → `test-suite-firebase-android firebase-basic` for specific areas
- 🧪 **Comprehensive validation** → `test-suite-android development-workflow` for full cycles
- 📋 **Easy discovery** → `list-test-lists-matching "firebase-*"` to find related tests
