# Justfile Architecture Guide

**CRITICAL BUSINESS INFRASTRUCTURE** - 22,000+ lines across 40 modules powering GameTwo development.

This document ensures correct recipe selection during development, testing, and deployment workflows.

---

## 🎯 Quick Decision Tree

**When you need to...**

### Build & Compile
- **First time setup**: `just build` (46 min)
- **C++ changes** (Firebase, modules): `just cpp-dev` (3-15 min) ⭐ **RECOMMENDED**
- **GDScript changes**: `just fastbuild-android` (30-60 sec) ⚡ **REQUIRED**
- **After ANY code changes before Android testing**: `just fastbuild-android` ⚡ **MANDATORY**

### Test & Validate
- **Before commit**: `just ci-validate` 🚨 **MANDATORY**
- **Automated testing**: `just test-android-target CONFIG`, `just test-desktop-target CONFIG`, or `just test-macos-target CONFIG`
- **Quick iteration**: `just config-restart-android CONFIG` (5 sec) ⚡
- **Cross-platform**: `just test-all [CONFIG]` (unified summary)

### Debug & Analyze
- **Error scan**: `just logs-errors TEST_ID` (98% token savings) ⚡
- **Text search**: `just logs-search TEST_ID "search_term"` (99% savings) ⚡
- **Pattern matching**: `just logs-pattern TEST_ID "firebase.*"`
- **Full Android logs**: `just logs-android-device "term"` (sees startup)

### Deploy (Development - export → install → run)
- **Android**: `just deploy-android` (export + install + run)
- **iOS**: `just deploy-ios` (default: iPad), `just deploy-ios-iphone`, `just deploy-ios-ipad`
- **macOS**: `just deploy-macos` (export + run)
- **Windows**: `just deploy-windows` (physical machine)
- **Editor**: `just run-editor-debug [verbose]` (Task-329)

### Ship (Production - App Store)
- **Android**: `just ship-android` (Play Store via fastlane)
- **iOS**: `just ship-ios` (App Store via fastlane)

---

## 📋 Module Architecture (40 Modules)

### **Foundation Layer** (Load Order: First)

#### `justfile-core-config.justfile`
- **Purpose**: Shared configuration, variables, paths
- **Provides**: Device IDs, build paths, log directories, utility functions
- **Used By**: ALL other modules
- **Critical Variables**:
  - `GAME_NAME`, `PROJECT_PATH`, `GODOT_EXECUTABLE`
  - `ANDROID_DEVICE_ID`, `IOS_TEST_DEVICE`, `IOS_DEPLOY_DEVICE`
  - `DEBUG_CONFIG_DIR`, `TEST_LIST_DIR`, `EDITOR_LOG_DIR`
  - `INTER_CONFIG_DELAY` (Firebase resource drainage)
- **Key Functions**: `_get-editor-log-file`, device utilities

---

### **Build System Layer**

#### `justfile-build-system.justfile`
- **Purpose**: Complete build infrastructure, template generation
- **Critical Recipes**:
  - `build-editor` - Godot editor compilation
  - `build-android-templates` - SCons compile C++ → Gradle package .aar
  - `install-android-template` - Extract templates to project/android/build/
  - `build-swappy` - Swappy Frame Pacing library
  - `templates-all`, `templates-android`, `templates-ios`
- **Build Hierarchy**:
  ```
  build (46 min) → build-artifacts → build-toolchain → editor + templates
  ```
- **When to Use**:
  - First-time setup
  - C++ module changes (Firebase SDK)
  - Template regeneration needed

#### `justfile-build-utils.justfile`
- **Purpose**: Build utilities and helpers
- **Recipes**: Build status checks, artifact validation, cleanup

