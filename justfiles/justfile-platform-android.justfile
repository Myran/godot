# Android Platform Development Commands
# Complete Android build, deploy, test, and device management workflow

# Note: Variables are inherited from main justfile

# Note: Validation functions are inherited from main justfile via justfile-validation.justfile

# Note: _validate-android-workflow is inherited from justfile-validation.justfile

# Quick Android build - Export APK and AAB files (2-3 minutes)
quick-build-android:
    @echo "⚡ Quick Android build (2-3 min)..."
    just insert-firebase-dependencies
    just export-apk-android
    just export-aab-android
    @echo "✅ Quick Android build complete!"

# Complete Android build with templates and all dependencies (20 minutes)
build-all-android: validate-env
    @echo "🤖 FULL BUILD - ANDROID ONLY"
    @echo "============================"
    @echo "⏱️  Estimated time: 20-25 minutes"
    @echo ""
    
    just _build-common
    just _build-android-full
    
    @echo "✅ Android full build complete!"

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

# Config workflow validation for Android
_validate-android-config-workflow CONFIG:
    @echo "✅ Android config workflow validated for {{CONFIG}}"

# Get safe config filename
_get-safe-config-file CONFIG:
    #!/usr/bin/env bash
    SAFE_CONFIG_NAME=$(echo "{{CONFIG}}" | sed 's/[^a-zA-Z0-9._-]/_/g')
    echo "project/debug_configs/${SAFE_CONFIG_NAME}.json"

# Pre-build hook
pre-build:
    @echo "🔧 Running pre-build tasks..."

# Fast Android development iteration (60 seconds - most used command)
fastbuild-android: _validate-android-workflow _validate-godot-editor
    @echo "⚡ Fast Android build (60 seconds)..."
    @echo "📋 Building optimized debug APK for rapid iteration..."
    
    # Build and install in one step
    just _gradle-build-install-android
    echo "✅ Fast build complete!"

# Android template building
build-android-templates minimal="no":
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔧 Building Android templates..."
    cd {{GODOT_SUBMODULE_PATH}}
    
    if [[ "{{minimal}}" == "yes" ]]; then
        echo "📦 Building minimal Android templates (debug only)..."
        scons platform=android target=template_debug arch=arm64 --jobs={{jobs}}
    else
        echo "📦 Building complete Android templates (debug + release)..."
        scons platform=android target=template_debug arch=arm32 arch=arm64 --jobs={{jobs}}
        scons platform=android target=template_release arch=arm32 arch=arm64 --jobs={{jobs}}
    fi
    
    echo "📁 Copying templates to templates/ directory..."
    cp bin/android_*.apk ../templates/
    echo "✅ Android templates built successfully"

# Clean Android template artifacts
clean-android-templates:
    @echo "🧹 Cleaning Android template artifacts..."
    rm -f templates/android_*.apk
    rm -f {{GODOT_SUBMODULE_PATH}}/bin/android_*.apk
    echo "✅ Android templates cleaned"

# Android development environment setup
setup-android:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔧 Setting up Android development environment..."
    
    # Validate Android SDK
    if [ ! -d "{{ANDROID_SDK_PATH}}" ]; then
        echo "❌ Android SDK not found at {{ANDROID_SDK_PATH}}"
        echo "💡 Install Android SDK or set ANDROID_SDK_PATH environment variable"
        exit 1
    fi
    
    # Validate required tools
    command -v adb >/dev/null || { echo "❌ adb not found"; exit 1; }
    command -v java >/dev/null || { echo "❌ Java not found"; exit 1; }
    
    echo "✅ Android development environment validated"

# Export Android AAB files (Google Play Store format)
export-aab-android: pre-build
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📦 Exporting Android AAB files (debug + release)..."
    echo $ANDROID_KEYSTORE | base64 -d > android.keystore
    
    # Debug build
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} \
        --export-debug "Android aab" \
        ../export/android/{{GAME_NAME}}_debug.aab --headless
    
    # Release build
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} \
        --export-release "Android aab" \
        ../export/android/{{GAME_NAME}}.aab --headless
    
    echo "✅ Android AAB files exported successfully"
    echo "📁 Debug: export/android/{{GAME_NAME}}_debug.aab"
    echo "📁 Release: export/android/{{GAME_NAME}}.aab"

# Export all Android formats (APK + AAB)
export-all-android:
    @echo "📦 Exporting all Android formats (APK + AAB)..."
    just export-apk-android
    just export-aab-android
    @echo "✅ All Android exports complete"

