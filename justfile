#!/usr/bin/env just --justfile

# Main build Justfile for Godot 4 Projects
# Import other Justfiles
import "justfile-run.justfile"
import "justfile-cicd.justfile"
import "justfile-support.justfile"
#import "justfile-test.justfile"
# Set default shell
set shell := ["bash", "-c"]

# Environment variables
export GAME_NAME := env_var_or_default("CI_PROJECT_NAME", "gametwo")
export GODOT_VERSION := "4.0"
export GODOT_BUILD_VERSION := "4.3.rc"
export GODOT_EXECUTABLE := "godot.macos.editor.arm64"  # For Apple Silicon Macs
export PROJECT_PATH := justfile_directory() + "/project"
export ANDROID_SDK_PATH := env_var_or_default("ANDROID_SDK_PATH", "~/Library/Android/sdk")
export ANDROID_NDK_PATH := env_var_or_default("ANDROID_NDK_PATH", ANDROID_SDK_PATH + "/ndk/25.1.8937393")
export ANDROID_PACKAGE_NAME := env_var_or_default("ANDROID_PACKAGE_NAME", "com.primaryhive." + GAME_NAME)
export IOS_BUNDLE_IDENTIFIER := env_var_or_default("IOS_BUNDLE_IDENTIFIER", "com.primaryhive." + GAME_NAME)
export IOS_IPHONE_DEVICE_ID := env_var_or_default("IOS_IPHONE_DEVICE_ID", "C9A2C197-B5E7-5B83-86C2-2D1EDF2CEB48")
export IOS_IPAD_DEVICE_ID := env_var_or_default("IOS_IPAD_DEVICE_ID", "A4045434-B5F5-48B5-8654-C128A403149A")
export KEYSTORE_PATH := env_var_or_default("KEYSTORE_PATH", "./keys/" + GAME_NAME + ".keystore")
export KEYSTORE_PASSWORD := env_var_or_default("KEYSTORE_PASSWORD", "lovegametwo")
export KEY_PASSWORD := env_var_or_default("KEY_PASSWORD", "lovegametwo")
export APPLE_TEAM_ID := env_var_or_default("APPLE_TEAM_ID", "123")
export APPLE_ID := env_var_or_default("APPLE_ID", "123")
export APP_STORE_CONNECT_API_KEY_PATH := env_var_or_default("APP_STORE_CONNECT_API_KEY_PATH", "123")
export IOS_PROVISIONING_PROFILE_UUID := env_var_or_default("IOS_PROVISIONING_PROFILE_UUID", "123")
export ANDROID_DEVICE_IP := env_var_or_default("ANDROID_DEVICE_IP", "192.168.1.100")
export ANDROID_DEVICE_ID := env_var_or_default("ANDROID_DEVICE_ID", "246d2c533a037ece")
export ANDROID_GRADLE_DIR := "build/gradle"

# Godot submodule settings
GODOT_REPO := "https://github.com/godotengine/godot.git"
GODOT_BRANCH := "gametwo"  # Replace with your custom branch name
GODOT_SUBMODULE_PATH := "godot"

# Utility functions
timestamp := `date +%Y%m%d%H%M%S`
jobs := `sysctl -n hw.logicalcpu`
    
default:
    @just help
c:
    @just --choose
    
