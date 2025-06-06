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

### Quick Testing (5-second cycles)
```bash
just run-desktop                           # Instant local testing
just fastbuild-android                    # rebuild android quickly after gdscript changes
just config-restart-android testing        # Push specific config + restart on device
just config-restart-ios testing           # iOS equivalent
```

### Action Name Testing (No JSON files needed!)
```bash
just config-restart-android 'Show Registry Stats'    # Test any action directly
just test-quick-android 'Backend Performance Test'   # Quick test single action
just test-config-android 'C++ Set Value Test'        # Automated test with results
just config-set 'Print Debug Info'                   # Set single action as embedded config
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
2. **Action Testing**: Use action names directly for instant testing: `just config-restart-android 'Action Name'`
3. **Device Testing**: Use `just config-restart-[platform] testing` for quick device validation of tests. Use 'just fastbuild-android' to build and transfer changes to android
4. **Full Validation**: Run `just test-all-[platform]` before commits
5. **Engine Changes**: Rebuild with `just godot-build-*` commands when modifying Godot source

### Action Name Shortcuts
Instead of creating JSON config files, you can now test individual actions directly:
- **Quick Testing**: `just config-restart-android 'Action Name'` - 5 second cycle
- **Automated Testing**: `just test-config-android 'Action Name'` - Full test with results
- **Log Monitoring**: `just test-monitor-android 'Action Name'` - Watch logs in real-time
- **Config Management**: `just config-set 'Action Name'` - Set as embedded config

All commands automatically:
- Detect if the argument is an action name vs config file
- Create temporary JSON configs for single actions
- Clean up temporary files after successful operations
- Handle action names with spaces when properly quoted

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
