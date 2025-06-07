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
just config-restart-android 'C++ Error Handling Test'
just config-restart-ios 'Firebase Connection Test'

# 🔍 Advanced Testing & Monitoring  
just test-config-android 'Large Data Performance Test'    # Full automated test with detailed results
just test-monitor-android 'Concurrent Operations Test'    # Real-time log monitoring with filtering
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
just test-config-android 'Failing Action Name'

# 2. Monitor logs in real-time during development
just test-monitor-android 'New Feature Action'

# 3. Quick validation after code changes
just fastbuild-android && just config-restart-android 'Test Action'

# 4. Set frequently used action as default
just config-set 'Daily Development Action'
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