# Comprehensive help system for all commands
help:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🚀 GameTwo Development Environment"
    echo "=================================="
    echo ""
    echo "⚡ DAILY COMMANDS"
    echo "  just android-dev [config]        # Complete Android workflow"
    echo "  just ios-dev                     # Complete iOS workflow"  
    echo "  just check [log]                 # Validate GDScript code"
    echo "  just open                        # Open Godot editor"
    echo ""
    echo "📱 RUN ON DEVICES"
    echo "  just run-desktop                 # Run on desktop"
    echo "  just run-android                 # Run on Android (automated)"
    echo "  just run-iphone                  # Run on iPhone"
    echo "  just run-ipad                    # Run on iPad"
    echo "  just android-dev                 # Complete Android workflow"
    echo ""
    echo "🏃 DEVELOPMENT WORKFLOWS"
    echo ""
    echo "  📱 LEVEL 1: Launch Only (1-2 sec)"
    echo "    just run-desktop               # Godot editor"
    echo "    just run-iphone                # iPhone (existing app)"
    echo "    just run-ipad                  # iPad (existing app)"
    echo "    just run-android               # Android (install + launch)"
    echo ""
    echo "  🔄 LEVEL 2: Quick Updates (5-10 sec)"  
    echo "    just update-content-iphone     # Update game data + launch"
    echo "    just update-content-ipad       # Update game data + launch"
    echo ""
    echo "  🔨 LEVEL 3: Full Rebuild (2-5 min)"
    echo "    just build-install-ios         # Complete iOS rebuild"
    echo "    just android-dev               # Complete Android workflow"
    echo ""
    echo "🤖 ANDROID (Fully Automated)"
    echo "  just android-export-apk          # Export APK (android-export)"
    echo "  just android-build-install       # Build & install (android-install)"
    echo "  just android-launch              # Launch app (android-run)"
    echo "  just android-restart             # Restart app"
    echo "  just android-quick [config]      # Quick config testing"
    echo "  just android-logs [duration]     # Monitor logs"
    echo ""
    echo "🍎 iOS (Manual Steps Required)"  
    echo "  just ios-export-pck              # Export game data (ios-export)"
    echo "  just ios-build                   # Build with Xcode (ios-build)"
    echo "  just ios-launch-help             # Launch instructions"
    echo "  just ios-update-pck              # Update game data (save-ios-to-app)"
    echo ""
    echo "🐛 DEBUG CONFIGS"
    echo "  just config-list                 # List configs"
    echo "  just config-push <n>          # Test config quickly"
    echo "  just config-clear                # Clear config"
    echo ""
    echo "🚀 PRODUCTION"
    echo "  just android-export-prod apk     # Production APK"
    echo "  just android-export-prod aab     # Play Store bundle"
    echo "  just ios-build                   # iOS build for Archive"
    echo ""
    echo "🛠️  SETUP"
    echo "  just templates-all               # Build all templates"
    echo "  just setup-android               # Setup Android environment"
    echo "  just build-editor                # Build custom Godot editor"
    echo ""
    echo ""
    echo "📖 DETAILED HELP"
    echo "  just help-run                    # Run commands guide"
    echo "  just help-android                # Android workflow guide"
    echo "  just help-ios                    # iOS workflow guide"
    echo "  just help-debug                  # Debug config guide"
    echo "  just help-production             # Production build guide"
    echo "  just help-templates              # Template setup guide"
    echo "  just help-workflows              # Common workflow patterns"
    echo ""
    echo "📋 just --list  🔍 just show <cmd>  💡 just help-workflows"

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

# Build Godot editor
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

# Legacy alias for templates-all
build-templates: templates-all

# build macos
build-macos-templates: validate-env
    @echo "Building export templates..."
    cd {{GODOT_SUBMODULE_PATH}} && scons platform=macos target=template_debug --jobs={{jobs}}
    cd {{GODOT_SUBMODULE_PATH}} && scons platform=macos target=template_release --jobs={{jobs}}
    mkdir -p templates
    cp {{GODOT_SUBMODULE_PATH}}/bin/godot.macos.template_debug.* templates/
    cp {{GODOT_SUBMODULE_PATH}}/bin/godot.macos.template_release.* templates/

# Run Godot editor
open:
    @echo "Running Godot editor..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --editor # --verbose --debug

# Legacy alias for open command
edit: open

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
        # Remove previous log file to avoid confusion with old errors
        rm -f validation_errors.log
        LOG_REDIRECT="> validation_errors.log 2>&1"
    else
        echo "Validating GDScript code..."
        LOG_REDIRECT=""
    fi
    
    # Start the Godot process and save its PID
    if [[ "{{OUTPUT}}" == "log" ]]; then
        ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --headless --close --check-only --debug --verbose > validation_errors.log 2>&1 &
    else
        ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --headless --check-only --verbose --debug &
    fi
    VALIDATION_PID=$!
    
    echo "Started validation process with PID: $VALIDATION_PID"
    
    # Wait for up to 90 seconds for the process to complete naturally
    TIMEOUT=90
    for ((i=1; i<=TIMEOUT; i++)); do
        if ! ps -p $VALIDATION_PID > /dev/null 2>&1; then
            echo "Validation process completed after $i seconds"
            if [[ "{{OUTPUT}}" == "log" ]]; then
                echo "Validation complete. Errors saved to validation_errors.log"
            else
                echo "Validation complete. Any errors will be shown above."
            fi
            exit 0
        fi
        
        # Print a progress message every 15 seconds
        if [ $((i % 15)) -eq 0 ]; then
            echo "Validation still running after $i seconds..."
        fi
        
        sleep 1
    done
    
    # If we get here, the process is still running after the timeout
    if ps -p $VALIDATION_PID > /dev/null 2>&1; then
        echo "Validation process (PID: $VALIDATION_PID) timed out after $TIMEOUT seconds. Terminating..."
        kill $VALIDATION_PID 2>/dev/null || true
        
        # Give it a moment to terminate gracefully
        sleep 2
        
        # Force kill if still running
        if ps -p $VALIDATION_PID > /dev/null 2>&1; then
            echo "Process didn't terminate gracefully. Forcing termination..."
            kill -9 $VALIDATION_PID 2>/dev/null || true
        fi
        echo "Validation process terminated due to timeout."
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

