# Android Platform Development Commands
# Complete Android build, deploy, test, and device management workflow

# Note: Variables are inherited from main justfile

# Note: Validation functions are inherited from main justfile via justfile-validation.justfile

# Note: _validate-android-workflow is inherited from justfile-validation.justfile

# ================================
# ANDROID BUILD COMMANDS
# ================================

# Quick Android build - Export APK and AAB files (2-3 minutes)
quick-build-android:
    @echo "⚡ Quick Android build (2-3 min)..."
    just insert-firebase-dependencies
    just export-apk-android
    just export-aab-android
    @echo "✅ Quick Android build complete!"

# Complete Android build with templates and all dependencies (20 minutes)
build-all-android force="no": validate-env
    @echo "🤖 FULL BUILD - ANDROID ONLY"
    @echo "============================"
    @if [ "{{force}}" = "yes" ]; then \
        echo "⏱️  Estimated time: 30-40 minutes (FORCE REBUILD)"; \
        echo "🔥 Force rebuild enabled - will rebuild everything from scratch"; \
    else \
        echo "⏱️  Estimated time: 3-25 minutes (smart rebuild)"; \
        echo "💡 Use 'just build-all-android force=yes' to force rebuild everything"; \
    fi
    @echo ""
    
    just _build-common {{force}}
    just _build-android-full {{force}}
    
    @echo "✅ Android full build complete!"

# Force rebuild everything from scratch (30-40 minutes)
rebuild-all-android: validate-env
    @echo "🔥 FORCE REBUILD - ANDROID ONLY"
    @echo "==============================="
    @echo "⏱️  Estimated time: 30-40 minutes"
    @echo "🗑️  Cleaning existing artifacts..."
    @echo ""
    
    # Clean existing artifacts
    rm -f editor/{{GODOT_EXECUTABLE}}
    rm -f templates/android_debug.apk templates/android_release.apk
    
    just _build-common yes
    just _build-android-full yes
    
    @echo "✅ Android force rebuild complete!"

# Android full build steps
_build-android-full force="no":
    @echo ""
    @echo "🤖 ANDROID BUILD STEPS"
    @echo "===================="
    @echo "📦 [1/4] Checking Android templates..."
    just _check-or-build-android-templates {{force}}
    @echo "🔥 [2/4] Setting up Firebase..."
    just insert-firebase-dependencies
    @echo "📱 [3/4] Exporting Android APK..."
    just export-apk-android
    @echo "📦 [4/4] Exporting Android AAB..."
    just export-aab-android

# Smart template check - only build if not already built
_check-or-build-android-templates force="no":
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "{{force}}" = "yes" ]; then
        echo "🔥 Force rebuild enabled - rebuilding Android templates..."
        just templates-android
    elif [ -f "templates/android_debug.apk" ] && [ -f "templates/android_release.apk" ]; then
        echo "✅ Android templates already built:"
        echo "   📱 templates/android_debug.apk"
        echo "   📱 templates/android_release.apk"
        echo "⏭️  Skipping template rebuild (saves 10+ minutes)"
    else
        echo "🔧 Building Android templates (this will take 10+ minutes)..."
        just templates-android
    fi

# Config workflow validation for Android
_validate-android-config-workflow CONFIG:
    @echo "✅ Android config workflow validated for {{CONFIG}}"

# Get safe config filename
_get-safe-config-file CONFIG:
    #!/usr/bin/env bash
    SAFE_CONFIG_NAME=$(echo "{{CONFIG}}" | sed 's/[^a-zA-Z0-9._-]/_/g')
    echo "{{DEBUG_CONFIG_DIR}}/${SAFE_CONFIG_NAME}.json"

# Pre-build hook
pre-build:
    @echo "🔧 Running pre-build tasks..."

