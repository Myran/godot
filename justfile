#!/usr/bin/env just --justfile

# Main build Justfile for Godot 4 Projects
# Import core configuration first, then other modules
import "justfiles/justfile-core-config.justfile"
import "justfiles/justfile-build-system.justfile"
import "justfiles/justfile-dev-tools.justfile"
import "justfiles/justfile-platform-ios.justfile"
import "justfiles/justfile-help.justfile"
import "justfiles/justfile-run.justfile"
import "justfiles/justfile-cicd.justfile"
import "justfiles/justfile-support.justfile"
import "justfiles/justfile-enhanced-log-analysis.justfile"
import "justfiles/justfile-debug-commands.justfile"
import "justfiles/justfile-gamestate-capture.justfile"
import "justfiles/justfile-gamestate-testing.justfile"
import "justfiles/justfile-log-filter-commands.justfile"
import "justfiles/justfile-wildcard-core.justfile"
import "justfiles/justfile-wildcard-commands.justfile"
import "justfiles/justfile-universal-log-tags.justfile"
import "justfiles/justfile-semantic-replay-commands.justfile"
import "justfiles/justfile-code-analysis.justfile"
import "justfiles/justfile-validation-shared.justfile"
import "justfiles/justfile-validation.justfile"
import "justfiles/justfile-config-validation.justfile"
import "justfiles/justfile-cross-platform-testing.justfile"
import "justfiles/justfile-platform-android.justfile"
import "justfiles/justfile-testing-core.justfile"
import "justfiles/justfile-config.justfile"
import "justfiles/justfile-logs.justfile"
import "justfiles/justfile-build-utils.justfile"
import "justfiles/justfile-android-device-logs.justfile"
# Wildcard help is now integrated in justfile-wildcard-commands.justfile

# Import validation-enhanced-testing LAST to override existing test commands
import "justfiles/justfile-validation-enhanced-testing.justfile"

#import "justfile-test.justfile"
# Set default shell
set shell := ["bash", "-c"]

# Note: All configuration variables, paths, and credentials are now inherited from justfile-core-config.justfile

default:
    @just help

# Main build command - complete pipeline from source to device deployment
build: build-pipeline

# Complete validation - format, syntax check, and runtime validation  
validate:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🚀 Running complete validation..."
    echo ""

    # Step 1: Apply code formatting automatically
    echo "1️⃣ Running code formatting..."
    just format
    echo "✅ Code formatting completed"
    echo ""

    # Step 2: Syntax validation
    echo "2️⃣ Running syntax validation..."
    if ! just validate-gdscript; then
        echo "❌ Syntax validation failed"
        exit 1
    fi
    echo "✅ Syntax validation passed"
    echo ""

    # Step 3: Runtime validation
    echo "3️⃣ Running Godot runtime validation..."
    if ! just validate-godot; then
        echo "❌ Godot runtime validation failed"
        exit 1
    fi
    echo "✅ Godot runtime validation passed"
    echo ""

    echo "🎉 All validation checks passed!"

# Alias for backward compatibility
pre-commit: validate

# Reimport all project assets using Godot CLI --import flag
# Useful after editing GDScript files externally or modifying autoloads
godot-import:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🔄 Reimporting project assets via Godot CLI..."
    echo ""
    
    if ! ./editor/{{GODOT_EXECUTABLE}} --headless --quit --import --path {{PROJECT_PATH}} 2>&1; then
        echo "❌ Godot import failed"
        exit 1
    fi
    
    echo "✅ Project assets reimported successfully"
    echo "💡 Use this command after editing GDScript files externally or changing autoloads"

# CI validation pipeline - runs both desktop and Android validation (fail-fast)
ci-validate:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🚀 Running comprehensive CI validation pipeline (All Platforms)..."
    echo ""

    # Step 1: Run desktop platform validation
    echo "1️⃣ Running desktop platform validation..."
    if ! just ci-validate-desktop; then
        echo "❌ Desktop CI validation failed"
        exit 1
    fi
    echo "✅ Desktop CI validation passed"
    echo ""

    # Step 2: Run Android platform validation  
    echo "2️⃣ Running Android platform validation..."
    if ! just ci-validate-android; then
        echo "❌ Android CI validation failed"
        exit 1
    fi
    echo "✅ Android CI validation passed"
    echo ""

    echo "🎉 All platform CI validations passed!"