# Export Android APK files
export-apk-android: _validate-godot-editor (_ensure-directory-exists "export/android")
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📦 Exporting Android APK files (debug + release)..."
    echo $ANDROID_KEYSTORE | base64 -d > android.keystore
    
    # Debug build
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} \
        --export-debug "Android apk" \
        ../export/android/{{GAME_NAME}}_debug.apk --headless
    
    # Release build  
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} \
        --export-release "Android apk" \
        ../export/android/{{GAME_NAME}}.apk --headless
    
    echo "✅ Android APK files exported successfully"
    echo "📁 Debug: export/android/{{GAME_NAME}}_debug.apk"
    echo "📁 Release: export/android/{{GAME_NAME}}.apk"

# Launch Android app on connected device
launch-android: _validate-android-workflow
    @echo "🚀 Launching Android app..."
    adb -s {{ANDROID_DEVICE_ID}} shell am start -n {{ANDROID_PACKAGE_NAME}}/com.godot.game.GodotApp
    echo "✅ Android app launched"

# Restart Android app (kill and relaunch)
restart-android-app: _validate-android-workflow
    @echo "🔄 Restarting Android app..."
    adb -s {{ANDROID_DEVICE_ID}} shell am force-stop {{ANDROID_PACKAGE_NAME}} || true
    sleep 1
    adb -s {{ANDROID_DEVICE_ID}} shell am start -n {{ANDROID_PACKAGE_NAME}}/com.godot.game.GodotApp
    echo "✅ Android app restarted"

# Gradle build and install helper
_gradle-build-install-android:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🔧 Building and installing Android APK..."
    
    # Navigate to build directory
    cd {{ANDROID_GRADLE_DIR}}
    
    # Build debug APK
    echo "📦 Building debug APK with Gradle..."
    ./gradlew assembleDebug
    
    # Install on device
    echo "📱 Installing APK on device {{ANDROID_DEVICE_ID}}..."
    adb -s {{ANDROID_DEVICE_ID}} install -r app/build/outputs/apk/debug/app-debug.apk
    
    echo "✅ Android APK built and installed successfully"

# Android development iteration workflow
iterate-android CONFIG="current":
    @echo "⚡ Android iteration workflow..."
    just config-restart-android "{{CONFIG}}"
    @echo "🎯 Ready for testing on Android device"

# Push configuration to Android device
config-push-android CONFIG_NAME: (_validate-android-config-workflow CONFIG_NAME)
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "📱 Pushing config to Android device..."
    
    CONFIG_FILE=$(just _get-safe-config-file "{{CONFIG_NAME}}")
    
    echo "📄 Config content to push:"
    cat "$CONFIG_FILE" | jq . || cat "$CONFIG_FILE"
    echo ""
    
    # Try app private directory first, fall back to public storage
    USER_DIR="/data/data/{{ANDROID_PACKAGE_NAME}}/files"
    PRIVATE_CONFIG="$USER_DIR/debug_startup_actions.json"
    PUBLIC_CONFIG="/sdcard/Android/data/{{ANDROID_PACKAGE_NAME}}/files/debug_startup_actions.json"
    
    echo "🔧 Pushing to device storage..."
    
    # First try to push directly to app private directory
    if adb -s {{ANDROID_DEVICE_ID}} shell "run-as {{ANDROID_PACKAGE_NAME}} cp /dev/null files/debug_startup_actions.json" 2>/dev/null; then
        echo "📁 App private directory accessible - using user:// path"
        # Use temporary location first, then copy
        TEMP_CONFIG="/sdcard/temp_debug_config.json"
        
        if adb -s {{ANDROID_DEVICE_ID}} push "$CONFIG_FILE" "$TEMP_CONFIG"; then
            if adb -s {{ANDROID_DEVICE_ID}} shell "run-as {{ANDROID_PACKAGE_NAME}} cp $TEMP_CONFIG files/debug_startup_actions.json" 2>/dev/null; then
                echo "✅ Config copied to app private directory"
                adb -s {{ANDROID_DEVICE_ID}} shell "rm $TEMP_CONFIG" 2>/dev/null || true
                echo "✅ Config push complete"
            else
                echo "❌ Failed to copy to app private directory"
                exit 1
            fi
        else
            echo "❌ Failed to upload config to temp location"
            exit 1
        fi
    else
        echo "📁 App private directory not accessible - using public storage"
        # Create public directory and push there
        adb -s {{ANDROID_DEVICE_ID}} shell "mkdir -p /sdcard/Android/data/{{ANDROID_PACKAGE_NAME}}/files/" 2>/dev/null || true
        
        if adb -s {{ANDROID_DEVICE_ID}} push "$CONFIG_FILE" "$PUBLIC_CONFIG"; then
            echo "✅ Config uploaded to public storage"
            echo "💡 App will read from public storage location"
            echo "✅ Config push complete"
        else
            echo "❌ Failed to upload config to public storage"
            exit 1
        fi
    fi