#### `justfile-platform-android.justfile`
- **Purpose**: Android-specific build and deployment
- **Critical Recipes**:
  - `fastbuild-android` ⚡ **MANDATORY after code changes**
  - `build-all-android` - Full Android pipeline (3-25 min)
  - `quick-build-android` - Skip template check (2-3 min)
  - `export-android-apk`, `export-android-aab` (Task-378)
  - `install-apk-android`, `launch-android`
  - `cpp-dev` ⭐ **ONE-COMMAND C++ workflow**
- **Build Pathways**:
  1. **Template Building** (C++ changes): `build-android-templates` → `install-android-template`
  2. **Full Pipeline**: `build-all-android` (templates + Firebase + APK + AAB)
  3. **Quick Build**: `quick-build-android` (Firebase + export)
  4. **Fast Build**: `fastbuild-android` ⚡ (dev iteration: 30-60 sec)
- **Critical**: `fastbuild-android` REQUIRED after ANY GDScript/C++ changes before Android testing

#### `justfile-platform-ios.justfile`
- **Purpose**: iOS-specific build and deployment
- **Critical Recipes**:
  - `build-pipeline-ios` - Complete iOS pipeline
  - `build-install-ios` - Rebuild & install (2-5 min)
  - `ios-deploy` - Device deployment via xcrun devicectl

#### `justfile-platform-windows.justfile`
- **Purpose**: Windows-specific build, VM building, and physical machine testing
- **Two-Machine Architecture** (Task-368):
  - **VM (192.168.50.92)**: MSVC builds, template compilation (BUILDING)
  - **Physical (192.168.50.80)**: GUI testing, no headless mode (TESTING)
- **Critical Recipes (VM - Building)**:
  - `win-vm-verify` - Verify VM connectivity
  - `win-vm-template-debug` - Build debug template on VM
  - `win-vm-template-release` - Build release template on VM
  - `win-vm-templates-package` - Copy templates from VM to Mac
- **Critical Recipes (Physical - Testing)**:
  - `win-physical-status` - Check physical machine status
  - `win-physical-wake` - Wake via Wake-on-LAN
  - `win-physical-deploy` - Deploy Windows export
  - `test-windows-physical-target CONFIG` - Automated testing with GUI
  - `test-windows-physical-manual CONFIG` - Manual testing (stays open)
  - `logs-windows-physical TEST_ID` - Retrieve logs
  - `logs-windows-physical-errors TEST_ID` - Error analysis
- **Key Features**:
  - Auto Wake-on-LAN before deploy/test operations
  - Python-based WoL (no external dependencies)
- **Naming Convention** (Task-368):
  - `win-vm-*` → Windows VM for BUILDING
  - `win-physical-*` → Windows physical for TESTING
  - `test-windows-*` → Tests on VM (headless capable)
  - `test-windows-physical-*` → Tests on physical machine (GUI mode)

#### `justfile-platform-macos.justfile`
- **Purpose**: macOS-specific build, deployment, and testing
- **Critical Recipes**:
  - `test-macos-target CONFIG` - Automated macOS testing (exported .app)
  - `test-macos-manual CONFIG` - Manual testing (stays open)
  - `test-macos-update CONFIG` - Update checksum baseline
  - `test-macos-reset CONFIG` - Reset checksum baseline
  - `run-macos` - Launch exported macOS app
  - `clear-test-macos` - Clear test configuration
- **Key Features**:
  - Tests exported `.app` bundle (not editor)
  - Editor preservation: NEVER kills Godot editor
  - Gatekeeper quarantine handling with `xattr -cr`
  - Config deployment to `~/Library/Application Support/Godot/app_userdata/gametwo/`
- **When to Use**:
  - macOS-specific testing with exported app
  - Cross-platform validation alongside Android/desktop

---

### **Testing & Validation Layer**

#### `justfile-testing-core.justfile`
- **Purpose**: Platform-agnostic testing infrastructure
- **Provides**: Shared setup, preparation, validation patterns
- **Key Functions**:
  - `_test-setup-android`, `_test-setup-desktop` - Test initialization
  - `_test-prepare-android`, `_test-prepare-desktop` - Cache clearing, validation
  - `_test-check-android-device`, `_test-check-desktop-godot` - Environment checks

