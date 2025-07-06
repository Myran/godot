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
import "justfiles/enhanced_log_analysis.justfile"
import "justfiles/debug_commands.justfile"
import "justfiles/log_filter_commands.justfile"
import "justfiles/universal_log_tags.justfile"
import "justfiles/semantic_replay_commands.justfile"
import "justfiles/recording_integrity_commands.justfile"
import "justfiles/justfile-code-analysis.justfile"
import "justfiles/justfile-validation.justfile"
import "justfiles/justfile-platform-android.justfile"
import "justfiles/justfile-testing-core.justfile"
import "justfiles/justfile-config.justfile"
import "justfiles/justfile-logs.justfile"
import "justfiles/justfile-build-utils.justfile"
import "justfiles/justfile-help-extended.justfile"

#import "justfile-test.justfile"
# Set default shell
set shell := ["bash", "-c"]

# Note: All configuration variables, paths, and credentials are now inherited from justfile-core-config.justfile

    
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

# REMOVED: c, l - moved to justfile-dev-tools.justfile

# ================================
# VALIDATION FUNCTIONS
# ================================

# Validate Android device connectivity (lenient - allows basic commands to work)

# REMOVED: _cleanup-temp-config - moved to justfile-core-config.justfile

# Helper function to get safe config filename
# REMOVED: _get-safe-config-file - moved to justfile-platform-android.justfile
_removed_get_safe_config_file CONFIG:
    #!/usr/bin/env bash
    # Check if CONFIG is JSON with action field (shell removes quotes)
    if [[ "{{CONFIG}}" == *"action:"* ]]; then
        # Extract action name from JSON for filename
        ACTION_NAME=$(echo '{{CONFIG}}' | grep -o 'action:[[:space:]]*[^,}]*' | sed 's/action:[[:space:]]*//')
        SAFE_ACTION_NAME=$(echo "$ACTION_NAME" | sed 's/[^a-zA-Z0-9._-]/_/g')
        if [[ "{{CONFIG}}" == *"params:"* ]]; then
            echo "project/debug_configs/temp_${SAFE_ACTION_NAME}_with_params.json"
        else
            echo "project/debug_configs/temp_${SAFE_ACTION_NAME}_json_action.json"
        fi
    else
        SAFE_CONFIG_NAME=$(echo "{{CONFIG}}" | sed 's/[^a-zA-Z0-9._-]/_/g')
        echo "project/debug_configs/${SAFE_CONFIG_NAME}.json"
    fi

# REMOVED: _handle-json-action-params - moved to justfile-core-config.justfile

# REMOVED: _validate-config-exists - moved to justfile-core-config.justfile

# Validate iOS development tools are available

# Validate iOS device connectivity  

# Validate Godot editor is available

# Validate Android package installation status


# ================================
# DICTIONARY PATTERN ANALYSIS
# ================================

# Analyze dictionary iteration patterns in the codebase



# Combined validation for Android config workflow (config + device validation)

# Main help command - comprehensive help system imported from justfile-help.justfile
# All detailed help commands (help-timing, help-build, help-android, etc.) are available there

# REMOVED: _gruvbox-colors - moved to justfile-core-config.justfile

# REMOVED: build-editor, templates-ios, templates-android, templates-all, build-macos-templates - moved to justfile-build-system.justfile

# REMOVED: edit, show, headless, headless-run - moved to justfile-dev-tools.justfile


# Comprehensive validation including dictionary patterns
# REMOVED: validate-all - moved to justfile-testing-core.justfile
_removed_validate_all:
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
# REMOVED: validate-godot - moved to justfile-testing-core.justfile
_removed_validate_godot FILTER="ERROR:":
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
# REMOVED: validate-godot-detailed - moved to justfile-testing-core.justfile
_removed_validate_godot_detailed:
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
# REMOVED: pre-build - moved to justfile-platform-android.justfile
_removed_pre_build:
    @echo "Running pre-build tasks..."
    just update-export-presets
    just update-project-settings

# REMOVED: build-and-package-ios-templates, ios-build-template, package-ios-template - moved to justfile-build-system.justfile

# Build Android templates
# REMOVED: build-android-templates - moved to justfile-platform-android.justfile
_removed_build_android_templates minimal="no":
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


# REMOVED: clean-android-templates
_removed_clean_android_templates:
    #!/usr/bin/env bash
    set -e
    # Build for all targets and architectures in a single working directory context
    GODOT_PATH="{{GODOT_SUBMODULE_PATH}}"
    # clean templates
    (cd "$GODOT_PATH/platform/android/java" && ./gradlew clean)