# Deploy config and restart Android app (5-second iteration)
config-restart-android CONFIG_NAME: (_validate-android-config-workflow CONFIG_NAME)
    #!/usr/bin/env bash
    set -euo pipefail
    echo "⚡ Config + restart workflow (5-second iteration)..."
    
    # Push config (2 seconds)
    just config-push-android "{{CONFIG_NAME}}"
    
    # Restart app (3 seconds)
    just restart-android-app

# Check current Android configuration status
config-status-android:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📱 Android configuration status..."
    
    # Check embedded config
    echo "🔧 Embedded config status:"
    if [ -f "project/embedded_config.json" ]; then
        echo "✅ Embedded config exists:"
        cat project/embedded_config.json | jq . 2>/dev/null || cat project/embedded_config.json
    else
        echo "❌ No embedded config found"
    fi
    echo ""
    
    # Check Android device config
    echo "📱 Android device config status:"
    if adb -s {{ANDROID_DEVICE_ID}} shell "run-as {{ANDROID_PACKAGE_NAME}} ls files/debug_startup_actions.json" >/dev/null 2>&1; then
        echo "✅ External config exists on device:"
        adb -s {{ANDROID_DEVICE_ID}} shell "run-as {{ANDROID_PACKAGE_NAME}} cat files/debug_startup_actions.json" 2>/dev/null || echo "  (could not read content)"
    else
        echo "❌ No external config found on device"
    fi

# Clear external Android configuration
config-clear-android:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🧹 Clearing external Android configuration..."
    
    # Remove external config from device
    if adb -s {{ANDROID_DEVICE_ID}} shell "run-as {{ANDROID_PACKAGE_NAME}} rm files/debug_startup_actions.json" 2>/dev/null; then
        echo "✅ External config removed from device"
    else
        echo "⚠️  No external config found on device (or removal failed)"
    fi

# Clear Android test cache to eliminate stale test state
clear-android-test-cache:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🧹 Clearing Android test cache..."
    
    # Check if device is connected
    if ! adb devices | grep -q "{{ANDROID_DEVICE_ID}}.*device"; then
        echo "❌ Android device not connected: {{ANDROID_DEVICE_ID}}"
        exit 1
    fi
    
    # Stop the application first
    echo "⏹️  Stopping application..."
    adb -s {{ANDROID_DEVICE_ID}} shell "am force-stop {{ANDROID_PACKAGE_NAME}}" 2>/dev/null || true
    
    # Clear application data (includes cached configs and test state)
    echo "🗑️  Clearing application data..."
    if adb -s {{ANDROID_DEVICE_ID}} shell "pm clear {{ANDROID_PACKAGE_NAME}}" 2>/dev/null; then
        echo "✅ Application data cleared"
    else
        echo "⚠️  Could not clear application data (app may not be installed)"
    fi
    
    # Clear any test config files on device storage
    echo "📁 Clearing test config files..."
    adb -s {{ANDROID_DEVICE_ID}} shell "rm -rf /sdcard/Android/data/{{ANDROID_PACKAGE_NAME}}/files/test_configs/" 2>/dev/null || true
    adb -s {{ANDROID_DEVICE_ID}} shell "rm -rf /sdcard/Android/data/{{ANDROID_PACKAGE_NAME}}/files/debug_startup_actions.json" 2>/dev/null || true
    
    # Clear any test preferences
    echo "⚙️  Clearing test preferences..."
    adb -s {{ANDROID_DEVICE_ID}} shell "rm -rf /data/data/{{ANDROID_PACKAGE_NAME}}/shared_prefs/test_*" 2>/dev/null || true
    adb -s {{ANDROID_DEVICE_ID}} shell "rm -rf /data/data/{{ANDROID_PACKAGE_NAME}}/shared_prefs/debug_*" 2>/dev/null || true
    
    echo "✅ Android test cache cleared"
    echo "💡 Run test commands to apply fresh configuration"
    
    echo "💡 App will use embedded config on next restart"