#### `justfile-validation-enhanced-testing.justfile`
- **Purpose**: Enhanced testing with automatic validation
- **Critical Recipes**:
  - `test-android-target CONFIG` - Automated Android testing
  - `test-desktop-target CONFIG` - Automated desktop testing
  - `test-macos-target CONFIG` - Automated macOS testing
  - `test-android-manual CONFIG` - Manual testing (stays open)
  - `test-desktop-manual CONFIG` - Manual desktop testing
  - `test-macos-manual CONFIG` - Manual macOS testing
- **Features**: Checksum validation, error analysis, baseline management
- **Load Order**: **LAST** to override existing test commands

#### `justfile-cross-platform-testing.justfile`
- **Purpose**: Multi-platform test orchestration
- **Critical Recipes**:
  - `test` - Multi-platform main config with unified summary
  - `test-all [CONFIG]` - Multi-platform with target selection
- **Benefits**: Unified reporting, cross-platform consistency

#### `justfile-validation.justfile`
- **Purpose**: Code validation (syntax, format, runtime)
- **Critical Recipes**:
  - `validate` - Complete validation (format + syntax + runtime)
  - `validate-gdscript` - Syntax validation
  - `validate-godot` - Runtime validation
  - `format` - Auto-format code
  - `lint` - Code quality checks
- **Used In**: `ci-validate`, pre-commit workflow

#### `justfile-validation-shared.justfile`
- **Purpose**: Shared validation utilities
- **Provides**: Common validation patterns, error handling

#### `justfile-config-validation.justfile`
- **Purpose**: Debug config validation
- **Recipes**: Config format validation, structure checks

#### `justfile-cicd.justfile`
- **Purpose**: CI/CD pipeline integration
- **Critical Recipes**:
  - `ci-validate` 🚨 **MANDATORY before commits**
  - `ci-validate-desktop` - Desktop platform validation
  - `ci-validate-android` - Android platform validation
- **Validation Steps**:
  1. Code formatting (`just format`)
  2. Asset reimport (`just godot-import`)
  3. Code linting (`just lint`)
  4. Godot validation (`just validate-godot`)
  5. Platform warnings check

---

### **Debugging & Analysis Layer**

#### `justfile-logs.justfile`
- **Purpose**: Core log extraction and analysis
- **Critical Recipes**:
  - `logs-errors TEST_ID [PLATFORM]` ⚡ (98% token savings)
  - `logs-search TEST_ID "search_term" [PLATFORM]` ⚡ (99% savings)
  - `logs-latest [PLATFORM]` - Latest test results
  - `logs-android TEST_ID [TAGS...]` - Android log extraction
  - `logs-desktop TEST_ID [TAGS...]` - Desktop log extraction
  - `logs-tags TEST_ID TAGS...` - Precision tag filtering
- **Progressive Debugging**:
  1. `logs-errors` - Quick error scan
  2. `logs-search` - Simple text search
  3. `logs-android`/`logs-desktop` - Component analysis
  4. `logs-tags` - Precision debugging

#### `justfile-enhanced-log-analysis.justfile`
- **Purpose**: Advanced log analysis
- **Critical Recipes**:
  - `logs-checksum-detail TEST_ID` - Checksum comparison
  - `logs-performance TEST_ID` - Performance analysis
  - `logs-lifecycle TEST_ID` - Test lifecycle events
  - `logs-summary TEST_ID` - Quick test summary
  - `logs-benchmark TEST_ID PATTERN` - Pattern performance