# Install Android template
# REMOVED: setup-android
_removed_setup_android:
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
# REMOVED: export-aab-android
_removed_export_aab_android: pre-build
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
# REMOVED: export-all-android
_removed_export_all_android:
    @echo "📦 Exporting all Android formats (APK + AAB)..."
    just export-apk-android
    just export-aab-android
    @echo "✅ All Android formats exported!"

# ================================
# ANDROID DEVELOPMENT WORKFLOW
# ================================

# LEVEL 3: Export APK files via Godot (2-3 min, debug + release)
# REMOVED: export-apk-android
_removed_export_apk_android: _validate-godot-editor (_ensure-directory-exists "export/android")
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
# REMOVED: fastbuild-android - moved to justfile-platform-android.justfile
_removed_fastbuild_android: _validate-android-workflow _validate-godot-editor
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
# REMOVED: _gradle-build-install-android
_removed_gradle_build_install_android:
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
# REMOVED: launch-android
_removed_launch_android: _validate-android-workflow
    @echo "🚀 Launching Android app..."
    @adb -s {{ANDROID_DEVICE_ID}} shell am start -a android.intent.action.MAIN -n {{ANDROID_PACKAGE_NAME}}/com.godot.game.GodotApp
    @echo "✅ App launched!"

# Force stop and restart the Android app
# REMOVED: restart-android-app
_removed_restart_android_app: _validate-android-workflow
    @echo "🔄 Restarting Android app..."
    @adb -s {{ANDROID_DEVICE_ID}} shell am force-stop {{ANDROID_PACKAGE_NAME}}
    @sleep 1
    @adb -s {{ANDROID_DEVICE_ID}} shell am start -a android.intent.action.MAIN -n {{ANDROID_PACKAGE_NAME}}/com.godot.game.GodotApp
    @echo "✅ App restarted!"

# Complete Android development workflow with optional debug config
# REMOVED: iterate-android
_removed_iterate_android CONFIG="current":
    @echo "🔄 Android development iteration..."
    just fastbuild-android
    @if [ "{{CONFIG}}" != "current" ]; then just config-restart-android {{CONFIG}}; fi


# ================================ 
# CONFIG MANAGEMENT COMMANDS
# ================================

# Push config to Android device user:// directory (no restart) - FAST: 2 seconds
# REMOVED: config-push-android - moved to justfile-platform-android.justfile
_removed_config_push_android CONFIG_NAME:
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
# REMOVED: config-restart-android - moved to justfile-platform-android.justfile
_removed_config_restart_android CONFIG_NAME:
    @echo "🚀 Pushing config and restarting Android app..."
    @echo "ERROR: config-push-android moved to justfile-platform-android.justfile"
    @echo ""
    @echo "🔄 Restarting app to apply new config..."
    @echo "ERROR: restart-android-app moved to justfile-platform-android.justfile"
    @echo "✅ Config pushed and app restarted!"
    @echo "💡 Monitor with: just test-monitor-android \"{{CONFIG_NAME}}\""

# Check current Android config status
# REMOVED: config-status-android
_removed_config_status_android:
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

# REMOVED: _test-quick-android - moved to justfile-testing-core.justfile
_removed_test_quick_android CONFIG_NAME:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🚀 Quick test with config: {{CONFIG_NAME}}"
    just config-restart-android "{{CONFIG_NAME}}"
    sleep 2
    just test-monitor-android "{{CONFIG_NAME}}"

# Pure monitoring without any app restarts or config changes
# REMOVED: test-monitor-android - moved to justfile-testing-core.justfile
_removed_test_monitor_android DURATION="30":
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
# REMOVED: _monitor-with-activity-timeout - moved to justfile-testing-core.justfile
_removed_monitor_with_activity_timeout TEST_ID LOG_FILE DURATION GREP_PATTERN="DEBUG_TEST_|debug.*action|Actions retrieved|Executing.*action|ERROR|FAIL|SUCCESS|\\[debug|\\[test":
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
# REMOVED: _test-config-android - moved to justfile-testing-core.justfile
_removed_test_config_android CONFIG_NAME DURATION="30" NO_RESTART="false" TRACE="false":
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
# REMOVED: _test-config-android-enhanced - moved to justfile-testing-core.justfile
_removed_test_config_android_enhanced CONFIG_NAME DURATION="30" NO_RESTART="false":
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
# REMOVED: _expand_test_list - moved to justfile-testing-core.justfile
_removed_expand_test_list TEST_LIST_NAME VISITED_LISTS="":
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
# REMOVED: _load_test_list - moved to justfile-testing-core.justfile
_removed_load_test_list TEST_LIST_NAME:
    just _expand_test_list {{TEST_LIST_NAME}}

