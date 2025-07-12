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
import "justfiles/justfile-universal-log-tags.justfile"
import "justfiles/justfile-semantic-replay-commands.justfile"
import "justfiles/justfile-recording-integrity-commands.justfile"
import "justfiles/justfile-code-analysis.justfile"
import "justfiles/justfile-validation.justfile"
import "justfiles/justfile-config-validation.justfile"
import "justfiles/justfile-cross-platform-testing.justfile"
import "justfiles/justfile-platform-android.justfile"
import "justfiles/justfile-testing-core.justfile"
import "justfiles/justfile-config.justfile"
import "justfiles/justfile-logs.justfile"
import "justfiles/justfile-build-utils.justfile"
import "justfiles/justfile-help-extended.justfile"

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

# Pre-commit validation - format, syntax check, and runtime validation  
pre-commit:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🚀 Running pre-commit validation..."
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
    if ! just validate; then
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

    echo "🎉 All pre-commit checks passed!"

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


