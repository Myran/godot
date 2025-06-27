#!/usr/bin/env just --justfile

# Main build Justfile for Godot 4 Projects
# Import other Justfiles
import "justfile-help.justfile"
import "justfile-run.justfile"
import "justfile-cicd.justfile"
import "justfile-support.justfile"
import "enhanced_log_analysis.justfile"
import "debug_commands.justfile"
import "log_filter_commands.justfile"
import "universal_log_tags.justfile"
import "action_recording_commands.justfile"

#import "justfile-test.justfile"
# Set default shell
set shell := ["bash", "-c"]

# ================================
# CORE PROJECT CONFIGURATION
# ================================
GAME_NAME := env_var_or_default("CI_PROJECT_NAME", "gametwo")
PROJECT_PATH := justfile_directory() + "/project"
GODOT_EXECUTABLE := "godot.macos.editor.arm64"  # For Apple Silicon Macs
GODOT_VERSION := "4.0"
GODOT_BUILD_VERSION := "4.3.rc"

# ================================
# DEVICE CONFIGURATION
# ================================
# iOS Devices
IOS_IPHONE_DEVICE_ID := env_var_or_default("IOS_IPHONE_DEVICE_ID", "C9A2C197-B5E7-5B83-86C2-2D1EDF2CEB48")
IOS_IPAD_DEVICE_ID := env_var_or_default("IOS_IPAD_DEVICE_ID", "A4045434-B5F5-48B5-8654-C128A403149A")

# Android Devices  
ANDROID_DEVICE_ID := env_var_or_default("ANDROID_DEVICE_ID", "246d2c533a037ece")
ANDROID_DEVICE_IP := env_var_or_default("ANDROID_DEVICE_IP", "192.168.1.100")

# ================================
# PLATFORM IDENTIFIERS
# ================================
ANDROID_PACKAGE_NAME := env_var_or_default("ANDROID_PACKAGE_NAME", "com.primaryhive." + GAME_NAME)
IOS_BUNDLE_IDENTIFIER := env_var_or_default("IOS_BUNDLE_IDENTIFIER", "com.primaryhive." + GAME_NAME)

# ================================
# BUILD PATHS & TOOLS
# ================================
ANDROID_SDK_PATH := env_var_or_default("ANDROID_SDK_PATH", "~/Library/Android/sdk")
ANDROID_NDK_PATH := env_var_or_default("ANDROID_NDK_PATH", ANDROID_SDK_PATH + "/ndk/25.1.8937393")
ANDROID_GRADLE_DIR := "build/gradle"
KEYSTORE_PATH := env_var_or_default("KEYSTORE_PATH", "./keys/" + GAME_NAME + ".keystore")

# ================================
# CREDENTIALS (Environment-based)
# ================================
# Only sensitive data remains as exports for security
export KEYSTORE_PASSWORD := env_var_or_default("KEYSTORE_PASSWORD", "lovegametwo")
export KEY_PASSWORD := env_var_or_default("KEY_PASSWORD", "lovegametwo")
export APPLE_TEAM_ID := env_var_or_default("APPLE_TEAM_ID", "123")
export APPLE_ID := env_var_or_default("APPLE_ID", "123")
export APP_STORE_CONNECT_API_KEY_PATH := env_var_or_default("APP_STORE_CONNECT_API_KEY_PATH", "123")
export IOS_PROVISIONING_PROFILE_UUID := env_var_or_default("IOS_PROVISIONING_PROFILE_UUID", "123")

# Godot submodule settings
GODOT_REPO := "https://github.com/godotengine/godot.git"
GODOT_BRANCH := "gametwo"  # Replace with your custom branch name
GODOT_SUBMODULE_PATH := "godot"

# Utility functions
timestamp := `date +%Y%m%d%H%M%S`
jobs := `sysctl -n hw.logicalcpu`

    
default:
    @just help

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

c:
    @just --choose
l:
    @just -l

# ================================
# VALIDATION FUNCTIONS
# ================================

# Validate Android device connectivity (lenient - allows basic commands to work)
_validate-android-device:
    @true

# Strict Android device validation (requires actual device connection)
_require-android-device:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! adb -s {{ANDROID_DEVICE_ID}} shell echo "Connected" >/dev/null 2>&1; then
        echo "❌ Android device not connected: {{ANDROID_DEVICE_ID}}"
        echo "💡 Check device connection and run: adb devices"
        exit 1
    fi
    echo "✅ Android device connected"

# Clean up temporary config file if it was auto-generated
_cleanup-temp-config CONFIG:
    #!/usr/bin/env bash
    set -euo pipefail
    CONFIG_FILE="project/debug_configs/{{CONFIG}}.json"
    
    # Check if this is a temporary config by looking for our specific description patterns
    if [ -f "$CONFIG_FILE" ] && (grep -q "Temporary config for single action:" "$CONFIG_FILE" 2>/dev/null || grep -q "Temporary.*config for.*pattern:" "$CONFIG_FILE" 2>/dev/null); then
        echo "🧹 Cleaning up temporary config: $CONFIG_FILE"
        rm "$CONFIG_FILE"
        echo "✅ Temporary config cleaned up"
    fi

# Helper function to get safe config filename
_get-safe-config-file CONFIG:
    #!/usr/bin/env bash
    SAFE_CONFIG_NAME=$(echo "{{CONFIG}}" | sed 's/[^a-zA-Z0-9._-]/_/g')
    echo "project/debug_configs/${SAFE_CONFIG_NAME}.json"

# Validate config file exists or create temporary config for single action
_validate-config-exists CONFIG:
    #!/usr/bin/env bash
    set -euo pipefail
    # Generate safe filename for config (replace unsafe characters)
    SAFE_CONFIG_NAME=$(echo "{{CONFIG}}" | sed 's/[^a-zA-Z0-9._-]/_/g')
    CONFIG_FILE="project/debug_configs/${SAFE_CONFIG_NAME}.json"
    
    # Check if safe config file exists (including temporary ones)
    if [ -f "$CONFIG_FILE" ]; then
        exit 0
    fi
    
    # Also check if original unsafe filename exists (for backward compatibility)
    ORIGINAL_CONFIG_FILE="project/debug_configs/{{CONFIG}}.json"
    if [ -f "$ORIGINAL_CONFIG_FILE" ]; then
        exit 0
    fi
    
    # Config file doesn't exist - check if CONFIG is a config pattern or action name
    echo "🔍 Config file not found: $CONFIG_FILE"
    
    # Check if it's a wildcard pattern
    if [[ "{{CONFIG}}" == *'*'* ]]; then
        echo "🔍 Detected wildcard pattern: {{CONFIG}}"
        
        # First, try to match config file names
        echo "🔍 Checking for matching config files..."
        CONFIG_PATTERN="{{CONFIG}}"
        MATCHING_CONFIGS=$(ls project/debug_configs/*.json 2>/dev/null | sed 's|project/debug_configs/||g' | sed 's|\.json||g' | grep -E "^$(echo "$CONFIG_PATTERN" | sed 's/\*/.*/')\$" | head -20)
        
        if [ -n "$MATCHING_CONFIGS" ]; then
            echo "✅ Found matching config files:"
            echo "$MATCHING_CONFIGS" | sed 's/^/  /'
            echo "🔧 Creating temporary test list for config pattern: {{CONFIG}}"
            
            # Create temporary test list file 
            TEMP_LIST_FILE="project/test-lists/temp_pattern_${SAFE_CONFIG_NAME}.json"
            CONFIG_LIST=$(echo "$MATCHING_CONFIGS" | sed 's/^/    "/' | sed 's/$/",/' | sed '$s/,$//')
            {
                echo '{'
                echo '  "name": "Config Pattern: '"$CONFIG_PATTERN"'",'
                echo '  "description": "Auto-generated test list for config pattern: '"$CONFIG_PATTERN"'",'
                echo '  "configs": ['
                echo "$CONFIG_LIST"
                echo '  ]'
                echo '}'
            } > "$TEMP_LIST_FILE"
            
            # Run the temporary test list 
            echo "✅ Temporary test list created: $TEMP_LIST_FILE"
            echo "🚀 Executing config pattern as test list..."
            
            # Execute via test list system and exit with its result
            exec just _test-list-android "temp_pattern_${SAFE_CONFIG_NAME}"
        fi
        
        echo "🔍 No matching config files, checking for action pattern..."
        echo "🔧 Creating temporary config for wildcard pattern: {{CONFIG}}"
        
        # Create temporary config with safe filename - NO TRAP HERE
        # Cleanup will be handled by the calling test function
        PATTERN_NAME="{{CONFIG}}"
        echo '{"description":"Temporary config for wildcard pattern: '"$PATTERN_NAME"'","actions":["'"$PATTERN_NAME"'"]}' > "$CONFIG_FILE"
        echo "✅ Temporary wildcard config created: $CONFIG_FILE"
        echo "💡 This temporary config will be cleaned up automatically"
        exit 0
    fi
    
    # Look for the action in existing config files to see if it's a valid action name
    if grep -r "\"{{CONFIG}}\"" project/debug_configs/*.json >/dev/null 2>&1; then
        echo "✅ Found '{{CONFIG}}' as an action name"
        echo "🔧 Creating temporary config for single action: {{CONFIG}}"
        
        # Create temporary config with safe filename - NO TRAP HERE
        # Cleanup will be handled by the calling test function
        ACTION_NAME="{{CONFIG}}"
        echo '{"description":"Temporary config for single action: '"$ACTION_NAME"'","actions":["'"$ACTION_NAME"'"]}' > "$CONFIG_FILE"
        echo "✅ Temporary config created: $CONFIG_FILE"
        echo "💡 This temporary config will be cleaned up automatically"
        exit 0
    fi
    
    # Check if action would match any existing wildcard patterns
    ACTION_NAME="{{CONFIG}}"
    MATCHED_PATTERN=""
    while IFS= read -r pattern; do
        # Convert wildcard pattern to regex and test
        regex_pattern=$(echo "$pattern" | sed 's/\./\\./g; s/\*/[^.]*/g; s/\?/[^.]/g')
        if echo "$ACTION_NAME" | grep -qE "^${regex_pattern}$"; then
            MATCHED_PATTERN="$pattern"
            break
        fi
    done < <(grep -rh '"[^"]*\*[^"]*"' project/debug_configs/*.json 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' | sort -u)
    
    if [ -n "$MATCHED_PATTERN" ]; then
        echo "✅ Action '{{CONFIG}}' matches wildcard pattern: $MATCHED_PATTERN"
        echo "🔧 Creating temporary config for single action: {{CONFIG}}"
        
        # Create temporary config with safe filename - NO TRAP HERE
        # Cleanup will be handled by the calling test function
        echo '{"description":"Temporary config for single action: '"$ACTION_NAME"'","actions":["'"$ACTION_NAME"'"]}' > "$CONFIG_FILE"
        echo "✅ Temporary config created: $CONFIG_FILE"
        echo "💡 This temporary config will be cleaned up automatically"
        exit 0
    fi
    
    # Neither config file nor action name found
    echo "❌ Neither config file nor action name found for: {{CONFIG}}"
    echo ""
    echo "💡 Available config files:"
    ls -1 project/debug_configs/*.json 2>/dev/null | sed 's|project/debug_configs/||g' | sed 's|\.json||g' | sed 's/^/  /' || echo "  (no configs found)"
    echo ""
    echo "💡 Example action names (from existing configs):"
    grep -h "\"[A-Z].*Test\"" project/debug_configs/*.json 2>/dev/null | sed 's/.*"\([^"]*\)".*/  \1/' | sort -u | head -10 || echo "  (no action examples found)"
    exit 1

# Validate iOS development tools are available
_validate-ios-tools:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! xcrun devicectl list devices >/dev/null 2>&1; then
        echo "❌ iOS development tools not available"
        echo "💡 Install Xcode Command Line Tools: xcode-select --install"
        exit 1
    fi

# Validate iOS device connectivity  
_validate-ios-device DEVICE_TYPE:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Get device ID based on type
    if [ "{{DEVICE_TYPE}}" = "iphone" ]; then
        DEVICE_ID="{{IOS_IPHONE_DEVICE_ID}}"
        DEVICE_NAME="iPhone"
    elif [ "{{DEVICE_TYPE}}" = "ipad" ]; then
        DEVICE_ID="{{IOS_IPAD_DEVICE_ID}}"
        DEVICE_NAME="iPad"
    else
        echo "❌ Invalid device type: {{DEVICE_TYPE}}. Use 'iphone' or 'ipad'"
        exit 1
    fi
    
    # Check device connectivity
    if ! xcrun devicectl list devices | grep -q "$DEVICE_ID" 2>/dev/null; then
        echo "❌ $DEVICE_NAME not connected: $DEVICE_ID"
        echo "💡 Check device connection and run: xcrun devicectl list devices"
        exit 1
    fi

# Validate file or directory exists
_validate-path-exists PATH:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -e "{{PATH}}" ]; then
        echo "❌ Path not found: {{PATH}}"
        exit 1
    fi

# Validate Godot editor is available
_validate-godot-editor:
    #!/usr/bin/env bash
    set -euo pipefail
    EDITOR_PATH="./editor/{{GODOT_EXECUTABLE}}"
    if [ ! -f "$EDITOR_PATH" ]; then
        echo "❌ Godot editor not found: $EDITOR_PATH"
        echo "💡 Build the editor first: just build-editor"
        exit 1
    fi

# Validate Android package installation status
_validate-android-package-installed:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! adb -s {{ANDROID_DEVICE_ID}} shell pm list packages | grep -q "{{ANDROID_PACKAGE_NAME}}" 2>/dev/null; then
        echo "❌ Android package not installed: {{ANDROID_PACKAGE_NAME}}"
        echo "💡 Install APK first: just install-apk-android"
        exit 1
    fi

# Validate directory exists, create if missing
_ensure-directory-exists DIR:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -d "{{DIR}}" ]; then
        echo "📁 Creating directory: {{DIR}}"
        mkdir -p "{{DIR}}"
    fi

# Combined validation for Android development workflow
_validate-android-workflow:
    @just _require-android-device
    @echo "✅ Android workflow validated"

# ================================
# DICTIONARY PATTERN ANALYSIS
# ================================

# Analyze dictionary iteration patterns in the codebase
analyze-dict-patterns:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔍 Analyzing dictionary iteration patterns in GDScript files..."
    echo ""
    
    # Find direct dictionary key iteration patterns
    echo "📋 Direct dictionary key iteration (should use DictUtils):"
    find project -name "*.gd" -exec grep -Hn "for .* in .*\.keys()" {} \; | grep -v "DictUtils" || echo "  ✅ No problematic patterns found"
    echo ""
    
    # Find direct dictionary iteration
    echo "📋 Direct dictionary iteration (may need deterministic ordering):"
    grep -rn "for .* in [a-zA-Z_][a-zA-Z0-9_]*:" project/**/*.gd | head -10 || echo "  ✅ No patterns found"
    echo ""
    
    # Find Array.map() usage that might have typing issues
    echo "📋 Array.map() usage (check for type safety):"
    grep -rn "\.map(" project/**/*.gd || echo "  ✅ No .map() usage found"
    echo ""
    
    # Check current DictUtils usage
    echo "📋 Current DictUtils usage:"
    grep -rn "DictUtils\." project/**/*.gd | wc -l | awk '{print "  Found " $1 " usages"}'
    echo ""
    
    echo "💡 Run 'just validate-dict-patterns' to check compliance"

# Validate dictionary patterns comply with DictUtils standards
validate-dict-patterns:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔍 Validating dictionary pattern compliance..."
    
    VIOLATIONS=0
    
    # Check for direct dictionary key iteration
    if find project -name "*.gd" -exec grep -l "for .* in .*\.keys()" {} \; | grep -v "DictUtils" >/dev/null 2>&1; then
        echo "❌ Found direct dictionary key iteration patterns:"
        find project -name "*.gd" -exec grep -Hn "for .* in .*\.keys()" {} \; | grep -v "DictUtils" || true
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
    
    # Check for direct dictionary iteration (excluding Array iterations)
    # Look for dictionary-specific patterns that might be problematic
    DICT_ITERATION_PATTERNS=$(find project -name "*.gd" -exec grep -l "for .* in .*\.values()\|for .* in .*:" {} \; 2>/dev/null | wc -l || echo "0")
    if [ "$DICT_ITERATION_PATTERNS" -gt 0 ]; then
        echo "ℹ️  Found $DICT_ITERATION_PATTERNS files with dictionary-like iteration patterns"
        echo "   (This is informational - manual review recommended for battle-critical code)"
        # Don't count this as a violation for now
    fi
    
    if [ $VIOLATIONS -eq 0 ]; then
        echo "✅ All dictionary patterns comply with DictUtils standards"
        exit 0
    else
        echo "❌ Found $VIOLATIONS categories of dictionary pattern violations"
        echo "💡 Run 'just analyze-dict-patterns' for detailed analysis"
        exit 1
    fi

# Combined validation for iOS development workflow  
_validate-ios-workflow DEVICE_TYPE:
    @just _validate-ios-tools
    @just _validate-ios-device {{DEVICE_TYPE}}
    @echo "✅ iOS {{DEVICE_TYPE}} validated"

# Combined validation for config workflow (config validation only)
_validate-config-workflow CONFIG:
    @just _validate-config-exists "{{CONFIG}}"
    @echo "✅ Config validated"

# Combined validation for Android config workflow (config + device validation)
_validate-android-config-workflow CONFIG:
    @just _validate-config-exists "{{CONFIG}}"
    @just _require-android-device
    @echo "✅ Android config workflow validated"

# Main help command - comprehensive help system imported from justfile-help.justfile
# All detailed help commands (help-timing, help-build, help-android, etc.) are available there

# Gruvbox Material colors
_gruvbox-colors:
    # Base colors
    @export BG_H="#1d2021"
    @export BG="#282828"
    @export BG_S="#32302f"
    @export FG="#d4be98"
    
    # Regular colors
    @export RED="#ea6962"
    @export GREEN="#a9b665"
    @export YELLOW="#d8a657"
    @export BLUE="#7daea3"
    @export PURPLE="#d3869b"
    @export AQUA="#89b482"
    @export ORANGE="#e78a4e"
    @export GRAY="#928374"

# Build custom Godot editor from source
build-editor: validate-env
    @echo "Building Godot editor..."
    cd {{GODOT_SUBMODULE_PATH}} && scons platform=macos target=editor use_lto=yes --jobs={{jobs}} # vulkan_sdk_path=
    mv {{GODOT_SUBMODULE_PATH}}/bin/godot.macos.editor.* editor/

# Build iOS export templates (complete chain)
templates-ios:
    just build-and-package-ios-templates

# Build Android export templates (complete chain)  
templates-android minimal="no":
    just build-android-templates minimal={{minimal}}
    just setup-android

# Build all export templates (iOS + Android)
templates-all:
    just templates-ios
    just templates-android

# build macos
build-macos-templates: validate-env
    @echo "Building export templates..."
    cd {{GODOT_SUBMODULE_PATH}} && scons platform=macos target=template_debug --jobs={{jobs}}
    cd {{GODOT_SUBMODULE_PATH}} && scons platform=macos target=template_release --jobs={{jobs}}
    mkdir -p templates
    cp {{GODOT_SUBMODULE_PATH}}/bin/godot.macos.template_debug.* templates/
    cp {{GODOT_SUBMODULE_PATH}}/bin/godot.macos.template_release.* templates/

# Open Godot editor for development
edit:
    @echo "Running Godot editor..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --editor # --verbose --debug

# Show the implementation of a specific command
show COMMAND:
    @just --show {{COMMAND}}

# Run Godot in headless mode without GUI
headless:
    @echo "Running Godot in headless mode..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --headless
    
# Run Godot in headless mode with additional arguments
headless-run *ARGS:
    @echo "Running Godot in headless mode with args: {{ARGS}}"
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --headless {{ARGS}}

# Validate GDScript code by checking for errors
check OUTPUT="console":
    #!/usr/bin/env bash
    set -euo pipefail
    
    if [[ "{{OUTPUT}}" == "log" ]]; then
        echo "Validating GDScript code and saving errors to log file..."
        rm -f validation_errors.log
    else
        echo "Validating GDScript code..."
    fi
    
    cd {{PROJECT_PATH}}
    
    # Find all .gd files excluding addons
    gdscript_files=$(find . -name "*.gd" -type f -not -path "./addons/*")
    total_files=$(echo "$gdscript_files" | wc -l)
    
    echo "Checking $total_files GDScript files..."
    
    error_count=0
    current_file=0
    
    for file in $gdscript_files; do
        current_file=$((current_file + 1))
        
        if [[ "{{OUTPUT}}" == "log" ]]; then
            if ! gdparse "$file" >> validation_errors.log 2>&1; then
                echo "ERROR in $file" >> validation_errors.log
                error_count=$((error_count + 1))
            fi
        else
            if ! gdparse "$file" 2>/dev/null; then
                echo "❌ $file"
                error_count=$((error_count + 1))
            fi
        fi
        
        # Show progress every 25 files
        if [[ "{{OUTPUT}}" != "log" && $((current_file % 25)) -eq 0 ]]; then
            echo "Progress: $current_file/$total_files files checked..."
        fi
    done
    
    if [[ $error_count -eq 0 ]]; then
        echo "✅ All $total_files GDScript files passed validation"
        if [[ "{{OUTPUT}}" == "log" ]]; then
            echo "No errors found" > validation_errors.log
        fi
        exit 0
    else
        echo "❌ Found $error_count files with syntax errors"
        if [[ "{{OUTPUT}}" == "log" ]]; then
            echo "Validation complete. Errors saved to validation_errors.log"
        fi
        exit 1
    fi

# Alias for check command (mentioned in project docs)
validate OUTPUT="console": (check OUTPUT)

# Comprehensive validation including dictionary patterns
validate-all:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔍 Running comprehensive codebase validation..."
    echo ""
    
    # Run syntax validation
    echo "1️⃣ Syntax validation..."
    just validate
    echo ""
    
    # Run dictionary pattern validation (non-blocking)
    echo "2️⃣ Dictionary pattern validation..."
    if just validate-dict-patterns; then
        echo "✅ Dictionary patterns validated"
    else
        echo "⚠️  Dictionary pattern warnings (non-blocking)"
    fi
    echo ""
    
    echo "✅ Comprehensive validation complete"

# Runtime validation using Godot headless with quit action
validate-godot FILTER="ERROR:":
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🚀 Running Godot headless runtime validation..."
    
    # Set the embedded config to use the quit action
    echo "📋 Setting embedded config to system-quit-only..."
    just config-set system-quit-only
    
    # Create temporary file for capturing output
    TEMP_OUTPUT=$(mktemp)
    trap "rm -f $TEMP_OUTPUT" EXIT
    
    # Determine filter settings and run validation
    if [[ "{{FILTER}}" == "all" ]]; then
        echo "🎮 Starting Godot headless with debug system (showing all output)..."
        # Run and capture all output
        timeout 30s ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --headless --debug --verbose > "$TEMP_OUTPUT" 2>&1
        exit_code=$?
        cat "$TEMP_OUTPUT"
    else
        echo "🎮 Starting Godot headless with debug system (filtering for '{{FILTER}}' with file context)..."
        # Run and capture output, then filter
        timeout 30s ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --headless --debug --verbose > "$TEMP_OUTPUT" 2>&1
        exit_code=$?
        
        # Enhanced filter to show file context with ERROR messages
        awk '/Loading resource:.*\.gd$/ {file=$0} /{{FILTER}}/ {if(file) {print file; file=""} print}' "$TEMP_OUTPUT"
    fi
    
    # Check exit codes and error presence
    if [ $exit_code -eq 124 ]; then
        echo "❌ Godot headless validation timed out after 30 seconds"
        exit 1
    elif [ $exit_code -ne 0 ]; then
        echo "❌ Godot headless validation failed with exit code $exit_code"
        exit $exit_code
    fi
    
    # Check for errors in output (fail if any errors found)
    if grep -q "{{FILTER}}" "$TEMP_OUTPUT"; then
        echo "❌ Godot validation failed: errors detected in output"
        exit 1
    fi
    
    echo "✅ Runtime validation completed successfully"

# Detailed Godot validation with line numbers and full error context
validate-godot-detailed:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🔍 Running detailed Godot validation with full error context..."
    
    # Set the embedded config to use the quit action
    echo "📋 Setting embedded config to system-quit-only..."
    just config-set system-quit-only
    
    echo "🎮 Starting Godot headless with detailed error reporting..."
    
    # Create temporary file for full output
    TEMP_LOG=$(mktemp)
    
    # Run Godot and capture all output
    timeout 30s ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --headless --check-only --quit 2>&1 | tee "$TEMP_LOG" || {
        exit_code=$?
        if [ $exit_code -eq 124 ]; then
            echo "❌ Godot validation timed out after 30 seconds"
            rm -f "$TEMP_LOG"
            exit 1
        fi
    }
    
    # Parse and display detailed error information
    echo ""
    echo "📊 Detailed Error Analysis:"
    echo "=========================="
    
    # Count different types of issues (strip ANSI color codes first)
    error_count=$(sed 's/\x1b\[[0-9;]*m//g' "$TEMP_LOG" | grep "ERROR:" | wc -l | tr -d ' \n')
    warning_count=$(sed 's/\x1b\[[0-9;]*m//g' "$TEMP_LOG" | grep "WARNING:" | wc -l | tr -d ' \n')
    
    echo "🔴 Errors found: $error_count"
    echo "🟡 Warnings found: $warning_count"
    
    if [ "$error_count" -gt 0 ]; then
        echo ""
        echo "🔴 ERROR DETAILS:"
        echo "=================="
        # Show errors with file context and line numbers
        grep -n -A 2 -B 2 "ERROR:" "$TEMP_LOG" || true
    fi
    
    if [ "$warning_count" -gt 0 ]; then
        echo ""
        echo "🟡 WARNING DETAILS:"
        echo "==================="
        # Show warnings with context
        grep -n -A 1 -B 1 "WARNING:" "$TEMP_LOG" || true
    fi
    
    # Cleanup
    rm -f "$TEMP_LOG"
    
    echo ""
    if [ "$error_count" -eq 0 ]; then
        echo "✅ No errors found - validation passed"
        exit 0
    else
        echo "❌ Found $error_count errors - validation failed"
        exit 1
    fi

# Pre-build hook
pre-build:
    @echo "Running pre-build tasks..."
    just update-export-presets
    just update-project-settings

# Build and package iOS templates
build-and-package-ios-templates: validate-env
    just ios-build-template
    just package-ios-template