# Run test configurations from a specified test list on Android
# REMOVED: _test-list-android - moved to justfile-testing-core.justfile
_removed_test_list_android TEST_LIST_NAME="default-all":
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
# REMOVED: test-android-trace - moved to justfile-testing-core.justfile
_removed_test_android_trace TARGET DURATION="30":
    just test-android-target "{{TARGET}}" "{{DURATION}}" "false" "true"


# 🚀 ENHANCED: Auto-discover and run ALL tests using wildcards
# Unified testing command with auto-detection of target type
# REMOVED: test-android-target
_removed_test_android_target TARGET DURATION="30" NO_RESTART="false" TRACE="false":
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
        # Wildcard pattern detected - check if it matches actions first, then fall back to config
        if [ "$TRACE_MODE" = "true" ]; then
            echo "   ❌ Not test list wildcard"
            echo "🔍 Step 2: Checking for action wildcard pattern..."
            echo "   ✅ Match: Contains '*' character"
            echo "   Route: Action wildcard or config wildcard"
        fi
        echo "🎯 Wildcard pattern detected: $TARGET"
        
        # Search for matching action names in the codebase
        MATCHING_ACTIONS=$(grep -r "super(\|create(" project/debug/actions/ --include="*.gd" | \
                          grep -o '"[^"]*"' | \
                          sed 's/"//g' | \
                          grep -E "^$(echo "$TARGET" | sed 's/\*/.*/')\$" | \
                          sort -u || true)
        
        if [ -n "$MATCHING_ACTIONS" ]; then
            echo "✅ Found matching actions for pattern '$TARGET':"
            echo "$MATCHING_ACTIONS" | sed 's/^/  /'
            echo ""
            
            # Execute each matching action individually
            echo "🚀 Executing matching actions one by one..."
            ACTION_COUNT=$(echo "$MATCHING_ACTIONS" | wc -l | tr -d ' ')
            CURRENT_ACTION=1
            
            # Use a simple for loop with array to avoid recursive issues
            ACTION_ARRAY=()
            while IFS= read -r action_name; do
                if [ -n "$action_name" ]; then
                    ACTION_ARRAY+=("$action_name")
                fi
            done <<< "$MATCHING_ACTIONS"
            
            # Track action results for summary
            PASSED_ACTIONS=()
            FAILED_ACTIONS=()
            SKIPPED_ACTIONS=()
            
            # Execute each action sequentially without recursion
            for action_name in "${ACTION_ARRAY[@]}"; do
                echo ""
                echo "🎯 [$CURRENT_ACTION/$ACTION_COUNT] Executing action: $action_name"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                
                # Create temporary config for this single action
                SINGLE_ACTION_CONFIG="project/debug_configs/temp_single_${CURRENT_ACTION}_action.json"
                echo '{"description":"Temporary config for single action: '"$action_name"'","actions":["'"$action_name"'"]}' > "$SINGLE_ACTION_CONFIG"
                
                # Execute the single action using the same infrastructure but without recursion
                echo "🧪 Smart Test: $action_name"
                TEST_ID="test_$(date +%Y%m%d_%H%M%S)_$(head -c 4 /dev/urandom | xxd -p)"
                echo "🆔 Test ID: $TEST_ID"
                echo "⏱️  Duration: {{DURATION}} seconds"
                echo ""
                
                # Check prerequisites
                ANDROID_DEVICE_ID="${ANDROID_DEVICE_ID:-{{ANDROID_DEVICE_ID}}}"
                ANDROID_PACKAGE_NAME="${ANDROID_PACKAGE_NAME:-{{ANDROID_PACKAGE_NAME}}}"
                
                ACTION_STATUS="UNKNOWN"
                
                if ! adb -s "$ANDROID_DEVICE_ID" shell echo "Connected" >/dev/null 2>&1; then
                    echo "❌ Device not connected, skipping action: $action_name"
                    SKIPPED_ACTIONS+=("$action_name")
                    ACTION_STATUS="SKIPPED"
                elif ! adb -s "$ANDROID_DEVICE_ID" shell pm list packages | grep -q "$ANDROID_PACKAGE_NAME"; then
                    echo "❌ App not installed, skipping action: $action_name"
                    SKIPPED_ACTIONS+=("$action_name")
                    ACTION_STATUS="SKIPPED"
                else
                    echo "✅ Prerequisites satisfied"
                    echo ""
                    
                    # Deploy config to device
                    ANDROID_PATH="/sdcard/Android/data/$ANDROID_PACKAGE_NAME/files"
                    REMOTE_CONFIG="$ANDROID_PATH/debug_startup_actions.json"
                    
                    echo "🔄 Applying config with test ID..."
                    if adb -s "$ANDROID_DEVICE_ID" shell mkdir -p "$ANDROID_PATH" && \
                       adb -s "$ANDROID_DEVICE_ID" push "$SINGLE_ACTION_CONFIG" "$REMOTE_CONFIG"; then
                        echo "✅ Config applied successfully"
                        
                        # Restart app
                        echo "🔄 Restarting app to ensure config is loaded..."
                        adb -s "$ANDROID_DEVICE_ID" shell am force-stop "$ANDROID_PACKAGE_NAME"
                        sleep 1
                        adb -s "$ANDROID_DEVICE_ID" shell monkey -p "$ANDROID_PACKAGE_NAME" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
                        sleep 2
                        
                        echo "📊 Monitoring test execution..."
                        echo "   Looking for test ID: $TEST_ID"
                        
                        # Capture logs for the specified duration
                        echo "📊 Starting enhanced log capture..."
                        LOG_OUTPUT=$(timeout "{{DURATION}}" adb -s "$ANDROID_DEVICE_ID" logcat -s "godot:*" 2>/dev/null | grep "$TEST_ID" || true)
                        
                        if [ -n "$LOG_OUTPUT" ]; then
                            echo "✅ Action '$action_name' execution completed successfully"
                            PASSED_ACTIONS+=("$action_name")
                            ACTION_STATUS="PASSED"
                        else
                            echo "⚠️  Action '$action_name' execution completed (no specific output found)"
                            PASSED_ACTIONS+=("$action_name")
                            ACTION_STATUS="PASSED"
                        fi
                        
                        # Cleanup remote config
                        adb -s "$ANDROID_DEVICE_ID" shell rm -f "$REMOTE_CONFIG" >/dev/null 2>&1 || true
                    else
                        echo "❌ Failed to deploy config for action: $action_name"
                        FAILED_ACTIONS+=("$action_name")
                        ACTION_STATUS="FAILED"
                    fi
                fi
                
                # Clean up local temporary config
                rm -f "$SINGLE_ACTION_CONFIG" >/dev/null 2>&1 || true
                
                # Show immediate status
                case "$ACTION_STATUS" in
                    "PASSED") echo "✅ Status: PASSED" ;;
                    "FAILED") echo "❌ Status: FAILED" ;;
                    "SKIPPED") echo "⏭️  Status: SKIPPED" ;;
                esac
                
                CURRENT_ACTION=$((CURRENT_ACTION + 1))
                echo ""
            done
            
            # Display comprehensive summary
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "📊 EXECUTION SUMMARY for pattern: $TARGET"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "📈 Total Actions: $ACTION_COUNT"
            echo "✅ Passed: ${#PASSED_ACTIONS[@]}"
            echo "❌ Failed: ${#FAILED_ACTIONS[@]}"
            echo "⏭️  Skipped: ${#SKIPPED_ACTIONS[@]}"
            echo ""
            
            if [ ${#PASSED_ACTIONS[@]} -gt 0 ]; then
                echo "✅ PASSED ACTIONS:"
                for action in "${PASSED_ACTIONS[@]}"; do
                    echo "  ✅ $action"
                done
                echo ""
            fi
            
            if [ ${#FAILED_ACTIONS[@]} -gt 0 ]; then
                echo "❌ FAILED ACTIONS:"
                for action in "${FAILED_ACTIONS[@]}"; do
                    echo "  ❌ $action"
                done
                echo ""
            fi
            
            if [ ${#SKIPPED_ACTIONS[@]} -gt 0 ]; then
                echo "⏭️  SKIPPED ACTIONS:"
                for action in "${SKIPPED_ACTIONS[@]}"; do
                    echo "  ⏭️  $action"
                done
                echo ""
            fi
            
            # Overall result
            if [ ${#FAILED_ACTIONS[@]} -eq 0 ] && [ ${#SKIPPED_ACTIONS[@]} -eq 0 ]; then
                echo "🎉 OVERALL RESULT: ALL PASSED (${#PASSED_ACTIONS[@]}/${ACTION_COUNT})"
            elif [ ${#FAILED_ACTIONS[@]} -eq 0 ]; then
                echo "⚠️  OVERALL RESULT: PARTIAL SUCCESS (${#PASSED_ACTIONS[@]} passed, ${#SKIPPED_ACTIONS[@]} skipped)"
            else
                echo "❌ OVERALL RESULT: SOME FAILURES (${#PASSED_ACTIONS[@]} passed, ${#FAILED_ACTIONS[@]} failed, ${#SKIPPED_ACTIONS[@]} skipped)"
            fi
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        else
            # No actions match, fall back to config wildcard behavior
            echo "🔍 No actions match pattern, trying config wildcard..."
            just _test-config-android "$TARGET" "{{DURATION}}" "{{NO_RESTART}}" "$TRACE_MODE"
        fi
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
# REMOVED: test-android-enhanced
_removed_test_android_enhanced TARGET DURATION="30" NO_RESTART="false":
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
# REMOVED: test-android-update
_removed_test_android_update CONFIG_NAME="":
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{CONFIG_NAME}}"
    
    # If no config provided, use shared fzf selector for checksum configs only
    if [ -z "$CONFIG_NAME" ]; then
        CONFIG_NAME=$(just _fzf-select-config "checksum" "checksum")
        if [ "$?" -ne 0 ] || [ -z "$CONFIG_NAME" ]; then
            echo "❌ No selection made"
            exit 1
        fi
        echo "Selected: $CONFIG_NAME"
        echo ""
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
# REMOVED: test-android-reset
_removed_test_android_reset CONFIG_NAME="":
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_NAME="{{CONFIG_NAME}}"
    
    # If no config provided, use shared fzf selector for checksum configs only  
    if [ -z "$CONFIG_NAME" ]; then
        CONFIG_NAME=$(just _fzf-select-config "checksum" "checksum")
        if [ "$?" -ne 0 ] || [ -z "$CONFIG_NAME" ]; then
            echo "❌ No selection made"
            exit 1
        fi
        echo "Selected: $CONFIG_NAME"
        echo ""
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
# REMOVED: test-android-list-checksum
_removed_test_android_list_checksum:
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

# REMOVED: test-all-android
_removed_test_all_android:
    echo "🚀 Complete Test Suite - Full system validation"
    just _test-list-android default-all

# Universal test command - Interactive chooser (no args) or direct execution (with TARGET)
# No args: Shows all debug configs and test lists with descriptions for easy selection
# With args: Direct execution like test-android-target (configs, wildcards, actions, test lists)
# REMOVED: test-android
_removed_test_android TARGET="" DURATION="30" NO_RESTART="false":
    #!/usr/bin/env bash
    
    # If arguments provided, use direct execution mode
    if [ -n "{{TARGET}}" ]; then
        echo "🎯 Direct execution mode: {{TARGET}}"
        just test-android-target "{{TARGET}}" "{{DURATION}}" "{{NO_RESTART}}"
        exit $?
    fi
    
    # Use shared fzf selection for all configs
    selected=$(just _fzf-select-config "android" "all")
    if [ "$?" -eq 0 ] && [ -n "$selected" ]; then
        echo "Running: just test-android-target '$selected'"
        just test-android-target "$selected" "{{DURATION}}" "{{NO_RESTART}}"
    else
        echo "❌ No selection made"
        exit 1
    fi

# REMOVED: test-android-manual
_removed_test_android_manual:
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
# REMOVED: _test-smoke-android
_removed_test_smoke_android:
    echo "⚡ Quick Smoke Test - 30 seconds essential validation"
    just _test-config-android smoke-test

# REMOVED: _test-development-android
_removed_test_development_android:
    echo "🔧 Development Workflow - Daily development cycle"
    just _test-list-android development-workflow

# REMOVED: _test-production-android
_removed_test_production_android:
    echo "🚀 Production Ready - Comprehensive release validation"
    just _test-list-android production-ready



# List available test lists
# REMOVED: list-test-lists
_removed_list_test_lists:
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
# REMOVED: list-test-lists
_removed_list_test_lists-matching PATTERN:
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

# Log analysis and token efficiency guide