#### `justfile-wildcard-commands.justfile`
- **Purpose**: Wildcard pattern system (10x productivity)
- **Critical Recipes**:
  - `logs-pattern TEST_ID PATTERN` - Single pattern matching
  - `logs-multi TEST_ID PATTERN1 PATTERN2` - Multiple patterns (OR)
  - `logs-exclude TEST_ID PATTERN EXCLUDE` - Include/exclude filtering
  - `logs-discover TEST_ID PREFIX` - Find tags with prefix
  - `logs-tree TEST_ID` - Hierarchical tag structure
  - `logs-suggest TEST_ID PARTIAL` - Auto-complete suggestions
- **Pattern Examples**:
  - `"firebase.*"` - All Firebase operations
  - `"*.error"` - All error operations
  - `"game.*.start"` - All start events
  - `"cpp.firebase.auth.*"` - Specific layer navigation

#### `justfile-wildcard-core.justfile`
- **Purpose**: Wildcard system implementation
- **Provides**: Pattern matching engine, tag discovery

#### `justfile-log-filter-commands.justfile`
- **Purpose**: Advanced log filtering
- **Recipes**: Complex filtering, multi-tag operations

#### `justfile-universal-log-tags.justfile`
- **Purpose**: Unified tag system documentation
- **Provides**: Tag hierarchy, naming conventions

#### `justfile-android-device-logs.justfile`
- **Purpose**: Android device log monitoring
- **Critical Recipes**:
  - `logs-android-device "SEARCH_TERM" [LINES]` ⚡ **Complete device logs**
  - `logs-android-clear` - Clear device buffers
  - `logs-android-health` - Buffer health monitoring
  - `logs-android-status` - Device & app diagnostics
  - `android-logs-errors [DURATION]` - Error monitoring
  - `android-logs-tagged "TAG" [DURATION] [COUNT]` - Tag filtering
  - `android-logs-live [DURATION] [FILTER] [COUNT]` - Live monitoring
- **When to Use**:
  - Missing logs in test results → Use `logs-android-device`
  - Startup/initialization logs → Use `logs-android-device`
  - Live monitoring → Use `android-logs-live`

#### `justfile-ios-device-logs.justfile`
- **Purpose**: iOS device log monitoring (legacy, transitioning)
- **Recipes**: iOS log retrieval, filtering

#### `justfile-device-logging-core.justfile`
- **Purpose**: Unified device logging infrastructure
- **Provides**: Cross-platform log management

#### `justfile-log-cross-validation.justfile`
- **Purpose**: Cross-platform log validation
- **Recipes**: Log consistency checks, platform comparison

---

### **Configuration & Debug Layer**

#### `justfile-config.justfile`
- **Purpose**: Debug config management
- **Critical Recipes**:
  - `config-list` - List available configs
  - `config-restart-android ACTION` ⚡ (5 sec quick testing)
  - `config-push-android CONFIG` - Deploy config (2 sec)
  - `config-set CONFIG` - Set default config
  - `runtime-filter-reset` - Reset advanced_logger filtering
- **Config System**: JSON-based debug configurations in `tests/debug_configs/`

#### `justfile-filter-configs.justfile`
- **Purpose**: Advanced logger runtime filtering
- **Recipes**: Tag filtering, log level management

#### `justfile-debug-commands.justfile`
- **Purpose**: Debug utilities and helpers
- **Recipes**: Debug state inspection, diagnostic tools

---

### **Gamestate & Replay Layer**

#### `justfile-gamestate-capture.justfile`
- **Purpose**: Gamestate extraction and management
- **Critical Recipes**:
  - `capture-gamestate-desktop NAME` - Desktop extraction
  - `capture-gamestate-android NAME` - Android extraction
  - `list-saved-states` - Show saved states
  - `clean-saved-states` - Remove all states
- **Workflow**: Play → Save → Capture → Load → Test

#### `justfile-gamestate-testing.justfile`
- **Purpose**: Gamestate testing and validation
- **Critical Recipes**:
  - `test-save-load-cycle-desktop` - Desktop save/load consistency
  - `test-save-load-cycle-android` - Android save/load consistency
  - `test-gamestate-cycle` - Complete gamestate test cycle