# Fast Android development iteration (60 seconds - most used command)
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
    cp platform/android/java/app/build/outputs/apk/debug/android_debug.apk ../templates/
    cp platform/android/java/app/build/outputs/apk/release/android_release.apk ../templates/
    echo "✅ Android templates built successfully"

# Clean Android template artifacts
clean-android-templates:
    @echo "🧹 Cleaning Android template artifacts..."
    rm -f templates/android_debug.apk
    rm -f templates/android_release.apk
    rm -f {{GODOT_SUBMODULE_PATH}}/platform/android/java/app/build/outputs/apk/debug/android_debug.apk
    rm -f {{GODOT_SUBMODULE_PATH}}/platform/android/java/app/build/outputs/apk/release/android_release.apk
    echo "✅ Android templates cleaned"

# Rebuild android_source.zip from current Godot source
rebuild-android-source-zip:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔧 Rebuilding android_source.zip from current Godot source..."
    
    # Remove old template
    rm -f templates/android_source.zip
    
    # Copy gradlew files to app directory temporarily
    echo "📦 Copying gradlew wrapper files..."
    cp {{GODOT_SUBMODULE_PATH}}/platform/android/java/gradlew {{GODOT_SUBMODULE_PATH}}/platform/android/java/app/
    cp {{GODOT_SUBMODULE_PATH}}/platform/android/java/gradlew.bat {{GODOT_SUBMODULE_PATH}}/platform/android/java/app/
    cp -r {{GODOT_SUBMODULE_PATH}}/platform/android/java/gradle {{GODOT_SUBMODULE_PATH}}/platform/android/java/app/
    
    # Create new template zip from Godot source
    echo "📦 Creating android_source.zip with updated minSdk and gradlew wrapper..."
    cd {{GODOT_SUBMODULE_PATH}}/platform/android/java/app
    zip -r ../../../../../templates/android_source.zip . -x "build/*" ".gradle/*" "*.tmp"
    
    # Clean up temporary files
    rm -f gradlew gradlew.bat
    rm -rf gradle
    
    echo "✅ android_source.zip rebuilt with current Godot source (minSdk 23) and gradlew wrapper"

# Install Android template from android_source.zip
install-android-template:
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

