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
l:
    @just -l
# Comprehensive help system for all commands
help:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🚀 GameTwo Development Environment"
    echo "=================================="
    echo ""
    echo "⚡ DAILY DEVELOPMENT"
    echo "  just hotreload-ios-iphone        # iOS hot reload (5-10 sec) ✨"
    echo "  just hotreload-ios-ipad          # iOS hot reload (5-10 sec) ✨"
    echo "  just fastbuild-android           # Android fast build (30-60 sec) ⚡"
    echo "  just run-desktop                 # Desktop (instant) 🚀"
    echo ""
    echo "🏗️  BUILD COMMANDS"
    echo "  just build-all                   # Everything for both platforms (40 min)"
    echo "  just build-all-android           # Android only (20 min)"
    echo "  just build-all-ios               # iOS only (20 min)"
    echo "  just build-status                # Check what's built"
    echo ""
    echo "📦 QUICK BUILDS (Skip editor/templates)"
    echo "  just quick-build-android         # Android APK + AAB (2-3 min)"
    echo "  just quick-build-ios             # iOS project (2-3 min)"
    echo "  just quick-build-all             # Both platforms (5-10 min)"
    echo ""
    echo "🔥 HOT UPDATES"
    echo "  just hotreload-ios-iphone        # Replace iOS game data (5-10 sec)"
    echo "  just hotreload-ios-ipad          # Replace iOS game data (5-10 sec)"
    echo "  just hotconfig-android <config>  # Push config only (2 sec!)"
    echo ""
    echo "🚀 LAUNCH COMMANDS"
    echo "  just launch-android              # Launch existing Android app"
    echo "  just launch-ios-iphone           # Launch existing iPhone app"
    echo "  just launch-ios-ipad             # Launch existing iPad app"
    echo "  just restart-android-app         # Force restart Android app"
    echo ""
    echo "🐛 DEBUG CONFIGS"
    echo "  just push-config <config>        # Push config to user:// (2 sec!) ⚡ RECOMMENDED"
    echo "  just push-config-restart <config># Push + restart app (5 sec!) 🚀 RECOMMENDED"
    echo "  just config-status               # Check current config status"
    echo "  just config-list                 # List available configs"
    echo "  just hotconfig-android <config>  # Hot push config (legacy, 2 sec!)"
    echo "  just config-clear                # Clear external config"
    echo ""
    echo "🧪 SMART TESTING"
    echo "  just config-test-smart <config>  # Smart test with pass/fail detection (30 sec)"
    echo "  just test-smart-database         # Test database configuration" 
    echo "  just test-smart-system           # Test system configuration"
    echo "  just test-all-configs            # Run all test configurations"
    echo ""
    echo "🛠️  SETUP"
    echo "  just templates-all               # Build all templates"
    echo "  just setup-android               # Setup Android environment"
    echo "  just build-editor                # Build custom Godot editor"
    echo ""
    echo "📖 DETAILED HELP"
    echo "  just help-timing                 # Platform timing comparison"
    echo "  just help-build                  # Build system guide"
    echo "  just help-android                # Android workflow guide"
    echo "  just help-ios                    # iOS workflow guide"
    echo "  just help-workflows              # Common workflow patterns"
    echo ""
    echo "📋 just --list  🔍 just show <cmd>  💡 just help-timing"

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

# Alias for check command (mentioned in project docs)
validate OUTPUT="console": (check OUTPUT)

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
export-apk-android:
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
fastbuild-android:
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
launch-android:
    @echo "🚀 Launching Android app..."
    @adb -s {{ANDROID_DEVICE_ID}} shell am start -a android.intent.action.MAIN -n {{ANDROID_PACKAGE_NAME}}/com.godot.game.GodotApp
    @echo "✅ App launched!"

# Force stop and restart the Android app
restart-android-app:
    @echo "🔄 Restarting Android app..."
    @adb -s {{ANDROID_DEVICE_ID}} shell am force-stop {{ANDROID_PACKAGE_NAME}}
    @sleep 1
    @adb -s {{ANDROID_DEVICE_ID}} shell am start -a android.intent.action.MAIN -n {{ANDROID_PACKAGE_NAME}}/com.godot.game.GodotApp
    @echo "✅ App restarted!"