- **Test Integration**: Included in `just test` validation

#### `justfile-semantic-replay-commands.justfile`
- **Purpose**: Battle replay system
- **Critical Recipes**:
  - `replay-generate-desktop SESSION_ID NAME` - Generate replay config
  - `replay-generate-android SESSION_ID NAME` - Android replay generation
- **Workflow**: Play → Generate → Test

---

### **Development Tools Layer**

#### `justfile-dev-tools.justfile`
- **Purpose**: Developer utilities
- **Recipes**: Code formatting, linting, syntax checking, asset management

#### `justfile-run.justfile`
- **Purpose**: Run game on platforms
- **Critical Recipes**:
  - `run-editor` - Godot editor mode (Task-329)
  - `run-editor-debug [verbose]` - Debug mode with leak detection (Task-329)
  - `run-android` - Launch Android app
  - `restart-android-app` - Restart Android app
- **Safety**: 🚨 Use `test-*` commands for debug actions, NOT `run-*`

#### `justfile-code-analysis.justfile`
- **Purpose**: Codebase analysis
- **Recipes**: Repomix integration, code metrics, architecture analysis

---

### **Sentry Integration Layer**

#### `justfile-sentry.justfile`
- **Purpose**: Sentry crash reporting orchestration
- **Imports**: Platform-specific Sentry modules

#### `justfile-gdscript-sentry.justfile`
- **Purpose**: GDScript-level Sentry integration

#### `justfile-native-android-sentry.justfile`
- **Purpose**: Android native Sentry SDK

#### `justfile-native-ios-sentry.justfile`
- **Purpose**: iOS native Sentry SDK

#### `justfile-native-windows-sentry.justfile`
- **Purpose**: Windows native Sentry SDK

#### `justfile-sentry-test.justfile`
- **Purpose**: Sentry integration testing

---

### **Support & Documentation Layer**

#### `justfile-help.justfile`
- **Purpose**: Interactive help system
- **Critical Recipes**:
  - `help` - Interactive command browser (fzf)
  - `help-debug` - Debug & testing workflows
  - `help-build` - Build system architecture
  - `help-logs` - Log analysis guide
  - `help-workflows` - Common workflow patterns
  - `help-wildcards` - Wildcard pattern system
  - `help-gamestate` - Gamestate workflow guide

#### `justfile-support.justfile`
- **Purpose**: Support utilities and diagnostics

---

## 🔄 Critical Workflow Patterns

### **Daily Development (OODA Loop)**

```bash
# OBSERVE
just ci-validate           # Code quality, format, lint

# ORIENT (after code changes)
just fastbuild-android     # ⚡ MANDATORY before Android testing

# DECIDE
just test-android-target CONFIG  # Automated testing with validation

# ACT
just logs-errors TEST_ID   # ⚡ Quick error scan (98% efficiency)
```

### **C++ Development Workflow**

```bash
# ⭐ RECOMMENDED: One-command workflow
just cpp-dev               # Build templates → Install → Fastbuild (3-15 min)

# Manual workflow (alternative)
just build-android-templates     # 1. Build C++ → .aar
just install-android-template    # 2. Install template
just fastbuild-android           # 3. Package + deploy (REQUIRED)
```

### **Pre-Commit Workflow**

```bash
just ci-validate           # 🚨 MANDATORY (format + lint + validation)
just test-android test-all # Comprehensive testing (15 configs)
just logs-errors TEST_ID   # Error verification
```

### **Debugging Workflow (Progressive)**

```bash
# 1. EXPLORE STRUCTURE (Most Efficient)
just logs-tree TEST_ID              # Discover tag hierarchy
just logs-discover TEST_ID firebase # Find firebase-related tags

# 2. QUICK ERROR SCAN (98% savings)
just logs-errors TEST_ID            # Show only errors
just logs-search TEST_ID "search_term" # ⚡ Simple text search

# 3. COMPONENT ANALYSIS (87-95% savings)
just logs-pattern TEST_ID "firebase.*" # Pattern matching
just logs-android TEST_ID firebase     # Android logs with tags

# 4. PRECISION DEBUGGING (<200 tokens)
just logs-tags TEST_ID firebase auth   # Exact tag filtering
```