# CI validation - desktop platform only
ci-validate-desktop:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🖥️  Running CI validation pipeline (Desktop only)..."
    echo ""

    # Step 1: Format code (auto-fix formatting issues)
    echo "1️⃣ Running code formatting..."
    if ! just format; then
        echo "❌ Code formatting failed"
        exit 1
    fi
    echo "✅ Code formatting completed"
    echo ""

    # Step 2: Reimport project assets via Godot CLI
    echo "2️⃣ Reimporting project assets..."
    if ! just godot-import; then
        echo "❌ Godot import failed"
        exit 1
    fi
    echo "✅ Project assets reimported successfully"
    echo ""

    # Step 3: Lint code quality and style  
    echo "3️⃣ Running code linting..."
    if ! just lint > /tmp/lint_output.txt 2>&1; then
        echo "❌ Code linting failed with problems:"
        cat /tmp/lint_output.txt
        rm -f /tmp/lint_output.txt
        exit 1
    fi
    
    # Check if any problems were reported (but exclude success messages)
    if grep -q "Failure:.*problem found\|Failure:.*problems found" /tmp/lint_output.txt; then
        echo "❌ Linting problems found:"
        cat /tmp/lint_output.txt
        rm -f /tmp/lint_output.txt
        exit 1
    fi
    
    rm -f /tmp/lint_output.txt
    echo "✅ Code linting passed"
    echo ""

    # Step 4: Godot engine validation
    echo "4️⃣ Running Godot runtime validation..."
    if ! just validate-godot; then
        echo "❌ Godot runtime validation failed"
        exit 1
    fi
    echo "✅ Godot runtime validation passed"
    echo ""

    # Step 5: Check for desktop warnings only
    echo "5️⃣ Checking for desktop warnings..."
    if ! just show-warnings > /tmp/warnings_desktop.txt 2>&1; then
        echo "❌ Failed to check desktop warnings"
        exit 1
    fi
    
    # Check if any warnings were found
    if [ -s /tmp/warnings_desktop.txt ]; then
        echo "❌ Desktop warnings found:"
        cat /tmp/warnings_desktop.txt
        rm -f /tmp/warnings_desktop.txt
        exit 1
    fi
    
    rm -f /tmp/warnings_desktop.txt
    echo "✅ No desktop warnings found"
    echo ""

    echo "🎉 Desktop CI validation passed!"

# CI validation - Android platform only
ci-validate-android:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🤖 Running CI validation pipeline (Android only)..."
    echo ""

    # Step 1: Format code (auto-fix formatting issues)
    echo "1️⃣ Running code formatting..."
    if ! just format; then
        echo "❌ Code formatting failed"
        exit 1
    fi
    echo "✅ Code formatting completed"
    echo ""

    # Step 2: Reimport project assets via Godot CLI
    echo "2️⃣ Reimporting project assets..."
    if ! just godot-import; then
        echo "❌ Godot import failed"
        exit 1
    fi
    echo "✅ Project assets reimported successfully"
    echo ""

    # Step 3: Lint code quality and style  
    echo "3️⃣ Running code linting..."
    if ! just lint > /tmp/lint_output.txt 2>&1; then
        echo "❌ Code linting failed with problems:"
        cat /tmp/lint_output.txt
        rm -f /tmp/lint_output.txt
        exit 1
    fi
    
    # Check if any problems were reported (but exclude success messages)
    if grep -q "Failure:.*problem found\|Failure:.*problems found" /tmp/lint_output.txt; then
        echo "❌ Linting problems found:"
        cat /tmp/lint_output.txt
        rm -f /tmp/lint_output.txt
        exit 1
    fi
    
    rm -f /tmp/lint_output.txt
    echo "✅ Code linting passed"
    echo ""

    # Step 4: Godot engine validation
    echo "4️⃣ Running Godot runtime validation..."
    if ! just validate-godot; then
        echo "❌ Godot runtime validation failed"
        exit 1
    fi
    echo "✅ Godot runtime validation passed"
    echo ""

    # Step 5: Check for Android warnings only
    echo "5️⃣ Checking for Android platform warnings..."
    if ! just show-warnings-android > /tmp/warnings_android.txt 2>&1; then
        echo "❌ Failed to check Android warnings"
        exit 1
    fi
    
    # Check if any Android-specific warnings were found (excluding known acceptable warnings)
    if grep -q "ERROR\|SCRIPT ERROR\|Parse Error\|Failed to\|deprecated" /tmp/warnings_android.txt; then
        echo "❌ Critical Android platform issues found:"
        cat /tmp/warnings_android.txt
        rm -f /tmp/warnings_android.txt
        exit 1
    elif grep -q "WARNING.*experimental\|WARNING.*tools:ignore" /tmp/warnings_android.txt; then
        echo "⚠️  Android platform warnings found (non-critical):"
        grep "WARNING\|experimental" /tmp/warnings_android.txt | head -3
        echo "💡 These are acceptable development/gradle warnings"
    fi
    
    rm -f /tmp/warnings_android.txt
    echo "✅ No Android platform warnings found"
    echo ""

    echo "🎉 Android CI validation passed!"

# ================================
# LOGGING UTILITIES
# ================================

# Run any just command with automatic timestamped logging
log-run +ARGS:
    #!/usr/bin/env bash
    set -euo pipefail

    # Create logs directory if it doesn't exist
    mkdir -p logs

    # Generate timestamp and clean command name for filename
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    COMMAND_NAME=$(echo "{{ARGS}}" | tr ' ' '_' | tr -d '"' | sed 's/[^a-zA-Z0-9_-]/_/g')
    LOG_FILE="logs/${TIMESTAMP}_${COMMAND_NAME}.log"

    echo "🚀 Running: just {{ARGS}}"
    echo "📝 Saving output to: $LOG_FILE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Run the command with tee to show output and save to file
    just {{ARGS}} 2>&1 | tee "$LOG_FILE"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ Log saved to: $LOG_FILE"