# build ios template
ios-build-template:
    @echo "============================="
    @echo "BUILDING IOS EXECUTABLES"
    @echo "============================="
    cd {{GODOT_SUBMODULE_PATH}} && scons platform=ios target=template_debug arch=arm64 --jobs={{jobs}}
    cd {{GODOT_SUBMODULE_PATH}} && scons platform=ios target=template_release arch=arm64 --jobs={{jobs}}

    @echo "=========================="
    @echo "PREPARING IOS TEMPLATES"
    @echo "=========================="
    chmod +x {{GODOT_SUBMODULE_PATH}}/bin/libgodot*.a
    mkdir -p {{GODOT_SUBMODULE_PATH}}/misc/dist/ios_xcode/libgodot.ios.template_release.xcframework/ios-arm64
    mkdir -p {{GODOT_SUBMODULE_PATH}}/misc/dist/ios_xcode/libgodot.ios.template_debug.xcframework/ios-arm64
    cp {{GODOT_SUBMODULE_PATH}}/bin/libgodot.ios.template_release.arm64.a {{GODOT_SUBMODULE_PATH}}/misc/dist/ios_xcode/libgodot.ios.template_release.xcframework/ios-arm64/libgodot.a
    cp {{GODOT_SUBMODULE_PATH}}/bin/libgodot.ios.template_debug.arm64.a {{GODOT_SUBMODULE_PATH}}/misc/dist/ios_xcode/libgodot.ios.template_debug.xcframework/ios-arm64/libgodot.a

    # Copying to current xcode framework
    chmod +x {{GODOT_SUBMODULE_PATH}}/bin/libgodot*
    cp {{GODOT_SUBMODULE_PATH}}/bin/libgodot.ios.template_release.arm64.a export/ios/{{GAME_NAME}}.xcframework/ios-arm64/libgodot.a

# Package ios template
package-ios-template:
    @echo "=========================="
    @echo "PACKAGING IOS TEMPLATES"
    @echo "=========================="
    rm -f templates/ios.zip
    mkdir -p templates
    cd {{GODOT_SUBMODULE_PATH}}/misc/dist/ios_xcode && zip -9 -r ../../../../templates/ios.zip *

    @echo "iOS templates built and packaged successfully."

# Build Android templates
build-android-templates minimal="no":
    #!/usr/bin/env bash
    set -e
    
    # Define the module flags based on the minimal argument
    MODULE_FLAGS=""
    if [ "{{minimal}}" = "yes" ]; then
        MODULE_FLAGS="module_bmp_enabled=no module_bullet_enabled=no module_csg_enabled=no module_dds_enabled=no module_enet_enabled=no module_etc_enabled=no module_gdnative_enabled=no module_gridmap_enabled=no module_hdr_enabled=no module_mbedtls_enabled=yes module_mobile_vr_enabled=no module_opus_enabled=no module_pvr_enabled=no module_recast_enabled=no module_squish_enabled=no module_tga_enabled=no module_thekla_unwrap_enabled=no module_theora_enabled=no module_tinyexr_enabled=no module_vorbis_enabled=no module_webm_enabled=no module_websocket_enabled=no disable_advanced_gui=no disable_3d=yes"
    fi
    
    # Build for all targets and architectures in a single working directory context
    GODOT_PATH="{{GODOT_SUBMODULE_PATH}}"
    
    # Debug arm32
    (cd "$GODOT_PATH" && scons platform=android target=template_debug arch=arm32 --jobs={{jobs}} $MODULE_FLAGS optimize=size use_lto=yes)
    
    # Debug arm64
    (cd "$GODOT_PATH" && scons platform=android target=template_debug arch=arm64 --jobs={{jobs}} $MODULE_FLAGS optimize=size use_lto=yes)
    
    # Release arm32
    (cd "$GODOT_PATH" && scons platform=android target=template_release arch=arm32 --jobs={{jobs}} $MODULE_FLAGS optimize=size use_lto=yes)
    
    # Release arm64
    (cd "$GODOT_PATH" && scons platform=android target=template_release arch=arm64 --jobs={{jobs}} $MODULE_FLAGS optimize=size use_lto=yes)
    
    # Generate templates
    (cd "$GODOT_PATH/platform/android/java" && ./gradlew generateGodotTemplates)
    
    # Make sure the templates directory exists
    mkdir -p templates
    
    # Move templates
    echo "Moving templates...."
    mv "$GODOT_PATH/bin/android_debug.apk" templates/android_debug.apk
    mv "$GODOT_PATH/bin/android_release.apk" templates/android_release.apk
    mv "$GODOT_PATH/bin/android_source.zip" templates/android_source.zip


clean-android-templates:
    #!/usr/bin/env bash
    set -e
    # Build for all targets and architectures in a single working directory context
    GODOT_PATH="{{GODOT_SUBMODULE_PATH}}"
    # clean templates
    (cd "$GODOT_PATH/platform/android/java" && ./gradlew clean)

# Install Android template
setup-android:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Installing Android gradle for custom builds"
    rm -rf project/android
    mkdir project/android
    unzip -o templates/android_source.zip -d project/android/build
    chmod +x project/android
    md5=$(md5sum templates/android_source.zip | awk NF=1)
    rp=$(realpath templates/android_source.zip)
    echo "$rp [$md5]"  >> project/android/.build_version
    touch project/android/.gdignore
    echo "Done installing Android template"

# LEVEL 3: Export AAB files via Godot (2-3 min, debug + release)
export-aab-android: pre-build
    @echo "📦 Exporting Android AAB files (debug + release)..."
    echo $ANDROID_KEYSTORE | base64 -d > android.keystore
    
    # Debug build
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} \
        --export-debug "Android aab" \
        ../export/android/{{GAME_NAME}}_debug.aab --headless
    
    # Release build
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} \
        --export-release "Android aab" \
        ../export/android/{{GAME_NAME}}.aab --headless
    
    @echo "✅ Android AAB files exported successfully"
    @echo "📁 Debug: export/android/{{GAME_NAME}}_debug.aab"
    @echo "📁 Release: export/android/{{GAME_NAME}}.aab"

# LEVEL 3: Export both APK and AAB files (2-3 min, all formats)
export-all-android:
    @echo "📦 Exporting all Android formats (APK + AAB)..."
    just export-apk-android
    just export-aab-android
    @echo "✅ All Android formats exported!"

# ================================
# ANDROID DEVELOPMENT WORKFLOW
# ================================

# LEVEL 3: Export APK files via Godot (2-3 min, debug + release)
export-apk-android: _validate-godot-editor (_ensure-directory-exists "export/android")
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📦 Exporting Android APK files (debug + release)..."
    
    # Export debug APK
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --headless --export-debug "Android apk" \
        ../export/android/{{GAME_NAME}}_debug.apk
    
    # Export release APK  
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --headless --export-release "Android apk" \
        ../export/android/{{GAME_NAME}}.apk
    
    echo "✅ Android APK files exported successfully"
    echo "📁 Debug: export/android/{{GAME_NAME}}_debug.apk"
    echo "📁 Release: export/android/{{GAME_NAME}}.apk"

# ================================
# ANDROID COMMANDS - FAST BUILD (NO HOT RELOAD)
# ================================

# Fast Android rebuild and install - Hybrid approach (30-60 sec, no templates)
fastbuild-android: _validate-android-workflow _validate-godot-editor
    @echo "⚡ Fast Android rebuild with hybrid approach (30-60 sec)..."
    @echo "   🔄 Step 1: Processing GDScript changes with Godot export..."
    @echo "   🔨 Step 2: Fast gradle build with custom parameters..."
    @echo "   ⚠️  Android limitation: Full reinstall required (no hot reload like iOS)"
    # First: Process GDScript changes via Godot export (creates/updates android build files)
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --headless --export-debug "Android apk" /tmp/temp_android_export.apk
    # Second: Use direct gradle for fast, customized build and install
    just _gradle-build-install-android
    just launch-android

# Internal helper: Gradle build + install (no launch)
_gradle-build-install-android:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # First insert Firebase dependencies
    just insert-firebase-dependencies
    
    echo "🔨 Building Android APK with Gradle..."
    
    # Create timestamp for unique filename
    TIMESTAMP=$(date +%s)
    TEMP_DIR="/tmp/android_deploy"
    mkdir -p "$TEMP_DIR"
    
    # Run Gradle build
    cd {{PROJECT_PATH}}/android/build && \
    ./gradlew validateJavaVersion clean assembleStandardDebug \
      -Paddons_directory={{PROJECT_PATH}}/addons \
      -Pexport_package_name={{ANDROID_PACKAGE_NAME}} \
      -Pexport_version_code=$(date +%Y%m%d%H%M%S) \
      -Pexport_version_name=1.0.$(date +%Y%m%d%H%M%S) \
      -Pexport_version_min_sdk=24 \
      -Pexport_version_target_sdk=34 \
      -Pexport_enabled_abis=arm64-v8a \
      -Pplugins_local_binaries= \
      -Pplugins_remote_binaries= \
      -Pplugins_maven_repos= \
      -Pperform_zipalign=true \
      -Pperform_signing=true \
      -Pcompress_native_libraries=false
    
    # Copy and rename binary
    echo "📱 Building APK..."
    EXPORT_FILENAME="gametwo_debug_$TIMESTAMP.apk"
    cd {{PROJECT_PATH}}/android/build && \
    ./gradlew copyAndRenameBinary \
      -Pexport_edition=standard \
      -Pexport_build_type=debug \
      -Pexport_format=apk \
      -Pexport_path=file:$TEMP_DIR \
      -Pexport_filename=$EXPORT_FILENAME
    
    # Uninstall existing package
    echo "🗑️  Uninstalling existing package..."
    adb -s {{ANDROID_DEVICE_ID}} uninstall {{ANDROID_PACKAGE_NAME}} 2>/dev/null || echo "Package not installed"
    
    # Install new APK
    echo "📲 Installing APK to device..."
    adb -s {{ANDROID_DEVICE_ID}} install "$TEMP_DIR/$EXPORT_FILENAME"
    
    echo "✅ APK installed successfully!"
    echo "💾 APK saved at: $TEMP_DIR/$EXPORT_FILENAME"

# Launch Android app on device
launch-android: _validate-android-workflow
    @echo "🚀 Launching Android app..."
    @adb -s {{ANDROID_DEVICE_ID}} shell am start -a android.intent.action.MAIN -n {{ANDROID_PACKAGE_NAME}}/com.godot.game.GodotApp
    @echo "✅ App launched!"

# Force stop and restart the Android app
restart-android-app: _validate-android-workflow
    @echo "🔄 Restarting Android app..."
    @adb -s {{ANDROID_DEVICE_ID}} shell am force-stop {{ANDROID_PACKAGE_NAME}}
    @sleep 1
    @adb -s {{ANDROID_DEVICE_ID}} shell am start -a android.intent.action.MAIN -n {{ANDROID_PACKAGE_NAME}}/com.godot.game.GodotApp
    @echo "✅ App restarted!"

# Complete Android development workflow with optional debug config
iterate-android CONFIG="current":
    @echo "🔄 Android development iteration..."
    just fastbuild-android
    @if [ "{{CONFIG}}" != "current" ]; then just config-restart-android {{CONFIG}}; fi


# ================================ 
# CONFIG MANAGEMENT COMMANDS
# ================================

# Push config to Android device user:// directory (no restart) - FAST: 2 seconds
config-push-android CONFIG_NAME: (_validate-android-config-workflow CONFIG_NAME)
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "📱 Pushing config to Android device..."
    
    CONFIG_FILE=$(just _get-safe-config-file "{{CONFIG_NAME}}")
    
    echo "📄 Config content to push:"
    cat "$CONFIG_FILE" | jq . || cat "$CONFIG_FILE"
    echo ""
    
    # Android user:// directory maps to app's private files directory: /data/data/{package}/files/
    USER_DIR="/data/data/{{ANDROID_PACKAGE_NAME}}/files"
    REMOTE_CONFIG="$USER_DIR/debug_startup_actions.json"
    
    echo "🔧 Pushing to user:// directory (app private storage)..."
    echo "📁 Target: $REMOTE_CONFIG"
    
    # Check if app is debuggable and run-as works
    echo "🔍 Testing run-as access to app private directory..."
    if adb -s {{ANDROID_DEVICE_ID}} shell "run-as {{ANDROID_PACKAGE_NAME}} echo 'Access OK'" 2>/dev/null | grep -q "Access OK"; then
        echo "✅ run-as access confirmed"
        
        # Use temporary location on external storage first
        TEMP_CONFIG="/sdcard/temp_debug_config.json"
        
        echo "📱 Uploading config to temporary location..."
        if adb -s {{ANDROID_DEVICE_ID}} push "$CONFIG_FILE" "$TEMP_CONFIG"; then
            echo "✅ Config uploaded to temp location"
            
            # Copy from temp to app private directory using run-as
            echo "📁 Copying to app private directory (user://)..."
            if adb -s {{ANDROID_DEVICE_ID}} shell "run-as {{ANDROID_PACKAGE_NAME}} cp $TEMP_CONFIG files/debug_startup_actions.json" 2>/dev/null; then
                echo "✅ Config copied to user:// directory"
                
                # Cleanup temp file
                adb -s {{ANDROID_DEVICE_ID}} shell "rm $TEMP_CONFIG" 2>/dev/null || true
                
                # Verify file exists in user:// directory
                echo "🔍 Verifying config in user:// directory..."
                if adb -s {{ANDROID_DEVICE_ID}} shell "run-as {{ANDROID_PACKAGE_NAME}} ls files/debug_startup_actions.json" >/dev/null 2>&1; then
                    echo "✅ Config file verified in user:// directory!"
                    
                    # Show content to verify
                    echo "📄 Config content from user:// directory:"
                    adb -s {{ANDROID_DEVICE_ID}} shell "run-as {{ANDROID_PACKAGE_NAME}} cat files/debug_startup_actions.json" 2>/dev/null || echo "  (could not read content)"
                else
                    echo "❌ Config file not found in user:// directory after copy"
                    
                    # Debug: List files in user:// directory:"
                    echo "📋 Files in user:// directory:"
                    adb -s {{ANDROID_DEVICE_ID}} shell "run-as {{ANDROID_PACKAGE_NAME}} ls -la files/" 2>/dev/null || echo "  (could not list files)"
                    exit 1
                fi
            else
                echo "❌ Failed to copy config to user:// directory"
                echo "💡 This might be a permissions issue or the app is not debuggable"
                exit 1
            fi
        else
            echo "❌ Failed to upload config to temp location"
            exit 1
        fi
    else
        echo "❌ Cannot access app private directory with run-as"
        echo "💡 This usually means:"
        echo "   - App is not debuggable (release build)"
        echo "   - App is not installed"  
        echo "   - Device doesn't support run-as"
        exit 1
    fi
    
    echo "✅ Config pushed to user:// directory!"
    echo "💡 App will use this config on next start/restart"
    echo "💡 Use 'just config-restart-android {{CONFIG_NAME}}' to push + restart immediately"
    
    # Clean up temporary config if it was auto-generated
    just _cleanup-temp-config "{{CONFIG_NAME}}"

# Push config to Android device AND restart app - FAST: 5 seconds 
config-restart-android CONFIG_NAME: (_validate-android-config-workflow CONFIG_NAME)
    @echo "🚀 Pushing config and restarting Android app..."
    @just config-push-android "{{CONFIG_NAME}}"
    @echo ""
    @echo "🔄 Restarting app to apply new config..."
    @just restart-android-app
    @echo "✅ Config pushed and app restarted!"
    @echo "💡 Monitor with: just test-monitor-android \"{{CONFIG_NAME}}\""

# Check current Android config status
config-status-android:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "📱 Android Debug Config Status"
    echo "============================="
    echo "Device: {{ANDROID_DEVICE_ID}}"
    echo "Package: {{ANDROID_PACKAGE_NAME}}"
    echo ""
    
    # Check external config in user:// directory on device
    echo "📱 External config status in user:// directory:"
    if adb -s {{ANDROID_DEVICE_ID}} shell "run-as {{ANDROID_PACKAGE_NAME}} ls files/debug_startup_actions.json" >/dev/null 2>&1; then
        echo "✅ External config exists in user:// (ACTIVE - highest priority)"
        echo "📄 Content:"
        adb -s {{ANDROID_DEVICE_ID}} shell "run-as {{ANDROID_PACKAGE_NAME}} cat files/debug_startup_actions.json" 2>/dev/null | jq . 2>/dev/null || \
        adb -s {{ANDROID_DEVICE_ID}} shell "run-as {{ANDROID_PACKAGE_NAME}} cat files/debug_startup_actions.json" 2>/dev/null || echo "  (could not read content)"
    else
        echo "❌ No external config in user:// directory"
    fi
    echo ""
    
    echo "💡 Available commands:"
    echo "  just config-push-android <config>    # Push config (no restart)"
    echo "  just config-restart-android <config> # Push config + restart app"
    echo "  just restart-android-app             # Just restart app"

# ================================
# DEBUG CONFIG MANAGEMENT
# ================================

# Create debug config directory and sample configs
config-setup:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📋 Setting up debug configuration files..."
    
    # Create debug configs directory
    mkdir -p project/debug_configs
    
    # Create sample configuration files
    
    # 1. System testing config
    echo '{"actions": ["Show Registry Stats", "Print Debug Info", "Log System Info"]}' > project/debug_configs/system-testing.json
    
    # 2. Database testing config  
    echo '{"actions": ["RTDB Status", "RTDB Get Simple Value", "RTDB List Children"]}' > project/debug_configs/database-testing.json
    
    # 3. Gameplay testing config
    echo '{"actions": ["Reset Match Level", "Load Match Level 1", "Draw Hand"]}' > project/debug_configs/gameplay-testing.json
    
    # 4. Performance testing config
    echo '{"actions": ["Show Registry Stats", "RTDB Concurrent Operations", "RTDB Large Data Test"]}' > project/debug_configs/performance-testing.json
    
    # 5. Minimal testing config
    echo '{"actions": ["Print Debug Info"]}' > project/debug_configs/minimal-testing.json
    
    # 6. Empty config (no actions)
    echo '{"actions": []}' > project/debug_configs/no-actions.json
    
    echo "✅ Debug configs created:"
    echo "  📁 project/debug_configs/"
    ls -la project/debug_configs/
    echo ""
    echo "💡 Use 'just config-set <name>' to switch configs"
    echo "   Example: just config-set system-testing"


# Set a specific debug configuration (updates embedded config)
config-set CONFIG_NAME: (_validate-config-exists CONFIG_NAME)
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_FILE=$(just _get-safe-config-file "{{CONFIG_NAME}}")
    TARGET_FILE="project/debug_startup_actions.json"
    
    echo "📝 Setting debug config to: {{CONFIG_NAME}}"
    echo "📄 Config content:"
    cat "$CONFIG_FILE" | jq .
    
    # Copy config to main debug startup file
    cp "$CONFIG_FILE" "$TARGET_FILE"
    
    echo "✅ Debug config updated!"
    echo "💡 Next steps:"
    echo "   1. For development: just config-restart-android {{CONFIG_NAME}}"
    echo "   2. For full rebuild: just save-android-project && just install-android-app"
    
    # Clean up temporary config if it was auto-generated
    just _cleanup-temp-config "{{CONFIG_NAME}}"


# Remove external debug config from Android device (fall back to embedded config)
config-clear-android:
    #!/usr/bin/env bash
    set -euo pipefail
    
    ANDROID_PATH="/sdcard/Android/data/{{ANDROID_PACKAGE_NAME}}/files"
    REMOTE_CONFIG="$ANDROID_PATH/debug_startup_actions.json"
    
    echo "🗑️  Removing external debug config..."
    adb -s {{ANDROID_DEVICE_ID}} shell "rm -f $REMOTE_CONFIG" 2>/dev/null || true
    echo "✅ External config removed - app will use embedded config"
    echo "💡 Run 'just restart-android-app' to apply changes"

# ================================
# LOGGER CONFIG MANAGEMENT
# ================================

# Quick tag filtering for focused debugging sessions
config-android-tags ACTIVE_TAGS IGNORED_TAGS:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🏷️  Updating Android logger tags..."
    echo "   Active tags: {{ACTIVE_TAGS}}"
    echo "   Ignored tags: {{IGNORED_TAGS}}"
    
    # Parse comma-separated tags
    IFS=',' read -ra ACTIVE_ARRAY <<< "{{ACTIVE_TAGS}}"
    IFS=',' read -ra IGNORED_ARRAY <<< "{{IGNORED_TAGS}}"
    
    # Create temporary config file
    TEMP_CONFIG=$(mktemp)
    
    # Create base config template
    cp "project/addons/advanced_logger/settings.cfg" "$TEMP_CONFIG"
    
    # Build active tags array string
    ACTIVE_FORMATTED=""
    for tag in "${ACTIVE_ARRAY[@]}"; do
        tag=$(echo "$tag" | xargs) # trim whitespace
        if [ -n "$tag" ]; then
            if [ -n "$ACTIVE_FORMATTED" ]; then
                ACTIVE_FORMATTED="$ACTIVE_FORMATTED, "
            fi
            ACTIVE_FORMATTED="$ACTIVE_FORMATTED\"$tag\""
        fi
    done
    
    # Build ignored tags array string
    IGNORED_FORMATTED=""
    for tag in "${IGNORED_ARRAY[@]}"; do
        tag=$(echo "$tag" | xargs) # trim whitespace
        if [ -n "$tag" ]; then
            if [ -n "$IGNORED_FORMATTED" ]; then
                IGNORED_FORMATTED="$IGNORED_FORMATTED, "
            fi
            IGNORED_FORMATTED="$IGNORED_FORMATTED\"$tag\""
        fi
    done
    
    # Update active tags in config
    sed -i '' "s/active_tags=Array\[String\](\[.*\])/active_tags=Array[String]([$ACTIVE_FORMATTED])/g" "$TEMP_CONFIG"
    
    # Update ignored tags in config
    sed -i '' "s/ignored_tags=Array\[String\](\[.*\])/ignored_tags=Array[String]([$IGNORED_FORMATTED])/g" "$TEMP_CONFIG"
    
    # Push to device
    echo "📱 Pushing logger config to Android device..."
    adb -s {{ANDROID_DEVICE_ID}} push "$TEMP_CONFIG" "/sdcard/Android/data/{{ANDROID_PACKAGE_NAME}}/files/advanced_logger_settings.cfg"
    
    # Clean up
    rm "$TEMP_CONFIG"
    
    echo "✅ Logger tags updated!"
    echo "💡 Restart app to apply: just restart-android-app"

# Set Android logger level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
config-android-level LEVEL:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Convert level name to number
    case "{{LEVEL}}" in
        DEBUG|debug)
            LEVEL_NUM=0
            LEVEL_NAME="DEBUG"
            ;;
        INFO|info)
            LEVEL_NUM=1
            LEVEL_NAME="INFO"
            ;;
        WARNING|warning|WARN|warn)
            LEVEL_NUM=2
            LEVEL_NAME="WARNING"
            ;;
        ERROR|error)
            LEVEL_NUM=3
            LEVEL_NAME="ERROR"
            ;;
        CRITICAL|critical)
            LEVEL_NUM=4
            LEVEL_NAME="CRITICAL"
            ;;
        *)
            echo "❌ Invalid log level: {{LEVEL}}"
            echo "💡 Valid levels: DEBUG, INFO, WARNING, ERROR, CRITICAL"
            exit 1
            ;;
    esac
    
    echo "📊 Setting Android logger level to $LEVEL_NAME ($LEVEL_NUM)..."
    
    # Create temporary config file with current settings
    TEMP_CONFIG=$(mktemp)
    
    # Create base config template
    cp "project/addons/advanced_logger/settings.cfg" "$TEMP_CONFIG"
    
    # Update log level in config
    sed -i '' "s/log_level=[0-9]/log_level=$LEVEL_NUM/g" "$TEMP_CONFIG"
    
    # Push to device
    echo "📱 Pushing logger config to Android device..."
    adb -s {{ANDROID_DEVICE_ID}} push "$TEMP_CONFIG" "/sdcard/Android/data/{{ANDROID_PACKAGE_NAME}}/files/advanced_logger_settings.cfg"
    
    # Clean up
    rm "$TEMP_CONFIG"
    
    echo "✅ Logger level set to $LEVEL_NAME!"
    echo "💡 Restart app to apply: just restart-android-app"

# Reset Android logger config to project defaults
config-android-reset:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🔄 Resetting Android logger config to project defaults..."
    
    # Remove custom logger config from device
    adb -s {{ANDROID_DEVICE_ID}} shell "rm -f /sdcard/Android/data/{{ANDROID_PACKAGE_NAME}}/files/advanced_logger_settings.cfg" 2>/dev/null || true
    
    echo "✅ Logger config reset!"
    echo "💡 App will use project defaults (DEBUG level) on next start"
    echo "💡 Restart app to apply: just restart-android-app"

# Runtime app log control (advanced_logger) - Filter what gets written during app execution
runtime-filter-tags ACTIVE_TAGS IGNORED_TAGS:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🏷️  Updating advanced_logger runtime tag filtering..."
    echo "   Active tags: {{ACTIVE_TAGS}}"
    echo "   Ignored tags: {{IGNORED_TAGS}}"
    
    # Parse comma-separated tags
    IFS=',' read -ra ACTIVE_ARRAY <<< "{{ACTIVE_TAGS}}"
    IFS=',' read -ra IGNORED_ARRAY <<< "{{IGNORED_TAGS}}"
    
    # Create temporary config file
    TEMP_CONFIG=$(mktemp)
    
    # Create base config template
    cp "project/addons/advanced_logger/settings.cfg" "$TEMP_CONFIG"
    
    # Build active tags array string
    ACTIVE_FORMATTED=""
    for tag in "${ACTIVE_ARRAY[@]}"; do
        tag=$(echo "$tag" | xargs) # trim whitespace
        if [ -n "$tag" ]; then
            if [ -n "$ACTIVE_FORMATTED" ]; then
                ACTIVE_FORMATTED="$ACTIVE_FORMATTED, "
            fi
            ACTIVE_FORMATTED="$ACTIVE_FORMATTED\"$tag\""
        fi
    done
    
    # Build ignored tags array string
    IGNORED_FORMATTED=""
    for tag in "${IGNORED_ARRAY[@]}"; do
        tag=$(echo "$tag" | xargs) # trim whitespace
        if [ -n "$tag" ]; then
            if [ -n "$IGNORED_FORMATTED" ]; then
                IGNORED_FORMATTED="$IGNORED_FORMATTED, "
            fi
            IGNORED_FORMATTED="$IGNORED_FORMATTED\"$tag\""
        fi
    done
    
    # Update active tags in config
    sed -i '' "s/active_tags=Array\[String\](\[.*\])/active_tags=Array[String]([$ACTIVE_FORMATTED])/g" "$TEMP_CONFIG"
    
    # Update ignored tags in config
    sed -i '' "s/ignored_tags=Array\[String\](\[.*\])/ignored_tags=Array[String]([$IGNORED_FORMATTED])/g" "$TEMP_CONFIG"
    
    # Auto-detect platform and push to device
    if command -v adb >/dev/null 2>&1 && adb devices | grep -q device; then
        echo "📱 Pushing advanced_logger config to Android device..."
        adb -s {{ANDROID_DEVICE_ID}} push "$TEMP_CONFIG" "/sdcard/Android/data/{{ANDROID_PACKAGE_NAME}}/files/advanced_logger_settings.cfg"
    else
        echo "📱 Android device not found, config saved locally"
    fi
    
    # Clean up
    rm "$TEMP_CONFIG"
    
    echo "✅ Advanced_logger runtime tag filtering updated!"
    echo "💡 Restart app to apply: just restart-android-app"