### **Cross-Platform Testing**

```bash
# Multi-platform with unified summary
just test-all [CONFIG]     # Desktop + Android with single report

# Platform-specific automated testing
just test-android-target CONFIG  # Android automated
just test-desktop-target CONFIG  # Desktop automated

# Manual testing (stays open)
just test-android-manual CONFIG  # Android inspection
just test-desktop-manual CONFIG  # Desktop inspection
```

---

## 🚨 Critical Safety Rules

### **Build Requirements**

1. **After ANY GDScript/C++ changes**: `just fastbuild-android` ⚡ **MANDATORY** before Android testing
2. **Before commit**: `just ci-validate` 🚨 **MANDATORY**
3. **After C++ changes**: Use `just cpp-dev` ⭐ (one command: build → install → fastbuild)

### **Testing Requirements**

1. **Use `test-*` commands**, NOT `run-*` for debug actions
   - ✅ `just test-android-target CONFIG` (enables debug coordinator)
   - ❌ `just run-android` (debug actions won't execute)

2. **Always clear cache** before testing (handled automatically by test commands)

3. **Inter-config delay**: 5 seconds between configs (Firebase resource drainage)

### **Log Analysis Requirements**

1. **Start with token-efficient commands**:
   - `logs-errors` (98% savings) - Quick error scan
   - `logs-search` (99% savings) - Simple text search
   - `logs-pattern` - Wildcard matching

2. **Use full Android logs when needed**:
   - Missing logs → `just logs-android-device "term"`
   - Startup logs → `just logs-android-device "term"`

3. **Buffer safety**: Check buffer saturation before trusting live logs

---

## 📊 Module Dependency Graph

```
justfile (main entry)
    │
    ├─→ justfile-core-config.justfile (FOUNDATION - loaded first)
    │
    ├─→ BUILD SYSTEM
    │   ├─→ justfile-build-system.justfile
    │   ├─→ justfile-build-utils.justfile
    │   ├─→ justfile-platform-android.justfile
    │   ├─→ justfile-platform-ios.justfile
    │   ├─→ justfile-platform-macos.justfile
    │   └─→ justfile-platform-windows.justfile
    │
    ├─→ TESTING & VALIDATION
    │   ├─→ justfile-testing-core.justfile
    │   ├─→ justfile-validation-shared.justfile
    │   ├─→ justfile-validation.justfile
    │   ├─→ justfile-config-validation.justfile
    │   ├─→ justfile-cross-platform-testing.justfile
    │   ├─→ justfile-validation-enhanced-testing.justfile (LAST - overrides)
    │   └─→ justfile-cicd.justfile
    │
    ├─→ DEBUGGING & ANALYSIS
    │   ├─→ justfile-wildcard-core.justfile
    │   ├─→ justfile-wildcard-commands.justfile
    │   ├─→ justfile-logs.justfile
    │   ├─→ justfile-enhanced-log-analysis.justfile
    │   ├─→ justfile-log-filter-commands.justfile
    │   ├─→ justfile-universal-log-tags.justfile
    │   ├─→ justfile-android-device-logs.justfile
    │   ├─→ justfile-ios-device-logs.justfile
    │   ├─→ justfile-device-logging-core.justfile
    │   └─→ justfile-log-cross-validation.justfile
    │
    ├─→ CONFIG & DEBUG
    │   ├─→ justfile-config.justfile
    │   ├─→ justfile-filter-configs.justfile
    │   └─→ justfile-debug-commands.justfile
    │
    ├─→ GAMESTATE & REPLAY
    │   ├─→ justfile-gamestate-capture.justfile
    │   ├─→ justfile-gamestate-testing.justfile
    │   └─→ justfile-semantic-replay-commands.justfile
    │
    ├─→ DEVELOPMENT TOOLS
    │   ├─→ justfile-dev-tools.justfile
    │   ├─→ justfile-run.justfile
    │   └─→ justfile-code-analysis.justfile
    │
    ├─→ SENTRY INTEGRATION
    │   ├─→ justfile-sentry.justfile
    │   ├─→ justfile-gdscript-sentry.justfile
    │   ├─→ justfile-native-android-sentry.justfile
    │   ├─→ justfile-native-ios-sentry.justfile
    │   ├─→ justfile-native-windows-sentry.justfile
    │   └─→ justfile-sentry-test.justfile
    │
    └─→ SUPPORT & DOCUMENTATION
        ├─→ justfile-help.justfile
        └─→ justfile-support.justfile
```

---

## 🎯 Recipe Selection Matrix

### **I need to build...**

| Scenario | Recipe | Time | When to Use |
|----------|--------|------|-------------|
| First-time setup | `just build` | 46 min | Initial setup, complete rebuild |
| C++ module changes | `just cpp-dev` ⭐ | 3-15 min | Firebase SDK, custom C++ modules |
| GDScript changes | `just fastbuild-android` ⚡ | 30-60 sec | **REQUIRED** before Android testing |
| Full Android build | `just build-all-android` | 3-25 min | Release builds, first-time setup |
| iOS build | `just build-install-ios` | 2-5 min | iOS development, deployment |
| Templates only | `just build-android-templates` | 3-15 min | C++ changes without full build |

### **I need to test...**

| Scenario | Recipe | Benefits |
|----------|--------|----------|
| Automated Android | `just test-android-target CONFIG` | Checksum validation, error analysis |
| Automated Desktop | `just test-desktop-target CONFIG` | Cross-platform testing |
| Automated macOS | `just test-macos-target CONFIG` | Exported app testing |
| Automated Windows | `just test-windows-physical-target CONFIG` | GUI mode on physical machine |
| Cross-platform | `just test-all [CONFIG]` | Unified summary, consistency |
| Quick iteration | `just config-restart-android CONFIG` ⚡ | 5-second cycles |
| Manual inspection | `just test-android-manual CONFIG` | Stays open, manual control |
| macOS inspection | `just test-macos-manual CONFIG` | Exported app, stays open |
| Windows inspection | `just test-windows-physical-manual CONFIG` | GUI mode, stays open |
| Comprehensive | `just test-android test-all` | 15 configs, all domains |

### **I need to debug...**

| Scenario | Recipe | Token Savings |
|----------|--------|---------------|
| Quick error scan | `just logs-errors TEST_ID` ⚡ | 98% |
| Simple text search | `just logs-search TEST_ID "term"` ⚡ | 99% |
| Pattern matching | `just logs-pattern TEST_ID "firebase.*"` | 90-95% |
| Component analysis | `just logs-android TEST_ID firebase` | 87-95% |
| Precision filtering | `just logs-tags TEST_ID firebase auth` | <200 tokens |
| Full device logs | `just logs-android-device "term"` | Complete view |
| Log structure | `just logs-tree TEST_ID` | Hierarchical view |

### **I need to validate...**

| Scenario | Recipe | Required? |
|----------|--------|-----------|
| Before commit | `just ci-validate` | 🚨 **MANDATORY** |
| Complete validation | `just validate` | Format + syntax + runtime |
| Code formatting | `just format` | Auto-fix formatting |
| Code linting | `just lint` | Quality checks |
| Syntax only | `just validate-gdscript` | Quick syntax check |
| Runtime only | `just validate-godot` | Engine validation |

### **I need to manage...**

| Scenario | Recipe | Use Case |
|----------|--------|----------|
| Debug configs | `just config-list` | List available configs |
| Quick deploy | `just config-restart-android CONFIG` ⚡ | 5-second testing |
| Gamestate capture | `just capture-gamestate-desktop NAME` | Scenario reproduction |
| Replay generation | `just replay-generate-desktop SESSION_ID NAME` | Battle replay testing |
| Device logs | `just android-logs-status` | Device diagnostics |

---

## 🧠 Decision-Making Principles

### **Build System Decisions**

1. **C++ changes** → Use `just cpp-dev` (one command handles everything)
2. **GDScript changes** → **ALWAYS** run `just fastbuild-android` before Android testing
3. **Release builds** → Use full pipelines (`build-all-android`, `build-all-ios`)
4. **First-time setup** → Start with `just build` (complete toolchain)

### **Testing Decisions**

1. **Automated testing** → Use `test-*-target` recipes (validation included)
2. **Manual testing** → Use `test-*-manual` recipes (stays open)
3. **Quick iterations** → Use `config-restart-android` (5-second cycles)
4. **Comprehensive testing** → Use `test-all` or domain-specific suites

### **Debugging Decisions**

1. **Start efficient** → `logs-errors` or `logs-search` (98-99% token savings)
2. **Pattern matching** → Use `logs-pattern` for wildcard searches
3. **Missing logs** → Switch to `logs-android-device` (full device logs)
4. **Explore structure** → Use `logs-tree` to discover tag hierarchy

### **Validation Decisions**

1. **Before commit** → **ALWAYS** run `just ci-validate`
2. **During development** → Run `just validate` frequently
3. **Quick checks** → Use `format` and `lint` independently
4. **CI/CD** → Use platform-specific validators

---

## 📖 Additional Resources

- **Interactive Help**: `just help` (fzf browser with all recipes)
- **Topic-Specific Help**:
  - `just help-debug` - Debug workflows
  - `just help-build` - Build system architecture
  - `just help-logs` - Log analysis guide
  - `just help-workflows` - Common patterns
  - `just help-wildcards` - Pattern system
  - `just help-gamestate` - Gamestate workflows

- **Advanced Documentation**: See `/CLAUDE-ADVANCED.md` for:
  - Wildcard pattern deep dive
  - Git workflow integration
  - Architecture details
  - Performance optimization

---

## ⚡ Quick Reference Commands

```bash
# Build
just cpp-dev                          # ⭐ C++ workflow (one command)
just fastbuild-android                # ⚡ REQUIRED after code changes

# Validate
just ci-validate                      # 🚨 MANDATORY before commit

# Test
just test-android-target CONFIG       # Automated testing
just config-restart-android CONFIG    # ⚡ Quick iteration (5 sec)
just test-all [CONFIG]                # Cross-platform unified

# Debug
just logs-errors TEST_ID              # ⚡ Error scan (98% savings)
just logs-search TEST_ID "term"       # ⚡ Text search (99% savings)
just logs-pattern TEST_ID "firebase.*" # Pattern matching
just logs-android-device "term"       # Full device logs

# Config
just config-list                      # List available configs
just capture-gamestate-desktop NAME   # Capture scenario
just list-saved-states                # Show saved states

# Windows Physical Machine (192.168.50.80)
just win-physical-status              # Check machine status
just win-physical-wake                # Wake via Wake-on-LAN
just win-physical-deploy              # Deploy Windows export
just test-windows-physical-target CONFIG  # Run test with GUI
just logs-windows-physical TEST_ID    # Retrieve logs

# Help
just help                             # Interactive browser
just help-debug                       # Debug workflows
```

---

**Remember**: This justfile system is **critical business infrastructure**. Following these patterns ensures:
- ✅ Correct build sequences
- ✅ Efficient testing workflows
- ✅ Token-efficient debugging
- ✅ Cross-platform consistency
- ✅ Pre-commit validation

**When in doubt**: Check `just help` or relevant `help-*` commands for detailed guidance.