# Run any just command with automatic timestamped logging (SILENT - output only to file)
log-run-silent +ARGS:
    #!/usr/bin/env bash
    set -euo pipefail

    # Create logs directory if it doesn't exist
    mkdir -p logs

    # Generate timestamp and clean command name for filename
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    COMMAND_NAME=$(echo "{{ARGS}}" | tr ' ' '_' | tr -d '"' | sed 's/[^a-zA-Z0-9_-]/_/g')
    LOG_FILE="logs/${TIMESTAMP}_${COMMAND_NAME}.log"

    echo "🚀 Running: just {{ARGS}} (silent)"
    echo "📝 Saving output to: $LOG_FILE"

    # Run the command and redirect ALL output directly to file (no display)
    just {{ARGS}} > "$LOG_FILE" 2>&1

    echo "✅ Log saved to: $LOG_FILE"

# ================================
# VALIDATION FUNCTIONS
# ================================

runtime-filter-reset:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🔄 Resetting advanced_logger runtime filtering to project defaults..."

    # Auto-detect platform and remove custom config
    if command -v adb >/dev/null 2>&1 && adb devices | grep -q device; then
        echo "📱 Removing custom advanced_logger config from Android device..."
        adb -s {{ANDROID_DEVICE_ID}} shell "rm -f /sdcard/Android/data/{{ANDROID_PACKAGE_NAME}}/files/advanced_logger_settings.cfg" 2>/dev/null || true
    else
        echo "📱 Android device not found, local config reset"
    fi

    echo "✅ Advanced_logger runtime filtering reset!"
    echo "💡 App will use project defaults (DEBUG level, all tags) on next start"
    echo "💡 Restart app to apply: just restart-android-app"