# Runtime app log level control (advanced_logger) - Set log level during app execution
runtime-filter-level LEVEL:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Convert level name to number
    case "{{LEVEL}}" in
        DEBUG|debug)
            LEVEL_NUM=0
            LEVEL_NAME="DEBUG"
            ;;
        INFO|info)
            LEVEL_NUM=1
            LEVEL_NAME="INFO"
            ;;
        WARNING|warning|WARN|warn)
            LEVEL_NUM=2
            LEVEL_NAME="WARNING"
            ;;
        ERROR|error)
            LEVEL_NUM=3
            LEVEL_NAME="ERROR"
            ;;
        CRITICAL|critical)
            LEVEL_NUM=4
            LEVEL_NAME="CRITICAL"
            ;;
        *)
            echo "❌ Invalid log level: {{LEVEL}}"
            echo "💡 Valid levels: DEBUG, INFO, WARNING, ERROR, CRITICAL"
            exit 1
            ;;
    esac
    
    echo "📊 Setting advanced_logger runtime level to $LEVEL_NAME ($LEVEL_NUM)..."
    
    # Create temporary config file
    TEMP_CONFIG=$(mktemp)
    
    # Create base config template
    cp "project/addons/advanced_logger/settings.cfg" "$TEMP_CONFIG"
    
    # Update log level in config
    sed -i '' "s/log_level=[0-9]/log_level=$LEVEL_NUM/g" "$TEMP_CONFIG"
    
    # Auto-detect platform and push to device
    if command -v adb >/dev/null 2>&1 && adb devices | grep -q device; then
        echo "📱 Pushing advanced_logger config to Android device..."
        adb -s {{ANDROID_DEVICE_ID}} push "$TEMP_CONFIG" "/sdcard/Android/data/{{ANDROID_PACKAGE_NAME}}/files/advanced_logger_settings.cfg"
    else
        echo "📱 Android device not found, config saved locally"
    fi
    
    # Clean up
    rm "$TEMP_CONFIG"
    
    echo "✅ Advanced_logger runtime level set to $LEVEL_NAME!"
    echo "💡 Restart app to apply: just restart-android-app"

# Runtime app log reset (advanced_logger) - Reset to project defaults
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

# Monitor Android debug startup system with current configuration

_test-quick-android CONFIG_NAME:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🚀 Quick test with config: {{CONFIG_NAME}}"
    just config-restart-android "{{CONFIG_NAME}}"
    sleep 2
    just test-monitor-android "{{CONFIG_NAME}}"

# Pure monitoring without any app restarts or config changes
test-monitor-android DURATION="30":
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "👁️  Pure Log Monitoring (no app restarts or config changes)"
    echo "Device: {{ANDROID_DEVICE_ID}}"
    echo "Duration: {{DURATION}} seconds"
    echo "Package: {{ANDROID_PACKAGE_NAME}}"
    echo ""
    
    # Verify device connection
    if ! adb -s {{ANDROID_DEVICE_ID}} shell echo "Connected" >/dev/null 2>&1; then
        echo "❌ Device not connected"
        exit 1
    fi
    
    # Check if app is running
    if adb -s {{ANDROID_DEVICE_ID}} shell pidof "{{ANDROID_PACKAGE_NAME}}" >/dev/null 2>&1; then
        echo "✅ App is running"
    else
        echo "⚠️  App is not running - launch it manually if needed"
    fi
    echo ""
    
    echo "🔍 Filtering for debug actions, test events, and errors..."
    echo "⏹️  Press Ctrl+C to stop monitoring early"
    echo ""
    
    # Create timestamped log file
    LOG_FILE="monitor_logs_{{timestamp}}.log"
    
    # Clear old logs for fresh monitoring
    echo "🧹 Clearing old logs for fresh monitoring..."
    adb -s {{ANDROID_DEVICE_ID}} logcat -c
    
    # Use activity-based timeout monitoring
    completion_status=$(just _monitor-with-activity-timeout "" "$LOG_FILE" "{{DURATION}}")
    
    # Apply filtering and display results
    if [ -f "$LOG_FILE" ]; then
        echo ""
        echo "📊 Monitoring completed"
        echo "💾 Filtering and displaying results..."
        
        # Filter and display the log with the same pattern
        grep -E "(DEBUG_TEST_|debug.*action|Actions retrieved|Executing.*action|ERROR|FAIL|SUCCESS|\\[debug|\\[test)" "$LOG_FILE" || true
        
        echo ""
        echo "💾 Full filtered log saved: $LOG_FILE"
        
        # Show summary if any debug activity was captured
        if [ -s "$LOG_FILE" ]; then
            echo ""
            echo "📋 Recent debug activity summary:"
            tail -5 "$LOG_FILE" | sed 's/^/  /'
        else
            echo "ℹ️  No debug activity detected during monitoring period"
        fi
    else
        echo "❌ No log file generated"
    fi

# Reusable activity-based timeout monitoring function
_monitor-with-activity-timeout TEST_ID LOG_FILE DURATION GREP_PATTERN="DEBUG_TEST_|debug.*action|Actions retrieved|Executing.*action|ERROR|FAIL|SUCCESS|\\[debug|\\[test":
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Start log capture in background
    adb -s {{ANDROID_DEVICE_ID}} logcat -v time -s godot > "{{LOG_FILE}}" 2>/dev/null &
    LOGCAT_PID=$!
    
    # Activity-based timeout monitoring
    elapsed_time=0
    time_since_last_activity=0
    last_activity_count=0
    max_idle_time={{DURATION}}
    test_complete=false
    
    while [ $time_since_last_activity -lt $max_idle_time ] && [ "$test_complete" = false ]; do
        sleep 1
        elapsed_time=$((elapsed_time + 1))
        time_since_last_activity=$((time_since_last_activity + 1))
        
        if [ -f "{{LOG_FILE}}" ]; then
            # Check for test completion if TEST_ID provided
            if [ -n "{{TEST_ID}}" ] && grep -q "DEBUG_TEST_COMPLETE.*{{TEST_ID}}" "{{LOG_FILE}}" 2>/dev/null; then
                test_complete=true
                break
            fi
            
            # Check for any activity matching the pattern
            current_activity_count=$(grep -cE "{{GREP_PATTERN}}" "{{LOG_FILE}}" 2>/dev/null | head -1 | tr -d '\n\r' || echo "0")
            
            # Reset timeout if new activity detected
            if [ "$current_activity_count" -gt "$last_activity_count" ]; then
                time_since_last_activity=0
                last_activity_count=$current_activity_count
            fi
        fi
        
        # Progress indicator
        if [ $((elapsed_time % 5)) -eq 0 ]; then
            echo "   Progress: ${elapsed_time}s elapsed, ${time_since_last_activity}s idle (timeout: ${max_idle_time}s)"
        fi
    done
    
    # Stop log capture
    kill $LOGCAT_PID 2>/dev/null || true
    wait $LOGCAT_PID 2>/dev/null || true
    
    # Return completion status
    echo "$test_complete"

# Automated test with pass/fail determination and unique test IDs for Android
# Forces app restart by default to ensure config is loaded (use NO_RESTART="true" to skip)
_test-config-android CONFIG_NAME DURATION="30" NO_RESTART="false" TRACE="false": (_validate-config-exists CONFIG_NAME)
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Set up cleanup trap to ensure temp configs are cleaned up even if script is interrupted
    trap 'just cleanup-temp-configs >/dev/null 2>&1 || true' EXIT INT TERM
    
    # Configuration
    CONFIG_NAME="{{CONFIG_NAME}}"
    DURATION="{{DURATION}}"
    NO_RESTART="{{NO_RESTART}}"
    TRACE_MODE="{{TRACE}}"
    ANDROID_DEVICE_ID="${ANDROID_DEVICE_ID:-{{ANDROID_DEVICE_ID}}}"
    ANDROID_PACKAGE_NAME="${ANDROID_PACKAGE_NAME:-{{ANDROID_PACKAGE_NAME}}}"
    
    # Generate unique test ID
    TEST_ID="test_$(date +%Y%m%d_%H%M%S)_$(head -c 4 /dev/urandom | xxd -p)"
    
    if [ "$TRACE_MODE" = "true" ]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🔧 CONFIG EXECUTION TRACE"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi
    
    echo "🧪 Smart Test: $CONFIG_NAME"
    echo "🆔 Test ID: $TEST_ID"
    echo "⏱️  Duration: $DURATION seconds"
    echo ""
    
    # Check prerequisites
    if [ "$TRACE_MODE" = "true" ]; then
        echo "🔍 Step 1: Checking prerequisites..."
        echo "   Device ID: $ANDROID_DEVICE_ID"
        echo "   Package: $ANDROID_PACKAGE_NAME"
    fi
    
    if ! adb -s "$ANDROID_DEVICE_ID" shell echo "Connected" >/dev/null 2>&1; then
        if [ "$TRACE_MODE" = "true" ]; then
            echo "   ❌ Device connection failed"
        fi
        echo "❌ Device not connected"
        exit 1
    fi
    
    if [ "$TRACE_MODE" = "true" ]; then
        echo "   ✅ Device connected"
    fi
    
    if ! adb -s "$ANDROID_DEVICE_ID" shell pm list packages | grep -q "$ANDROID_PACKAGE_NAME"; then
        if [ "$TRACE_MODE" = "true" ]; then
            echo "   ❌ App package not found"
        fi
        echo "❌ App not installed"
        exit 1
    fi
    
    if [ "$TRACE_MODE" = "true" ]; then
        echo "   ✅ App package found"
        echo "🔍 Step 2: Resolving config file..."
        echo "   Input config: $CONFIG_NAME"
    fi
    
    # Get the safe config filename
    SAFE_CONFIG_FILE=$(just _get-safe-config-file "$CONFIG_NAME")
    
    if [ "$TRACE_MODE" = "true" ]; then
        echo "   Safe filename: $SAFE_CONFIG_FILE"
    fi
    
    if [ ! -f "$SAFE_CONFIG_FILE" ]; then
        if [ "$TRACE_MODE" = "true" ]; then
            echo "   ❌ Config file not found"
        fi
        echo "❌ Config file not found: $SAFE_CONFIG_FILE"
        exit 1
    fi
    
    if [ "$TRACE_MODE" = "true" ]; then
        echo "   ✅ Config file exists"
        echo "   Contents preview:"
        head -3 "$SAFE_CONFIG_FILE" | sed 's/^/     /'
    fi
    
    echo "✅ Prerequisites satisfied"
    echo ""
    
    # Create results directory
    timestamp=$(date +%Y%m%d_%H%M%S)
    test_dir="test_results/smart_${CONFIG_NAME}_$timestamp"
    mkdir -p "$test_dir"
    
    # Apply config with test ID
    echo "🔄 Applying config with test ID..."
    
    # Create enhanced config with test ID metadata
    enhanced_config=$(mktemp)
    jq --arg test_id "$TEST_ID" --arg config_name "$CONFIG_NAME" --arg timestamp "$timestamp" \
        '. + {"test_metadata": {"test_id": $test_id, "config": $config_name, "timestamp": $timestamp}}' \
        "$SAFE_CONFIG_FILE" > "$enhanced_config"
    
    # Push config to device using proper permissions approach
    TEMP_CONFIG="/sdcard/temp_debug_config_$TEST_ID.json"
    
    # Push to temporary location first
    adb -s "$ANDROID_DEVICE_ID" push "$enhanced_config" "$TEMP_CONFIG"
    
    # Copy to app private directory using run-as
    if adb -s "$ANDROID_DEVICE_ID" shell "run-as $ANDROID_PACKAGE_NAME cp $TEMP_CONFIG files/debug_startup_actions.json" 2>/dev/null; then
        echo "✅ Config applied successfully"
    else
        echo "❌ Failed to apply config to app directory"
        adb -s "$ANDROID_DEVICE_ID" shell "rm $TEMP_CONFIG" 2>/dev/null || true
        rm "$enhanced_config"
        exit 1
    fi
    
    # Cleanup temp files
    adb -s "$ANDROID_DEVICE_ID" shell "rm $TEMP_CONFIG" 2>/dev/null || true
    rm "$enhanced_config"

    # Force restart app to ensure config is loaded (unless explicitly disabled)
    if [ "$NO_RESTART" != "true" ]; then
        echo "🔄 Restarting app to ensure config is loaded..."
        adb -s "$ANDROID_DEVICE_ID" shell am force-stop "$ANDROID_PACKAGE_NAME" 2>/dev/null || true
        sleep 1
        echo "🚀 Starting test with fresh app instance..."
        adb -s "$ANDROID_DEVICE_ID" shell am start -a android.intent.action.MAIN -n "$ANDROID_PACKAGE_NAME"/com.godot.game.GodotApp
    else
        echo "⚡ Starting test without restart (using current app state)..."
        adb -s "$ANDROID_DEVICE_ID" shell am start -a android.intent.action.MAIN -n "$ANDROID_PACKAGE_NAME"/com.godot.game.GodotApp
    fi
    
    # Monitor test execution
    echo "📊 Monitoring test execution..."
    echo "   Looking for test ID: $TEST_ID"
    
    log_file="$test_dir/test_logs.log"
    test_result=1
    test_complete=false
    success_count=0
    failure_count=0
    startup_count=0
    
    # Enhanced single log capture with clear markers
    echo "🧹 Clearing old logs for fresh test monitoring..."
    adb -s "$ANDROID_DEVICE_ID" logcat -c
    
    # Start single log capture with enhanced formatting
    echo "📊 Starting enhanced log capture..."
    adb -s "$ANDROID_DEVICE_ID" logcat -v time -s godot > "$log_file" 2>/dev/null &
    LOGCAT_PID=$!
    
    # Monitor for completion with activity-based timeout
    elapsed_time=0
    time_since_last_activity=0
    last_activity_count=0
    max_idle_time=$DURATION  # Maximum time without activity before timeout
    restart_processed=false  # Track if restart signal has been processed
    
    while [ $time_since_last_activity -lt $max_idle_time ]; do
        sleep 1
        elapsed_time=$((elapsed_time + 1))
        time_since_last_activity=$((time_since_last_activity + 1))
        
        if [ -f "$log_file" ]; then
            # Check for restart signal and handle automatic restart (check BEFORE test completion)
            if [ "$restart_processed" = "false" ] && grep -q "DEBUG_TEST_RESTART_NEEDED.*$TEST_ID" "$log_file" 2>/dev/null; then
                restart_processed=true  # Mark as processed to prevent infinite loop
                echo ""
                echo "🔄 Auto-restart signal detected - triggering validation phase..."
                
                # Check if this is a determinism test that has saved a hash
                restart_line=$(grep "DEBUG_TEST_RESTART_NEEDED.*$TEST_ID" "$log_file" | tail -1)
                if echo "$restart_line" | grep -q '"reason": "config_updated"'; then
                    echo "🔐 Determinism test detected - preserving modified config with saved hash"
                    echo "⚠️  NOT pushing original config to avoid overwriting expectedHash"
                elif echo "$restart_line" | grep -q '"reason": "checksum_baseline_saved"'; then
                    echo "📸 Checksum test detected - updating baseline and validating..."
                    
                    # Extract checksum from restart signal
                    CHECKSUM=$(echo "$restart_line" | grep -o '"checksum": "[^"]*"' | cut -d'"' -f4)
                    if [ -n "$CHECKSUM" ] && [ -f "$SAFE_CONFIG_FILE" ]; then
                        echo "📝 Saving baseline checksum: $CHECKSUM"
                        jq --arg checksum "$CHECKSUM" '.checksum_config.expected_checksum = $checksum' "$SAFE_CONFIG_FILE" > "$SAFE_CONFIG_FILE.tmp" && mv "$SAFE_CONFIG_FILE.tmp" "$SAFE_CONFIG_FILE"
                        echo "✅ Baseline checksum saved to $SAFE_CONFIG_FILE"
                        
                        # Push updated config for validation
                        echo "🔄 Pushing updated config with baseline checksum..."
                        enhanced_config=$(mktemp)
                        jq --arg test_id "$TEST_ID" --arg config_name "$CONFIG_NAME" --arg timestamp "$timestamp" \
                            '. + {"test_metadata": {"test_id": $test_id, "config": $config_name, "timestamp": $timestamp}}' \
                            "$SAFE_CONFIG_FILE" > "$enhanced_config"
                        
                        TEMP_CONFIG="/sdcard/temp_debug_config_validation_$TEST_ID.json"
                        adb -s "$ANDROID_DEVICE_ID" push "$enhanced_config" "$TEMP_CONFIG"
                        adb -s "$ANDROID_DEVICE_ID" shell "run-as $ANDROID_PACKAGE_NAME cp $TEMP_CONFIG files/debug_startup_actions.json"
                        adb -s "$ANDROID_DEVICE_ID" shell "rm $TEMP_CONFIG" 2>/dev/null || true
                        rm "$enhanced_config"
                        echo "✅ Updated config pushed to device for validation"
                    else
                        echo "⚠️  Failed to extract checksum or config file not found"
                    fi
                else
                    echo "🔄 Standard restart - config will be preserved"
                fi
                
                # Stop current logcat temporarily for clean restart
                echo "📊 Stopping log capture for restart..."
                kill $LOGCAT_PID 2>/dev/null || true
                wait $LOGCAT_PID 2>/dev/null || true
                
                # Add clear restart boundary marker
                echo "$(date '+%m-%d %H:%M:%S.%3N') I/justfile (RESTART): ===== APP RESTART FOR VALIDATION PHASE =====" >> "$log_file"
                
                # Restart app (preserves config with expectedHash)
                echo "🚀 Force stopping app for clean restart..."
                adb -s "$ANDROID_DEVICE_ID" shell am force-stop "$ANDROID_PACKAGE_NAME"
                echo "⏱️  Waiting for app to fully terminate..."
                sleep 3
                
                echo "🚀 Starting fresh app instance for validation phase..."
                adb -s "$ANDROID_DEVICE_ID" shell am start -a android.intent.action.MAIN -n "$ANDROID_PACKAGE_NAME"/com.godot.game.GodotApp
                
                # Resume log capture with validation marker
                echo "📊 Resuming log capture for validation phase..."
                sleep 1  # Brief pause to ensure app starts
                echo "$(date '+%m-%d %H:%M:%S.%3N') I/justfile (VALIDATION): ===== VALIDATION PHASE STARTED =====" >> "$log_file"
                
                # Resume single log capture
                adb -s "$ANDROID_DEVICE_ID" logcat -v time -s godot >> "$log_file" 2>/dev/null &
                LOGCAT_PID=$!
                
                # Reset activity timer for validation phase
                time_since_last_activity=0
                continue
            fi
            
            # Count interim results and check for new activity
            # Primary method: Look for DEBUG_TEST_SUCCESS/FAILURE with test ID
            success_count=$(grep -c "DEBUG_TEST_SUCCESS.*$TEST_ID" "$log_file" 2>/dev/null | head -1 | tr -d '\n\r' || echo "0")
            failure_count=$(grep -c "DEBUG_TEST_FAILURE.*$TEST_ID" "$log_file" 2>/dev/null | head -1 | tr -d '\n\r' || echo "0")
            
            # Fallback method: If no test ID matches found, count completion messages (for when test context isn't set)
            if [ "$success_count" -eq 0 ] && [ "$failure_count" -eq 0 ]; then
                success_count=$(grep -c "🔄  Completed:" "$log_file" 2>/dev/null | head -1 | tr -d '\n\r' || echo "0")
                failure_count=$(grep -c "🔄  ERROR:" "$log_file" 2>/dev/null | head -1 | tr -d '\n\r' || echo "0")
            fi
            
            # Check for action completions (SUCCESS/FAILURE) to reset timer on each action completion
            if [ "$success_count" -gt 0 ] || [ "$failure_count" -gt 0 ]; then
                current_activity_count=$((success_count + failure_count))
            else
                current_activity_count=$(grep -c "DEBUG_TEST_SUCCESS.*$TEST_ID\|DEBUG_TEST_FAILURE.*$TEST_ID" "$log_file" 2>/dev/null | head -1 | tr -d '\n\r' || echo "0")
            fi
            
            # Check for test completion (after restart signal check)
            if grep -q "DEBUG_TEST_COMPLETE.*$TEST_ID" "$log_file" 2>/dev/null; then
                test_complete=true
                break
            fi
            
            # Fallback completion detection: if we have some completed actions and no activity for a few seconds
            if [ "$current_activity_count" -gt 0 ] && [ "$time_since_last_activity" -ge 5 ]; then
                test_complete=true
                echo "   ✅ Actions completed with no activity for 5s, finishing test"
                break
            fi
            
            # Reset timeout if new activity detected
            if [ "$current_activity_count" -gt "$last_activity_count" ]; then
                time_since_last_activity=0
                last_activity_count=$current_activity_count
            fi
        fi
        
        # Progress indicator (show total elapsed time and idle time)
        if [ $((elapsed_time % 5)) -eq 0 ]; then
            echo "   Progress: ${elapsed_time}s elapsed, ${time_since_last_activity}s idle (timeout: ${max_idle_time}s) (✅$success_count ❌$failure_count)"
        fi
    done
    
    # Stop log capture
    echo "📊 Finalizing log capture..."
    kill $LOGCAT_PID 2>/dev/null || true
    wait $LOGCAT_PID 2>/dev/null || true
    
    # Add final completion marker
    echo "$(date '+%m-%d %H:%M:%S.%3N') I/justfile (COMPLETE): ===== TEST EXECUTION COMPLETE =====" >> "$log_file"
    
    echo ""
    echo "📋 Test Results Analysis"
    echo "========================"
    
    # Parse final results
    if [ -f "$log_file" ]; then
        # Parse final results (clean output)
        # Primary method: Look for DEBUG_TEST_SUCCESS/FAILURE with test ID
        success_count=$(grep -c "DEBUG_TEST_SUCCESS.*$TEST_ID" "$log_file" 2>/dev/null | head -1 | tr -d '\n\r' || echo "0")
        failure_count=$(grep -c "DEBUG_TEST_FAILURE.*$TEST_ID" "$log_file" 2>/dev/null | head -1 | tr -d '\n\r' || echo "0")
        startup_count=$(grep -c "debug.*startup.*$TEST_ID\|DEBUG_TEST_START.*$TEST_ID" "$log_file" 2>/dev/null | head -1 | tr -d '\n\r' || echo "0")
        
        # Fallback method: If no test ID matches found, count completion messages (for when test context isn't set)
        if [ "$success_count" -eq 0 ] && [ "$failure_count" -eq 0 ]; then
            success_count=$(grep -c "🔄  Completed:" "$log_file" 2>/dev/null | head -1 | tr -d '\n\r' || echo "0")
            failure_count=$(grep -c "🔄  ERROR:" "$log_file" 2>/dev/null | head -1 | tr -d '\n\r' || echo "0")
            startup_count=$(grep -c "🔄  Executing" "$log_file" 2>/dev/null | head -1 | tr -d '\n\r' || echo "0")
        fi
        
        # Ensure variables are integers (strip any whitespace/newlines and validate)
        success_count=$(echo "$success_count" | tr -d ' \t\n\r' | grep -E '^[0-9]+$' || echo "0")
        failure_count=$(echo "$failure_count" | tr -d ' \t\n\r' | grep -E '^[0-9]+$' || echo "0")
        startup_count=$(echo "$startup_count" | tr -d ' \t\n\r' | grep -E '^[0-9]+$' || echo "0")
        
        echo "🆔 Test ID: $TEST_ID"
        echo "📊 Startup events: $startup_count"
        echo "📊 Successful actions: $success_count"
        echo "📊 Failed actions: $failure_count"
        echo ""
        
        # Show individual action results
        echo "📋 Individual Action Results:"
        echo "  ✅ $success_count actions completed successfully"
        if [ "$failure_count" -gt 0 ]; then
            echo "  ❌ $failure_count actions failed"
        fi
        echo ""
        
        # Handle checksum results if present
        if grep -q "CHECKSUM_FIRST_RUN\|CHECKSUM_VALID\|CHECKSUM_MISMATCH" "$log_file" 2>/dev/null; then
            echo "🔍 Processing checksum results..."
            
            if grep -q "CHECKSUM_FIRST_RUN" "$log_file"; then
                # Extract and save checksum to config
                CHECKSUM=$(grep "CHECKSUM_FIRST_RUN" "$log_file" | tail -1 | grep -o '"checksum": "[^"]*"' | cut -d'"' -f4)
                if [ -n "$CHECKSUM" ] && [ -f "$SAFE_CONFIG_FILE" ]; then
                    echo "📝 First run detected - saving baseline checksum: $CHECKSUM"
                    jq --arg checksum "$CHECKSUM" '.checksum_config.expected_checksum = $checksum' "$SAFE_CONFIG_FILE" > "$SAFE_CONFIG_FILE.tmp" && mv "$SAFE_CONFIG_FILE.tmp" "$SAFE_CONFIG_FILE"
                    echo "✅ Baseline checksum saved to $SAFE_CONFIG_FILE"
                fi
            elif grep -q "CHECKSUM_VALID" "$log_file"; then
                echo "✅ Checksum validation PASSED"
            elif grep -q "CHECKSUM_MISMATCH" "$log_file"; then
                echo "❌ Checksum validation FAILED"
                echo "💡 Run 'just test-android-update $CONFIG_NAME' to update baseline"
                test_result=1
            fi
            echo ""
        fi
        
        # Determine overall result
        if [ "$test_complete" = true ]; then
            echo "✅ Test completed normally"
            
            if [ "$failure_count" -eq 0 ] && [ "$success_count" -gt 0 ]; then
                echo "🎉 OVERALL RESULT: PASS"
                test_result=0
            elif [ "$failure_count" -gt 0 ]; then
                echo "❌ OVERALL RESULT: FAIL (failures detected)"
                test_result=1
            else
                echo "⚠️  OVERALL RESULT: INCONCLUSIVE (no actions executed)"
                test_result=1
            fi
        else
            echo "⏰ Test timed out (no activity for ${max_idle_time}s)"
            if [ "$failure_count" -gt 0 ]; then
                echo "❌ OVERALL RESULT: FAIL (timeout + failures)"
                test_result=1
            else
                echo "⚠️  OVERALL RESULT: TIMEOUT (idle timeout)"
                test_result=1
            fi
        fi
    else
        echo "❌ No log file found"
        test_result=1
    fi
    
    # Save results
    cat > "$test_dir/test_results.json" << EOF
    {
        "test_id": "$TEST_ID",
        "config": "$CONFIG_NAME",
        "timestamp": "$timestamp",
        "duration": $DURATION,
        "test_complete": $test_complete,
        "successful_actions": $success_count,
        "failed_actions": $failure_count,
        "startup_events": $startup_count,
        "overall_result": $([ $test_result -eq 0 ] && echo '"PASS"' || echo '"FAIL"')
    }
    EOF
    
    echo ""
    echo "💾 Test artifacts saved:"
    echo "   📄 Logs: $test_dir/test_logs.log"
    echo "   📊 Results: $test_dir/test_results.json"
    echo "   🆔 Test ID: $TEST_ID"
    echo ""
    
    echo "📊 Log Analysis Commands:"
    echo "   🔍 just logs-results-simple $TEST_ID $test_dir"
    echo "   📈 just logs-performance $TEST_ID"
    echo "   🚨 just logs-errors-only $TEST_ID"
    echo "   📝 just logs-test-id $TEST_ID"
    if [ $test_result -eq 0 ]; then
        echo "   🧹 just logs-cleanup-force 5"
    fi
    echo ""
    echo "📊 Enhanced Debug Commands:"
    echo "   🔍 just debug-test-flow $TEST_ID"
    echo "   📊 just debug-pids $TEST_ID"
    echo "   🔄 just debug-restarts $TEST_ID"
    echo "   ⚡ just debug-quick $TEST_ID"
    echo ""
    echo "🏷️  Universal Tag-Filtered Log Commands:"
    echo "   📋 just logs $TEST_ID                          # Full logs"
    echo "   📋 just logs $TEST_ID debug test               # Only debug+test logs"
    echo "   🚨 just logs-errors-tagged $TEST_ID            # All errors"
    echo "   🚨 just logs-errors-tagged $TEST_ID firebase   # Firebase errors only"
    echo "   ⚡ just logs-performance-tagged $TEST_ID        # All performance data"
    echo "   ⚡ just logs-performance-tagged $TEST_ID battle # Battle performance only"
    echo "   🔄 just logs-lifecycle-tagged $TEST_ID          # All test events"
    echo "   🔄 just logs-lifecycle-tagged $TEST_ID startup  # Startup events only"
    echo ""
    
    if [ $test_result -eq 0 ]; then
        echo "🎉 Test PASSED"
    else
        echo "💥 Test FAILED"
    fi
    
    # Clean up temporary config if it was auto-generated
    just _cleanup-temp-config "{{CONFIG_NAME}}"
    
    exit $test_result