# Complete Android development workflow with optional debug config
iterate-android CONFIG="current":
    @echo "🔄 Android development iteration..."
    just fastbuild-android
    @if [ "{{CONFIG}}" != "current" ]; then just hotconfig-android {{CONFIG}}; fi

# Hot config push for Android (2 sec!)
hotconfig-android CONFIG_NAME:
    @echo "🔥 Hot config update for Android (2 sec)..."
    @adb -s {{ANDROID_DEVICE_ID}} push \
        project/debug_configs/{{CONFIG_NAME}}.json \
    /sdcard/Android/data/{{ANDROID_PACKAGE_NAME}}/files/debug_startup_actions.json
    @just restart-android-app
    @echo "✅ Config updated without rebuild!"


# ================================ 
# CONSOLIDATED CONFIG COMMANDS (RECOMMENDED)
# ================================

# Push config to device user:// directory (no restart) - FAST: 2 seconds
push-config CONFIG_NAME:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "📱 Pushing config to Android device..."
    
    CONFIG_FILE="project/debug_configs/{{CONFIG_NAME}}.json"
    
    # Verify config file exists
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ Config file not found: $CONFIG_FILE"
        exit 1
    fi
    
    # Verify device connection
    if ! adb -s {{ANDROID_DEVICE_ID}} shell echo "Connected" >/dev/null 2>&1; then
        echo "❌ Device {{ANDROID_DEVICE_ID}} not connected"
        exit 1
    fi
    
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
    echo "💡 Use 'just push-config-restart {{CONFIG_NAME}}' to push + restart immediately"

# Push config to device AND restart app - FAST: 5 seconds 
push-config-restart CONFIG_NAME:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🚀 Pushing config and restarting app..."
    
    # First push the config (reuse the push-config command)
    just push-config {{CONFIG_NAME}}
    
    echo ""
    echo "🔄 Restarting app to apply new config..."
    just restart-android-app
    
    echo "✅ Config pushed and app restarted!"
    echo "💡 Monitor with: just test-android-debug-startup {{CONFIG_NAME}}"

