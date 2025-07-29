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
import "justfiles/justfile-log-filter-commands.justfile"
import "justfiles/justfile-wildcard-core.justfile"
import "justfiles/justfile-wildcard-commands.justfile"
import "justfiles/justfile-universal-log-tags.justfile"
import "justfiles/justfile-semantic-replay-commands.justfile"
import "justfiles/justfile-code-analysis.justfile"
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

    # Step 1: Check if code needs formatting (without modifying)
    echo "1️⃣ Checking code formatting..."
    format_needed=false

    # Check if any .gd files need formatting using gdformat --check
    cd {{PROJECT_PATH}}
    if ! find . -name "*.gd" -type f -not -path "./addons/*" -exec /Users/mattiasmyhrman/.local/bin/gdformat --check {} + 2>/dev/null; then
        format_needed=true
    fi
    cd - > /dev/null  # Return to original directory

    if [ "$format_needed" = true ]; then
        echo "❌ Code formatting required. Please run 'just format' and commit the changes."
        echo "📝 To see which files need formatting, run: just format"
        exit 1
    fi
    echo "✅ Code formatting validated"
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

    if [ ! -d "project/debug_configs" ]; then
        echo "❌ No debug configs directory found"
        echo "💡 Run 'just config-setup' to create sample configs"
        exit 1
    fi

    for config in project/debug_configs/*.json; do
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
    temp_files=(project/debug_configs/temp_wildcard_*.json)
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
    for pattern_file in project/debug_configs/*_*.json; do
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
    @echo "just test-android-target CONFIG        # Android automated testing"
    @echo "just test-desktop-target CONFIG        # Desktop automated testing"
    @echo ""
    @echo "just test-android-manual CONFIG        # Android manual testing"
    @echo "just test-desktop-manual CONFIG        # Desktop manual testing"
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

# Build system architecture and timing help
help-build:
    @echo "Build System Architecture"
    @echo "========================="
    @echo ""
    @echo "THREE-TIER BUILD SYSTEM"
    @echo "======================="
    @echo "just build                       # Complete: source to device deployment (46 min)"
    @echo "just build-toolchain             # Foundation: editor + templates (40 min)"
    @echo "just build-artifacts             # Deployable files for all platforms (45 min)"
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
    @echo "TOKEN-EFFICIENT COMMANDS"
    @echo "========================"
    @echo "just logs-errors TEST_ID            # Quick error scan (98% savings, <10 tokens)"
    @echo "just logs-last                      # Latest test results (99% savings, <5 tokens)"
    @echo "just logs-android TEST_ID *TAGS     # Android logs with tag filtering"
    @echo "just logs-desktop TEST_ID *TAGS     # Desktop logs with tag filtering"
    @echo ""
    @echo "PROGRESSIVE DEBUGGING WORKFLOW"
    @echo "=============================="
    @echo "1. QUICK ERROR SCAN (98% token savings)"
    @echo "just logs-errors TEST_ID            # Show only errors and failures"
    @echo "just logs-android-errors TEST_ID    # Android errors with tag filtering"
    @echo "just logs-desktop-errors TEST_ID    # Desktop errors with tag filtering"
    @echo "Examples:"
    @echo "  just logs-errors abc123"
    @echo "  just logs-android-errors abc123 firebase"
    @echo "  just logs-android-errors abc123 checksum"
    @echo ""
    @echo "2. COMPONENT ANALYSIS (87-95% token savings)"
    @echo "just logs-android TEST_ID [component] OR just logs-desktop TEST_ID [component]"
    @echo "Examples:"
    @echo "  just logs-android abc123 firebase"
    @echo "  just logs-android abc123 battle"
    @echo "  just logs-android abc123 system"
    @echo ""
    @echo "3. PRECISION DEBUGGING (<200 tokens)"
    @echo "just logs-tags TEST_ID *TAGS (available tags)"
    @echo "Examples:"
    @echo "  just logs-tags abc123 firebase"
    @echo "  just logs-tags abc123 battle determinism"
    @echo ""
    @echo "SPECIALIZED DEBUGGING COMMANDS"
    @echo "============================="
    @echo "just logs-checksum-detail TEST_ID       # Detailed checksum state comparison"
    @echo "just logs-performance TEST_ID            # Performance and timing analysis"
    @echo "just logs-lifecycle TEST_ID              # Test lifecycle events"
    @echo "just logs-summary TEST_ID                # Quick test summary"
    @echo ""

# Workflow patterns and best practices help
help-workflows:
    @echo "Common Workflow Patterns & Best Practices"
    @echo "========================================="
    @echo ""
    @echo "TESTING WORKFLOW PATTERNS"
    @echo "========================="
    @echo ""
    @echo "AUTOMATED TESTING:"
    @echo "just test-android-target CONFIG             # Android automated testing"
    @echo "just test-desktop-target CONFIG             # Desktop automated testing"
    @echo ""
    @echo "MANUAL TESTING:"
    @echo "just test-android-manual CONFIG             # Manual testing"
    @echo "just test-android CONFIG                    # Manual testing"