# Enhanced test config with detailed error analysis and action-level reporting
_test-config-android-enhanced CONFIG_NAME DURATION="30" NO_RESTART="false": (_validate-config-exists CONFIG_NAME)
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Set up cleanup trap to ensure temp configs are cleaned up even if script is interrupted
    trap 'just cleanup-temp-configs >/dev/null 2>&1 || true' EXIT INT TERM
    
    # Configuration
    CONFIG_NAME="{{CONFIG_NAME}}"
    DURATION="{{DURATION}}"
    NO_RESTART="{{NO_RESTART}}"
    ANDROID_DEVICE_ID="${ANDROID_DEVICE_ID:-{{ANDROID_DEVICE_ID}}}"
    ANDROID_PACKAGE_NAME="${ANDROID_PACKAGE_NAME:-{{ANDROID_PACKAGE_NAME}}}"
    
    # Generate unique test ID
    TEST_ID="test_$(date +%Y%m%d_%H%M%S)_$(head -c 4 /dev/urandom | xxd -p)"
    
    echo "🧪 Enhanced Smart Test: $CONFIG_NAME"
    echo "🆔 Test ID: $TEST_ID"
    echo "⏱️  Duration: $DURATION seconds"
    echo "🔍 Enhanced Analysis: Action-level error detection & categorization"
    echo ""
    
    # Check prerequisites
    if ! adb -s "$ANDROID_DEVICE_ID" shell echo "Connected" >/dev/null 2>&1; then
        echo "❌ Device not connected"
        exit 1
    fi
    
    if ! adb -s "$ANDROID_DEVICE_ID" shell pm list packages | grep -q "$ANDROID_PACKAGE_NAME"; then
        echo "❌ App not installed"
        exit 1
    fi
    
    # Get the safe config filename
    SAFE_CONFIG_FILE=$(just _get-safe-config-file "$CONFIG_NAME")
    
    if [ ! -f "$SAFE_CONFIG_FILE" ]; then
        echo "❌ Config file not found: $SAFE_CONFIG_FILE"
        exit 1
    fi
    
    echo "✅ Prerequisites satisfied"
    echo ""
    
    # Create results directory
    timestamp=$(date +%Y%m%d_%H%M%S)
    test_dir="test_results/enhanced_${CONFIG_NAME}_$timestamp"
    mkdir -p "$test_dir"
    
    # Apply config with test ID (same as regular test-android)
    echo "🔄 Applying config with test ID..."
    
    # Create enhanced config with test ID metadata
    enhanced_config=$(mktemp)
    jq --arg test_id "$TEST_ID" --arg config_name "$CONFIG_NAME" --arg timestamp "$timestamp" \
        '. + {"test_metadata": {"test_id": $test_id, "config": $config_name, "timestamp": $timestamp}}' \
        "$SAFE_CONFIG_FILE" > "$enhanced_config"
    
    # Push config to device using proper permissions approach
    TEMP_CONFIG="/sdcard/temp_debug_config_$TEST_ID.json"
    
    # Push to temporary location first
    adb -s "$ANDROID_DEVICE_ID" push "$enhanced_config" "$TEMP_CONFIG"
    
    # Copy to app private directory using run-as
    if adb -s "$ANDROID_DEVICE_ID" shell "run-as $ANDROID_PACKAGE_NAME cp $TEMP_CONFIG files/debug_startup_actions.json" 2>/dev/null; then
        echo "✅ Config applied successfully"
    else
        echo "❌ Failed to apply config to app directory"
        adb -s "$ANDROID_DEVICE_ID" shell "rm $TEMP_CONFIG" 2>/dev/null || true
        rm "$enhanced_config"
        exit 1
    fi
    
    # Cleanup temp files
    adb -s "$ANDROID_DEVICE_ID" shell "rm $TEMP_CONFIG" 2>/dev/null || true
    rm "$enhanced_config"

    # Force restart app to ensure config is loaded (unless explicitly disabled)
    if [ "$NO_RESTART" != "true" ]; then
        echo "🔄 Restarting app to ensure config is loaded..."
        adb -s "$ANDROID_DEVICE_ID" shell am force-stop "$ANDROID_PACKAGE_NAME" 2>/dev/null || true
        sleep 1
        echo "🚀 Starting test with fresh app instance..."
        adb -s "$ANDROID_DEVICE_ID" shell am start -a android.intent.action.MAIN -n "$ANDROID_PACKAGE_NAME"/com.godot.game.GodotApp
    else
        echo "⚡ Starting test without restart (using current app state)..."
        adb -s "$ANDROID_DEVICE_ID" shell am start -a android.intent.action.MAIN -n "$ANDROID_PACKAGE_NAME"/com.godot.game.GodotApp
    fi
    
    # Enhanced monitoring and analysis
    echo "📊 Enhanced Test Monitoring & Analysis..."
    echo "   Looking for test ID: $TEST_ID"
    echo "   🔍 Real-time error categorization enabled"
    echo "   📈 Action-level performance tracking enabled"
    
    log_file="$test_dir/test_logs.log"
    enhanced_log="$test_dir/enhanced_analysis.log" 
    test_result=1
    test_complete=false
    success_count=0
    failure_count=0
    startup_count=0
    timeout_count=0
    firebase_error_count=0
    network_error_count=0
    validation_error_count=0
    
    # Clear old logs and start log capture
    echo "🧹 Clearing old logs for fresh test monitoring..."
    adb -s "$ANDROID_DEVICE_ID" logcat -c
    adb -s "$ANDROID_DEVICE_ID" logcat -v time -s godot > "$log_file" 2>/dev/null &
    LOGCAT_PID=$!
    
    # Enhanced monitoring with real-time analysis
    elapsed_time=0
    time_since_last_activity=0
    last_activity_count=0
    max_idle_time=$DURATION
    
    while [ $time_since_last_activity -lt $max_idle_time ]; do
        sleep 1
        elapsed_time=$((elapsed_time + 1))
        time_since_last_activity=$((time_since_last_activity + 1))
        
        if [ -f "$log_file" ]; then
            # Check for test completion
            if grep -q "DEBUG_TEST_COMPLETE.*$TEST_ID" "$log_file" 2>/dev/null; then
                test_complete=true
                break
            fi
            
            # Enhanced real-time analysis
            success_count=$(grep -c "DEBUG_TEST_SUCCESS.*$TEST_ID" "$log_file" 2>/dev/null | head -1 | tr -d '\n\r' || echo "0")
            failure_count=$(grep -c "DEBUG_TEST_FAILURE.*$TEST_ID" "$log_file" 2>/dev/null | head -1 | tr -d '\n\r' || echo "0")
            
            # Error categorization in real-time
            firebase_error_count=$(grep -c "firebase.*error\|auth.*failed\|database.*error\|Firebase.*Exception" "$log_file" 2>/dev/null | head -1 | tr -d '\n\r' || echo "0")
            network_error_count=$(grep -c "network.*error\|connection.*failed\|timeout.*error" "$log_file" 2>/dev/null | head -1 | tr -d '\n\r' || echo "0")
            validation_error_count=$(grep -c "assertion.*failed\|validation.*error\|Expected.*but.*got" "$log_file" 2>/dev/null | head -1 | tr -d '\n\r' || echo "0")
            
            # Check for any debug activity
            # Check for action completions (SUCCESS/FAILURE) to reset timer on each action completion
            current_activity_count=$(grep -c "DEBUG_TEST_SUCCESS.*$TEST_ID\|DEBUG_TEST_FAILURE.*$TEST_ID" "$log_file" 2>/dev/null | head -1 | tr -d '\n\r' || echo "0")
            
            # Reset timeout if new activity detected
            if [ "$current_activity_count" -gt "$last_activity_count" ]; then
                time_since_last_activity=0
                last_activity_count=$current_activity_count
            fi
        fi
        
        # Enhanced progress indicator with error categorization
        if [ $((elapsed_time % 5)) -eq 0 ]; then
            echo "   Progress: ${elapsed_time}s elapsed, ${time_since_last_activity}s idle (✅$success_count ❌$failure_count 🔥$firebase_error_count 🌐$network_error_count 📋$validation_error_count)"
        fi
    done
    
    # Stop log capture
    kill $LOGCAT_PID 2>/dev/null || true
    wait $LOGCAT_PID 2>/dev/null || true
    
    echo ""
    echo "📋 Enhanced Test Results Analysis"
    echo "================================="
    
    # Parse final results with enhanced analysis
    if [ -f "$log_file" ]; then
        # Parse final results
        success_count=$(grep -c "DEBUG_TEST_SUCCESS.*$TEST_ID" "$log_file" 2>/dev/null | head -1 | tr -d '\n\r' || echo "0")
        failure_count=$(grep -c "DEBUG_TEST_FAILURE.*$TEST_ID" "$log_file" 2>/dev/null | head -1 | tr -d '\n\r' || echo "0")
        startup_count=$(grep -c "debug.*startup.*$TEST_ID\|DEBUG_TEST_START.*$TEST_ID" "$log_file" 2>/dev/null | head -1 | tr -d '\n\r' || echo "0")
        
        # Enhanced error categorization
        firebase_error_count=$(grep -c "firebase.*error\|auth.*failed\|database.*error\|Firebase.*Exception" "$log_file" 2>/dev/null | head -1 | tr -d '\n\r' || echo "0")
        network_error_count=$(grep -c "network.*error\|connection.*failed\|timeout.*error" "$log_file" 2>/dev/null | head -1 | tr -d '\n\r' || echo "0")
        validation_error_count=$(grep -c "assertion.*failed\|validation.*error\|Expected.*but.*got" "$log_file" 2>/dev/null | head -1 | tr -d '\n\r' || echo "0")
        
        # Ensure variables are integers
        success_count=$(echo "$success_count" | tr -d ' \t\n\r' | grep -E '^[0-9]+$' || echo "0")
        failure_count=$(echo "$failure_count" | tr -d ' \t\n\r' | grep -E '^[0-9]+$' || echo "0")
        startup_count=$(echo "$startup_count" | tr -d ' \t\n\r' | grep -E '^[0-9]+$' || echo "0")
        firebase_error_count=$(echo "$firebase_error_count" | tr -d ' \t\n\r' | grep -E '^[0-9]+$' || echo "0")
        network_error_count=$(echo "$network_error_count" | tr -d ' \t\n\r' | grep -E '^[0-9]+$' || echo "0")
        validation_error_count=$(echo "$validation_error_count" | tr -d ' \t\n\r' | grep -E '^[0-9]+$' || echo "0")
        
        echo "🆔 Test ID: $TEST_ID"
        echo "📊 Startup events: $startup_count"
        echo "📊 Successful actions: $success_count"
        echo "📊 Failed actions: $failure_count"
        echo ""
        echo "🔍 Error Category Analysis:"
        echo "   🔥 Firebase errors: $firebase_error_count"
        echo "   🌐 Network errors: $network_error_count"
        echo "   📋 Validation errors: $validation_error_count"
        echo ""
        
        # Enhanced individual action results with timing and error analysis
        echo "📋 Detailed Action Results:"
        if [ "$success_count" -gt 0 ] || [ "$failure_count" -gt 0 ]; then
            action_lines=$(grep "$TEST_ID" "$log_file" 2>/dev/null | grep "DEBUG_TEST_SUCCESS\|DEBUG_TEST_FAILURE")
            if [ -n "$action_lines" ]; then
                echo "$action_lines" | while read -r line; do
                    if echo "$line" | grep -q "DEBUG_TEST_SUCCESS"; then
                        status="✅"
                        category=""
                    else
                        status="❌"
                        # Analyze failure category
                        if echo "$line" | grep -qi "firebase\|auth\|database"; then
                            category=" [FIREBASE]"
                        elif echo "$line" | grep -qi "network\|connection\|timeout"; then
                            category=" [NETWORK]"
                        elif echo "$line" | grep -qi "assertion\|validation\|expected"; then
                            category=" [VALIDATION]"
                        else
                            category=" [SYSTEM]"
                        fi
                    fi
                    action=$(echo "$line" | grep -o '"action": "[^"]*"' | sed 's/"action": "\([^"]*\)"/\1/' || echo "unknown")
                    duration=$(echo "$line" | grep -o '"duration_ms": [0-9]*' | sed 's/"duration_ms": \([0-9]*\)/\1/' || echo "0")
                    
                    # Performance analysis
                    if [ -n "$duration" ] && [ "$duration" -gt 0 ]; then
                        if [ "$duration" -gt 10000 ]; then
                            perf_note=" ⚠️ SLOW"
                        elif [ "$duration" -gt 5000 ]; then
                            perf_note=" ⏰ MEDIUM"
                        else
                            perf_note=""
                        fi
                        echo "  $status $action (${duration}ms$perf_note)$category"
                    else
                        echo "  $status $action (no timing)$category"
                    fi
                done | sort
            else
                echo "  (no detailed action results found)"
            fi
        else
            echo "  (no actions executed)"
        fi
        echo ""
        
        # Enhanced debugging recommendations
        echo "💡 Debugging Recommendations:"
        if [ "$failure_count" -gt 0 ]; then
            if [ "$firebase_error_count" -gt 0 ]; then
                echo "   🔥 Firebase Issues Detected:"
                echo "      - Check Firebase configuration in firebase/ directory"
                echo "      - Verify network connectivity and auth status"
                echo "      - Run: just config-restart-android 'Firebase Connection Test'"
            fi
            if [ "$network_error_count" -gt 0 ]; then
                echo "   🌐 Network Issues Detected:"
                echo "      - Check device internet connectivity"
                echo "      - Verify VPN/firewall settings"
                echo "      - Run: just config-restart-android 'Network Connectivity Test'"
            fi
            if [ "$validation_error_count" -gt 0 ]; then
                echo "   📋 Validation Issues Detected:"
                echo "      - Check test data integrity"
                echo "      - Verify expected vs actual results in logs"
                echo "      - Run individual failing actions for detailed analysis"
            fi
            echo "   🔧 Quick Retest Commands:"
            echo "      - Retry same test: just test-android-enhanced '$CONFIG_NAME'"
            echo "      - Standard test: just test-android '$CONFIG_NAME'"
            echo "      - Detailed logs: just test-monitor-android '$CONFIG_NAME'"
            echo "      - Single action test: just config-restart-android '<Action Name>'"
        fi
        echo ""
        
        # Determine overall result with enhanced logic
        if [ "$test_complete" = true ]; then
            echo "✅ Test completed normally"
            
            if [ "$failure_count" -eq 0 ] && [ "$success_count" -gt 0 ]; then
                echo "🎉 OVERALL RESULT: PASS"
                test_result=0
            elif [ "$failure_count" -gt 0 ]; then
                echo "❌ OVERALL RESULT: FAIL"
                echo "   Primary failure categories: Firebase($firebase_error_count) Network($network_error_count) Validation($validation_error_count)"
                test_result=1
            else
                echo "⚠️  OVERALL RESULT: INCONCLUSIVE (no actions executed)"
                test_result=1
            fi
        else
            echo "⏰ Test timed out (no activity for ${max_idle_time}s)"
            if [ "$failure_count" -gt 0 ]; then
                echo "❌ OVERALL RESULT: FAIL (timeout + failures)"
                test_result=1
            else
                echo "⚠️  OVERALL RESULT: TIMEOUT (idle timeout)"
                test_result=1
            fi
        fi
    else
        echo "❌ No log file found"
        test_result=1
    fi
    
    # Save enhanced results with additional metadata
    overall_result_value=$([ $test_result -eq 0 ] && echo "PASS" || echo "FAIL")
    printf '{\n    "test_id": "%s",\n    "config": "%s",\n    "timestamp": "%s",\n    "duration": %d,\n    "test_complete": %s,\n    "successful_actions": %d,\n    "failed_actions": %d,\n    "startup_events": %d,\n    "error_categories": {\n        "firebase_errors": %d,\n        "network_errors": %d,\n        "validation_errors": %d\n    },\n    "overall_result": "%s",\n    "enhanced_analysis": true\n}\n' \
        "$TEST_ID" "$CONFIG_NAME" "$timestamp" "$elapsed_time" "$test_complete" \
        "$success_count" "$failure_count" "$startup_count" \
        "$firebase_error_count" "$network_error_count" "$validation_error_count" \
        "$overall_result_value" > "$test_dir/enhanced_results.json"
    
    echo "📁 Enhanced results saved to: $test_dir/enhanced_results.json"
    echo "📁 Full logs available at: $test_dir/test_logs.log"
    
    # Clean up temporary config if it was auto-generated
    just _cleanup-temp-config "{{CONFIG_NAME}}"
    
    exit $test_result


# Helper function to recursively expand test configurations from a test list file
_expand_test_list TEST_LIST_NAME VISITED_LISTS="":
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_LIST_FILE="project/test-lists/{{TEST_LIST_NAME}}.json"
    
    # Check for circular references
    if echo "{{VISITED_LISTS}}" | grep -q "{{TEST_LIST_NAME}}"; then
        echo "❌ Circular reference detected in test list: {{TEST_LIST_NAME}}"
        echo "Visit chain: {{VISITED_LISTS}} -> {{TEST_LIST_NAME}}"
        exit 1
    fi
    
    if [ ! -f "$TEST_LIST_FILE" ]; then
        echo "❌ Test list file not found: $TEST_LIST_FILE"
        echo "Available test lists:"
        ls project/test-lists/*.json 2>/dev/null | sed 's/.*\///; s/\.json$//' | sed 's/^/  - /' || echo "  (none found)"
        exit 1
    fi
    
    # Extract configs array from JSON using jq
    if ! command -v jq &> /dev/null; then
        echo "❌ jq is required for parsing test list files. Please install jq."
        exit 1
    fi
    
    # Update visited lists for circular reference detection
    if [ -z "{{VISITED_LISTS}}" ]; then
        UPDATED_VISITED="{{TEST_LIST_NAME}}"
    else
        UPDATED_VISITED="{{VISITED_LISTS}},{{TEST_LIST_NAME}}"
    fi
    
    # Process each config entry
    jq -r '.configs[]' "$TEST_LIST_FILE" | while IFS= read -r config; do
        if [[ "$config" == @* ]]; then
            # This is a nested list reference - check if it contains wildcards
            nested_list_pattern="${config#@}"
            
            if [[ "$nested_list_pattern" == *'*'* ]]; then
                # This is a wildcard pattern - expand to matching test lists
                for list_file in project/test-lists/*.json; do
                    if [ -f "$list_file" ]; then
                        list_name=$(basename "$list_file" .json)
                        # Convert glob pattern to regex and test against list name
                        regex_pattern=$(echo "$nested_list_pattern" | sed 's/\./\\./g; s/\*/[^.]*/g; s/\?/[^.]/g')
                        if echo "$list_name" | grep -qE "^${regex_pattern}$"; then
                            # Avoid recursing into the current list
                            if [[ "$list_name" != "{{TEST_LIST_NAME}}" ]]; then
                                just _expand_test_list "$list_name" "$UPDATED_VISITED"
                            fi
                        fi
                    fi
                done
            else
                # This is a direct list reference - recursively expand it
                just _expand_test_list "$nested_list_pattern" "$UPDATED_VISITED"
            fi
        else
            # This is a regular config or wildcard action pattern
            if [[ "$config" == *'*'* ]]; then
                # This is a wildcard action pattern - create temporary config and output it
                temp_config_name="temp_wildcard_$(echo "$config" | sed 's/[^a-zA-Z0-9]/_/g')"
                echo "$temp_config_name"
                
                # Create temporary config file with the wildcard pattern
                temp_config_file="project/debug_configs/${temp_config_name}.json"
                echo '{"description":"Temporary wildcard config for pattern: '"$config"'","actions":["'"$config"'"]}' > "$temp_config_file"
            else
                # This is a direct config file name - output it directly
                echo "$config"
            fi
        fi
    done

# Helper function to load test configurations from a test list file (backward compatibility)
_load_test_list TEST_LIST_NAME:
    just _expand_test_list {{TEST_LIST_NAME}}