# Check current config status
config-status:
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
    echo "  just push-config <config>        # Push config (no restart)"
    echo "  just push-config-restart <config># Push config + restart app"
    echo "  just restart-android-app         # Just restart app"

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
config-set CONFIG_NAME:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CONFIG_FILE="project/debug_configs/{{CONFIG_NAME}}.json"
    TARGET_FILE="project/debug_startup_actions.json"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ Config file not found: $CONFIG_FILE"
        echo "📋 Available configs:"
        ls -1 project/debug_configs/*.json 2>/dev/null | xargs -I {} basename {} .json | sed 's/^/  - /' || echo "  (none found - run 'just config-setup' first)"
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
config-clear:
    #!/usr/bin/env bash
    set -euo pipefail
    
    ANDROID_PATH="/sdcard/Android/data/{{ANDROID_PACKAGE_NAME}}/files"
    REMOTE_CONFIG="$ANDROID_PATH/debug_startup_actions.json"
    
    echo "🗑️  Removing external debug config..."
    adb -s {{ANDROID_DEVICE_ID}} shell "rm -f $REMOTE_CONFIG" 2>/dev/null || true
    echo "✅ External config removed - app will use embedded config"
    echo "💡 Run 'just restart-android-app' to apply changes"

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
    echo "  just restart-with-config <name>     # Quick testing (external config)"
    echo "  just config-set <name>        # Update embedded config"

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

# Smart test with automatic pass/fail determination and unique test IDs
config-test-smart CONFIG_NAME DURATION="30":
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Configuration
    CONFIG_NAME="{{CONFIG_NAME}}"
    DURATION="{{DURATION}}"
    ANDROID_DEVICE_ID="${ANDROID_DEVICE_ID:-{{ANDROID_DEVICE_ID}}}"
    ANDROID_PACKAGE_NAME="${ANDROID_PACKAGE_NAME:-{{ANDROID_PACKAGE_NAME}}}"
    
    # Generate unique test ID
    TEST_ID="test_$(date +%Y%m%d_%H%M%S)_$(head -c 4 /dev/urandom | xxd -p)"
    
    echo "🧪 Smart Test: $CONFIG_NAME"
    echo "🆔 Test ID: $TEST_ID"
    echo "⏱️  Duration: $DURATION seconds"
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
    
    if [ ! -f "project/debug_configs/$CONFIG_NAME.json" ]; then
        echo "❌ Config file not found: project/debug_configs/$CONFIG_NAME.json"
        exit 1
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
    jq --arg test_id "$TEST_ID" '. + {"test_metadata": {"test_id": $test_id, "config": "'$CONFIG_NAME'", "timestamp": "'$timestamp'"}}' \
        "project/debug_configs/$CONFIG_NAME.json" > "$enhanced_config"
    
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
    
    echo "🚀 Starting test..."
    # Launch app
    adb -s "$ANDROID_DEVICE_ID" shell am start -a android.intent.action.MAIN -n "$ANDROID_PACKAGE_NAME"/com.godot.game.GodotApp
    
    # Monitor test execution
    echo "📊 Monitoring test execution..."
    echo "   Looking for test ID: $TEST_ID"
    
    log_file="$test_dir/test_logs.log"
    test_result=1
    test_complete=false
    success_count=0
    failure_count=0
    startup_count=0
    
    # Start log capture
    adb -s "$ANDROID_DEVICE_ID" logcat -v time > "$log_file" 2>/dev/null &
    LOGCAT_PID=$!
    
    # Monitor for completion
    for i in $(seq 1 $DURATION); do
        sleep 1
        
        if [ -f "$log_file" ]; then
            # Check for test completion
            if grep -q "DEBUG_TEST_COMPLETE.*$TEST_ID" "$log_file" 2>/dev/null; then
                test_complete=true
                break
            fi
            
            # Count interim results (clean output)
            success_count=$(grep -c "DEBUG_TEST_SUCCESS.*$TEST_ID" "$log_file" 2>/dev/null | head -1 | tr -d '\n\r' || echo "0")
            failure_count=$(grep -c "DEBUG_TEST_FAILURE.*$TEST_ID" "$log_file" 2>/dev/null | head -1 | tr -d '\n\r' || echo "0")
        fi
        
        # Progress indicator
        if [ $((i % 5)) -eq 0 ]; then
            echo "   Progress: $i/${DURATION}s (✅$success_count ❌$failure_count)"
        fi
    done
    
    # Stop log capture
    kill $LOGCAT_PID 2>/dev/null || true
    wait $LOGCAT_PID 2>/dev/null || true
    
    echo ""
    echo "📋 Test Results Analysis"
    echo "========================"
    
    # Parse final results
    if [ -f "$log_file" ]; then
        # Parse final results (clean output)
        success_count=$(grep -c "DEBUG_TEST_SUCCESS.*$TEST_ID" "$log_file" 2>/dev/null | head -1 | tr -d '\n\r' || echo "0")
        failure_count=$(grep -c "DEBUG_TEST_FAILURE.*$TEST_ID" "$log_file" 2>/dev/null | head -1 | tr -d '\n\r' || echo "0")
        startup_count=$(grep -c "debug.*startup.*$TEST_ID\|DEBUG_TEST_START.*$TEST_ID" "$log_file" 2>/dev/null | head -1 | tr -d '\n\r' || echo "0")
        
        # Ensure variables are integers (strip any whitespace/newlines and validate)
        success_count=$(echo "$success_count" | tr -d ' \t\n\r' | grep -E '^[0-9]+$' || echo "0")
        failure_count=$(echo "$failure_count" | tr -d ' \t\n\r' | grep -E '^[0-9]+$' || echo "0")
        startup_count=$(echo "$startup_count" | tr -d ' \t\n\r' | grep -E '^[0-9]+$' || echo "0")
        
        echo "🆔 Test ID: $TEST_ID"
        echo "📊 Startup events: $startup_count"
        echo "📊 Successful actions: $success_count"
        echo "📊 Failed actions: $failure_count"
        
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
            echo "⏰ Test timed out"
            if [ "$failure_count" -gt 0 ]; then
                echo "❌ OVERALL RESULT: FAIL (timeout + failures)"
                test_result=1
            else
                echo "⚠️  OVERALL RESULT: TIMEOUT"
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
    
    if [ $test_result -eq 0 ]; then
        echo "🎉 Test PASSED"
    else
        echo "💥 Test FAILED"
    fi
    
    exit $test_result

# Database-specific smart test (convenience recipe)
test-smart-database DURATION="30":
    just config-test-smart database-testing {{DURATION}}

# System-specific smart test (convenience recipe)  
test-smart-system DURATION="30":
    just config-test-smart system-testing {{DURATION}}

# Run all standard test configurations
test-all-configs:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🧪 Running all test configurations..."
    echo ""
    
    configs=("system-testing" "database-testing" "minimal-testing" "performance-testing")
    failed_configs=()
    
    for config in "${configs[@]}"; do
        echo "Testing configuration: $config"
        if just config-test-smart "$config" 30; then
            echo "✅ $config PASSED"
        else
            echo "❌ $config FAILED"
            failed_configs+=("$config")
        fi
        echo ""
    done
    
    echo "📋 Final Results:"
    echo "=================="
    for config in "${configs[@]}"; do
        if [[ " ${failed_configs[*]} " =~ " $config " ]]; then
            echo "❌ $config: FAILED"
        else
            echo "✅ $config: PASSED"  
        fi
    done
    
    if [ ${#failed_configs[@]} -eq 0 ]; then
        echo ""
        echo "🎉 All configurations PASSED!"
        exit 0
    else
        echo ""
        echo "💥 ${#failed_configs[@]} configuration(s) FAILED"
        exit 1
    fi

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
    echo "📱 DEVELOPMENT LOOP (FASTEST):"
    echo "  # Initial setup:"
    echo "  just fastbuild-android               # Full workflow (30-60 sec)"
    echo ""
    echo "  # Rapid iteration:"
    echo "  just restart-with-config testing     # Quick config changes"
    echo "  just restart-android-app             # Just restart app"
    echo "  just hotconfig-android <config>      # Hot push config (2 sec!)"
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
    echo "  just build-install-ios                         # Export game data + build with Xcode"
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
    echo "    just build-install-ios                       # Automated: export + build"
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
    echo "  just iterate-android gameplay-testing # Test with specific config"
    echo "  just quick-test system-testing       # Quick config iteration"
    echo ""
    echo "🔧 CONFIGURATION MANAGEMENT:"
    echo "  just config-setup                    # Create sample debug configurations"
    echo "  just config-list                     # List all available configs"
    echo "  just config-set performance-testing  # Set embedded debug config"
    echo "  just push-debug-config gameplay-testing # Push config to device (quick testing)"
    echo "  just config-clear                    # Clear external config, use embedded"
    echo ""
    echo "🔄 DEBUG WORKFLOW PATTERNS:"
    echo ""
    echo "  🎯 RAPID CONFIG ITERATION:"
    echo "    just fastbuild-android             # Initial setup"
    echo "    just restart-with-config testing   # Test config changes (fast)"
    echo "    just quick-test performance        # Test different config"
    echo "    just test-android-debug-startup 30 # Monitor results"
    echo ""
    echo "  🧪 SYSTEMATIC TESTING:"
    echo "    just config-list                   # See all available configs"
    echo "    just iterate-android gameplay-testing # Test with specific config"
    echo "    just test-android-debug-startup performance-testing # Test debug startup"
    echo "    just check-android-debug-status    # Check device status"
    echo ""
    echo "  📊 PERFORMANCE ANALYSIS:"
    echo "    just iterate-android performance-testing # Launch with perf config"
    echo "    just test-android-debug-startup 60 # Extended monitoring"
    echo "    just restart-with-config baseline   # Compare with baseline"
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
    echo "  ✅ Use restart-with-config for rapid config iteration (fastest)"
    echo "  ✅ Use iterate-android with config for complete testing"
    echo "  ✅ Always run test-android-debug-startup to see immediate feedback"
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