# List available debug configurations
config-list:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📋 Available debug configurations:"
    echo ""

    if [ ! -d "{{DEBUG_CONFIG_DIR}}" ]; then
        echo "❌ No debug configs directory found"
        echo "💡 Run 'just config-setup' to create sample configs"
        exit 1
    fi

    for config in {{DEBUG_CONFIG_DIR}}/*.json; do
        if [ -f "$config" ]; then
            name=$(basename "$config" .json)
            echo "📄 $name:"
            cat "$config" | jq -c '.actions' | sed 's/^/   /'
            echo ""
        fi
    done

    echo "💡 Usage:"
    echo "  just config-restart-android <name>  # Quick testing (5 sec) ⚡"
    echo "  just test-android                   # Interactive test chooser (fzf)"
    echo "  just test-android-target <name>     # Full testing with auto-detection"
    echo "  just test-android-trace <name>      # Debug mode: shows validation/config steps"
    echo "  just config-set <name>              # Set as default config"

# ================================
# DEBUG TESTING & MONITORING
# ================================

# Clean up temporary wildcard config files
cleanup-temp-configs VERBOSE="false":
    #!/usr/bin/env bash
    set -euo pipefail

    # Clean up legacy temporary files
    temp_files=({{DEBUG_CONFIG_DIR}}/temp_wildcard_*.json)
    files_cleaned=0

    if [[ -e "${temp_files[0]}" ]]; then
        if [[ "{{VERBOSE}}" == "true" ]]; then
            echo "🧹 Cleaning up legacy temporary config files:"
            for file in "${temp_files[@]}"; do
                echo "  Removing: $file"
            done
        fi
        rm -f "${temp_files[@]}"
        files_cleaned=$((files_cleaned + ${#temp_files[@]}))
    fi

    # Clean up new safe filename temporary files (those created from wildcards/actions)
    # Look for files with patterns like rtdb_*.json, backend_*.json, etc.
    # These are temporary files created for testing that don't match standard config names
    for pattern_file in {{DEBUG_CONFIG_DIR}}/*_*.json; do
        if [[ -f "$pattern_file" ]]; then
            # Check if this looks like a temporary file by seeing if it contains wildcards in the description
            if grep -q "Temporary config for" "$pattern_file" 2>/dev/null; then
                if [[ "{{VERBOSE}}" == "true" ]]; then
                    echo "  Removing temporary config: $pattern_file"
                fi
                rm -f "$pattern_file"
                files_cleaned=$((files_cleaned + 1))
            fi
        fi
    done

    if [[ $files_cleaned -gt 0 ]]; then
        if [[ "{{VERBOSE}}" == "true" ]]; then
            echo "✅ Cleanup complete ($files_cleaned files removed)"
        fi
    else
        if [[ "{{VERBOSE}}" == "true" ]]; then
            echo "ℹ️  No temporary config files to clean up"
        fi
    fi

# ================================
# DETAILED HELP COMMANDS  
# ================================

# Enhanced debug help with new testing features
help-debug:
    @echo "Debug & Testing Workflow Guide (Enhanced Testing System)"
    @echo "========================================================="
    @echo ""
    @echo "TL;DR - QUICK REFERENCE"
    @echo "======================="
    @echo "Emergency: just logs-errors TEST_ID (5 sec, <10 tokens)"
    @echo "just test-android-target CONFIG (automated testing with built-in validation)"
    @echo "Iterate: just config-restart-android ACTION (5-second cycles)"
    @echo "Debug: Progressive -> logs-errors -> logs-android/logs-desktop -> logs-tags"
    @echo ""
    @echo "ENHANCED TESTING COMMANDS"
    @echo "========================="
    @echo "just test                               # Multi-platform test suite (main config) with unified summary"
    @echo "just test-all                           # 🚀 NEW: Multi-platform with target selection + unified summary"
    @echo "just test-all CONFIG                    # Multi-platform test specific config on desktop + android"
    @echo ""
    @echo "just test-android-target CONFIG         # Android automated testing"
    @echo "just test-desktop-target CONFIG         # Desktop automated testing"
    @echo ""
    @echo "just test-android-manual CONFIG         # Android manual testing"
    @echo "just test-desktop-manual CONFIG         # Desktop manual testing"
    @echo ""
    @echo "ADVANCED PATTERN SYSTEMS"
    @echo "========================"
    @echo "just test-android test-all             # ⭐ Run ALL *-all test suites (@ symbols)"
    @echo "just test-android '/archive/generated-replays/' # 🚀 All battle replays (25+ configs)"
    @echo "just test-android '/archive/generated-replays/merge-*' # 🎯 Specific replay patterns"
    @echo "just test-android firebase-all         # All Firebase testing using @ symbol expansion"
    @echo "just test-android system-all           # Complete system validation"
    @echo "just _expand_test_list test-all        # Preview what configs will be executed"
    @echo ""
    @echo "PATTERN SYSTEM BENEFITS:"
    @echo "• @ Symbols: Automatic discovery, deduplication, circular protection"
    @echo "• /folder/: Direct replay access, wildcard patterns, auto-discovery"
    @echo "• Mixed Syntax: Combine both patterns in same test-list"
    @echo "• Easy Maintenance: Add test suites without updating master lists"
    @echo ""
    @echo "ENHANCED TESTING BENEFITS:"
    @echo "• Automatic error analysis with smart filtering (98% token savings)"
    @echo "• Built-in checksum validation with automatic baseline management ✅ FIXED"
    @echo "• Cross-platform log extraction and parsing"
    @echo "• Progressive failure detection and reporting"
    @echo ""
    @echo "CRITICAL: Debug Action Execution"
    @echo "================================"
    @echo "ALWAYS use test-* commands for debug actions:"
    @echo ""
    @echo "CORRECT:"
    @echo "just test-desktop-target CONFIG       # Enhanced with validation"
    @echo "just test-android-target CONFIG       # Enhanced with validation"
    @echo "just test-desktop CONFIG              # Enables debug coordinator"
    @echo "just test-android CONFIG              # Debug actions execute properly"
    @echo ""
    @echo "WRONG:"
    @echo "just run-desktop                      # Skips debug coordinator (editor mode)"
    @echo "just run-android                      # Debug actions won't execute"
    @echo ""
    @echo "DESKTOP DEBUG COMMANDS"
    @echo "====================="
    @echo "just run-desktop-debug               # Debug mode (normal output)"
    @echo "just run-desktop-debug verbose      # Debug mode with ObjectDB leak details"
    @echo ""
    @echo "🎮 GAMESTATE SAVE/LOAD WORKFLOW"
    @echo "==============================="
    @echo "just help-gamestate                  # Complete workflow guide"
    @echo "just capture-gamestate NAME          # Extract captured state from logs"
    @echo "just list-saved-states               # Show available saved states"
    @echo "just test-save-load-cycle            # Validate save/load consistency"
    @echo "just test-gamestate-cycle            # Complete gamestate test cycle"
    @echo ""
    @echo "📋 Common Usage:"
    @echo "  play → save state → capture-gamestate → load state → test"
    @echo ""

# Build system architecture and timing help
help-build:
    @echo "Build System Architecture"
    @echo "========================="
    @echo ""
    @echo "🏗️  BUILD SYSTEM HIERARCHY (Top-Down Breakdown)"
    @echo "==============================================="
    @echo ""
    @echo "┌─ just build (alias: build-pipeline) - 46 min"
    @echo "│  Complete: source → device deployment"
    @echo "│"
    @echo "├──┬─ just build-artifacts - 45 min"
    @echo "│  │  Builds: All deployable files for all platforms"
    @echo "│  │"
    @echo "│  ├──┬─ just build-toolchain - 40 min"
    @echo "│  │  │  Builds: Editor + templates"
    @echo "│  │  │"
    @echo "│  │  ├─── just build-editor"
    @echo "│  │  │    Compiles custom Godot editor from source"
    @echo "│  │  │"
    @echo "│  │  └─── just templates-all"
    @echo "│  │       ├─── just templates-ios"
    @echo "│  │       │    └─── just build-and-package-ios-templates"
    @echo "│  │       │"
    @echo "│  │       └─── just templates-android"
    @echo "│  │            ├─── just build-android-templates"
    @echo "│  │            │    ├─ SCons: Compile C++ modules → .so files"
    @echo "│  │            │    └─ Gradle: Package .so → .aar (generateGodotTemplates)"
    @echo "│  │            │       Output: templates/android_source.zip"
    @echo "│  │            │"
    @echo "│  │            └─── just setup-android"
    @echo "│  │                 Validates Android SDK environment"
    @echo "│  │"
    @echo "│  ├─── just install-android-template"
    @echo "│  │    Extracts templates/android_source.zip → project/android/build/"
    @echo "│  │"
    @echo "│  ├─── just quick-build-android"
    @echo "│  │    ├─── just insert-firebase-dependencies"
    @echo "│  │    └─── just export-apk-android"
    @echo "│  │         Godot export (calls Gradle internally for APK)"
    @echo "│  │         Output: export/android/gametwo_debug.apk"
    @echo "│  │"
    @echo "│  └─── just build-pipeline-ios"
    @echo "│       iOS: source → ready for device"
    @echo "│"
    @echo "└─── just install-apk-android"
    @echo "     Installs export/android/gametwo_debug.apk to device"
    @echo ""
    @echo "🎯 ALTERNATIVE BUILD PATHS"
    @echo "=========================="
    @echo ""
    @echo "🏗️  just build-all-android - 3-25 min (Android-only pipeline)"
    @echo "   ├─── just _build-common"
    @echo "   └─── just _build-android-full"
    @echo "        ├─── just _check-or-build-android-templates"
    @echo "        │    └─ Calls templates-android if needed"
    @echo "        ├─── just insert-firebase-dependencies"
    @echo "        ├─── just export-apk-android"
    @echo "        │    Godot --export-debug (Gradle runs internally)"
    @echo "        │    Output: export/android/ (NOT installed to device)"
    @echo "        └─── just export-aab-android"
    @echo "             Output: AAB for Play Store"
    @echo ""
    @echo "⚡ just fastbuild-android - 30-60 sec (Dev iteration)"
    @echo "   Requires: install-android-template run first"
    @echo "   ├─── Godot --export-debug to /tmp/"
    @echo "   ├─── just insert-firebase-dependencies"
    @echo "   ├─── just _gradle-build-install-android"
    @echo "   │    ├─ insert-firebase-dependencies"
    @echo "   │    ├─ Gradle assembleStandardDebug (explicit, direct control)"
    @echo "   │    │  Builds from project/android/build/"
    @echo "   │    └─ adb install (direct to device)"
    @echo "   └─── just launch-android"
    @echo ""
    @echo "ANDROID BUILD PATHWAYS (Understanding the System)"
    @echo "================================================="
    @echo ""
    @echo "🔧 1. TEMPLATE BUILDING (C++ Changes)"
    @echo "   just build-android-templates     # SCons compile C++ → Gradle package .aar (3-15 min)"
    @echo "   just install-android-template    # Install templates to Godot"
    @echo "   Use when: C++ module changes (Firebase, custom modules)"
    @echo "   Output: templates/android_source.zip + project/android/build/"
    @echo ""
    @echo "🏗️  2. FULL PIPELINE (Complete Build)"
    @echo "   just build-all-android           # Templates + Firebase + APK + AAB (3-25 min)"
    @echo "   Flow:"
    @echo "     → build-android-templates (SCons + Gradle .aar)"
    @echo "     → insert-firebase-dependencies"
    @echo "     → export-apk-android (Godot export, calls Gradle internally)"
    @echo "     → export-aab-android (AAB for Play Store)"
    @echo "   Use when: Building for release or first-time setup"
    @echo "   Output: export/android/gametwo_debug.apk (NOT installed to device)"
    @echo "   Note: Uses templates/android_source.zip directly (no install-android-template needed)"
    @echo ""
    @echo "⚡ 3. QUICK BUILD (Skip Template Check)"
    @echo "   just quick-build-android         # Firebase + Export (2-3 min)"
    @echo "   Flow:"
    @echo "     → insert-firebase-dependencies"
    @echo "     → export-apk-android (Godot export, Gradle)"
    @echo "   Use when: GDScript/asset changes, templates already built"
    @echo ""
    @echo "🚀 4. FAST BUILD (Dev Iteration)"
    @echo "   just fastbuild-android           # Godot export + Gradle build + Install (30-60 sec)"
    @echo "   Flow:"
    @echo "     → Godot --export-debug to /tmp/"
    @echo "     → insert-firebase-dependencies"
    @echo "     → Gradle assembleStandardDebug (explicit control)"
    @echo "     → Install to device + launch"
    @echo "   Use when: Rapid GDScript iteration (REQUIRED after template changes for testing)"
    @echo "   Requires: install-android-template must be run first"
    @echo "   Output: Builds to project/android/build/ and installs to device"
    @echo ""
    @echo "📦 5. EXPORT ONLY (No Firebase)"
    @echo "   just export-apk-android          # Pure Godot export (1-2 min)"
    @echo "   Use when: Creating export artifacts without Firebase setup"
    @echo ""
    @echo "🎯 C++ DEVELOPMENT WORKFLOW"
    @echo "============================"
    @echo "For C++ changes (Firebase, custom modules):"
    @echo "   just build-android-templates     # 1. Build C++ → .aar"
    @echo "   just install-android-template    # 2. Install template"
    @echo "   just fastbuild-android           # 3. Package + deploy (REQUIRED for testing)"
    @echo ""
    @echo "Why fastbuild is required:"
    @echo "   • Gradle step combines new .aar templates with game files"
    @echo "   • Installs to device for immediate testing"
    @echo "   • Without it, templates exist but aren't deployed"
    @echo ""
    @echo "🔍 TEMPLATE SYSTEM EXPLAINED"
    @echo "============================"
    @echo "Two template usage patterns:"
    @echo ""
    @echo "Pattern 1: export-apk-android (Godot-managed)"
    @echo "   • Uses: templates/android_source.zip directly"
    @echo "   • Godot extracts internally during export"
    @echo "   • No install-android-template needed"
    @echo "   • Output: export/android/"
    @echo ""
    @echo "Pattern 2: fastbuild-android (Direct Gradle)"
    @echo "   • Uses: project/android/build/ (pre-extracted)"
    @echo "   • Requires: install-android-template first"
    @echo "   • Direct Gradle control with custom parameters"
    @echo "   • Output: project/android/build/ → device"
    @echo ""
    @echo "💡 GRADLE IN THE BUILD SYSTEM"
    @echo "=============================="
    @echo "Gradle runs in TWO different stages:"
    @echo ""
    @echo "Stage 1: Template Packaging (build-android-templates)"
    @echo "   Command: ./gradlew generateGodotTemplates"
    @echo "   Location: godot/platform/android/java/"
    @echo "   Purpose: Package C++ .so files into .aar libraries"
    @echo "   Output: godot/bin/godot-lib.debug.aar"
    @echo ""
    @echo "Stage 2: Game APK Building"
    @echo "   A) Via Godot export (export-apk-android):"
    @echo "      • Godot calls Gradle internally (implicit)"
    @echo "      • Location: Godot manages internally"
    @echo ""
    @echo "   B) Via direct Gradle (fastbuild-android):"
    @echo "      • Command: ./gradlew assembleStandardDebug"
    @echo "      • Location: project/android/build/"
    @echo "      • Purpose: Build APK with .aar + game assets + Firebase"
    @echo "      • Output: Installable APK for device"
    @echo ""
    @echo "SMART BUILD COMMANDS (Development)"
    @echo "=================================="
    @echo "# Fast development builds"
    @echo "just fastbuild-android           # Android fast build (30-60 sec)"
    @echo "just build-install-ios           # iOS rebuild & install (2-5 min)"
    @echo "just build-status                # Check what's built"
    @echo ""
    @echo "# Platform-specific pipelines"
    @echo "just build-all-android           # Android smart rebuild (3-25 min)"
    @echo "just build-all-ios               # iOS smart rebuild (3-5 min)"

# Log analysis and token efficiency help
help-logs:
    @echo "Log Analysis & Token Efficiency Guide"
    @echo "====================================="
    @echo ""
    @echo "🚀 NEW: WILDCARD PATTERN SYSTEM (10x Productivity)"
    @echo "=================================================="
    @echo "just help-wildcards                     # Complete wildcard system help"
    @echo "just help-wildcard-quick                # Quick pattern reference"
    @echo ""
    @echo "WILDCARD PATTERN COMMANDS:"
    @echo "just logs-pattern TEST_ID PATTERN       # Single pattern matching"
    @echo "just logs-multi TEST_ID PATTERN1 PATTERN2  # Multiple patterns (OR logic)"
    @echo "just logs-exclude TEST_ID PATTERN EXCLUDE  # Include/exclude filtering"
    @echo "just logs-discover TEST_ID PREFIX        # Find tags with prefix"
    @echo "just logs-tree TEST_ID                   # Show hierarchical tag structure"
    @echo "just logs-suggest TEST_ID PARTIAL        # Auto-complete suggestions"
    @echo ""
    @echo "PATTERN EXAMPLES:"
    @echo "  just logs-pattern TEST_ID \"firebase.*\"     # All Firebase operations"
    @echo "  just logs-pattern TEST_ID \"*.error\"        # All error operations"
    @echo "  just logs-pattern TEST_ID \"game.*.start\"   # All start events"
    @echo "  just logs-exclude TEST_ID \"firebase.*\" \"firebase.debug\"  # Firebase without debug"
    @echo ""
    @echo "TOKEN-EFFICIENT COMMANDS"
    @echo "========================"
    @echo "just logs-errors TEST_ID            # Quick error scan (98% savings, <10 tokens)"
    @echo "just logs-text TEST_ID \"search_term\" # ⭐ NEW: Simple text search (99% savings, case-insensitive)"
    @echo "just logs-last                      # Latest test results (99% savings, <5 tokens)"
    @echo "just logs-android TEST_ID *TAGS     # Android logs with tag filtering"
    @echo "just logs-desktop TEST_ID *TAGS     # Desktop logs with tag filtering"
    @echo ""
    @echo "PROGRESSIVE DEBUGGING WORKFLOW"
    @echo "=============================="
    @echo "1. EXPLORE STRUCTURE (NEW - Most Efficient)"
    @echo "just logs-tree TEST_ID                  # Discover tag hierarchy"
    @echo "just logs-discover TEST_ID firebase     # Find firebase-related tags"
    @echo ""
    @echo "2. QUICK ERROR SCAN (98% token savings)"
    @echo "just logs-errors TEST_ID            # Show only errors and failures"
    @echo "just logs-text TEST_ID \"search_term\" # ⭐ NEW: Simple text search (any string)"
    @echo "just logs-pattern TEST_ID \"*.error\"   # All errors using wildcards"
    @echo "just logs-android-errors TEST_ID    # Android errors with tag filtering"
    @echo "just logs-desktop-errors TEST_ID    # Desktop errors with tag filtering"
    @echo "Examples:"
    @echo "  just logs-errors abc123"
    @echo "  just logs-text abc123 \"warning\"          # Find any warnings"
    @echo "  just logs-text abc123 \"parsing to config\" # Find specific text"
    @echo "  just logs-pattern abc123 \"firebase.*\""
    @echo "  just logs-android-errors abc123 firebase"
    @echo "  just logs-android-errors abc123 checksum"
    @echo ""
    @echo "3. COMPONENT ANALYSIS (87-95% token savings)"
    @echo "just logs-android TEST_ID [component] OR just logs-desktop TEST_ID [component]"
    @echo "just logs-pattern TEST_ID \"domain.*\" (NEW - more precise)"
    @echo "Examples:"
    @echo "  just logs-android abc123 firebase"
    @echo "  just logs-pattern abc123 \"database.*\""
    @echo "  just logs-pattern abc123 \"game.battle.*\""
    @echo "  just logs-android abc123 system"
    @echo ""
    @echo "4. PRECISION DEBUGGING (<200 tokens)"
    @echo "just logs-tags TEST_ID *TAGS (available tags)"
    @echo "just logs-pattern TEST_ID \"specific.pattern\" (NEW - exact matching)"
    @echo "Examples:"
    @echo "  just logs-tags abc123 firebase"
    @echo "  just logs-pattern abc123 \"firebase.auth\""
    @echo "  just logs-tags abc123 battle determinism"
    @echo ""
    @echo "@ SYMBOL TESTING LOG ANALYSIS"
    @echo "=============================="
    @echo ""
    @echo "ANALYZING @ SYMBOL TEST RUNS:"
    @echo "When you run: just test-android test-all"
    @echo "Get TEST_ID, then analyze with:"
    @echo ""
    @echo "just logs-errors TEST_ID                 # Quick pass/fail across all 15 configs"
    @echo "just logs-pattern TEST_ID \"*.error\"     # All errors from comprehensive testing"
    @echo "just logs-pattern TEST_ID \"firebase.*\"  # Focus on Firebase issues"
    @echo "just logs-pattern TEST_ID \"game.*\"      # Focus on game system issues"
    @echo "just logs-exclude TEST_ID \"firebase.*\" \"firebase.debug\" # Filter noise"
    @echo ""
    @echo "DOMAIN-SPECIFIC LOG ANALYSIS:"
    @echo "firebase-all testing:"
    @echo "  just logs-pattern TEST_ID \"firebase.*\"     # All Firebase operations"
    @echo "  just logs-pattern TEST_ID \"database.*\"     # Database-specific issues"
    @echo ""
    @echo "system-all testing:"
    @echo "  just logs-pattern TEST_ID \"system.*\"       # All system operations"
    @echo "  just logs-pattern TEST_ID \"performance.*\"  # Performance data"
    @echo ""
    @echo "battle-all testing:"
    @echo "  just logs-pattern TEST_ID \"game.battle.*\"  # Battle system focus"
    @echo "  just logs-pattern TEST_ID \"*.checksum\"     # Determinism validation"
    @echo ""
    @echo "COMPREHENSIVE TESTING ANALYSIS:"
    @echo "After test-all (15 configs), efficiently analyze:"
    @echo "1. just logs-errors TEST_ID                   # Overall pass/fail"
    @echo "2. just logs-tree TEST_ID                     # See what domains were tested"
    @echo "3. just logs-pattern TEST_ID \"*.timeout\"     # Find timeout issues"
    @echo "4. just logs-multi TEST_ID \"*.error\" \"*.fail\" # All failure types"
    @echo ""
    @echo "SPECIALIZED DEBUGGING COMMANDS"
    @echo "============================="
    @echo "just logs-checksum-detail TEST_ID       # Detailed checksum state comparison"
    @echo "just logs-performance TEST_ID            # Performance and timing analysis"
    @echo "just logs-lifecycle TEST_ID              # Test lifecycle events"
    @echo "just logs-summary TEST_ID                # Quick test summary"
    @echo "just logs-benchmark TEST_ID PATTERN     # Pattern performance testing"
    @echo ""

# Workflow patterns and best practices help
help-workflows:
    @echo "Common Workflow Patterns & Best Practices"
    @echo "========================================="
    @echo ""
    @echo "TESTING WORKFLOW PATTERNS"
    @echo "========================="
    @echo ""
    @echo "CROSS-PLATFORM TESTING:"
    @echo "just test                                   # Multi-platform test suite (main config) with unified summary"
    @echo "just test-all                               # Multi-platform with target selection + unified summary"
    @echo "just test-all CONFIG                        # Multi-platform test specific config on desktop + android"
    @echo ""
    @echo "AUTOMATED TESTING:"
    @echo "just test-android-target CONFIG             # Android automated testing"
    @echo "just test-desktop-target CONFIG             # Desktop automated testing"
    @echo ""
    @echo "MANUAL TESTING:"
    @echo "just test-android-manual CONFIG             # Manual testing"
    @echo "just test-android CONFIG                    # Manual testing"
    @echo ""
    @echo "@ SYMBOL TESTING WORKFLOWS (NEW)"
    @echo "================================"
    @echo ""
    @echo "COMPREHENSIVE TESTING:"
    @echo "just test-android test-all                  # Ultimate comprehensive testing (15 configs)"
    @echo "just _expand_test_list test-all             # Preview what will be executed"
    @echo ""
    @echo "DOMAIN-SPECIFIC TESTING:"
    @echo "just test-android firebase-all              # All Firebase testing automatically"
    @echo "just test-android system-all                # Complete system validation"
    @echo "just test-android battle-all                # Battle system comprehensive testing"
    @echo ""
    @echo "DEVELOPMENT WORKFLOW PATTERNS"
    @echo "============================="
    @echo ""
    @echo "DAILY DEVELOPMENT:"
    @echo "1. just validate                            # Syntax + format check"
    @echo "2. just test-android firebase-all           # Domain testing"
    @echo "3. just logs-errors TEST_ID                 # Quick error scan"
    @echo "4. just config-restart-android ACTION       # 5-second iterations"
    @echo ""
    @echo "PRE-COMMIT WORKFLOW:"
    @echo "1. just validate                            # Complete validation"
    @echo "2. just test-android test-all               # Comprehensive testing"
    @echo "3. just logs-errors TEST_ID                 # Error verification"
    @echo ""
    @echo "DEBUGGING WORKFLOW:"
    @echo "1. just test-android CONFIG                 # Reproduce issue"
    @echo "2. just logs-errors TEST_ID                 # Find errors (98% token savings)"
    @echo "3. just logs-pattern TEST_ID \"*.error\"      # All error operations"
    @echo "4. just logs-android TEST_ID component      # Deep analysis"
    @echo ""
    @echo "PERFORMANCE INVESTIGATION:"
    @echo "1. just test-android system-performance     # Performance testing"
    @echo "2. just logs-performance TEST_ID            # Performance analysis"
    @echo "3. just logs-pattern TEST_ID \"performance.*\" # All performance data"
    @echo ""
    @echo "@ SYMBOL BEST PRACTICES"
    @echo "======================="
    @echo ""
    @echo "CREATE FOCUSED TEST LISTS:"
    @echo "• Use @firebase-* for Firebase domain testing"
    @echo "• Use @*-all for comprehensive testing"
    @echo "• Mix @ symbols with specific configs for custom workflows"
    @echo ""
    @echo "ORGANIZE BY PURPOSE:"
    @echo "• development-workflow: Daily testing patterns"
    @echo "• pre-commit: Essential validation before commits"
    @echo "• production-ready: Release readiness validation"
    @echo "• firebase-all: Complete Firebase testing"
    @echo ""
    @echo "LEVERAGE AUTO-DISCOVERY:"
    @echo "• New test lists ending with -all are automatically included in test-all"
    @echo "• Wildcard patterns find new content without manual updates"
    @echo "• Focus on creating good individual test lists, not maintaining master lists"
    @echo ""
    @echo "COMMON PATTERNS"
    @echo "=============="
    @echo ""
    @echo "REGRESSION TESTING:"
    @echo "just test-android test-all                  # Run everything"
    @echo "just logs-errors TEST_ID                    # Quick pass/fail check"
    @echo ""
    @echo "FEATURE DEVELOPMENT:"
    @echo "just test-android firebase-all              # Test related systems"
    @echo "just config-restart-android ACTION          # Rapid iteration"
    @echo ""
    @echo "BUG INVESTIGATION:"
    @echo "just test-android CONFIG                    # Reproduce bug"
    @echo "just logs-pattern TEST_ID \"*.error\"        # Find all errors"
    @echo "just logs-exclude TEST_ID \"firebase.*\" \"firebase.debug\" # Filter noise"
    @echo ""
    @echo "PERFORMANCE ANALYSIS:"
    @echo "just test-android system-performance        # Performance baseline"
    @echo "just logs-pattern TEST_ID \"performance.*\"  # All performance data"
    @echo "just logs-pattern TEST_ID \"*.timeout\"      # Find timeout issues"