# Legacy alias for setup-android
install-android-template: setup-android

# Build and export for Android
build-android BUILD_TYPE="apk": pre-build
    @echo "Building and exporting for Android ({{BUILD_TYPE}})..."
    echo $ANDROID_KEYSTORE | base64 -d > android.keystore
    
    # Debug build
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} \
        --export-debug "Android {{BUILD_TYPE}}" \
        ../export/android/{{GAME_NAME}}_debug.{{BUILD_TYPE}} --headless
    
    # Release build
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} \
        --export-release "Android {{BUILD_TYPE}}" \
        ../export/android/{{GAME_NAME}}.{{BUILD_TYPE}} --headless

# Alias commands for easier use
build-android-apk: (build-android "apk")
build-android-aab: (build-android "aab")

# ================================
# ANDROID DEVELOPMENT WORKFLOW
# ================================

# Export complete Android APK file  
android-export-apk:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📦 Exporting complete Android APK..."
    
    # Export project files using Godot's export system
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --headless --export-debug "Android apk" \
        ../android_project_export.apk
    
    echo "✅ Android APK exported successfully"

# Build Android APK and install to device
android-build-install:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # First insert Firebase dependencies
    just insert-firebase-dependencies
    
    echo "🔨 Building Android APK with package: {{ANDROID_PACKAGE_NAME}}"
    
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
android-launch:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🚀 Launching {{ANDROID_PACKAGE_NAME}}..."
    adb -s {{ANDROID_DEVICE_ID}} shell am start -a android.intent.action.MAIN -n {{ANDROID_PACKAGE_NAME}}/com.godot.game.GodotApp
    echo "✅ App launched!"


# Force stop and restart the Android app
android-restart:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔄 Restarting {{ANDROID_PACKAGE_NAME}}..."
    adb -s {{ANDROID_DEVICE_ID}} shell am force-stop {{ANDROID_PACKAGE_NAME}}
    sleep 1
    adb -s {{ANDROID_DEVICE_ID}} shell am start -a android.intent.action.MAIN -n {{ANDROID_PACKAGE_NAME}}/com.godot.game.GodotApp
    echo "✅ App restarted!"

# Legacy aliases for android-restart command
restart: android-restart
restart-android-app: android-restart

# Complete Android workflow: export APK → build & install → launch
android-full-workflow: android-export-apk android-build-install android-launch


# Complete Android development workflow with optional debug config and testing
android-dev CONFIG="current" TEST="false":
    just android-full-workflow
    @if [ "{{CONFIG}}" != "current" ]; then just config-push {{CONFIG}}; fi
    just android-restart
    @if [ "{{TEST}}" == "true" ]; then just android-test {{CONFIG}}; fi


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
    echo "💡 Use 'just set-debug-config <name>' to switch configs"
    echo "   Example: just set-debug-config system-testing"

# Legacy alias for config-setup
setup-debug-configs: config-setup

# Set a specific debug configuration (updates embedded config)
config-set CONFIG_NAME:

# Legacy alias for config-set
set-debug-config CONFIG_NAME: (config-set CONFIG_NAME)
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_FILE="project/debug_configs/{{CONFIG_NAME}}.json"
    TARGET_FILE="project/debug_startup_actions.json"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ Config file not found: $CONFIG_FILE"
        echo "📋 Available configs:"
        ls -1 project/debug_configs/*.json 2>/dev/null | xargs -I {} basename {} .json | sed 's/^/  - /' || echo "  (none found - run 'just setup-debug-configs' first)"
        exit 1
    fi
    
    echo "📝 Setting debug config to: {{CONFIG_NAME}}"
    echo "📄 Config content:"
    cat "$CONFIG_FILE" | jq .
    
    # Copy config to main debug startup file
    cp "$CONFIG_FILE" "$TARGET_FILE"
    
    echo "✅ Debug config updated!"
    echo "💡 Next steps:"
    echo "   1. For development: just push-debug-config {{CONFIG_NAME}} && just restart-android-app"
    echo "   2. For full rebuild: just save-android-project && just install-android-app"

# Push debug config to Android device (external config for quick testing)
push-debug-config CONFIG_NAME:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_FILE="project/debug_configs/{{CONFIG_NAME}}.json"
    ANDROID_PATH="/sdcard/Android/data/{{ANDROID_PACKAGE_NAME}}/files"
    REMOTE_CONFIG="$ANDROID_PATH/debug_startup_actions.json"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ Config file not found: $CONFIG_FILE"
        echo "📋 Available configs:"
        ls -1 project/debug_configs/*.json 2>/dev/null | xargs -I {} basename {} .json | sed 's/^/  - /' || echo "  (none found)"
        exit 1
    fi
    
    # Verify device connection
    if ! adb -s {{ANDROID_DEVICE_ID}} shell echo "Connected" >/dev/null 2>&1; then
        echo "❌ Device {{ANDROID_DEVICE_ID}} not connected"
        exit 1
    fi
    
    # Create app data directory
    adb -s {{ANDROID_DEVICE_ID}} shell "mkdir -p $ANDROID_PATH" 2>/dev/null || true
    
    echo "📱 Pushing debug config '{{CONFIG_NAME}}' to device..."
    echo "📄 Config content:"
    cat "$CONFIG_FILE" | jq .
    
    # Push config to device
    adb -s {{ANDROID_DEVICE_ID}} push "$CONFIG_FILE" "$REMOTE_CONFIG"
    
    echo "✅ Config pushed to device!"
    echo "📱 Location: $REMOTE_CONFIG"
    echo "💡 Run 'just restart-android-app' to apply changes"

# Set config and restart app in one command (for rapid iteration)
restart-with-config CONFIG_NAME:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔄 Setting config '{{CONFIG_NAME}}' and restarting app..."
    just push-debug-config {{CONFIG_NAME}}
    just restart-android-app
    echo "✅ App restarted with config: {{CONFIG_NAME}}"

# Remove external debug config (fall back to embedded config)
clear-external-debug-config:
    #!/usr/bin/env bash
    set -euo pipefail
    
    ANDROID_PATH="/sdcard/Android/data/{{ANDROID_PACKAGE_NAME}}/files"
    REMOTE_CONFIG="$ANDROID_PATH/debug_startup_actions.json"
    
    echo "🗑️  Removing external debug config..."
    adb -s {{ANDROID_DEVICE_ID}} shell "rm -f $REMOTE_CONFIG" 2>/dev/null || true
    echo "✅ External config removed - app will use embedded config"
    echo "💡 Run 'just restart-android-app' to apply changes"

# List available debug configurations
list-debug-configs:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📋 Available debug configurations:"
    echo ""
    
    if [ ! -d "project/debug_configs" ]; then
        echo "❌ No debug configs directory found"
        echo "💡 Run 'just setup-debug-configs' to create sample configs"
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
    echo "  just restart-with-config <name>     # Quick testing (external config)"
    echo "  just set-debug-config <name>        # Update embedded config"

# ================================
# DEBUG TESTING & MONITORING
# ================================

# Test debug startup system with current configuration
test-android-debug-startup CONFIG_NAME="current":
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "=== Android Debug Startup Test ==="
    echo "Device: {{ANDROID_DEVICE_ID}}"
    echo "Package: {{ANDROID_PACKAGE_NAME}}"
    echo "Config: {{CONFIG_NAME}}"
    echo ""
    
    # Verify device and app
    if ! adb -s {{ANDROID_DEVICE_ID}} shell echo "Connected" >/dev/null 2>&1; then
        echo "❌ Device not connected"
        exit 1
    fi
    
    if ! adb -s {{ANDROID_DEVICE_ID}} shell pm list packages | grep -q "{{ANDROID_PACKAGE_NAME}}"; then
        echo "❌ App not installed. Run 'just install-android-app' first"
        exit 1
    fi
    
    # Show current config
    if [ "{{CONFIG_NAME}}" != "current" ]; then
        echo "📄 Testing with config: {{CONFIG_NAME}}"
        cat "project/debug_configs/{{CONFIG_NAME}}.json" | jq .
    else
        echo "📄 Current embedded config:"
        if [ -f "project/debug_startup_actions.json" ]; then
            cat project/debug_startup_actions.json | jq .
        else
            echo "  (no config file found)"
        fi
    fi
    echo ""
    
    # Start monitoring
    echo "📊 Starting log monitoring..."
    LOG_FILE="android_debug_{{timestamp}}.log"
    adb -s {{ANDROID_DEVICE_ID}} logcat -v time -s 'System.out:*' 'GameTwo:*' 'GodotIO:*' > "$LOG_FILE" &
    LOGCAT_PID=$!
    
    # Restart app
    echo "🔄 Restarting app..."
    just restart-android-app
    
    # Wait and monitor
    echo "⏳ Monitoring for 15 seconds..."
    for i in {1..15}; do
        echo -n "."
        sleep 1
    done
    echo ""
    
    # Stop monitoring and show results
    kill $LOGCAT_PID 2>/dev/null || true
    
    echo "📋 Debug startup execution:"
    if [ -f "$LOG_FILE" ]; then
        grep -E "(debug.*startup|Actions retrieved|Executing.*action)" "$LOG_FILE" | tail -10 || echo "  (no debug startup activity found)"
        echo ""
        echo "💾 Full log: $LOG_FILE"
    fi

# Quick test with a specific config (push config + restart + monitor)
quick-test CONFIG_NAME:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🚀 Quick test with config: {{CONFIG_NAME}}"
    just restart-with-config {{CONFIG_NAME}}
    sleep 2
    just monitor-debug-logs 10

# Monitor Android debug logs in real-time
monitor-debug-logs DURATION="30":
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📱 Monitoring debug logs for {{DURATION}} seconds..."
    echo "Press Ctrl+C to stop early"
    echo ""
    
    timeout {{DURATION}} adb -s {{ANDROID_DEVICE_ID}} logcat -v time | \
    grep -E "(debug|startup|DebugStartup|GameTwo.*INFO)" --line-buffered || true
    
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
    echo "  just clear-external-debug-config    # Remove external, use embedded"
    echo "  just set-debug-config <name>        # Update embedded config"

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
    echo "  just run-iphone              # Launch existing iOS app"
    echo "  just run-iphone-debug        # Launch iOS app (debug)"
    echo "  just run-ipad                # Launch existing iOS app"
    echo "  just run-ipad-debug          # Launch iOS app (debug)"
    echo "  just run-android             # Install & launch Android APK"
    echo "  just run-android-debug       # Install & launch debug APK"
    echo ""
    echo "🔄 LEVEL 2: Quick Updates (5-10 seconds)"
    echo "  just update-content-iphone   # Export game data → update → launch"
    echo "  just update-content-ipad     # Export game data → update → launch"
    echo ""
    echo "🔨 LEVEL 3: Full Rebuild (2-5 minutes)"
    echo "  just build-install-ios       # Complete iOS project rebuild"
    echo "  just android-dev             # Complete Android workflow"
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
    echo "  Daily: just update-content-iphone    # Fast iteration"
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
    echo "  just android-dev                     # Complete build → install → run workflow"
    echo "  just android-dev gameplay-testing   # With debug config"
    echo "  just android-dev system-testing true # With debug config + monitoring"
    echo ""
    echo "🔧 STEP-BY-STEP COMMANDS:"
    echo "  1️⃣  just android-export-apk          # Export complete APK file (android-export)"
    echo "  2️⃣  just android-build-install       # Build APK with Gradle + install to device (android-install)"
    echo "  3️⃣  just android-launch              # Launch app on device via adb (android-run)"
    echo "  4️⃣  just android-restart             # Quick restart (for config changes)"
    echo ""
    echo "🐛 DEBUG CONFIGURATION WORKFLOW:"
    echo "  just config-list                     # See available debug configs"
    echo "  just android-quick system-testing    # Push config + restart (rapid iteration)"
    echo "  just config-push gameplay-testing    # Push specific config to device"
    echo "  just android-logs 30                 # Monitor device logs for 30 seconds"
    echo "  just android-status                  # Check device + app status"
    echo "  just android-test performance-testing # Test debug startup system"
    echo ""
    echo "📱 DEVELOPMENT LOOP (FASTEST):"
    echo "  # Initial setup:"
    echo "  just android-dev                     # Full workflow"
    echo ""
    echo "  # Rapid iteration:"
    echo "  just android-quick testing           # Quick config changes"
    echo "  just android-restart                 # Just restart app"
    echo "  just android-logs                    # Monitor what's happening"
    echo ""
    echo "🚀 PRODUCTION BUILDS:"
    echo "  just android-export-prod apk         # Production APK for testing"
    echo "  just android-export-prod aab         # App Bundle for Play Store"
    echo ""
    echo "🔍 TROUBLESHOOTING:"
    echo "  • Device not found: Check 'adb devices' and ANDROID_DEVICE_ID variable"
    echo "  • Install fails: Run 'adb -s {{ANDROID_DEVICE_ID}} uninstall {{ANDROID_PACKAGE_NAME}}'"
    echo "  • App won't start: Check 'just android-logs' for errors"
    echo "  • Gradle issues: Run 'just clean-android' then retry"
    echo ""

# iOS-specific help and workflow guide  
help-ios:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🍎 iOS Development Workflow Guide"
    echo "=================================="
    echo ""
    echo "📋 OVERVIEW:"
    echo "iOS development is MIXED AUTO/MANUAL - automation where possible, manual steps where required"
    echo "Reason: iOS security model requires manual interaction with Xcode/Simulator/iPhone/iPad"
    echo ""
    echo "⚡ QUICK START:"
    echo "  just ios-dev                         # Export game data + build with Xcode"
    echo "  just ios-launch-help                 # Get instructions for manual launch"
    echo ""
    echo "🔧 STEP-BY-STEP WORKFLOW:"
    echo "  1️⃣  just ios-export-pck              # ✅ AUTOMATED: Export game data (PCK file) (ios-export)"
    echo "  2️⃣  just ios-build                   # ✅ AUTOMATED: Build iOS project with Xcode (ios-build)"
    echo "  3️⃣  just ios-launch-help             # ⚠️  MANUAL: Shows launch instructions (new command)"
    echo "  4️⃣  [Manual] Open Xcode → Run        # ⚠️  MANUAL: Launch in Xcode or Simulator"
    echo ""
    echo "📱 DEVELOPMENT WORKFLOWS:"
    echo ""
    echo "  🎯 COMPLETE WORKFLOW:"
    echo "    just ios-dev                       # Automated: export + build"
    echo "    # Then manually: Open Xcode workspace and run"
    echo ""
    echo "  🔄 QUICK ITERATION (Game Changes Only):"
    echo "    just ios-export-pck                # Export new game data (ios-export)"
    echo "    just ios-update-pck                # Update data in built app (save-ios-to-app)"
    echo "    # Then manually: Restart app in Simulator"
    echo ""
    echo "  🏗️  CODE CHANGES (Requires Rebuild):"
    echo "    just ios-export-pck                # Export new game data (ios-export)"
    echo "    just ios-build                     # Rebuild iOS project (ios-build)"
    echo "    # Then manually: Run in Xcode"
    echo ""
    echo "🛠️  MANUAL STEPS EXPLAINED:"
    echo ""
    echo "  📂 LAUNCH iOS APP:"
    echo "    just ios-launch-help               # Shows these options:"
    echo "    • Option 1: open export/ios/{{GAME_NAME}}.xcworkspace"
    echo "    • Option 2: Use Xcode → Open → select workspace → Run"
    echo "    • Option 3: Deploy to device via Xcode (requires dev cert)"
    echo ""
    echo "  🔄 RESTART iOS APP:"
    echo "    just ios-restart-help              # Shows these options (new command):"
    echo "    • Simulator: Device → Restart"
    echo "    • Simulator: Stop app → Relaunch"  
    echo "    • Device: Force close → Relaunch"
    echo ""
    echo "🚀 PRODUCTION BUILDS:"
    echo "  just ios-build                       # Build iOS project"
    echo "  # Then manually: Xcode → Archive → Upload to App Store"
    echo ""
    echo "💡 iOS vs ANDROID DIFFERENCES:"
    echo "  📱 Android: Complete automation (adb handles everything)"
    echo "  🍎 iOS: Mixed automation (Apple security requires manual steps)"
    echo ""
    echo "  ✅ What's automated:"
    echo "    • Game data export (PCK files)"
    echo "    • Xcode project building"
    echo "    • Game data updates"
    echo ""
    echo "  ⚠️  What requires manual steps:"
    echo "    • App launching (Xcode/Simulator)"
    echo "    • App restarting (Simulator/Device)"
    echo "    • Device deployment (requires certificates)"
    echo "    • App Store submission (Xcode Archive)"
    echo ""
    echo "🔍 TROUBLESHOOTING:"
    echo "  • Build fails: Check Xcode project settings and certificates"
    echo "  • PCK not loading: Verify ios-update-pck path matches Xcode build"
    echo "  • Simulator issues: Device → Erase All Content and Settings"
    echo "  • Missing workspace: Run 'just ios-build' to regenerate"


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
    echo "  just android-dev gameplay-testing    # Test with specific config"
    echo "  just android-quick system-testing    # Quick config iteration"
    echo ""
    echo "🔧 CONFIGURATION MANAGEMENT:"
    echo "  just config-setup                    # Create sample debug configurations"
    echo "  just config-list                     # List all available configs"
    echo "  just config-set performance-testing  # Set embedded debug config"
    echo "  just config-push gameplay-testing    # Push config to device (quick testing)"
    echo "  just config-clear                    # Clear external config, use embedded"
    echo ""
    echo "🔄 DEBUG WORKFLOW PATTERNS:"
    echo ""
    echo "  🎯 RAPID CONFIG ITERATION:"
    echo "    just android-dev                   # Initial setup"
    echo "    just android-quick testing         # Test config changes (fast)"
    echo "    just android-quick performance     # Test different config"
    echo "    just android-logs 30               # Monitor results"
    echo ""
    echo "  🧪 SYSTEMATIC TESTING:"
    echo "    just config-list                   # See all available configs"
    echo "    just android-dev gameplay-testing true # Test with monitoring"
    echo "    just android-test performance-testing  # Test debug startup"
    echo "    just android-status                # Check device status"
    echo ""
    echo "  📊 PERFORMANCE ANALYSIS:"
    echo "    just android-dev performance-testing # Launch with perf config"
    echo "    just android-logs 60               # Extended monitoring"
    echo "    just android-quick baseline        # Compare with baseline"
    echo ""
    echo "📱 CONFIGURATION TYPES:"
    echo "  • gameplay-testing: Gameplay mechanics and features"
    echo "  • performance-testing: Performance optimizations and profiling"
    echo "  • system-testing: System integration and device testing"
    echo "  • network-testing: Network and connectivity testing"
    echo "  • database-testing: Database and persistence testing"
    echo ""
    echo "🔍 MONITORING & DEBUGGING:"
    echo "  just android-logs [duration]         # Monitor device logs"
    echo "  just android-status                  # Check device & app status"
    echo "  just android-test [config]           # Test debug startup system"
    echo "  just check log                       # Validate GDScript and log errors"
    echo ""
    echo "💡 BEST PRACTICES:"
    echo "  ✅ Use android-quick for rapid config iteration (fastest)"
    echo "  ✅ Use android-dev with config for complete testing"
    echo "  ✅ Always run android-logs to see immediate feedback"
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
    echo "    just android-restart               # Quick restart (fastest)"
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
    echo "    just ios-dev                       # Export + build"
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
    echo "    just ios-dev                       # Test iOS build"
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
    echo "  • Small changes: android-restart"
    echo "  • Config testing: android-quick"
    echo "  • Major changes: android-dev"
    echo "  • iOS changes: ios-dev + manual launch"
    echo "  • Bug hunting: check + logs + systematic testing"
    echo "  • Performance: performance-testing config"
    echo "  • Release prep: full validation + clean builds"


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

# Legacy alias for build-install-ios (DEPRECATED)
ios-dev: build-install-ios



# Full build and deploy process
build-all: validate-env
    @echo "Running full build and deploy process..."
    just install-deps
    just build-editor
    just build-templates
    just update-version
    #just format
    just insert-firebase-dependencies
    just build-android apk
    just build-android aab
    just ios-build

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