# Check Android template health and auto-fix issues
check-android-template:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔍 Checking Android template health..."
    
    ISSUES_FOUND=0
    
    # Check if template directory exists
    if [ ! -d "{{ANDROID_GRADLE_DIR}}" ]; then
        echo "❌ Template directory missing: {{ANDROID_GRADLE_DIR}}"
        ISSUES_FOUND=1
    fi
    
    # Check if gradlew exists and is executable
    if [ ! -x "{{ANDROID_GRADLE_DIR}}/gradlew" ]; then
        echo "❌ gradlew missing or not executable"
        ISSUES_FOUND=1
    fi
    
    # Check if config.gradle has correct minSdk
    if [ -f "{{ANDROID_GRADLE_DIR}}/config.gradle" ]; then
        if ! grep -q "minSdk.*: 23" "{{ANDROID_GRADLE_DIR}}/config.gradle"; then
            echo "❌ config.gradle has wrong minSdk (should be 23 for Firebase compatibility)"
            ISSUES_FOUND=1
        fi
    else
        echo "❌ config.gradle missing"
        ISSUES_FOUND=1
    fi
    
    # Check if Firebase integration is ready (google-services.json and build.gradle has Firebase)
    if [ ! -f "{{ANDROID_GRADLE_DIR}}/google-services.json" ]; then
        echo "❌ google-services.json missing (Firebase config)"
        ISSUES_FOUND=1
    elif [ -f "{{ANDROID_GRADLE_DIR}}/build.gradle" ] && ! grep -q "firebase-bom" "{{ANDROID_GRADLE_DIR}}/build.gradle"; then
        echo "❌ Firebase dependencies not injected in build.gradle"
        ISSUES_FOUND=1
    fi
    
    if [ $ISSUES_FOUND -eq 1 ]; then
        echo "🔧 Issues found. Run 'just rebuild-android-source-zip && just install-android-template' to fix"
        exit 1
    else
        echo "✅ Android template is healthy"
    fi

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
    
    # Use existing keystore files if available, fallback to ANDROID_KEYSTORE variable
    if [ -f "gametwo-release.keystore" ]; then
        echo "✅ Using existing release keystore: gametwo-release.keystore"
        cp gametwo-release.keystore android.keystore
    elif [ -f "gametwo-debug.keystore" ]; then
        echo "✅ Using existing debug keystore: gametwo-debug.keystore"
        cp gametwo-debug.keystore android.keystore
    elif [ -n "${ANDROID_KEYSTORE:-}" ]; then
        echo "🔑 Using ANDROID_KEYSTORE environment variable"
        echo $ANDROID_KEYSTORE | base64 -d > android.keystore
    else
        echo "⚠️  No keystore found - using unsigned build"
        echo "💡 Either set ANDROID_KEYSTORE environment variable or ensure keystore files exist"
    fi
    
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
    
    # Use existing keystore files if available, fallback to ANDROID_KEYSTORE variable
    if [ -f "gametwo-debug.keystore" ]; then
        echo "✅ Using existing debug keystore: gametwo-debug.keystore"
        cp gametwo-debug.keystore android.keystore
    elif [ -n "${ANDROID_KEYSTORE:-}" ]; then
        echo "🔑 Using ANDROID_KEYSTORE environment variable"
        echo $ANDROID_KEYSTORE | base64 -d > android.keystore
    else
        echo "⚠️  No keystore found - using unsigned build"
        echo "💡 Either set ANDROID_KEYSTORE environment variable or ensure gametwo-debug.keystore exists"
    fi
    
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
    
    # Ensure app is running so private directory is accessible
    APP_RUNNING=$(adb -s {{ANDROID_DEVICE_ID}} shell "pidof {{ANDROID_PACKAGE_NAME}}" 2>/dev/null || echo "")
    if [[ -z "$APP_RUNNING" ]]; then
        echo "🚀 App not running - starting app to create private directory..."
        adb -s {{ANDROID_DEVICE_ID}} shell "am start -n {{ANDROID_PACKAGE_NAME}}/com.godot.game.GodotApp" >/dev/null
        sleep 2
    fi
    
    # Test if private directory is accessible
    if ! adb -s {{ANDROID_DEVICE_ID}} shell "run-as {{ANDROID_PACKAGE_NAME}} cp /dev/null files/debug_startup_actions.json" 2>/dev/null; then
        echo "❌ App private directory not accessible"
        echo "💡 Make sure app is installed and has been run at least once"
        echo "💡 Try: adb shell am start -n {{ANDROID_PACKAGE_NAME}}/com.godot.game.GodotApp"
        exit 1
    fi
    
    echo "📁 App private directory accessible - pushing config..."
    
    # Use temporary location first, then copy to private directory
    TEMP_CONFIG="/sdcard/temp_debug_config.json"
    
    if adb -s {{ANDROID_DEVICE_ID}} push "$CONFIG_FILE" "$TEMP_CONFIG"; then
        if adb -s {{ANDROID_DEVICE_ID}} shell "run-as {{ANDROID_PACKAGE_NAME}} cp $TEMP_CONFIG files/debug_startup_actions.json" 2>/dev/null; then
            echo "✅ Config copied to app private directory"
            adb -s {{ANDROID_DEVICE_ID}} shell "rm $TEMP_CONFIG" 2>/dev/null || true
            echo "✅ Config push complete"
        else
            echo "❌ Failed to copy to app private directory"
            adb -s {{ANDROID_DEVICE_ID}} shell "rm $TEMP_CONFIG" 2>/dev/null || true
            exit 1
        fi
    else
        echo "❌ Failed to upload config to temp location"
        exit 1
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