# Run test configurations from a specified test list on Android
_test-list-android TEST_LIST_NAME="default-all":
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_LIST_FILE="project/test-lists/{{TEST_LIST_NAME}}.json"
    
    # Load test list metadata
    if [ ! -f "$TEST_LIST_FILE" ]; then
        echo "❌ Test list file not found: $TEST_LIST_FILE"
        echo "Available test lists:"
        ls project/test-lists/*.json 2>/dev/null | sed 's/.*\///; s/\.json$//' | sed 's/^/  - /' || echo "  (none found)"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo "❌ jq is required for parsing test list files. Please install jq."
        exit 1
    fi
    
    TEST_NAME=$(jq -r '.name' "$TEST_LIST_FILE")
    TEST_DESC=$(jq -r '.description' "$TEST_LIST_FILE")
    
    echo "🧪 Running test list: $TEST_NAME"
    echo "📝 $TEST_DESC"
    echo ""
    
    # Load configs into bash array using expanded list functionality (supports @listname)
    configs=()
    while IFS= read -r config; do
        configs+=("$config")
    done < <(just _expand_test_list {{TEST_LIST_NAME}})
    
    if [ ${#configs[@]} -eq 0 ]; then
        echo "❌ No test configurations found in $TEST_LIST_FILE"
        exit 1
    fi
    
    echo "📋 Test configurations to run: ${#configs[@]}"
    for config in "${configs[@]}"; do
        echo "  - $config"
    done
    echo ""
    
    failed_configs=()
    # Create temporary files to store results instead of associative arrays
    temp_results=$(mktemp)
    
    for config in "${configs[@]}"; do
        echo "Testing configuration: $config"
        
        # Determine timeout based on config type - comprehensive tests need more time
        if echo "$config" | grep -q "comprehensive"; then
            timeout=90  # 90 seconds for comprehensive tests
        elif echo "$config" | grep -q "performance\|stress\|large"; then
            timeout=60  # 60 seconds for performance tests
        elif echo "$config" | grep -q "layer-all\|integration"; then
            timeout=75  # 75 seconds for layer tests and integration tests (wildcard-based)
        else
            timeout=45  # 45 seconds for standard tests
        fi
        
        # Capture the test output to extract test ID and action results
        # Temporarily disable exit on error to properly capture test results
        set +e
        test_output=$(just _test-config-android "$config" "$timeout" 2>&1)
        test_exit_code=$?
        set -e
        
        if [ $test_exit_code -eq 0 ]; then
            echo "✅ $config PASSED"
            config_status="PASSED"
        else
            echo "❌ $config FAILED"
            failed_configs+=("$config")
            config_status="FAILED"
        fi
        
        # Store basic result in temp file (detailed action processing removed for stability)
        echo "$config|$config_status|" >> "$temp_results"
        
        echo ""
    done
    
    echo "📋 Final Results for: $TEST_NAME"
    echo "=================="
    for config in "${configs[@]}"; do
        # Check if config is in failed_configs array using portable method
        is_failed=false
        if [ ${#failed_configs[@]} -gt 0 ]; then
            for failed_config in "${failed_configs[@]}"; do
                if [ "$failed_config" = "$config" ]; then
                    is_failed=true
                    break
                fi
            done
        fi
        
        if [ "$is_failed" = "true" ]; then
            echo "❌ $config: FAILED"
        else
            echo "✅ $config: PASSED"  
        fi
        
        # Show detailed action results if available
        if [ -f "$temp_results" ]; then
            action_details=$(grep "^$config|" "$temp_results" | cut -d'|' -f3)
            if [ -n "$action_details" ]; then
                echo "   Actions: $action_details"
            fi
        fi
    done
    
    # Clean up temporary file
    rm -f "$temp_results"
    
    if [ ${#failed_configs[@]} -eq 0 ]; then
        echo ""
        echo "🎉 All configurations PASSED!"
        exit 0
    else
        echo ""
        echo "💥 ${#failed_configs[@]} configuration(s) FAILED"
        exit 1
    fi

# 🔍 TRACE MODE: Shows detailed validation/config steps for debugging
# Perfect for understanding how the testing system processes different input types
test-android-trace TARGET DURATION="30":
    just test-android-target "{{TARGET}}" "{{DURATION}}" "false" "true"


# 🚀 ENHANCED: Auto-discover and run ALL tests using wildcards
# Unified testing command with auto-detection of target type
test-android-target TARGET DURATION="30" NO_RESTART="false" TRACE="false":
    #!/usr/bin/env bash
    set -euo pipefail
    
    TARGET="{{TARGET}}"
    TRACE_MODE="{{TRACE}}"
    
    # Enable step-by-step tracing if requested
    if [ "$TRACE_MODE" = "true" ]; then
        echo "🔍 TRACE MODE: Showing validation/config steps"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🎯 Target: $TARGET"
        echo "⏱️  Duration: {{DURATION}}s"
        echo "🔄 Restart: {{NO_RESTART}}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi
    
    # Auto-detect target type and route to appropriate implementation
    if [ "$TRACE_MODE" = "true" ]; then
        echo "🔍 Step 1: Analyzing target pattern..."
        echo "   Input: '$TARGET'"
        echo "   Checking for: Test list wildcard (@pattern)"
    fi
    
    if [[ "$TARGET" == "@"*"*"* ]]; then
        # Test list wildcard pattern detected - use test list expansion
        PATTERN="${TARGET#@}"  # Remove @ prefix
        echo "🎯 Test list wildcard detected: $TARGET"
        if [ "$TRACE_MODE" = "true" ]; then
            echo "   ✅ Match: Test list wildcard pattern"
            echo "   Extracted pattern: '$PATTERN'"
        fi
        echo "🔍 Finding test lists matching pattern: $PATTERN"
        
        # Find matching test lists
        MATCHING_LISTS=$(just list-test-lists-matching "$PATTERN" 2>/dev/null | grep "🏷️" | awk '{print $2}' || true)
        
        if [ -n "$MATCHING_LISTS" ]; then
            echo "📋 Found matching test lists:"
            echo "$MATCHING_LISTS" | sed 's/^/  - /'
            echo ""
            
            # Execute each matching test list
            echo "$MATCHING_LISTS" | while read -r list_name; do
                if [ -n "$list_name" ]; then
                    echo "🧪 Executing test list: $list_name"
                    just _test-list-android "$list_name"
                    echo ""
                fi
            done
        else
            echo "❌ No test lists found matching pattern: $PATTERN"
            echo "💡 Available patterns:"
            echo "   @pre-*        # All pre-* test lists"
            echo "   @*-validation # All *-validation test lists"
            echo "   @firebase-*   # All firebase-* test lists"
            echo ""
            echo "💡 Use 'just list-test-lists' to see all available lists"
            exit 1
        fi
        exit 0
    elif [[ "$TARGET" == *"*"* ]]; then
        # Wildcard pattern detected - use config testing with temporary config
        if [ "$TRACE_MODE" = "true" ]; then
            echo "   ❌ Not test list wildcard"
            echo "🔍 Step 2: Checking for action wildcard pattern..."
            echo "   ✅ Match: Contains '*' character"
            echo "   Route: _test-config-android (wildcard mode)"
        fi
        echo "🎯 Wildcard pattern detected: $TARGET"
        just _test-config-android "$TARGET" "{{DURATION}}" "{{NO_RESTART}}" "$TRACE_MODE"
    elif [ -f "project/debug_configs/$TARGET.json" ]; then
        # Config file exists - use config testing
        if [ "$TRACE_MODE" = "true" ]; then
            echo "   ❌ Not action wildcard pattern"
            echo "🔍 Step 3: Checking for existing config file..."
            echo "   File: project/debug_configs/$TARGET.json"
            echo "   ✅ Match: Config file exists"
            echo "   Route: _test-config-android (config mode)"
        fi
        echo "📋 Config file detected: $TARGET"
        just _test-config-android "$TARGET" "{{DURATION}}" "{{NO_RESTART}}" "$TRACE_MODE"
    elif [ -f "project/test-lists/$TARGET.json" ]; then
        # Test list exists - use list testing
        if [ "$TRACE_MODE" = "true" ]; then
            echo "   ❌ Config file not found"
            echo "🔍 Step 4: Checking for test list file..."
            echo "   File: project/test-lists/$TARGET.json"
            echo "   ✅ Match: Test list file exists"
            echo "   Route: _test-list-android"
        fi
        echo "📝 Test list detected: $TARGET"
        just _test-list-android "$TARGET"
    else
        # Try validation to see if it's a valid action name or wildcard pattern
        if [ "$TRACE_MODE" = "true" ]; then
            echo "   ❌ Test list file not found"
            echo "🔍 Step 5: Validating as action name..."
            echo "   Testing: _validate-config-exists '$TARGET'"
        fi
        if just _validate-config-exists "$TARGET" >/dev/null 2>&1; then
            # Validation succeeded - it's a valid action or matches a pattern
            if [ "$TRACE_MODE" = "true" ]; then
                echo "   ✅ Match: Valid action name"
                echo "   Route: _test-config-android (action mode)"
            fi
            echo "🎯 Action detected: $TARGET"
            just _test-config-android "$TARGET" "{{DURATION}}" "{{NO_RESTART}}" "$TRACE_MODE"
        else
            if [ "$TRACE_MODE" = "true" ]; then
                echo "   ❌ Validation failed: Not a valid action name"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo "🚫 TRACE COMPLETE: No matches found"
            fi
            echo "❌ Target not found: $TARGET"
            echo "💡 Checking available options..."
            echo ""
            echo "📋 Available config files:"
            ls project/debug_configs/*.json 2>/dev/null | sed 's/.*\//  /' | sed 's/\.json$//' | head -5 || echo "  (none found)"
            echo ""
            echo "📝 Available test lists:"  
            ls project/test-lists/*.json 2>/dev/null | sed 's/.*\//  /' | sed 's/\.json$//' | head -5 || echo "  (none found)"
            echo ""
            echo "🎯 Example wildcard patterns:"
            echo "  backend.*             # All backend tests"
            echo "  *.*.error_handling    # All error handling tests"
            exit 1
        fi
    fi

# Enhanced unified testing command with auto-detection
test-android-enhanced TARGET DURATION="30" NO_RESTART="false":
    #!/usr/bin/env bash
    set -euo pipefail
    
    TARGET="{{TARGET}}"
    
    # Auto-detect target type and route to appropriate enhanced implementation
    if [[ "$TARGET" == "@"*"*"* ]]; then
        # Test list wildcard pattern detected - enhanced testing not directly supported
        PATTERN="${TARGET#@}"  # Remove @ prefix
        echo "🎯 Test list wildcard detected: $TARGET"
        echo "💡 Note: Enhanced analysis will run on individual configs within matching lists"
        echo "🔍 Finding test lists matching pattern: $PATTERN"
        
        # Find matching test lists
        MATCHING_LISTS=$(just list-test-lists-matching "$PATTERN" 2>/dev/null | grep "🏷️" | awk '{print $2}' || true)
        
        if [ -n "$MATCHING_LISTS" ]; then
            echo "📋 Found matching test lists:"
            echo "$MATCHING_LISTS" | sed 's/^/  - /'
            echo ""
            
            # Execute each matching test list (will use standard execution, not enhanced)
            echo "$MATCHING_LISTS" | while read -r list_name; do
                if [ -n "$list_name" ]; then
                    echo "🧪 Executing test list: $list_name"
                    just _test-list-android "$list_name"
                    echo ""
                fi
            done
        else
            echo "❌ No test lists found matching pattern: $PATTERN"
            echo "💡 Available patterns:"
            echo "   @pre-*        # All pre-* test lists"
            echo "   @*-validation # All *-validation test lists"
            echo "   @firebase-*   # All firebase-* test lists"
            echo ""
            echo "💡 Use 'just list-test-lists' to see all available lists"
            exit 1
        fi
        exit 0
    elif [[ "$TARGET" == *"*"* ]]; then
        # Wildcard pattern detected - use enhanced config testing
        echo "🎯 Enhanced wildcard pattern testing: $TARGET"
        just _test-config-android-enhanced "$TARGET" "{{DURATION}}" "{{NO_RESTART}}"
    elif [ -f "project/debug_configs/$TARGET.json" ]; then
        # Config file exists - use enhanced config testing
        echo "📋 Enhanced config testing: $TARGET"
        just _test-config-android-enhanced "$TARGET" "{{DURATION}}" "{{NO_RESTART}}"
    elif [ -f "project/test-lists/$TARGET.json" ]; then
        # Test list exists - enhanced testing not directly supported for lists
        echo "📝 Test list detected: $TARGET"
        echo "💡 Note: Enhanced analysis runs on individual configs within the list"
        just _test-list-android "$TARGET"
    else
        echo "❌ Target not found: $TARGET"
        echo "💡 Checking available options..."
        echo ""
        echo "📋 Available config files:"
        ls project/debug_configs/*.json 2>/dev/null | sed 's/.*\//  /' | sed 's/\.json$//' | head -5 || echo "  (none found)"
        echo ""
        echo "📝 Available test lists:"  
        ls project/test-lists/*.json 2>/dev/null | sed 's/.*\//  /' | sed 's/\.json$//' | head -5 || echo "  (none found)"
        echo ""
        echo "🎯 Example wildcard patterns:"
        echo "  backend.*             # All backend tests"
        echo "  *.*.error_handling    # All error handling tests"
        exit 1
    fi

# Force update checksum baseline for a config
test-android-update CONFIG_NAME="":
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{CONFIG_NAME}}"
    
    # If no config provided, show fzf selector for checksum configs only
    if [ -z "$CONFIG_NAME" ]; then
        if ! command -v fzf >/dev/null 2>&1; then
            echo "❌ 'fzf' command not found. Install with: brew install fzf"
            echo "💡 Available checksum configs:"
            just test-android-list-checksum
            exit 1
        fi
        
        echo "📸 Select checksum config to UPDATE baseline:"
        echo ""
        
        # Build options with only checksum-enabled configs
        options=()
        for file in project/debug_configs/*.json; do
            if [ -f "$file" ]; then
                name=$(basename "$file" .json)
                
                # Only include checksum-enabled configs
                if jq -e '.checksum_config' "$file" >/dev/null 2>&1; then
                    desc=$(jq -r '.description // "No description"' "$file" 2>/dev/null || echo "No description")
                    expected_checksum=$(jq -r '.checksum_config.expected_checksum // ""' "$file")
                    state_type=$(jq -r '.checksum_config.state_type // "unknown"' "$file")
                    
                    if [ -n "$expected_checksum" ]; then
                        status="✅ BASELINE SET"
                    else
                        status="🔄 NEEDS BASELINE"
                    fi
                    
                    options+=("📸 $name ($state_type) $status - $desc")
                fi
            fi
        done
        
        if [ ${#options[@]} -eq 0 ]; then
            echo "❌ No checksum-enabled configs found"
            echo "💡 Use 'just test-android-list-checksum' to see all configs"
            exit 1
        fi
        
        # Use fzf to select
        selected_line=$(printf '%s\n' "${options[@]}" | fzf \
            --prompt="Select checksum config to UPDATE: " \
            --height=~80% \
            --layout=reverse \
            --border \
            --preview-window=hidden \
            --header="📸 Checksum Configs Only | Will force update baseline")
        
        if [ -n "$selected_line" ]; then
            # Extract the name (between prefix and state_type)
            CONFIG_NAME=$(echo "$selected_line" | sed -E 's/^📸 ([^ ]+) \([^)]+\) .*/\1/')
            echo "Selected: $CONFIG_NAME"
            echo ""
        else
            echo "❌ No selection made"
            exit 1
        fi
    fi
    
    echo "📸 Force updating checksum baseline for: $CONFIG_NAME"
    echo ""
    
    # Check if config file exists
    CONFIG_FILE="project/debug_configs/$CONFIG_NAME.json"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ Config file not found: $CONFIG_FILE"
        echo "💡 Available configs:"
        ls project/debug_configs/*.json 2>/dev/null | sed 's/.*\//  /' | sed 's/\.json$//' | head -10 || echo "  (none found)"
        exit 1
    fi
    
    # Check if it's a checksum config
    if ! jq -e '.checksum_config' "$CONFIG_FILE" >/dev/null 2>&1; then
        echo "❌ Config file does not contain checksum configuration"
        echo "💡 This command only works with checksum-enabled configs"
        exit 1
    fi
    
    # Clear the expected checksum to force regeneration
    echo "🔄 Clearing existing baseline to force regeneration..."
    jq '.checksum_config.expected_checksum = ""' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    echo "✅ Baseline cleared"
    echo ""
    
    # Run the test to generate new baseline
    echo "🧪 Running test to generate new baseline..."
    just test-android-target "$CONFIG_NAME"

# Reset checksum baseline (remove expected checksum from config)
test-android-reset CONFIG_NAME="":
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{CONFIG_NAME}}"
    
    # If no config provided, show fzf selector for checksum configs only
    if [ -z "$CONFIG_NAME" ]; then
        if ! command -v fzf >/dev/null 2>&1; then
            echo "❌ 'fzf' command not found. Install with: brew install fzf"
            echo "💡 Available checksum configs:"
            just test-android-list-checksum
            exit 1
        fi
        
        echo "🗑️  Select checksum config to RESET baseline:"
        echo ""
        
        # Build options with only checksum-enabled configs
        options=()
        for file in project/debug_configs/*.json; do
            if [ -f "$file" ]; then
                name=$(basename "$file" .json)
                
                # Only include checksum-enabled configs
                if jq -e '.checksum_config' "$file" >/dev/null 2>&1; then
                    desc=$(jq -r '.description // "No description"' "$file" 2>/dev/null || echo "No description")
                    expected_checksum=$(jq -r '.checksum_config.expected_checksum // ""' "$file")
                    state_type=$(jq -r '.checksum_config.state_type // "unknown"' "$file")
                    
                    if [ -n "$expected_checksum" ]; then
                        status="✅ BASELINE SET"
                    else
                        status="🔄 NEEDS BASELINE"
                    fi
                    
                    options+=("🗑️ $name ($state_type) $status - $desc")
                fi
            fi
        done
        
        if [ ${#options[@]} -eq 0 ]; then
            echo "❌ No checksum-enabled configs found"
            echo "💡 Use 'just test-android-list-checksum' to see all configs"
            exit 1
        fi
        
        # Use fzf to select
        selected_line=$(printf '%s\n' "${options[@]}" | fzf \
            --prompt="Select checksum config to RESET: " \
            --height=~80% \
            --layout=reverse \
            --border \
            --preview-window=hidden \
            --header="🗑️ Checksum Configs Only | Will remove baseline (start fresh)")
        
        if [ -n "$selected_line" ]; then
            # Extract the name (between prefix and state_type)
            CONFIG_NAME=$(echo "$selected_line" | sed -E 's/^🗑️ ([^ ]+) \([^)]+\) .*/\1/')
            echo "Selected: $CONFIG_NAME"
            echo ""
        else
            echo "❌ No selection made"
            exit 1
        fi
    fi
    
    echo "🗑️  Resetting checksum baseline for: $CONFIG_NAME"
    echo ""
    
    # Check if config file exists
    CONFIG_FILE="project/debug_configs/$CONFIG_NAME.json"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ Config file not found: $CONFIG_FILE"
        echo "💡 Available configs:"
        ls project/debug_configs/*.json 2>/dev/null | sed 's/.*\//  /' | sed 's/\.json$//' | head -10 || echo "  (none found)"
        exit 1
    fi
    
    # Check if it's a checksum config
    if ! jq -e '.checksum_config' "$CONFIG_FILE" >/dev/null 2>&1; then
        echo "❌ Config file does not contain checksum configuration"
        echo "💡 This command only works with checksum-enabled configs"
        exit 1
    fi
    
    # Show current checksum if it exists
    CURRENT_CHECKSUM=$(jq -r '.checksum_config.expected_checksum // ""' "$CONFIG_FILE")
    if [ -n "$CURRENT_CHECKSUM" ]; then
        echo "📋 Current baseline checksum: $CURRENT_CHECKSUM"
    else
        echo "📋 No baseline checksum currently set"
    fi
    echo ""
    
    # Clear the expected checksum
    echo "🔄 Removing baseline checksum..."
    jq '.checksum_config.expected_checksum = ""' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    echo "✅ Baseline checksum removed"
    echo ""
    echo "💡 Next run of 'just test-android-target $CONFIG_NAME' will create a new baseline"

# List checksum-enabled configs (configs with checksum_config section)
test-android-list-checksum:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "📸 Checksum-Enabled Test Configurations"
    echo "======================================="
    echo ""
    
    checksum_configs=()
    regular_configs=()
    
    # Scan all config files
    for config_file in project/debug_configs/*.json; do
        if [ -f "$config_file" ]; then
            config_name=$(basename "$config_file" .json)
            
            # Check if it has checksum_config section
            if jq -e '.checksum_config' "$config_file" >/dev/null 2>&1; then
                # Get checksum status
                expected_checksum=$(jq -r '.checksum_config.expected_checksum // ""' "$config_file")
                state_type=$(jq -r '.checksum_config.state_type // "unknown"' "$config_file")
                
                if [ -n "$expected_checksum" ]; then
                    checksum_configs+=("✅ $config_name ($state_type) - BASELINE SET")
                else
                    checksum_configs+=("🔄 $config_name ($state_type) - NEEDS BASELINE")
                fi
            else
                regular_configs+=("   $config_name")
            fi
        fi
    done
    
    # Display results
    checksum_count=${#checksum_configs[@]}
    regular_count=${#regular_configs[@]}
    
    if [ $checksum_count -gt 0 ]; then
        echo "🧪 CHECKSUM-ENABLED CONFIGS ($checksum_count):"
        printf '%s\n' "${checksum_configs[@]}"
        echo ""
        echo "📋 USAGE:"
        echo "  just test-android-target <config>     # Run checksum test"
        echo "  just test-android-update <config>     # Force update baseline"
        echo "  just test-android-reset <config>      # Remove baseline"
        echo ""
    else
        echo "❌ No checksum-enabled configs found"
        echo ""
    fi
    
    echo "🔧 REGULAR CONFIGS ($regular_count):"
    if [ $regular_count -gt 0 ]; then
        printf '%s\n' "${regular_configs[@]}"
        echo ""
        echo "💡 To enable checksum testing on a regular config, add:"
        echo '   "checksum_config": {'
        echo '     "state_type": "your_state_type",'
        echo '     "expected_checksum": ""'
        echo '   }'
        echo ""
        echo "📝 For new checksum configs, ensure:"
        echo '   "description": "Feature CHECKSUM Test - Description"  # Include "checksum" keyword'
        echo '   Filename: *-checksum-test.json or *-snapshot-test.json'
    else
        echo "   (none found)"
    fi
    echo ""
    echo "📜 NAMING CONVENTION:"
    echo "  *-checksum-test.json    # Recommended for checksum configs"
    echo "  *-snapshot-test.json    # Alternative naming"
    echo "  regular-config.json     # Standard test configs"
    echo ""
    echo "📝 DESCRIPTION REQUIREMENT:"
    echo '  "description": "Feature CHECKSUM Test - ..."  # Include "checksum" for fzf search'

test-all-android:
    echo "🚀 Complete Test Suite - Full system validation"
    just _test-list-android default-all

# Universal test command - Interactive chooser (no args) or direct execution (with TARGET)
# No args: Shows all debug configs and test lists with descriptions for easy selection
# With args: Direct execution like test-android-target (configs, wildcards, actions, test lists)
test-android TARGET="" DURATION="30" NO_RESTART="false":
    #!/usr/bin/env bash
    
    # If arguments provided, use direct execution mode
    if [ -n "{{TARGET}}" ]; then
        echo "🎯 Direct execution mode: {{TARGET}}"
        just test-android-target "{{TARGET}}" "{{DURATION}}" "{{NO_RESTART}}"
        exit $?
    fi
    
    # Interactive mode (no arguments provided)
    if ! command -v fzf >/dev/null 2>&1; then
        echo "❌ 'fzf' command not found. Install with: brew install fzf"
        echo "💡 Using fallback: just test-android-manual"
        just test-android-manual
        exit $?
    fi
    
    # Build options with category prefixes and descriptions
    options=()
    
    # Add debug configs with 🔧 prefix
    for file in project/debug_configs/*.json; do
        name=$(basename "$file" .json)
        desc=$(jq -r '.description // "No description"' "$file" 2>/dev/null || echo "No description")
        options+=("🔧 $name - $desc")
    done
    
    # Add test lists with 📝 prefix  
    for file in project/test-lists/*.json; do
        name=$(basename "$file" .json)
        desc=$(jq -r '.description // .name // "No description"' "$file" 2>/dev/null || echo "No description")
        options+=("📝 $name - $desc")
    done
    
    # Use fzf to select with nice formatting
    selected_line=$(printf '%s\n' "${options[@]}" | fzf \
        --prompt="Select test: " \
        --height=~80% \
        --layout=reverse \
        --border \
        --preview-window=hidden \
        --header="🔧 Debug Configs | 📝 Test Lists | Use fuzzy search to filter")
    
    if [ -n "$selected_line" ]; then
        # Extract the name (between prefix and description)
        selected=$(echo "$selected_line" | sed -E 's/^[📝🔧] ([^ ]+) - .*/\1/')
        echo "Running: just test-android-target '$selected'"
        just test-android-target "$selected" "{{DURATION}}" "{{NO_RESTART}}"
    else
        echo "❌ No selection made"
        exit 1
    fi

test-android-manual:
    #!/usr/bin/env bash
    echo "📋 Select a test to run:"
    echo ""
    
    # Build arrays of files and descriptions
    configs=()
    descriptions=()
    
    # Add debug configs
    echo "🔧 Debug Configurations:"
    for file in project/debug_configs/*.json; do
        name=$(basename "$file" .json)
        desc=$(jq -r '.description // "No description"' "$file" 2>/dev/null || echo "No description")
        configs+=("$name")
        descriptions+=("$desc")
        printf "%2d. %-20s - %s\n" ${#configs[@]} "$name" "$desc"
    done
    
    echo ""
    echo "📝 Test Lists:"
    for file in project/test-lists/*.json; do
        name=$(basename "$file" .json)
        desc=$(jq -r '.description // .name // "No description"' "$file" 2>/dev/null || echo "No description")
        configs+=("$name")
        descriptions+=("$desc")
        printf "%2d. %-20s - %s\n" ${#configs[@]} "$name" "$desc"
    done
    
    echo ""
    read -p "Enter number (1-${#configs[@]}): " choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#configs[@]}" ]; then
        selected="${configs[$((choice-1))]}"
        echo "Running: just test-android-target '$selected'"
        just test-android-target "$selected"
    else
        echo "❌ Invalid selection"
        exit 1
    fi

# Essential test suite commands - focused workflows
_test-smoke-android:
    echo "⚡ Quick Smoke Test - 30 seconds essential validation"
    just _test-config-android smoke-test

_test-development-android:
    echo "🔧 Development Workflow - Daily development cycle"
    just _test-list-android development-workflow

_test-production-android:
    echo "🚀 Production Ready - Comprehensive release validation"
    just _test-list-android production-ready



# List available test lists
list-test-lists:
    #!/usr/bin/env bash
    echo "📋 Available test lists:"
    echo "======================="
    
    if [ ! -d "project/test-lists" ]; then
        echo "❌ No test-lists directory found"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo "❌ jq is required for parsing test list files. Please install jq."
        exit 1
    fi
    
    for file in project/test-lists/*.json; do
        if [ -f "$file" ]; then
            filename=$(basename "$file" .json)
            name=$(jq -r '.name' "$file")
            description=$(jq -r '.description' "$file")
            config_count=$(jq -r '.configs | length' "$file")
            
            echo ""
            echo "🏷️  $filename"
            echo "   Name: $name"
            echo "   Description: $description"
            echo "   Configs: $config_count"
            echo "   Usage: just test-android $filename"
        fi
    done

# List test lists matching a wildcard pattern
list-test-lists-matching PATTERN:
    #!/usr/bin/env bash
    echo "📋 Test lists matching pattern: {{PATTERN}}"
    echo "======================================"
    
    if [ ! -d "project/test-lists" ]; then
        echo "❌ No test-lists directory found"
        exit 1
    fi
    
    # Convert glob pattern to regex
    regex_pattern=$(echo "{{PATTERN}}" | sed 's/\./\\./g; s/\*/[^.]*/g; s/\?/[^.]/g')
    found_any=false
    
    for file in project/test-lists/*.json; do
        if [ -f "$file" ]; then
            filename=$(basename "$file" .json)
            if echo "$filename" | grep -qE "^${regex_pattern}$"; then
                if [ "$found_any" = false ]; then
                    echo ""
                    found_any=true
                fi
                
                name=$(jq -r '.name' "$file" 2>/dev/null || echo "N/A")
                description=$(jq -r '.description' "$file" 2>/dev/null || echo "N/A")
                config_count=$(jq -r '.configs | length' "$file" 2>/dev/null || echo "N/A")
                
                echo "🏷️  $filename"
                echo "   Name: $name"
                echo "   Description: $description"
                echo "   Configs: $config_count"
                echo "   Usage: just test-android $filename"
                echo ""
            fi
        fi
    done
    
    if [ "$found_any" = false ]; then
        echo ""
        echo "❌ No test lists found matching pattern: {{PATTERN}}"
        echo "💡 Available patterns you can try:"
        echo "   firebase-*    # All Firebase test lists"
        echo "   *-validation  # All validation test lists"
        echo "   system-*      # All system test lists"
        echo ""
        echo "💡 Use 'just list-test-lists' to see all available lists"
    fi

# ================================
# LOG FILTERING AND ANALYSIS HELPERS
# ================================

# Show only logs for a specific test ID (saves tons of reading!)
_logs-test-id TEST_ID:
    #!/usr/bin/env bash
    set -euo pipefail
    
    LOG_FILE=$(find test_results -name "test_logs.log" -exec grep -l "{{TEST_ID}}" {} \; | head -1)
    
    if [ -z "$LOG_FILE" ]; then
        echo "❌ No logs found for test ID: {{TEST_ID}}"
        echo "💡 Available test IDs:"
        find test_results -name "test_logs.log" -exec basename {} \; | sed 's/test_logs.log//' | head -5
        exit 1
    fi
    
    echo "🔍 Filtering logs for test ID: {{TEST_ID}}"
    echo "📁 Log file: $LOG_FILE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    grep "{{TEST_ID}}" "$LOG_FILE" | \
    sed 's/^.*I\/godot.*: //' | \
    grep -v "BUFFER\|font_size"

# Show logs for a specific test ID
logs-android TEST_ID:
    just _logs-test-id "{{TEST_ID}}"

# Show only test results (SUCCESS/FAILURE) for a specific test ID
_logs-results-only TEST_ID:
    #!/usr/bin/env bash
    set -euo pipefail
    
    LOG_FILE=$(find test_results -name "test_logs.log" -exec grep -l "{{TEST_ID}}" {} \; | head -1)
    
    if [ -z "$LOG_FILE" ]; then
        echo "❌ No logs found for test ID: {{TEST_ID}}"
        exit 1
    fi
    
    echo "📊 Results for test ID: {{TEST_ID}}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    grep "{{TEST_ID}}" "$LOG_FILE" | \
    grep "DEBUG_TEST_SUCCESS\|DEBUG_TEST_FAILURE" | \
    sed 's/^.*DEBUG_TEST_SUCCESS.*/✅ SUCCESS/' | \
    sed 's/^.*DEBUG_TEST_FAILURE.*/❌ FAILURE/' | \
    paste - <(grep "{{TEST_ID}}" "$LOG_FILE" | grep "DEBUG_TEST_SUCCESS\|DEBUG_TEST_FAILURE" | \
    grep -o '"action": "[^"]*"' | sed 's/"action": "\([^"]*\)"/\1/') | \
    paste - <(grep "{{TEST_ID}}" "$LOG_FILE" | grep "DEBUG_TEST_SUCCESS\|DEBUG_TEST_FAILURE" | \
    grep -o '"duration_ms": [0-9]*' | sed 's/"duration_ms": \([0-9]*\)/\1ms/') | \
    column -t -s $'\t'

# Show test results only for a specific test ID
logs-android-results TEST_ID:
    just _logs-results-only "{{TEST_ID}}"

# Simple results filter (when you know the log file) - Clean output
_logs-results-simple TEST_ID LOG_DIR:
    #!/usr/bin/env bash
    echo "📊 Results for {{TEST_ID}} in {{LOG_DIR}}:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    grep "{{TEST_ID}}" "{{LOG_DIR}}/test_logs.log" | \
    grep "DEBUG_TEST_SUCCESS\|DEBUG_TEST_FAILURE" | \
    sed 's/^.*DEBUG_TEST_SUCCESS.*/✅ SUCCESS/' | \
    sed 's/^.*DEBUG_TEST_FAILURE.*/❌ FAILURE/' | \
    paste - <(grep "{{TEST_ID}}" "{{LOG_DIR}}/test_logs.log" | grep "DEBUG_TEST_SUCCESS\|DEBUG_TEST_FAILURE" | \
    grep -o '"action": "[^"]*"' | sed 's/"action": "\([^"]*\)"/\1/') | \
    paste - <(grep "{{TEST_ID}}" "{{LOG_DIR}}/test_logs.log" | grep "DEBUG_TEST_SUCCESS\|DEBUG_TEST_FAILURE" | \
    grep -o '"duration_ms": [0-9]*' | sed 's/"duration_ms": \([0-9]*\)/\1ms/') | \
    column -t -s $'\t'

# Even simpler - just show action names and status  
_logs-quick TEST_ID LOG_DIR:
    #!/usr/bin/env bash
    echo "⚡ Quick Results for {{TEST_ID}}:"
    grep "{{TEST_ID}}" "{{LOG_DIR}}/test_logs.log" | \
    grep "DEBUG_TEST_SUCCESS\|DEBUG_TEST_FAILURE" | \
    grep -o '"action": "[^"]*".*"duration_ms": [0-9]*' | \
    sed 's/"action": "\([^"]*\)".*"duration_ms": \([0-9]*\)/\1: \2ms/' | \
    while read line; do
        if grep -q "DEBUG_TEST_SUCCESS" <<< "$(grep "$line" "{{LOG_DIR}}/test_logs.log")"; then
            echo "✅ $line"
        else
            echo "❌ $line"
        fi
    done

# Show recent test directories and their IDs  
_logs-list-recent:
    #!/usr/bin/env bash
    echo "📁 Recent Test Results:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    find test_results -name "test_results.json" -type f | \
    head -10 | \
    while read file; do
        if [ -f "$file" ]; then
            test_id=$(jq -r '.test_id // "unknown"' "$file" 2>/dev/null || echo "unknown")
            config=$(jq -r '.config // "unknown"' "$file" 2>/dev/null || echo "unknown")  
            result=$(jq -r '.overall_result // "unknown"' "$file" 2>/dev/null || echo "unknown")
            timestamp=$(jq -r '.timestamp // "unknown"' "$file" 2>/dev/null || echo "unknown")
            
            status_icon="❓"
            if [ "$result" = "PASS" ]; then
                status_icon="✅"
            elif [ "$result" = "FAIL" ]; then
                status_icon="❌"
            fi
            
            echo "$status_icon $test_id [$config] - $timestamp"
            echo "   📄 just logs-android $test_id"
            echo "   📊 just logs-android-results $test_id"
        fi
    done

# Show recent test runs and their IDs
logs-android-recent:
    just _logs-list-recent

# Show errors only for a specific test ID (perfect for debugging!)
_logs-errors-only TEST_ID:
    #!/usr/bin/env bash
    set -euo pipefail
    
    LOG_FILE=$(find test_results -name "test_logs.log" -exec grep -l "{{TEST_ID}}" {} \; | head -1)
    
    if [ -z "$LOG_FILE" ]; then
        echo "❌ No logs found for test ID: {{TEST_ID}}"
        exit 1
    fi
    
    echo "🚨 Errors for test ID: {{TEST_ID}}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Show all errors from this test run (not just lines containing test ID)
    grep -E "(E/godot|SCRIPT ERROR|ERROR:|FAILED|DEBUG_TEST_FAILURE)" "$LOG_FILE" | \
    sed 's/^[0-9-]* [0-9:]* [EI]\/godot *([0-9]*): //' | \
    grep -v "BUFFER\|font_size\|=== BUFFER DUMP\|=== END BUFFER DUMP"

# Show errors only for a specific test ID
logs-android-errors TEST_ID:
    just _logs-errors-only "{{TEST_ID}}"

# Show performance breakdown for a specific test ID
_logs-performance TEST_ID:
    #!/usr/bin/env bash
    set -euo pipefail
    
    LOG_FILE=$(find test_results -name "test_logs.log" -exec grep -l "{{TEST_ID}}" {} \; | head -1)
    
    if [ -z "$LOG_FILE" ]; then
        echo "❌ No logs found for test ID: {{TEST_ID}}"
        exit 1
    fi
    
    echo "⏱️  Performance Analysis for: {{TEST_ID}}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Extract JSON data from logs and parse with jq
    grep "{{TEST_ID}}" "$LOG_FILE" | \
    grep "DEBUG_TEST_SUCCESS.*duration_ms" | \
    sed 's/^.*DEBUG_TEST_SUCCESS //' | \
    jq -r 'select(.duration_ms != null) | "[\(.action)]: \(.duration_ms)ms" + (if .duration_ms > 1000 then " ⚠️ SLOW" elif .duration_ms > 500 then " 🐌 SLOW-ISH" else " ✅ GOOD" end)' 2>/dev/null | \
    sort -t: -k2 -n || echo "No performance data found for test ID: {{TEST_ID}}"

# Show performance breakdown for a specific test ID
logs-android-performance TEST_ID:
    just _logs-performance "{{TEST_ID}}"

# Clean up old test logs (keeps most recent 10, removes the rest)
_logs-cleanup KEEP="10":
    #!/usr/bin/env bash
    set -euo pipefail
    
    KEEP_COUNT={{KEEP}}
    echo "🧹 Cleaning up old test logs (keeping most recent $KEEP_COUNT)..."
    
    # Count current logs
    TOTAL_COUNT=$(find test_results -name 'smart_*' -type d | wc -l | tr -d ' ')
    
    if [ "$TOTAL_COUNT" -le "$KEEP_COUNT" ]; then
        echo "✅ Only $TOTAL_COUNT test directories found, nothing to clean"
        exit 0
    fi
    
    TO_DELETE=$((TOTAL_COUNT - KEEP_COUNT))
    
    echo "📊 Found $TOTAL_COUNT test directories"
    echo "🗑️  Will delete $TO_DELETE oldest directories (keeping newest $KEEP_COUNT)"
    echo ""
    
    # Show what will be deleted (oldest directories)
    echo "🗂️  Directories to be deleted:"
    find test_results -name 'smart_*' -type d | sort | head -n "$TO_DELETE" | sed 's/^/  /'
    echo ""
    
    read -p "❓ Proceed with deletion? (y/N): " confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        # Delete oldest directories
        find test_results -name 'smart_*' -type d | sort | head -n "$TO_DELETE" | xargs rm -rf
        
        REMAINING=$(find test_results -name 'smart_*' -type d | wc -l | tr -d ' ')
        echo "✅ Cleanup complete! $REMAINING test directories remaining"
    else
        echo "❌ Cleanup cancelled"
    fi

# Clean up old test logs
logs-android-cleanup KEEP="10":
    just _logs-cleanup "{{KEEP}}"

# Clean up temporary config files (wildcard configs and single action configs)
cleanup-temp-configs-verbose:
    just cleanup-temp-configs "true"

# Force cleanup without confirmation (use carefully!)
_logs-cleanup-force KEEP="10":
    #!/usr/bin/env bash
    set -euo pipefail
    
    KEEP_COUNT={{KEEP}}
    TOTAL_COUNT=$(find test_results -name 'smart_*' -type d | wc -l | tr -d ' ')
    
    if [ "$TOTAL_COUNT" -le "$KEEP_COUNT" ]; then
        echo "✅ Only $TOTAL_COUNT test directories found, nothing to clean"
        exit 0
    fi
    
    TO_DELETE=$((TOTAL_COUNT - KEEP_COUNT))
    
    echo "🧹 Force cleaning $TO_DELETE old test directories..."
    find test_results -name 'smart_*' -type d | sort | head -n "$TO_DELETE" | xargs rm -rf
    
    REMAINING=$(find test_results -name 'smart_*' -type d | wc -l | tr -d ' ')
    echo "✅ Cleanup complete! $REMAINING test directories remaining"

# Build iOS executable with optimized settings  
build-ios-executable:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🍎 Building iOS executable..."
    
    cd godot
    
    echo "============================="
    echo "BUILDING IPHONE RELEASE ARM64"
    echo "============================="
    scons p=ios tools=no target=template_release arch=arm64 --jobs={{jobs}} \
        module_bmp_enabled=no module_bullet_enabled=no module_csg_enabled=no \
        module_dds_enabled=no module_enet_enabled=no module_etc_enabled=no \
        module_gdnative_enabled=no module_gridmap_enabled=no module_hdr_enabled=no \
        module_mbedtls_enabled=yes module_mobile_vr_enabled=no module_opus_enabled=no \
        module_pvr_enabled=no module_recast_enabled=no module_regex_enabled=no \
        module_squish_enabled=no module_tga_enabled=no module_thekla_unwrap_enabled=no \
        module_theora_enabled=no module_tinyexr_enabled=no module_vorbis_enabled=no \
        module_webm_enabled=no module_websocket_enabled=no disable_advanced_gui=no \
        disable_3d=yes optimize=size use_lto=yes
    
    echo "============================="
    echo "BUILDING IPHONE DEBUG ARM64"
    echo "============================="
    scons p=ios tools=no target=template_debug arch=arm64 --jobs={{jobs}}
    
    cd ..
    echo "✅ iOS executable build complete"

# Monitor Android debug logs in real-time with activity-based timeout
# Platform log monitoring - Monitor live system/platform logs in real-time
platform-logs-monitor DURATION="30":
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📱 Monitoring live platform logs for {{DURATION}} seconds..."
    echo "🔄 Timeout resets after each activity"
    echo "Press Ctrl+C to stop early"
    echo ""
    
    # Create timestamped log file
    LOG_FILE="platform_monitor_{{timestamp}}.log"
    
    # Clear old logs for fresh monitoring
    echo "🧹 Clearing old platform logs for fresh monitoring..."
    
    # Auto-detect platform and monitor accordingly
    if command -v adb >/dev/null 2>&1 && adb devices | grep -q device; then
        echo "📱 Monitoring Android platform logs..."
        adb -s {{ANDROID_DEVICE_ID}} logcat -c
        # Use activity-based timeout monitoring
        completion_status=$(just _monitor-with-activity-timeout "" "$LOG_FILE" "{{DURATION}}" "(debug|startup|DebugStartup|INFO)")
    else
        echo "📱 No Android device found for platform monitoring"
        echo "💡 Connect Android device or implement iOS monitoring"
        exit 1
    fi
    
    # Apply filtering and display results
    if [ -f "$LOG_FILE" ]; then
        echo "📊 Platform log monitoring complete"
        echo "📁 Logs saved to: $LOG_FILE"
    else
        echo "⚠️ No platform logs captured"
    fi

monitor-debug-logs DURATION="30":
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📱 Monitoring debug logs for {{DURATION}} seconds..."
    echo "🔄 Timeout resets after each debug activity"
    echo "Press Ctrl+C to stop early"
    echo ""
    
    # Create timestamped log file
    LOG_FILE="debug_monitor_{{timestamp}}.log"
    
    # Clear old logs for fresh monitoring
    echo "🧹 Clearing old logs for fresh monitoring..."
    adb -s {{ANDROID_DEVICE_ID}} logcat -c
    
    # Use activity-based timeout monitoring with debug-specific pattern
    completion_status=$(just _monitor-with-activity-timeout "" "$LOG_FILE" "{{DURATION}}" "(debug|startup|DebugStartup|INFO)")
    
    # Apply filtering and display results
    if [ -f "$LOG_FILE" ]; then
        echo ""
        echo "📊 Filtering and displaying debug logs..."
        
        # Filter and display the log with the same pattern
        grep -E "(debug|startup|DebugStartup|INFO)" "$LOG_FILE" || true
        
        echo ""
        echo "💾 Full log saved: $LOG_FILE"
    else
        echo "❌ No log file generated"
    fi
    
    echo ""
    echo "✅ Monitoring complete"

# Show current debug configuration status
check-android-debug-status:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "=== Android Debug Configuration Status ==="
    echo "Device: {{ANDROID_DEVICE_ID}}"
    echo ""
    
    if ! adb -s {{ANDROID_DEVICE_ID}} shell echo "Connected" >/dev/null 2>&1; then
        echo "❌ Device not connected"
        exit 1
    fi
    
    # Check embedded config
    echo "📄 Embedded config (res://debug_startup_actions.json):"
    if [ -f "project/debug_startup_actions.json" ]; then
        cat project/debug_startup_actions.json | jq .
    else
        echo "  (no embedded config found)"
    fi
    echo ""
    
    # Check external config
    ANDROID_PATH="/sdcard/Android/data/{{ANDROID_PACKAGE_NAME}}/files"
    REMOTE_CONFIG="$ANDROID_PATH/debug_startup_actions.json"
    
    echo "📱 External config (user://debug_startup_actions.json):"
    if adb -s {{ANDROID_DEVICE_ID}} shell "test -f $REMOTE_CONFIG" 2>/dev/null; then
        echo "✅ External config found (takes priority):"
        adb -s {{ANDROID_DEVICE_ID}} shell "cat $REMOTE_CONFIG" | jq . || adb -s {{ANDROID_DEVICE_ID}} shell "cat $REMOTE_CONFIG"
    else
        echo "  (no external config - using embedded config)"
    fi
    echo ""
    
    echo "💡 Priority: External config overrides embedded config"
    echo "🔧 Commands:"
    echo "  just restart-with-config <name>     # Quick external config test"
    echo "  just config-clear                   # Remove external, use embedded"
    echo "  just config-set <name>        # Update embedded config"

# Android-specific help and workflow guide
# Detailed help for run commands
help-run:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🏃 Run Commands Guide"
    echo "===================="
    echo ""
    echo "The 'just run-*' commands provide direct, discoverable ways to run your"
    echo "project on different platforms. No need to remember target parameters!"
    echo ""
    echo "📱 LEVEL 1: Launch Only (1-2 seconds)"
    echo "  just run-desktop             # Launch in Godot editor"
    echo "  just run-desktop-debug       # Launch with debug output"
    echo "  just launch-ios-iphone       # Launch existing iOS app"
    echo "  just launch-ios-iphone-debug # Launch iOS app (debug)"
    echo "  just launch-ios-ipad         # Launch existing iOS app"
    echo "  just launch-ios-ipad-debug   # Launch iOS app (debug)"
    echo "  just launch-android          # Launch existing Android app"
    echo "  just run-android-debug       # Launch existing Android app (debug)"
    echo ""
    echo "🔄 LEVEL 2: Quick Updates"
    echo "  iOS (5-10 seconds):"
    echo "    just hotreload-ios-iphone # Export game data → update → launch"
    echo "    just hotreload-ios-ipad   # Export game data → update → launch"
    echo "  Android (30 sec - 2 min):"
    echo "    just install-apk-android   # Install existing APK → launch"
    echo "    just fastbuild-android     # Gradle build → install → launch"
    echo ""
    echo "🔨 LEVEL 3: Full Rebuild (2-5 minutes)"
    echo "  just build-install-ios       # Complete iOS project rebuild"
    echo "  just export-apk-android      # Export Android APK files"
    echo "  just export-aab-android      # Export Android AAB files"
    echo ""
    echo "📋 WHAT EACH LEVEL DOES"
    echo "  LEVEL 1: App already built/installed → just launch"
    echo "  LEVEL 2: App already built → export new game data → replace → launch"  
    echo "  LEVEL 3: Start from scratch → build everything → install → launch"
    echo ""
    echo "📋 REQUIREMENTS"
    echo "  LEVEL 1: Existing app installation required"
    echo "  LEVEL 2: Existing iOS app build required (use LEVEL 3 first)"
    echo "  LEVEL 3: No requirements (builds from scratch)"
    echo ""
    echo "💡 TYPICAL WORKFLOW"
    echo "  Day 1: just build-install-ios        # Full setup (once)"
    echo "  Daily: just hotreload-ios-iphone    # Fast iteration"
    echo ""
    echo "⚙️  DEVICE CONFIGURATION"
    echo "  Configure device IDs via environment variables:"
    echo "  • IOS_IPHONE_DEVICE_ID={{IOS_IPHONE_DEVICE_ID}}"
    echo "  • IOS_IPAD_DEVICE_ID={{IOS_IPAD_DEVICE_ID}}"
    echo "  • ANDROID_DEVICE_ID={{ANDROID_DEVICE_ID}}"
    echo "  • IOS_BUNDLE_IDENTIFIER={{IOS_BUNDLE_IDENTIFIER}}"
    echo ""
    echo "🔧 LEGACY SUPPORT"
    echo "  The old 'just run <target>' command still works but shows a"
    echo "  deprecation warning. Use explicit 'just run-<platform>' instead."
    echo ""
    echo "💡 Run 'just --list | grep run-' to see all run commands"

help-android:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🤖 Android Development Workflow Guide"
    echo "====================================="
    echo ""
    echo "📋 OVERVIEW:"
    echo "Android development is FULLY AUTOMATED - one command handles everything!"
    echo "Deploys directly to Android phones/tablets via ADB"
    echo "Device: {{ANDROID_DEVICE_ID}}"
    echo "Package: {{ANDROID_PACKAGE_NAME}}"
    echo ""
    echo "⚡ QUICK START:"
    echo "  just fastbuild-android               # Complete build → install → run workflow (30-60 sec)"
    echo "  just iterate-android gameplay-testing # With debug config"
    echo "  just quick-test system-testing       # Quick config test with monitoring"
    echo ""
    echo "🔧 STEP-BY-STEP COMMANDS:"
    echo "  1️⃣  just export-apk-android          # Export complete APK file (2-3 min)"
    echo "  2️⃣  just install-apk-android         # Install APK to device"
    echo "  3️⃣  just launch-android              # Launch app on device via adb"
    echo "  4️⃣  just restart-android-app         # Quick restart (for config changes)"
    echo ""
    echo "🐛 DEBUG CONFIGURATION WORKFLOW:"
    echo "  just config-list                     # See available debug configs"
    echo "  just restart-with-config system-testing # Push config + restart (rapid iteration)"
    echo "  just push-debug-config gameplay-testing # Push specific config to device"
    echo "  just test-android-debug-startup 30   # Monitor debug startup and logs"
    echo "  just check-android-debug-status      # Check device + app status"
    echo "  just quick-test performance-testing  # Test debug startup system"
    echo ""
    echo "📊 LOG ANALYSIS & DEBUGGING:"
    echo "  just logs-list-recent                # Show recent test runs with status"
    echo "  just logs-results-simple TEST_ID LOG_DIR # Quick filtered results"
    echo "  just logs-performance TEST_ID         # Performance breakdown with timing"
    echo "  just logs-errors-only TEST_ID         # Show only errors for debugging"
    echo "  just logs-cleanup-force 5             # Clean old logs (keep 5 most recent)"
    echo ""
    echo "📱 DEVELOPMENT LOOP (FASTEST):"
    echo "  # Initial setup:"
    echo "  just fastbuild-android               # Full workflow (30-60 sec)"
    echo ""
    echo "  # Rapid iteration:"
    echo "  just restart-with-config testing     # Quick config changes"
    echo "  just restart-android-app             # Just restart app"
    echo "  just hotconfig-android <config>      # Hot push config (2 sec!)"
    echo ""
    echo "  # Analyze results:"
    echo "  just logs-list-recent                # See recent test results"
    echo "  just logs-results-simple TEST_ID LOG_DIR # Quick results view"
    echo ""
    echo "🧪 TESTING BEHAVIOR:"
    echo "  • test-android automatically RESTARTS the app to ensure config is loaded"
    echo "  • This guarantees reliable test results but takes ~5 seconds"
    echo "  • For rapid iteration: test-android <config> 30 true (skips restart)"
    echo "  • Use test-monitor-android <config> to watch debug startup logs"
    echo ""
    echo "🚀 PRODUCTION BUILDS:"
    echo "  just export-apk-android              # Production APK for testing"
    echo "  just export-aab-android              # App Bundle for Play Store"
    echo "  just deploy-android                  # Deploy to Play Store"
    echo ""
    echo "🔍 TROUBLESHOOTING:"
    echo "  • Device not found: Check 'adb devices' and ANDROID_DEVICE_ID variable"
    echo "  • Install fails: Run 'adb -s {{ANDROID_DEVICE_ID}} uninstall {{ANDROID_PACKAGE_NAME}}'"
    echo "  • App won't start: Check 'just test-android-debug-startup' for errors"
    echo "  • Gradle issues: Run 'just clean-android-templates' then retry"
    echo "  • Log analysis: Use 'just logs-errors-only TEST_ID' to focus on specific issues"
    echo ""
    echo "💡 For action name shortcuts and advanced debug workflows: just help-debug"
    echo ""

# iOS-specific help and workflow guide  
help-ios:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📱 iOS Development Workflow Guide"
    echo "=================================="
    echo "Devices: iPhone ({{IOS_IPHONE_DEVICE_ID}}) | iPad ({{IOS_IPAD_DEVICE_ID}})"
    echo "Bundle: {{IOS_BUNDLE_IDENTIFIER}}"
    echo ""
    echo "🔍 OVERVIEW:"
    echo "iOS development combines AUTOMATION + MANUAL steps due to Apple's security model"
    echo "Automated: Building, exporting, hot reloading | Manual: Some launching, device deployment"
    echo ""
    echo "⚡ QUICK START:"
    echo "  just build-install-ios              # Complete build + export (2-5 min)"
    echo "  just launch-ios-iphone              # Launch on iPhone (requires built app)"
    echo "  just hotreload-ios-iphone           # Hot reload content changes (5-10 sec)"
    echo ""
    echo "📋 STEP-BY-STEP SETUP:"
    echo "  1. just templates-ios               # Build iOS export templates (20 min, once)"
    echo "  2. just build-install-ios           # Export + build project (2-5 min)"
    echo "  3. just launch-ios-iphone           # Launch on device"
    echo ""
    echo "🔄 DEVELOPMENT WORKFLOWS:"
    echo ""
    echo "  🏗️  COMPLETE WORKFLOW (Code + Content Changes):"
    echo "    just build-install-ios            # Full rebuild + export (2-5 min)"
    echo "    just launch-ios-iphone            # Launch on iPhone"
    echo "    just launch-ios-ipad              # Launch on iPad"
    echo ""
    echo "  ⚡ HOT RELOAD WORKFLOW (Content Only - FASTEST):"
    echo "    just hotreload-ios-iphone         # Update content + launch (5-10 sec)"
    echo "    just hotreload-ios-ipad           # Update content + launch (5-10 sec)"
    echo ""
    echo "  🔨 REBUILD WORKFLOW (Code Changes):"
    echo "    just ios-export-pck               # Export game data only"
    echo "    just ios-build                    # Rebuild iOS project"
    echo "    just ios-update-pck               # Update app with new data"
    echo ""
    echo "🚀 LAUNCH COMMANDS:"
    echo ""
    echo "  📱 DEVICE LAUNCH (Automated):"
    echo "    just launch-ios-iphone            # Launch on iPhone"
    echo "    just launch-ios-iphone-debug      # Launch on iPhone (debug mode)"
    echo "    just launch-ios-ipad              # Launch on iPad"
    echo "    just launch-ios-ipad-debug        # Launch on iPad (debug mode)"
    echo ""
    echo "  ⚡ HOT RELOAD (Content Updates):"
    echo "    just hotreload-ios-iphone         # iPhone hot reload (5-10 sec)"
    echo "    just hotreload-ios-ipad           # iPad hot reload (5-10 sec)"
    echo ""
    echo "  💡 MANUAL LAUNCH OPTIONS:"
    echo "    just ios-launch-help              # Get manual launch instructions"
    echo "    just ios-restart-help             # Get manual restart instructions"
    echo ""
    echo "🏗️  BUILD COMMANDS:"
    echo ""
    echo "  📦 EXPORT & BUILD:"
    echo "    just build-install-ios            # Complete build + export (2-5 min)"
    echo "    just quick-build-ios              # Quick export (skip templates, 2-3 min)"
    echo "    just ios-build                    # Build iOS project only"
    echo "    just ios-export-pck               # Export game data only"
    echo ""
    echo "  🔧 TEMPLATE MANAGEMENT:"
    echo "    just templates-ios                # Build iOS export templates (20 min)"
    echo "    just ios-build-template           # Build iOS template only"
    echo "    just package-ios-template         # Package iOS template"
    echo ""
    echo "  📲 DATA UPDATES:"
    echo "    just ios-update-pck               # Update built app with new game data"
    echo ""
    echo "🧪 iOS ADVANTAGES vs Android:"
    echo "  ✅ HOT RELOAD: Content updates without full reinstall (5-10 sec vs 30-60 sec)"
    echo "  ✅ DEVICE TARGETING: Automated iPhone/iPad device selection"
    echo "  ✅ DEBUG MODES: Built-in debug launch options"
    echo "  ⚠️  MANUAL STEPS: Some operations require Xcode interaction"
    echo ""
    echo "🏭 PRODUCTION BUILDS:"
    echo "  just ios-build                      # Build for App Store"
    echo "  just deploy-ios                     # Deploy to App Store"
    echo "  # Manual: Xcode → Archive → Upload to App Store Connect"
    echo ""
    echo "🔍 TROUBLESHOOTING:"
    echo "  • Device not found: Check 'xcrun devicectl list devices' and device IDs"
    echo "  • Build fails: Check Xcode project settings and certificates"
    echo "  • Hot reload fails: Run 'just build-install-ios' for fresh build"
    echo "  • App won't launch: Check device connection and app installation"
    echo "  • Missing templates: Run 'just templates-ios' to rebuild"
    echo ""
    echo "💡 DEVELOPMENT TIPS:"
    echo "  • Use hot reload for rapid content iteration (5-10 sec)"
    echo "  • iPhone vs iPad: Commands automatically target correct device"
    echo "  • Debug modes available for both devices (-debug variants)"
    echo "  • Manual launch options available when automation fails"


# Debug configuration and workflow help
help-debug:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🐛 Debug Configuration & Workflow Guide"
    echo "======================================="
    echo ""
    echo "📋 OVERVIEW:"
    echo "Debug configurations allow you to test different game settings without rebuilding"
    echo "Perfect for testing gameplay mechanics, performance settings, and feature flags"
    echo ""
    echo "⚡ QUICK START:"
    echo "  just config-setup                    # Create sample debug configurations"
    echo "  just config-list                     # See available configs"
    echo "  just test-android minimal-testing        # Test with automatic restart"
    echo "  just test-android system-testing          # Quick test with monitoring"
    echo ""
    echo "🔧 CONFIGURATION MANAGEMENT:"
    echo "  just config-setup                    # Create sample debug configurations"
    echo "  just config-list                     # List all available configs"
    echo "  just config-set performance-testing  # Set embedded debug config"
    echo "  just config-push-android gameplay-testing # Push config to device (quick)"
    echo "  just config-clear-android            # Clear external config, use embedded"
    echo ""
    echo "📱 ANDROID LOGGER CONFIGURATION (Runtime Changes):"
    echo "  # Real-time logger control without rebuilding - changes apply after app restart"
    echo "  just config-android-tags \"firebase,battle\" \"cache\"    # Focus on specific tags"
    echo "  just config-android-level DEBUG                         # Set log verbosity" 
    echo "  just config-android-reset                               # Reset to project defaults"
    echo "  just restart-android-app                                # Apply configuration changes"
    echo ""
    echo "  # Logger workflow example:"
    echo "  just config-android-tags \"firebase,error\" \"cache,debug\"  # Focus Firebase errors"
    echo "  just restart-android-app                                    # Apply settings"
    echo "  just test-android '*.firebase.*'                            # Test with focused logs"
    echo "  just logs-errors-tagged TEST_ID firebase                    # Analyze Firebase errors only"
    echo ""
    echo "💡 ACTION & WILDCARD SHORTCUTS (No JSON files needed!):"
    echo "  # Single actions"
    echo "  just config-restart-android 'Show Registry Stats'    # Use any action directly"
    echo "  just test-android 'Backend Performance Test'        # Test single action"
    echo "  just config-set 'Print Debug Info'                   # Set single action config"
    echo ""
    echo "  # Wildcard patterns (auto-discover matching actions)"
    echo "  just config-restart-android 'cpp.*'                  # All C++ layer tests"
    echo "  just test-android '*.firebase.set_value'             # All set_value operations"
    echo "  just test-android '*.*.error_handling'               # All error handling tests"
    echo "  just config-restart-android 'system.debug.*'         # All system debug actions"
    echo ""
    echo "🧪 TESTING BEHAVIOR:"
    echo "  # Individual testing"
    echo "  just test-android <config>           # RELIABLE: Restarts app, tests actual config"
    echo "  just test-android <config> 30 true  # FAST: No restart, tests current state"
    echo "  just test-monitor-android [duration] # Pure monitoring only (no restarts)"
    echo "  just test-android <config>           # Push config + restart + monitor"
    echo ""
    echo "  # Essential test workflows (streamlined & focused)"
    echo "  just test-smoke-android                        # Quick smoke test (30 seconds)"
    echo "  just test-development-android                  # Daily development workflow"
    echo "  just test-production-android                   # Comprehensive release validation"
    echo "  just test-all-android                          # Complete test suite"
    echo ""
    echo "  # Unified testing: intelligent auto-detection"
    echo "  just test-android 'firebase.*'                 # All Firebase tests (auto-detects wildcard!)"
    echo "  just test-android '*.*.performance'            # All performance tests (auto-detects wildcard!)"
    echo "  just test-android wildcard-discovery           # Custom test list (auto-detects list!)"
    echo "  just test-android-enhanced 'cpp.*'             # Enhanced analysis with error categorization"
    echo "  just test-android-trace 'cpp.*'                # Debug mode: shows validation/config steps"
    echo ""
    echo "🧪 CHECKSUM SNAPSHOT TESTING:"
    echo "  # Automated state validation using MD5 checksums for regression testing"
    echo "  just test-android-target lineup-checksum-test  # Run checksum test (auto-creates baseline)"
    echo "  just test-android-update [config]              # Force update baseline (fzf if no config)"
    echo "  just test-android-reset [config]               # Remove baseline (fzf if no config)"
    echo "  just test-android-list-checksum                # List all checksum-enabled configs"
    echo ""
    echo "  # First run: Automatically saves baseline checksum to JSON config"
    echo "  # Subsequent runs: Validates current state against saved baseline"
    echo "  # Logs: CHECKSUM_VALID (pass) or CHECKSUM_MISMATCH (fail)"
    echo "  # Naming: *-checksum-test.json or *-snapshot-test.json for checksum configs"
    echo '  # Description: Include "checksum" keyword for fzf searchability'
    echo "  # fzf: Shows only checksum configs with baseline status indicators"
    echo ""
    echo "🏗️ WILDCARD PATTERN REFERENCE:"
    echo "  # ✅ ALL 51 debug actions now use hierarchical naming: layer.domain.operation"
    echo "  # 🚀 Zero config maintenance - wildcards auto-discover new actions!"
    echo ""
    echo "  📱 LAYERS (first part) - Complete coverage:"
    echo "    cpp.*              # C++ Firebase SDK (8 actions)"
    echo "    backend.*          # Backend Firebase (7 actions)"
    echo "    rtdb.*             # RTDB GDScript API (19 actions)"
    echo "    system.*           # System utilities (5 actions)"
    echo "    game.*             # Game logic (12 actions)"
    echo ""
    echo "  🎯 DOMAINS (middle part):"
    echo "    *.firebase.*       # Firebase operations (database, auth, analytics)"
    echo "    *.database.*       # Database operations (set, get, update, remove)"
    echo "    *.paths.*          # Path operations (nested structures, hierarchies)"
    echo "    *.children.*       # Children operations (list, push, manage)"
    echo "    *.listeners.*      # Real-time listeners (single_value, child events)"
    echo "    *.advanced.*       # Advanced operations (transactions, batching)"
    echo "    *.testing.*        # Testing utilities (validation, error handling)"
    echo "    *.debug.*          # Debug utilities (logging, stats, info)"
    echo "    *.match.*          # Game match functionality (levels, scoring)"
    echo "    *.network.*        # Network operations (connectivity, sync)"
    echo "    *.storage.*        # Data storage operations (save, load, cache)"
    echo ""
    echo "  ⚙️ OPERATIONS (last part):"
    echo "    *.*.set_value      # Data writing operations"
    echo "    *.*.get_value      # Data reading operations"
    echo "    *.*.error_handling # Error handling and recovery"
    echo "    *.*.performance    # Performance testing and optimization"
    echo "    *.*.concurrent_ops # Concurrency and threading tests"
    echo "    *.*.timeout_behavior # Timeout and reliability tests"
    echo ""
    echo "  🔥 POWERFUL COMBINATIONS:"
    echo "    # Layer-specific testing:"
    echo "    'cpp.firebase.*'   # All C++ Firebase operations (8 actions)"
    echo "    'rtdb.database.*'  # All RTDB database operations (4 actions)"
    echo "    'rtdb.listeners.*' # All RTDB real-time listeners (5 actions)"
    echo "    'system.debug.*'   # All system debug utilities (2 actions)"
    echo "    'game.match.*'     # All game match operations (6 actions)"
    echo ""
    echo "    # Cross-layer testing:"
    echo "    '*.*.set_value'    # All write operations across layers"
    echo "    '*.*.error_handling' # All error handling tests" 
    echo "    '*.firebase.*'     # All Firebase operations (cpp + backend)"
    echo "    '*.debug.*'        # All debug utilities (system + game)"
    echo ""
    echo "  💡 PRACTICAL EXAMPLES:"
    echo "    # Single action testing (precise):"
    echo "    just test-android 'system.debug.registry_stats'"
    echo "    just test-android 'game.match.reset_level'"
    echo "    just test-android 'rtdb.listeners.single_value'"
    echo ""
    echo "    # Feature-focused testing (grouped):"
    echo "    just test-android 'rtdb.database.*'           # All basic DB ops"
    echo "    just test-android 'game.match.*'              # All match mechanics"
    echo "    just test-android 'system.network.*'          # All network checks"
    echo ""
    echo "    # Cross-system validation (powerful):"
    echo "    just test-android '*.*.performance'           # Performance everywhere"
    echo "    just test-android '*.database.*'              # All database layers"
    echo "    just test-android '*.firebase.*'              # Full Firebase stack"
    echo ""
    echo "🏷️ TOKEN-EFFICIENT LOG DEBUGGING WITH TAGS:"
    echo ""
    echo "  🎯 UNIVERSAL TAG-FILTERED COMMANDS (90-98% token savings!):"
    echo "    just logs TEST_ID                       # Full logs"
    echo "    just logs TEST_ID debug test            # Only debug+test logs (92% reduction)"
    echo "    just logs TEST_ID firebase              # All Firebase operations (87% reduction)"
    echo "    just logs TEST_ID battle determinism    # Battle determinism only (95% reduction)"
    echo "    just logs-errors-tagged TEST_ID         # All errors (98% reduction)"
    echo "    just logs-errors-tagged TEST_ID firebase # Firebase errors only (99% reduction)"
    echo "    just logs-performance-tagged TEST_ID    # All performance data"
    echo "    just logs-lifecycle-tagged TEST_ID      # All lifecycle events"
    echo ""
    echo "  📋 SPECIFIC TAG COMMANDS:"
    echo "    just logs-tags TEST_ID debug test success     # Multiple tags (OR logic)"
    echo "    just logs-debug TEST_ID                        # Debug operations only"
    echo "    just logs-errors TEST_ID                       # Error logs only"
    echo "    just logs-lifecycle TEST_ID                    # App lifecycle events"
    echo ""
    echo "  🎯 COMMON TAG PATTERNS:"
    echo "    # Component-specific debugging:"
    echo "    just logs TEST_ID firebase rtdb        # Firebase + RTDB operations"
    echo "    just logs TEST_ID system startup       # System startup events"
    echo "    just logs TEST_ID game battle          # Game battle mechanics"
    echo ""
    echo "    # Error analysis:"
    echo "    just logs-errors-tagged TEST_ID cpp    # C++ layer errors only"
    echo "    just logs-errors-tagged TEST_ID battle # Battle system errors"
    echo ""
    echo "    # Performance tracking:"
    echo "    just logs-performance-tagged TEST_ID firebase  # Firebase performance"
    echo "    just logs-performance-tagged TEST_ID battle    # Battle performance"
    echo ""
    echo "  📊 TOKEN SAVINGS TABLE:"
    echo "    Full logs:                  400+ lines  = ~800 tokens"
    echo "    just logs TEST_ID battle:   ~50 lines   = ~100 tokens (87% reduction)"
    echo "    just logs TEST_ID debug:    ~30 lines   = ~60 tokens  (92% reduction)"
    echo "    logs-errors-tagged TEST_ID: 0-5 lines   = ~10 tokens  (98% reduction)"
    echo ""
    echo "📊 TRADITIONAL LOG ANALYSIS:"
    echo ""
    echo "  🔍 TEST RESULTS ANALYSIS:"
    echo "    just logs-list-recent               # List recent test runs with status"
    echo "    just logs-test-id TEST_ID           # Filter logs for specific test ID"
    echo "    just logs-results-only TEST_ID      # Show only SUCCESS/FAILURE results"
    echo "    just logs-results-simple TEST_ID LOG_DIR # Clean output when log dir known"
    echo "    just logs-quick TEST_ID LOG_DIR     # Quickest view - action names and status"
    echo ""
    echo "  ⚡ PERFORMANCE & ERROR ANALYSIS:"
    echo "    just logs-performance TEST_ID       # Performance breakdown with timing categories"
    echo "    just logs-errors-only TEST_ID       # Show only errors for debugging"
    echo ""
    echo "  🧹 LOG MANAGEMENT:"
    echo "    just logs-cleanup KEEP_COUNT        # Interactive cleanup (asks confirmation)"
    echo "    just logs-cleanup-force KEEP_COUNT  # Force cleanup without confirmation"
    echo "    just cleanup-temp-configs-verbose   # Clean up temporary config files"
    echo ""
    echo "🔄 DEBUG WORKFLOW PATTERNS:"
    echo ""
    echo "  🏷️ TOKEN-EFFICIENT DEBUGGING WORKFLOW (RECOMMENDED!):"
    echo "    just test-android 'system.*'             # Run system layer tests"
    echo "    just logs TEST_ID system debug           # Review system operations (95% token savings!)"
    echo "    just logs-errors-tagged TEST_ID          # Check for any errors (98% savings!)"
    echo "    just logs-performance-tagged TEST_ID system # Performance analysis"
    echo ""
    echo "  🎯 PROGRESSIVE DEBUGGING (ERROR → COMPONENT → PRECISION):"
    echo "    # 1. Quick error scan (fastest, 2-10 tokens)"
    echo "    just logs-errors-tagged TEST_ID          # Any errors? (99% token reduction)"
    echo "    # 2. Component focus (medium, 50-100 tokens)"
    echo "    just logs TEST_ID firebase               # Firebase operations (87% reduction)"
    echo "    # 3. Precision debugging (detailed, 200+ tokens)"
    echo "    just logs TEST_ID firebase rtdb success # Specific combination"
    echo ""
    echo "  🎯 RAPID CONFIG ITERATION:"
    echo "    just fastbuild-android                   # Initial setup"
    echo "    just config-restart-android testing      # Test config changes (fast)"
    echo "    just test-android performance            # Test different config"
    echo "    just logs TEST_ID debug test             # Quick token-efficient review"
    echo ""
    echo "  🧪 SYSTEMATIC TESTING WITH TAG-FILTERED ANALYSIS:"
    echo "    just config-list                         # See all available configs"
    echo "    just test-android gameplay-testing        # Reliable test with restart"
    echo "    just logs-list-recent                    # See recent test results"
    echo "    just logs-errors-tagged TEST_ID          # Check for errors first (token-efficient)"
    echo "    just logs-performance-tagged TEST_ID gameplay # Performance analysis (focused)"
    echo ""
    echo "  📊 PERFORMANCE ANALYSIS WITH TAG FILTERING:"
    echo "    just test-android performance-testing     # Launch with perf config"
    echo "    just logs-performance-tagged TEST_ID     # Token-efficient performance analysis"
    echo "    just config-restart-android baseline     # Compare with baseline"
    echo "    just logs-cleanup-force 5                # Keep only recent tests"
    echo ""
    echo "📱 CONFIGURATION TYPES:"
    echo "  • gameplay-testing: Gameplay mechanics and features"
    echo "  • performance-testing: Performance optimizations and profiling"
    echo "  • system-testing: System integration and device testing"
    echo "  • network-testing: Network and connectivity testing"
    echo "  • database-testing: Database and persistence testing"
    echo ""
    echo "🔍 MONITORING & DEBUGGING:"
    echo "  just test-android-debug-startup [duration] # Monitor device logs"
    echo "  just check-android-debug-status      # Check device & app status"
    echo "  just quick-test [config]             # Test debug startup system"
    echo "  just check log                       # Validate GDScript and log errors"
    echo ""
    echo "💡 BEST PRACTICES:"
    echo "  🏷️ TOKEN-EFFICIENT DEBUGGING (NEW!):"
    echo "  ✅ Always start with 'logs-errors-tagged TEST_ID' for fastest issue detection (98% savings)"
    echo "  ✅ Use 'logs TEST_ID component' for focused analysis (87-95% savings)"
    echo "  ✅ Combine tags for precision: 'logs TEST_ID firebase rtdb success'"
    echo "  ✅ Use progressive debugging: errors → component → precision"
    echo "  ✅ Test output includes copy-paste ready tag commands"
    echo ""
    echo "  🔧 CONFIGURATION & TESTING:"
    echo "  ✅ Use restart-with-config for rapid config iteration (fastest)"
    echo "  ✅ Use iterate-android with config for complete testing"
    echo "  ✅ Always run test-android-debug-startup to see immediate feedback"
    echo "  ✅ Use logs-list-recent to see recent test status at a glance"
    echo ""
    echo "  📊 LOG ANALYSIS:"
    echo "  ✅ Use tag-filtered commands for token efficiency (90-98% savings)"
    echo "  ✅ Use traditional commands only when full context needed"
    echo "  ✅ Use logs-cleanup-force to keep workspace clean"
    echo "  ✅ Use config-clear to return to baseline"
    echo "  ⚠️  External configs override embedded configs"
    echo "  ⚠️  Remember to config-clear when done testing"

# Production builds and deployment help
help-production:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🚀 Production Build & Deployment Guide"
    echo "======================================"
    echo ""
    echo "📋 OVERVIEW:"
    echo "Production builds create optimized, signed packages for app store distribution"
    echo "Different from debug builds: optimized, signed, no debug symbols"
    echo ""
    echo "⚡ QUICK START:"
    echo "  just android-export-prod apk         # Production APK for testing"
    echo "  just android-export-prod aab         # App Bundle for Play Store"
    echo "  just ios-build                       # iOS build (then Archive in Xcode)"
    echo ""
    echo "🤖 ANDROID PRODUCTION:"
    echo "  just android-export-prod apk         # Create production APK"
    echo "    • Optimized code and assets"
    echo "    • Signed with release keystore"
    echo "    • No debug symbols or logging"
    echo "    • Ready for sideloading/testing"
    echo ""
    echo "  just android-export-prod aab         # Create App Bundle (AAB)"
    echo "    • Google Play's preferred format"
    echo "    • Smaller download size"
    echo "    • Dynamic delivery support"
    echo "    • Required for Play Store"
    echo ""
    echo "🍎 iOS PRODUCTION:"
    echo "  just ios-build                       # Build iOS project (ios-build)"
    echo "  # Then manually in Xcode:"
    echo "  # 1. Product → Archive"
    echo "  # 2. Distribute App → App Store Connect"
    echo "  # 3. Upload to App Store"
    echo ""
    echo "📦 DEPLOYMENT WORKFLOWS:"
    echo ""
    echo "  🏪 PLAY STORE DEPLOYMENT:"
    echo "    just android-export-prod aab       # Create App Bundle"
    echo "    # Then upload to Play Console:"
    echo "    # 1. Open Google Play Console"
    echo "    # 2. Upload AAB to Release track"
    echo "    # 3. Fill release notes and submit"
    echo ""
    echo "  🍎 APP STORE DEPLOYMENT:"
    echo "    just ios-build                     # Build iOS project (ios-build)"
    echo "    # Then in Xcode:"
    echo "    # 1. Archive → Distribute App"
    echo "    # 2. Upload to App Store Connect"
    echo "    # 3. Submit for Review"
    echo ""
    echo "  🧪 TESTING DISTRIBUTION:"
    echo "    just android-export-prod apk       # Create APK for testing"
    echo "    # Distribute APK via:"
    echo "    # • Email/messaging"
    echo "    # • Firebase App Distribution"
    echo "    # • Google Play Internal Testing"
    echo ""
    echo "🔍 TROUBLESHOOTING:"
    echo "  • Build fails: Check signing certificates and keys"
    echo "  • Upload rejected: Verify app bundle format and signing"
    echo "  • iOS Archive missing: Ensure proper provisioning profiles"
    echo "  • Play Store rejection: Check target SDK and permissions"
    echo ""
    echo "💡 PRODUCTION CHECKLIST:"
    echo "  ✅ Version number incremented"
    echo "  ✅ Release notes prepared"
    echo "  ✅ All features tested"
    echo "  ✅ Performance profiled"
    echo "  ✅ Proper app icons and metadata"
    echo "  ✅ Store listing updated"

# Template building and setup help
help-templates:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📋 Template Building & Setup Guide"
    echo "=================================="
    echo ""
    echo "📋 OVERVIEW:"
    echo "Export templates are platform-specific builds of Godot needed for exporting projects"
    echo "Required once per Godot version, then reused for all project exports"
    echo ""
    echo "⚡ QUICK START:"
    echo "  just templates-all                   # Build all platform templates"
    echo "  just setup-android                   # Setup Android environment"
    echo "  just templates-android               # Build just Android templates"
    echo ""
    echo "🔧 TEMPLATE BUILDING:"
    echo "  just templates-all                   # Build all export templates"
    echo "    • iOS templates"
    echo "    • Android templates"
    echo "    • macOS templates (if on macOS)"
    echo ""
    echo "  just templates-android [minimal]     # Build Android templates"
    echo "    • minimal=yes: Faster build, basic features"
    echo "    • minimal=no: Full build, all features (default)"
    echo ""
    echo "  just templates-ios                   # Build iOS templates"
    echo "    • Requires macOS"
    echo "    • Requires Xcode and iOS SDK"
    echo ""
    echo "  just templates-macos                 # Build macOS templates"
    echo "    • Requires macOS"
    echo "    • For macOS desktop exports"
    echo ""
    echo "🛠️ ENVIRONMENT SETUP:"
    echo "  just setup-android                   # Setup Android build environment"
    echo "    • Downloads Android SDK/NDK"
    echo "    • Configures build tools"
    echo "    • Sets up required dependencies"
    echo ""
    echo "  just clean-android                   # Clean Android template cache"
    echo "    • Removes cached build files"
    echo "    • Forces clean rebuild"
    echo "    • Use when builds fail"
    echo ""
    echo "⏱️ BUILD TIME EXPECTATIONS:"
    echo "  • templates-android (minimal): ~10-15 minutes"
    echo "  • templates-android (full): ~20-30 minutes"
    echo "  • templates-ios: ~15-25 minutes"
    echo "  • templates-all: ~30-45 minutes"
    echo ""
    echo "🔄 WHEN TO REBUILD TEMPLATES:"
    echo "  • After updating Godot engine"
    echo "  • When export fails with template errors"
    echo "  • After changing engine compilation flags"
    echo "  • When switching between Godot versions"
    echo ""
    echo "📱 PLATFORM REQUIREMENTS:"
    echo ""
    echo "  🤖 ANDROID:"
    echo "    ✅ Any platform (Windows/Mac/Linux)"
    echo "    ✅ Android SDK/NDK (auto-installed)"
    echo "    ✅ Java 11+ (auto-detected)"
    echo ""
    echo "  🍎 iOS:"
    echo "    ⚠️  Requires macOS"
    echo "    ⚠️  Requires Xcode 12+"
    echo "    ⚠️  Requires iOS SDK"
    echo ""
    echo "  🖥️ macOS:"
    echo "    ⚠️  Requires macOS"
    echo "    ⚠️  Requires Xcode Command Line Tools"
    echo ""
    echo "🔍 TROUBLESHOOTING:"
    echo "  • Template build fails: Run just clean-android, then retry"
    echo "  • Missing SDK: Run just setup-android"
    echo "  • iOS build fails: Verify Xcode installation and iOS SDK"
    echo "  • Permission errors: Check file permissions in export templates folder"
    echo ""
    echo "💾 TEMPLATE LOCATIONS:"
    echo "  • Android: ~/.local/share/godot/export_templates/"
    echo "  • iOS: ~/.local/share/godot/export_templates/"
    echo "  • Templates are version-specific (4.4.dev, 4.3.stable, etc.)"

# General commands and utilities help
help-general:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔧 General Commands & Utilities Guide"
    echo "====================================="
    echo ""
    echo "📋 OVERVIEW:"
    echo "General-purpose commands for editor management, validation, and utilities"
    echo "Platform-neutral commands that support all development workflows"
    echo ""
    echo "⚡ DAILY USE COMMANDS:"
    echo "  just open                            # Open Godot editor"
    echo "  just check [output]                  # Validate GDScript code"
    echo "  just build-editor                    # Build custom Godot editor"
    echo "  just show <command>                  # Show command implementation"
    echo ""
    echo "🎮 GODOT EDITOR:"
    echo "  just open                            # Open Godot editor"
    echo "    • Opens project in Godot editor"
    echo "    • Uses built editor (if available)"
    echo "    • Falls back to system Godot"
    echo ""
    echo "  just build-editor                    # Build custom Godot editor"
    echo "    • Compiles latest Godot from source"
    echo "    • Includes custom modifications"
    echo "    • Takes 20-40 minutes"
    echo "    • Required for latest features"
    echo ""
    echo "✅ CODE VALIDATION:"
    echo "  just check                           # Validate GDScript (console output)"
    echo "  just check log                       # Validate GDScript (save to log file)"
    echo "    • Checks all GDScript files for errors"
    echo "    • Reports syntax and semantic errors"
    echo "    • No false positives from editor quirks"
    echo "    • Essential before commits/releases"
    echo ""
    echo "🔄 HEADLESS OPERATIONS:"
    echo "  just run-headless [args]             # Run Godot headless"
    echo "    • For automated testing"
    echo "    • Server-side game logic"
    echo "    • Batch processing"
    echo ""
    echo "  just prep-build                      # Update export presets"
    echo "    • Updates export presets"
    echo "    • Refreshes project settings"
    echo "    • Run before major exports"
    echo ""
    echo "📖 HELP & DOCUMENTATION:"
    echo "  just help                            # Main help system"
    echo "  just help-android                    # Android-specific help"
    echo "  just help-ios                        # iOS-specific help"
    echo "  just help-debug                      # Debug configuration help"
    echo "  just help-production                 # Production build help"
    echo "  just help-templates                  # Template building help"
    echo "  just help-general                    # This help (general commands)"
    echo ""
    echo "  just show <command>                  # Show command implementation"
    echo "  just --list                          # List all available commands"
    echo ""
    echo "🔧 UTILITY COMMANDS:"
    echo "  just --show <command>                # Show command implementation (native)"
    echo "  just --dump                          # Show entire parsed justfile"
    echo ""
    echo "⏱️ PERFORMANCE NOTES:"
    echo "  • just open: Instant"
    echo "  • just check: 5-30 seconds (depends on project size)"
    echo "  • just build-editor: 20-40 minutes (one-time per version)"
    echo "  • just run-headless: Depends on operation"
    echo ""
    echo "💡 BEST PRACTICES:"
    echo "  ✅ Run 'just check' before every commit"
    echo "  ✅ Build custom editor for latest features"
    echo "  ✅ Use 'just show' to understand commands before running"
    echo "  ✅ Use help commands to learn workflows"
    echo "  ⚠️  Don't interrupt build-editor (will corrupt build)"

# Common workflow patterns help
help-workflows:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔄 Common Workflow Patterns Guide"
    echo "================================="
    echo ""
    echo "📋 OVERVIEW:"
    echo "Proven workflow patterns for different development scenarios"
    echo "Choose the right pattern based on what you're working on"
    echo ""
    echo "🚀 DAILY DEVELOPMENT WORKFLOWS:"
    echo ""
    echo "  📱 ANDROID RAPID ITERATION:"
    echo "    just android-dev                   # Initial setup (once)"
    echo "    # Then for each change:"
    echo "    just restart-android-app           # Quick restart (fastest)"
    echo "    just android-logs 10               # Check results"
    echo "    # Perfect for: UI tweaks, small logic changes"
    echo ""
    echo "  📱 ANDROID WITH CONFIG TESTING:"
    echo "    just config-list                   # See available configs"
    echo "    just android-dev gameplay-testing  # Test with specific config"
    echo "    just android-quick performance     # Switch configs quickly"
    echo "    just android-logs 30               # Monitor results"
    echo "    # Perfect for: Feature flags, performance tuning"
    echo ""
    echo "  🍎 iOS DEVELOPMENT CYCLE:"
    echo "    just build-install-ios                       # Export + build"
    echo "    just ios-launch-help               # Get launch instructions (new command)"
    echo "    # Then manually launch in Xcode (iPhone/iPad Simulator or real device)"
    echo "    # For quick iteration:"
    echo "    just ios-update-pck                # Update game data only (save-ios-to-app)"
    echo "    # Perfect for: Game logic, content changes"
    echo ""
    echo "🧪 TESTING & DEBUGGING WORKFLOWS:"
    echo ""
    echo "  🐛 SYSTEMATIC BUG HUNTING:"
    echo "    just check log                     # Validate code first"
    echo "    just android-dev baseline          # Start with clean state"
    echo "    just android-logs 60               # Extended monitoring"
    echo "    just android-quick testing         # Try different configs"
    echo "    # Perfect for: Hard-to-reproduce bugs"
    echo ""
    echo "  📊 PERFORMANCE ANALYSIS:"
    echo "    just android-dev performance-testing # Launch with profiling"
    echo "    just android-logs 120              # Extended performance monitoring"
    echo "    just android-quick baseline        # Compare with baseline"
    echo "    # Perfect for: Optimization work"
    echo ""
    echo "🚀 RELEASE PREPARATION WORKFLOWS:"
    echo ""
    echo "  ✅ PRE-RELEASE CHECKLIST:"
    echo "    just check log                     # Validate all code"
    echo "    just config-clear                  # Clear debug configs"
    echo "    just android-dev                   # Test clean build"
    echo "    just android-export-prod apk       # Create test build"
    echo "    just build-install-ios                       # Test iOS build"
    echo "    # Perfect for: Release preparation"
    echo ""
    echo "  📦 PRODUCTION DEPLOYMENT:"
    echo "    just android-export-prod aab       # Play Store bundle"
    echo "    just ios-build                     # iOS build for Archive"
    echo "    # Then manual store uploads"
    echo "    # Perfect for: Store releases"
    echo ""
    echo "🛠️ SETUP & MAINTENANCE WORKFLOWS:"
    echo ""
    echo "  🔧 NEW ENVIRONMENT SETUP:"
    echo "    just setup-android                 # Setup Android tools"
    echo "    just templates-all                 # Build all templates"
    echo "    just config-setup                  # Setup debug configs"
    echo "    just android-dev                   # Test full workflow"
    echo "    # Perfect for: New developer onboarding"
    echo ""
    echo "  🔄 TEMPLATE REFRESH:"
    echo "    just clean-android                 # Clean old templates"
    echo "    just templates-android             # Rebuild Android templates"
    echo "    just templates-ios                 # Rebuild iOS templates"
    echo "    # Perfect for: After Godot updates"
    echo ""
    echo "💡 WORKFLOW SELECTION GUIDE:"
    echo "  • Small changes: restart-android-app"
    echo "  • Config testing: android-quick"
    echo "  • Major changes: android-dev"
    echo "  • iOS changes: build-install-ios + manual launch"
    echo "  • Bug hunting: check + logs + systematic testing"
    echo "  • Performance: performance-testing config"
    echo "  • Release prep: full validation + clean builds"

# Platform timing comparison guide
help-timing:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "⏱️  Platform Development Timing Guide"
    echo "===================================="
    echo ""
    echo "🚀 QUICK COMMANDS (< 10 seconds):"
    echo "  just run-desktop                 # 1-2 sec - Instant local testing"
    echo "  just config-push-android <cfg>   # 2 sec - Push config to device"
    echo "  just config-restart-android <cfg> # 5 sec - Config + restart"
    echo "  just restart-android-app         # 3 sec - Just restart Android app"
    echo "  just hotreload-ios-iphone        # 5-10 sec - iOS hot reload"
    echo ""
    echo "⚡ FAST ITERATION (< 60 seconds):"
    echo "  just fastbuild-android           # 30-60 sec - Fast Android rebuild"
    echo "  just test-monitor-android <cfg>  # 15-30 sec - Quick test monitoring"
    echo "  just test-android <cfg>          # 30-45 sec - Automated test"
    echo ""
    echo "🔧 MEDIUM BUILDS (2-5 minutes):"
    echo "  just quick-build-android         # 2-3 min - APK + AAB export"
    echo "  just quick-build-ios             # 2-3 min - iOS project export"
    echo "  just test-all-android            # 3-5 min - ENHANCED hierarchical test suite"
    echo ""
    echo "🏗️  FULL BUILDS (15+ minutes):"
    echo "  just build-all-android           # 20 min - Complete Android build"
    echo "  just build-all-ios               # 20 min - Complete iOS build"
    echo "  just build-all                   # 40 min - Both platforms"
    echo "  just templates-all               # 15-30 min - Rebuild all templates"
    echo ""
    echo "💡 OPTIMIZATION TIPS:"
    echo "  • Use run-desktop for logic testing (fastest)"
    echo "  • Use config-restart-android for device testing"
    echo "  • Use fastbuild-android after code changes"
    echo "  • Only use full builds when templates change"
    echo "  • iOS hot reload is fastest for iOS iteration"

# Build system architecture guide
help-build:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🏗️  Build System Architecture Guide"
    echo "=================================="
    echo ""
    echo "📦 BUILD COMPONENTS:"
    echo "  🎮 Godot Editor - Custom compiled editor with Firebase/Facebook modules"
    echo "  📱 Export Templates - Platform-specific runtime templates"
    echo "  🔧 Game Project - Your game code and assets"
    echo "  ⚙️  Platform Configs - Android/iOS specific settings"
    echo ""
    echo "🔄 BUILD PROCESS FLOW:"
    echo "  1️⃣  Pre-build checks (Godot executable, project validation)"
    echo "  2️⃣  Export game data (PCK file generation)"
    echo "  3️⃣  Platform-specific packaging (APK/IPA generation)"
    echo "  4️⃣  Post-build validation and deployment"
    echo ""
    echo "⚡ FAST BUILD STRATEGY:"
    echo "  • fastbuild-android: Hybrid approach (GDScript export + Gradle)"
    echo "  • Skips template rebuilding (saves 15+ minutes)"
    echo "  • Uses cached Gradle builds when possible"
    echo "  • Only rebuilds changed components"
    echo ""
    echo "🛠️  WHEN TO USE EACH BUILD:"
    echo "  fastbuild-android     → Code/config changes (daily development)"
    echo "  quick-build-android   → Asset changes, need APK file"
    echo "  build-all-android     → Template changes, clean builds"
    echo "  templates-all         → Godot engine updates, module changes"
    echo ""
    echo "📁 KEY DIRECTORIES:"
    echo "  export/android/       → Android build artifacts"
    echo "  export/ios/          → iOS build artifacts"
    echo "  godot/bin/           → Custom Godot executables"
    echo "  project/android/     → Android platform files"
    echo ""
    echo "🐛 TROUBLESHOOTING:"
    echo "  • Build fails: Try just clean-android then rebuild"
    echo "  • Missing templates: Run just templates-all"
    echo "  • Gradle issues: Check Android SDK configuration"
    echo "  • Permission errors: Verify device connection and permissions"

# Build and export for iOS
# Export iOS game data (PCK file only)
ios-export-pck: pre-build
    @echo "Exporting iOS game data (PCK file)..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --headless --export-pack ios ../export/ios/{{GAME_NAME}}.pck

# Build iOS project with Xcode (no install)
ios-build: pre-build
    @echo "Building iOS project with Xcode..."
    cd export/ios && xcodebuild -workspace {{GAME_NAME}}.xcworkspace -scheme {{GAME_NAME}} -configuration Debug -destination "generic/platform=iOS" -allowProvisioningUpdates

# Show instructions for launching iOS app manually
ios-launch-help:
    @echo "📱 iOS App Launch Instructions:"
    @echo "⚠️  iOS app launch requires manual steps"
    @echo "💡 Option 1: Open Xcode workspace: open export/ios/{{GAME_NAME}}.xcworkspace"
    @echo "💡 Option 2: Use iPhone/iPad Simulator from Xcode"
    @echo "💡 Option 3: Deploy to real iPhone/iPad via Xcode"

# Show instructions for restarting iOS app manually  
ios-restart-help:
    @echo "🔄 iOS App Restart Instructions:"
    @echo "⚠️  iOS app restart requires manual steps"
    @echo "💡 Simulator: Device → Restart"
    @echo "💡 Device: Force close app and relaunch"

# Update iOS app with new game data (copies PCK to built app)
ios-update-pck: pre-build
    @echo "Updating iOS app with new game data..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --headless --export-pack ios ../export/ios/build/products/Debug-iphoneos/{{GAME_NAME}}.app/{{GAME_NAME}}.pck
    @echo "✅ Game data updated in built iOS app"

# LEVEL 3: Full iOS rebuild & install (2-5 min, complete project rebuild)
build-install-ios:
    just ios-export-pck
    just ios-build
    @echo "✅ iOS development workflow complete!"
    @echo "💡 Next: Use ios-launch-help for manual launch steps"




# ================================
# BUILD COMMANDS - PLATFORM SPECIFIC
# ================================

# Full build and deploy process for all platforms
build-all: validate-env
    @echo "🏗️  FULL BUILD - ALL PLATFORMS"
    @echo "=============================="
    @echo "⏱️  Estimated time: 40-50 minutes"
    @echo ""
    @echo "💡 TIP: Use platform-specific builds to save time:"
    @echo "   • just build-all-android (20 min)"
    @echo "   • just build-all-ios (20 min)"
    @echo ""
    @echo "Press Enter to continue..."
    @read
    
    just _build-common
    just _build-android-full
    just _build-ios-full
    
    @echo "✅ Full build complete for all platforms!"
    @just build-status

# Build everything for Android only
build-all-android: validate-env
    @echo "🤖 FULL BUILD - ANDROID ONLY"
    @echo "============================"
    @echo "⏱️  Estimated time: 20-25 minutes"
    @echo ""
    
    just _build-common
    just _build-android-full
    
    @echo "✅ Android full build complete!"

# Build everything for iOS only
build-all-ios: validate-env
    @echo "🍎 FULL BUILD - iOS ONLY"
    @echo "======================="
    @echo "⏱️  Estimated time: 20-25 minutes"
    @echo ""
    
    just _build-common
    just _build-ios-full
    
    @echo "✅ iOS full build complete!"

# Quick build commands (skip editor/templates)
quick-build-android:
    @echo "⚡ Quick Android build (2-3 min)..."
    just insert-firebase-dependencies
    just export-apk-android
    just export-aab-android
    @echo "✅ Quick Android build complete!"

quick-build-ios:
    @echo "⚡ Quick iOS build (2-3 min)..."
    just ios-export-pck
    just ios-build
    @echo "✅ Quick iOS build complete!"

quick-build-all:
    @echo "⚡ Quick build for all platforms (5-10 min)..."
    just quick-build-android
    just quick-build-ios
    @echo "✅ Quick build complete!"

# Build status check
build-status:
    @echo "📊 BUILD STATUS CHECK"
    @echo "===================="
    @echo ""
    @echo "EDITOR:"
    @if [ -f "editor/{{GODOT_EXECUTABLE}}" ]; then \
        echo "  ✅ Built"; \
    else \
        echo "  ❌ Not built"; \
    fi
    @echo ""
    @echo "TEMPLATES:"
    @if [ -f "templates/android_debug.apk" ]; then \
        echo "  ✅ Android: Built"; \
    else \
        echo "  ❌ Android: Not built"; \
    fi
    @if [ -f "templates/ios.zip" ]; then \
        echo "  ✅ iOS: Built"; \
    else \
        echo "  ❌ iOS: Not built"; \
    fi
    @echo ""
    @echo "ANDROID EXPORTS:"
    @if [ -f "export/android/{{GAME_NAME}}.apk" ]; then \
        echo "  ✅ APK: export/android/{{GAME_NAME}}.apk"; \
    else \
        echo "  ❌ APK: Not exported"; \
    fi
    @if [ -f "export/android/{{GAME_NAME}}.aab" ]; then \
        echo "  ✅ AAB: export/android/{{GAME_NAME}}.aab"; \
    else \
        echo "  ❌ AAB: Not exported"; \
    fi
    @echo ""
    @echo "iOS EXPORTS:"
    @if [ -d "export/ios/{{GAME_NAME}}.xcworkspace" ]; then \
        echo "  ✅ Xcode project: Exported"; \
    else \
        echo "  ❌ Xcode project: Not exported"; \
    fi
    @if [ -d "export/ios/build/products/debug-iphoneos/{{GAME_NAME}}.app" ]; then \
        echo "  ✅ iOS app: Built"; \
    else \
        echo "  ❌ iOS app: Not built"; \
    fi

# ================================
# INTERNAL BUILD HELPERS (DRY)
# ================================

# Common build steps
_build-common:
    @echo "📦 [1/3] Installing dependencies..."
    just install-deps
    @echo "🔨 [2/3] Building Godot editor..."
    just build-editor
    @echo "📝 [3/3] Updating version..."
    just update-version

# Android full build steps
_build-android-full:
    @echo ""
    @echo "🤖 ANDROID BUILD STEPS"
    @echo "===================="
    @echo "📦 [1/4] Building Android templates..."
    just templates-android
    @echo "🔥 [2/4] Setting up Firebase..."
    just insert-firebase-dependencies
    @echo "📱 [3/4] Exporting Android APK..."
    just export-apk-android
    @echo "📦 [4/4] Exporting Android AAB..."
    just export-aab-android

# iOS full build steps
_build-ios-full:
    @echo ""
    @echo "🍎 iOS BUILD STEPS"
    @echo "================="
    @echo "📦 [1/3] Building iOS templates..."
    just templates-ios
    @echo "📱 [2/3] Exporting iOS project..."
    just ios-export-pck
    @echo "🔨 [3/3] Building with Xcode..."
    just ios-build

# ================================
# OLD BUILD-ALL BUGFIX
# ================================

replace TARGET_FILE PATTERN REPLACEMENT_FILE:
    #!/usr/bin/env bash
    set -euo pipefail
    python3 tools/replace_content.py "{{TARGET_FILE}}" "{{PATTERN}}" "{{REPLACEMENT_FILE}}"

insert-firebase-dependencies:
    cp firebase/google-services.json project/android/build/

    @echo "Preparing Firebase dependencies..."

    echo 'implementation platform ("com.google.firebase:firebase-bom:33.1.2")' > temp_dependencies.txt
    echo 'implementation "com.google.firebase:firebase-auth"' >> temp_dependencies.txt
    echo 'implementation "com.google.firebase:firebase-messaging"' >> temp_dependencies.txt
    echo 'implementation "com.google.firebase:firebase-database"' >> temp_dependencies.txt
    echo 'implementation "com.google.firebase:firebase-config"' >> temp_dependencies.txt
    echo 'implementation "com.google.firebase:firebase-analytics"' >> temp_dependencies.txt
    
    @echo "Preparing Firebase plugin..."

    echo 'apply plugin: "com.google.gms.google-services"' > temp_plugin.txt
    
    @echo "Preparing Firebase buildscript..."
    echo 'buildscript {' > temp_buildscript.txt
    echo '    repositories {' >> temp_buildscript.txt
    echo '        google()' >> temp_buildscript.txt
    echo '        mavenCentral()' >> temp_buildscript.txt
    echo '    }' >> temp_buildscript.txt
    echo '    dependencies {' >> temp_buildscript.txt
    echo '        classpath "com.google.gms:google-services:4.4.2"' >> temp_buildscript.txt
    echo '    }' >> temp_buildscript.txt
    echo '}' >> temp_buildscript.txt
    
    @echo "Inserting Firebase configurations..."

    just replace project/android/build/build.gradle  //ADD_FIREBASE_BUILDSCRIPT_HERE_ temp_buildscript.txt    
    just replace project/android/build/build.gradle  //ADD_FIREBASE_DEPENDENCIES_HERE_ temp_dependencies.txt
    just replace project/android/build/build.gradle  //ADD_FIREBASE_PLUGINS_HERE_ temp_plugin.txt

    @echo "Cleaning up temporary files..."

    rm temp_dependencies.txt temp_plugin.txt temp_buildscript.txt   

    @echo "Firebase dependencies inserted successfully."

# Wildcard patterns and development cycles guide
help-wildcards:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🎯 Wildcard Patterns & Development Cycles Guide"
    echo "=============================================="
    echo ""
    echo "🏗️ HIERARCHICAL ACTION NAMING"
    echo "All 51+ debug actions use consistent naming: layer.domain.operation"
    echo ""
    echo "📱 LAYERS (First Part - Architecture)"
    echo "  cpp.*              # C++ Firebase SDK (8 actions)"
    echo "  backend.*          # Backend Firebase (7 actions)"
    echo "  rtdb.*             # RTDB GDScript API (19 actions)"
    echo "  system.*           # System utilities (5 actions)"
    echo "  game.*             # Game logic (12 actions)"
    echo ""
    echo "🎯 DOMAINS (Middle Part - Functionality)"
    echo "  *.firebase.*       # Firebase operations (database, auth, analytics)"
    echo "  *.database.*       # Database operations (set, get, update, remove)"
    echo "  *.paths.*          # Path operations (nested structures, hierarchies)"
    echo "  *.children.*       # Children operations (list, push, manage)"
    echo "  *.listeners.*      # Real-time listeners (single_value, child events)"
    echo "  *.advanced.*       # Advanced operations (transactions, batching)"
    echo "  *.testing.*        # Testing utilities (validation, error handling)"
    echo "  *.debug.*          # Debug utilities (logging, stats, info)"
    echo "  *.match.*          # Game match functionality (levels, scoring)"
    echo "  *.network.*        # Network operations (connectivity, sync)"
    echo "  *.storage.*        # Data storage operations (save, load, cache)"
    echo ""
    echo "⚙️ OPERATIONS (Last Part - Specific Actions)"
    echo "  *.*.set_value      # Data writing operations"
    echo "  *.*.get_value      # Data reading operations"
    echo "  *.*.error_handling # Error handling and recovery"
    echo "  *.*.performance    # Performance testing and optimization"
    echo "  *.*.concurrent_ops # Concurrency and threading tests"
    echo "  *.*.timeout_behavior # Timeout and reliability tests"
    echo ""
    echo "⚡ DEVELOPMENT CYCLES"
    echo ""
    echo "🚀 5-Second Iteration (Config Commands)"
    echo "  just config-restart-android 'system.debug.registry_stats'"
    echo "  just config-restart-android 'cpp.*'"
    echo "  just config-restart-android '*.firebase.set_value'"
    echo "  → Deploy config + restart app + test (5 seconds total)"
    echo ""
    echo "🔄 60-Second Validation (Build Commands)"
    echo "  just fastbuild-android"
    echo "  just test-android 'cpp.*'"
    echo "  → Rebuild + deploy + test with full analysis (60 seconds)"
    echo ""
    echo "🎯 Progressive Testing Strategy"
    echo "  1. Layer-focused: 'cpp.*', 'backend.*', 'rtdb.*'"
    echo "  2. Domain-focused: '*.firebase.*', '*.debug.*'"
    echo "  3. Operation-focused: '*.*.performance', '*.*.error_handling'"
    echo ""
    echo "💡 PRACTICAL EXAMPLES"
    echo ""
    echo "  # Test Firebase functionality across all layers"
    echo "  just test-android '*.firebase.*'"
    echo "  just logs TEST_ID firebase"
    echo ""
    echo "  # Debug error handling implementations"
    echo "  just test-android '*.*.error_handling'"
    echo "  just logs-errors-tagged TEST_ID"
    echo ""
    echo "  # Performance optimization workflow"
    echo "  just config-restart-android '*.*.performance'"
    echo "  just logs-performance-tagged TEST_ID"

# Log analysis and token efficiency guide
help-logs:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📊 Log Analysis & Token Efficiency Guide"
    echo "======================================="
    echo ""
    echo "🎯 TOKEN EFFICIENCY DECISION TREE"
    echo ""
    echo "🚨 Step 1: Quick Error Scan (5 sec, <10 tokens)"
    echo "  just logs-errors-tagged TEST_ID"
    echo "  → 98% token savings, instant error detection"
    echo "  → If errors found: follow error patterns below"
    echo "  → If no errors: proceed to Step 2"
    echo ""
    echo "🔍 Step 2: Component Analysis (15 sec, <100 tokens)"
    echo "  just logs TEST_ID [component]"
    echo "  → 87-95% token savings vs full logs"
    echo "  → Focus on specific system components"
    echo ""
    echo "🔬 Step 3: Precision Analysis (<200 tokens)"
    echo "  just logs TEST_ID [component] [operation] [status]"
    echo "  → Multi-tag filtering for surgical analysis"
    echo ""
    echo "📋 AVAILABLE LOG COMMANDS"
    echo ""
    echo "🏷️ Tag-Filtered Commands (Recommended)"
    echo "  just logs TEST_ID [tags...]                   # Universal filtering"
    echo "  just logs-errors-tagged TEST_ID [tags...]     # Error-focused (98% savings)"
    echo "  just logs-performance-tagged TEST_ID [tags...] # Performance analysis"
    echo "  just logs-lifecycle-tagged TEST_ID [tags...]  # App lifecycle events"
    echo ""
    echo "📊 Traditional Commands (High Token Cost)"
    echo "  just logs TEST_ID                            # Full logs (use sparingly)"
    echo "  just logs-android-results TEST_ID            # Results summary only"
    echo "  just logs-android-recent                     # Recent test runs"
    echo ""
    echo "🎯 COMMON DEBUGGING PATTERNS"
    echo ""
    echo "🔥 Firebase Issues"
    echo "  Symptoms: 'Firebase timeout', 'Connection refused', 'Auth failed'"
    echo "  Debug: just logs-errors-tagged TEST_ID firebase"
    echo "  Analyze: just logs TEST_ID firebase error"
    echo ""
    echo "⚔️ Battle Determinism"
    echo "  Symptoms: 'expectedHash mismatch', 'VALIDATION MODE failed'"
    echo "  Debug: just logs TEST_ID battle determinism"
    echo "  Analyze: just logs TEST_ID battle validation"
    echo ""
    echo "⚡ Performance Issues"
    echo "  Symptoms: Slow execution, timeouts"
    echo "  Debug: just logs-performance-tagged TEST_ID"
    echo "  Analyze: just logs-performance-tagged TEST_ID [component]"
    echo ""
    echo "🔄 System Startup"
    echo "  Symptoms: Initialization failures, registry errors"
    echo "  Debug: just logs TEST_ID system startup"
    echo "  Analyze: just logs TEST_ID system debug initialization"
    echo ""
    echo "💡 TOKEN EFFICIENCY EXAMPLES"
    echo ""
    echo "  # Get recent test IDs first:"
    echo "  just logs-android-recent                           # List available test IDs"
    echo ""
    echo "  # 98% token savings - error-first debugging"
    echo "  just logs-errors-tagged test_20250618_132337_a36253d9                    # <10 tokens"
    echo "  just logs-errors-tagged test_20250618_132337_a36253d9 Firebase           # <10 tokens"
    echo ""
    echo "  # 87-95% token savings - component-focused"
    echo "  just logs test_20250618_132337_a36253d9 firebase                         # ~100 tokens"
    echo "  just logs test_20250618_132337_a36253d9 backend                          # ~100 tokens"
    echo "  just logs test_20250618_132337_a36253d9 debug test                       # ~50 tokens"
    echo ""
    echo "  # Precision analysis - multiple tags"
    echo "  just logs test_20250618_132337_a36253d9 firebase rtdb                    # ~50 tokens"
    echo "  just logs-performance-tagged test_20250618_132337_a36253d9 backend       # ~100 tokens"
    echo ""
    echo "  # Compare to traditional approach"
    echo "  just logs test_20250618_132337_a36253d9                                  # 2000+ tokens"

# Config management workflow guide
help-config:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔧 Config Management Workflow Guide"
    echo "==================================="
    echo ""
    echo "🎯 CONFIG TYPES & AUTO-DETECTION"
    echo ""
    echo "📄 Config Files (*.json in configs/)"
    echo "  just config-restart-android minimal-testing    # Uses configs/minimal-testing.json"
    echo "  just config-push-android system-testing        # Push system-testing.json (2 sec)"
    echo "  just config-set performance-testing             # Set as embedded default"
    echo ""
    echo "🎬 Single Actions (Direct Action Names)"
    echo "  just config-restart-android 'Show Registry Stats'     # Single action"
    echo "  just config-restart-android 'Backend Performance Test' # Single action"
    echo "  → System creates temporary config automatically"
    echo ""
    echo "🎯 Wildcard Patterns (Auto-Discovery)"
    echo "  just config-restart-android 'cpp.*'                   # All C++ actions"
    echo "  just config-restart-android '*.firebase.*'            # All Firebase operations"
    echo "  just config-restart-android '*.*.performance'         # All performance tests"
    echo "  → System discovers matching actions and creates temporary config"
    echo ""
    echo "📋 Test Lists (Predefined Workflows)"
    echo "  just config-restart-android development-workflow       # Uses test-lists/development-workflow.json"
    echo "  just config-restart-android pre-commit                 # Uses test-lists/pre-commit.json"
    echo ""
    echo "⚡ ULTRA-FAST ITERATION CYCLES"
    echo ""
    echo "🚀 5-Second Config Cycles (No Rebuild)"
    echo "  just config-restart-android TARGET"
    echo "  → Push config (1 sec) + restart app (1 sec) + ready to test (3 sec buffer)"
    echo "  → Perfect for rapid iteration during development"
    echo ""
    echo "⚙️ 2-Second Config Push (No Restart)"
    echo "  just config-push-android TARGET"
    echo "  → Deploy config only, manual restart needed"
    echo "  → Use when you want to queue multiple configs"
    echo ""
    echo "🔄 60-Second Full Rebuild Cycle"
    echo "  just fastbuild-android"
    echo "  → Full rebuild + deploy + install (when code changes)"
    echo ""
    echo "📱 ANDROID LOGGER CONFIGURATION"
    echo ""
    echo "🏷️ Runtime Tag Control (No Rebuild Required)"
    echo "  just config-android-tags \"firebase,battle\" \"cache,animation\""
    echo "  → Focus on specific components, filter noise"
    echo "  → Changes apply after app restart"
    echo ""
    echo "📊 Log Level Control"
    echo "  just config-android-level DEBUG         # Full debugging"
    echo "  just config-android-level INFO          # Reduce debug noise"
    echo "  just config-android-level ERROR         # Errors only"
    echo ""
    echo "🔄 Apply Logger Changes"
    echo "  just restart-android-app                # Apply new logger settings"
    echo "  just config-android-reset               # Reset to project defaults"
    echo ""
    echo "💡 WORKFLOW EXAMPLES"
    echo ""
    echo "🔥 Firebase Development Workflow"
    echo "  # 1. Focus logger on Firebase components"
    echo "  just config-android-tags \"firebase,error\" \"cache,debug\""
    echo "  just restart-android-app"
    echo ""
    echo "  # 2. Rapid Firebase testing (5-second cycles)"
    echo "  just config-restart-android '*.firebase.set_value'"
    echo "  just config-restart-android '*.firebase.get_value'"
    echo "  just config-restart-android 'backend.firebase.*'"
    echo ""
    echo "  # 3. Efficient debugging"
    echo "  just logs-errors-tagged TEST_ID firebase"
    echo "  just logs TEST_ID firebase rtdb"
    echo ""
    echo "⚔️ Battle System Development"
    echo "  # 1. Focus on battle determinism"
    echo "  just config-android-tags \"battle,validation\" \"cache\""
    echo "  just restart-android-app"
    echo ""
    echo "  # 2. Test battle mechanics (5-second cycles)"
    echo "  just config-restart-android 'game.match.*'"
    echo "  just config-restart-android '*.*.determinism'"
    echo ""
    echo "  # 3. Debug battle issues"
    echo "  just logs TEST_ID battle determinism"
    echo "  just logs-performance-tagged TEST_ID battle"
    echo ""
    echo "🎯 CONFIGURATION MANAGEMENT"
    echo ""
    echo "📋 List & Status Commands"
    echo "  just config-list                    # List available configs"
    echo "  just config-status-android          # Check current config status"
    echo "  just config-setup                   # Create sample debug configurations"
    echo ""
    echo "🔄 Config State Management"
    echo "  just config-set TARGET              # Set as embedded default"
    echo "  just config-clear-android           # Clear external config, use embedded"
    echo ""
    echo "💡 DECISION MATRIX"
    echo ""
    echo "  Use config-restart-android when:"
    echo "  ✅ Testing specific functionality (5-second cycles)"
    echo "  ✅ No code changes, only testing different scenarios"
    echo "  ✅ Want immediate feedback without rebuild"
    echo ""
    echo "  Use fastbuild-android when:"
    echo "  ✅ Made code changes that need compilation"
