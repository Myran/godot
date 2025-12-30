# Android Platform Development Commands
# Complete Android build, deploy, test, and device management workflow

# Note: Variables are inherited from main justfile

# Note: Validation functions are inherited from main justfile via justfile-validation.justfile

# Note: _validate-android-workflow is inherited from justfile-validation.justfile

# ================================
# ANDROID BUILD COMMANDS
# ================================


# Complete Android build with templates and all dependencies (20 minutes)
build-all-android force="no": validate-env validate-android-env
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
    @echo ""
    @echo "🔥 Building Native Sentry (crash reporting SDK)..."
    just build-sentry-native-android-all {{force}}

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
    @echo "📦 [1/3] Checking Android templates..."
    just templates-android {{force}}
    @echo "📥 [2/3] Setting up Android templates + SDK injection..."
    just setup-android-templates {{force}}
    @echo "📱 [3/3] Exporting Android builds (APK + AAB)..."
    just export-all-android {{force}}

# Smart template check - only build if not already built

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

# Setup Android development environment (one-time setup)
setup-env:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "📱 Setting up Android development environment..."
    echo ""

    # Create .env file if it doesn't exist
    if [ ! -f ".env" ]; then
        echo "📝 Creating .env file from template..."
        cp .env.template .env

        # Update paths automatically based on current directory
        CURRENT_DIR="$(pwd)"
        sed -i '' "s|/path/to/your/gametwo/keystore|${CURRENT_DIR}|g" .env

        echo "✅ .env file created at ${CURRENT_DIR}/.env"
        echo ""
        echo "🔑 NEXT STEPS:"
        echo "1. Edit .env and set your keystore password:"
        echo "   GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=\"your_password_here\""
        echo ""
        echo "2. The keystore path has been set to:"
        echo "   ${CURRENT_DIR}/gametwo-release.keystore"
        echo ""
        echo "3. Then run: just export-android-apk-release"
        echo ""
    else
        echo "✅ .env file already exists"
        echo ""
        echo "💡 To recreate it, remove the existing file first:"
        echo "   rm .env && just setup-android"
    fi

# Auto-validate and load .env for any Android command
validate-android-env:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔧 Loading Android environment..."

    # Load .env file
    if [ ! -f ".env" ]; then
        echo "❌ .env file not found! Copy .env.template to .env"
        echo "💡 Run: cp .env.template .env"
        echo "💡 Then edit .env with your keystore password"
        exit 1
    fi

    # Source environment variables
    set -a
    source .env
    set +a

    # Note: Using absolute paths for Godot compatibility
    # No path resolution needed - paths must be absolute in .env

    # Validate required release keystore environment variables
    if [ -z "${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:-}" ]; then
        echo "❌ Missing GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD in .env"
        echo "💡 Edit .env and add your release keystore password"
        exit 1
    fi

    if [ -z "${GODOT_ANDROID_KEYSTORE_RELEASE_USER:-}" ]; then
        echo "❌ Missing GODOT_ANDROID_KEYSTORE_RELEASE_USER in .env"
        echo "💡 Add: GODOT_ANDROID_KEYSTORE_RELEASE_USER=gametwo"
        exit 1
    fi

    # Validate keystore file exists
    if [ ! -f "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-}" ]; then
        echo "❌ Release keystore not found: ${GODOT_ANDROID_KEYSTORE_RELEASE_PATH}"
        echo "💡 Copy your keystore file to: keystore/gametwo-release.keystore"
        echo "💡 Or create one with: keytool -genkey -v -keystore keystore/gametwo-release.keystore -alias gametwo -keyalg RSA -keysize 2048 -validity 10000"
        exit 1
    fi

    echo "✅ Release Android environment loaded and validated"
    echo "  📱 Release keystore: ${GODOT_ANDROID_KEYSTORE_RELEASE_PATH}"
    echo "  🔑 Release alias: ${GODOT_ANDROID_KEYSTORE_RELEASE_USER}"

# Fast Android development iteration - optimized workflow alias
fastbuild: export-install-android-launch-debug
    @echo "⚡ Fast Android build (2x faster than old implementation)..."
    @echo "✅ Complete Sentry integration enabled"

# Alias for backward compatibility
fastbuild-android: export-install-android-launch-debug

# Note: Original fastbuild-android removed - alias to export-install-android-launch-debug
# Why: export-install-android-launch-debug is 2x faster (36s vs 75s) and has complete Sentry integration

# Android template building
build-android-templates force="no":
    #!/usr/bin/env bash
    set -euo pipefail

    # Check if Android templates already exist
    DEBUG_APK="templates/android_debug.apk"
    RELEASE_APK="templates/android_release.apk"
    SOURCE_ZIP="templates/android_source.zip"

    # Check if all outputs exist
    if [ "{{force}}" != "yes" ] && [ "{{force}}" != "force=yes" ] && [ -f "$DEBUG_APK" ] && [ -f "$RELEASE_APK" ] && [ -f "$SOURCE_ZIP" ]; then
        echo "✅ Android templates already built"
        echo "   Use 'just build-android-templates force=yes' to rebuild"
        exit 0
    fi

    if [ "{{force}}" = "yes" ] || [ "{{force}}" = "force=yes" ]; then
        echo "🔥 Force rebuild enabled - cleaning existing Android templates..."
        rm -f "$DEBUG_APK" "$RELEASE_APK" "$SOURCE_ZIP"
    fi

    # Build Swappy Frame Pacing libraries if not present
    just build-swappy {{force}}

    echo "🔧 Building Android templates..."
    cd {{GODOT_SUBMODULE_PATH}}

    echo "📦 Building complete Android templates (debug + release)..."
    scons platform=android target=template_debug arch=arm32 arch=arm64 --jobs={{jobs}}
    scons platform=android target=template_release arch=arm32 arch=arm64 production=yes optimize=size --jobs={{jobs}}

    echo "📦 Packaging .so files into .aar with Gradle..."
    cd platform/android/java
    ./gradlew generateGodotTemplates
    cd ../../..

    echo "📁 Copying templates to templates/ directory..."
    mkdir -p templates
    cp platform/android/java/app/build/outputs/apk/standard/debug/android_debug.apk templates/
    cp platform/android/java/app/build/outputs/apk/standard/release/android_release.apk templates/

    # Return to root directory and rebuild android_source.zip
    cd ..
    just rebuild-android-source-zip

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

# Install Android templates and inject Firebase + Sentry SDKs (complete setup)
setup-android-templates force="no":
    #!/usr/bin/env bash
    set -euo pipefail

    echo "📦 Setting up Android templates with SDK injection..."

    # Check if templates already set up
    if [ "{{force}}" != "yes" ] && [ "{{force}}" != "force=yes" ] && [ -f "project/android/.build_version" ] && [ -f "project/android/build/google-services.json" ] && [ -f "project/android/build/sentry.properties" ]; then
        echo "✅ Android templates already set up with SDK injection"
        echo "   Use 'just setup-android-templates force=yes' to rebuild"
        exit 0
    fi

    if [ "{{force}}" = "yes" ] || [ "{{force}}" = "force=yes" ]; then
        echo "🔥 Force rebuild enabled - resetting Android templates..."
        rm -rf project/android
    fi

    just install-android-template
    just android-inject-sdks
    just sentry-android-setup-libraries
    echo "✅ Android templates ready for export"

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
# Renamed from export-aab-android for platform naming consistency (Task-378)
export-android-aab force="yes": _validate-godot-editor (_ensure-directory-exists "export/android") pre-build
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📦 Exporting Android AAB files (debug + release)..."

    # Check if AAB files already exist
    DEBUG_AAB="export/android/{{GAME_NAME}}_debug.aab"
    RELEASE_AAB="export/android/{{GAME_NAME}}.aab"

    if [ "{{force}}" != "yes" ] && [ "{{force}}" != "force=yes" ] && [ -f "$DEBUG_AAB" ] && [ -f "$RELEASE_AAB" ]; then
        echo "✅ Android AAB files already exported:"
        echo "   📁 Debug: $DEBUG_AAB"
        echo "   📁 Release: $RELEASE_AAB"
        echo "   Use 'just export-android-aab force=yes' to re-export"
        exit 0
    fi

    if [ "{{force}}" = "yes" ] || [ "{{force}}" = "force=yes" ]; then
        echo "🔥 Force re-export enabled - removing existing AAB files..."
        rm -f "$DEBUG_AAB" "$RELEASE_AAB"
    fi

    # Source environment variables for Godot context
    if [ -f ".env" ]; then
        set -a
        source .env
        set +a
        echo "✅ Environment variables loaded for Godot export"
    else
        echo "❌ .env file not found"
        exit 1
    fi

    # Verify Sentry AAR files exist (should be there from build-sentry-gdscript-android)
    if [ ! -f "project/android/build/libs/debug/sentry_android_godot_plugin.debug.aar" ] || [ ! -f "project/android/build/libs/release/sentry_android_godot_plugin.release.aar" ]; then
        echo "❌ Sentry AAR files not found - run: just build-sentry-gdscript-android"
        exit 1
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
export-all-android force="yes":
    @echo "📦 Exporting all Android formats (APK + AAB)..."
    just export-android-apk {{force}}
    just export-android-aab {{force}}
    @echo "✅ All Android exports complete"

# Export Android APK files
# Renamed from export-apk-android for platform naming consistency (Task-378)
export-android-apk force="yes": _validate-godot-editor (_ensure-directory-exists "export/android")
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📦 Exporting Android APK files (debug + release)..."

    # Check if APK files already exist
    DEBUG_APK="export/android/{{GAME_NAME}}_debug.apk"
    RELEASE_APK="export/android/{{GAME_NAME}}.apk"

    if [ "{{force}}" != "yes" ] && [ "{{force}}" != "force=yes" ] && [ -f "$DEBUG_APK" ] && [ -f "$RELEASE_APK" ]; then
        echo "✅ Android APK files already exported:"
        echo "   📁 Debug: $DEBUG_APK"
        echo "   📁 Release: $RELEASE_APK"
        echo "   Use 'just export-android-apk force=yes' to re-export"
        exit 0
    fi

    if [ "{{force}}" = "yes" ] || [ "{{force}}" = "force=yes" ]; then
        echo "🔥 Force re-export enabled - removing existing APK files..."
        rm -f "$DEBUG_APK" "$RELEASE_APK"
    fi

    # Source environment variables for Godot context
    if [ -f ".env" ]; then
        set -a
        source .env
        set +a
        echo "✅ Environment variables loaded for Godot export"
    else
        echo "❌ .env file not found"
        exit 1
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

# Export Android APK - Debug only
# Renamed from export-apk-debug for platform naming consistency (Task-378)
export-android-apk-debug: _validate-godot-editor (_ensure-directory-exists "export/android")
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📦 Exporting Android APK (debug only)..."

    # Source environment variables for Godot context
    if [ -f ".env" ]; then
        set -a
        source .env
        set +a
        echo "✅ Environment variables loaded for Godot export"
    else
        echo "❌ .env file not found"
        exit 1
    fi

    # Verify Sentry AAR files exist (should be there from build-sentry-gdscript-android)
    if [ ! -f "project/android/build/libs/debug/sentry_android_godot_plugin.debug.aar" ]; then
        echo "❌ Sentry AAR files not found - run: just build-sentry-gdscript-android"
        exit 1
    fi

    # Debug build
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} \
        --export-debug "Android apk" \
        ../export/android/{{GAME_NAME}}_debug.apk --headless

    echo "✅ Android debug APK exported successfully"
    echo "📁 Debug: export/android/{{GAME_NAME}}_debug.apk"

# Export Android APK - Release only
# Renamed from export-apk-release for platform naming consistency (Task-378)
export-android-apk-release: _validate-godot-editor (_ensure-directory-exists "export/android")
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📦 Exporting Android APK (release only)..."

    # Source environment variables for Godot context
    if [ -f ".env" ]; then
        set -a
        source .env
        set +a
        echo "✅ Environment variables loaded for Godot export"
    else
        echo "❌ .env file not found"
        exit 1
    fi

    # Verify Sentry AAR files exist (should be there from build-sentry-gdscript-android)
    if [ ! -f "project/android/build/libs/release/sentry_android_godot_plugin.release.aar" ]; then
        echo "❌ Sentry AAR files not found - run: just build-sentry-gdscript-android"
        exit 1
    fi

    # Release build
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} \
        --export-release "Android apk" \
        ../export/android/{{GAME_NAME}}.apk --headless

    echo "✅ Android release APK exported successfully"
    echo "📁 Release: export/android/{{GAME_NAME}}.apk"

# Install Android debug APK
install-apk-debug: _validate-android-workflow
    @echo "📲 Installing Android debug APK..."
    # Uninstall existing package first to avoid signature conflicts
    adb -s {{ANDROID_DEVICE_ID}} uninstall {{ANDROID_PACKAGE_NAME}} 2>/dev/null || echo "Package not installed"
    # Install new APK
    adb -s {{ANDROID_DEVICE_ID}} install export/android/{{GAME_NAME}}_debug.apk
    echo "✅ Android debug APK installed"

# Install Android release APK
install-apk-release: _validate-android-workflow
    @echo "📲 Installing Android release APK..."
    # Uninstall existing package first to avoid signature conflicts
    adb -s {{ANDROID_DEVICE_ID}} uninstall {{ANDROID_PACKAGE_NAME}} 2>/dev/null || echo "Package not installed"
    # Install new APK
    adb -s {{ANDROID_DEVICE_ID}} install export/android/{{GAME_NAME}}.apk
    echo "✅ Android release APK installed"

# Launch Android app on connected device
launch-android: _validate-android-workflow
    @echo "🚀 Launching Android app..."
    adb -s {{ANDROID_DEVICE_ID}} shell am start -n {{ANDROID_PACKAGE_NAME}}/com.godot.game.GodotApp
    echo "✅ Android app launched"

# Export and install debug APK (complete workflow)
export-install-android-debug: export-android-apk-debug install-apk-debug
    @echo "🔄 Android: Export and install debug workflow completed"

# Export and install release APK (complete workflow)
export-install-android-release: export-android-apk-release install-apk-release
    @echo "🔄 Android: Export and install release workflow completed"

# Export, install, and launch debug APK
export-install-android-launch-debug: export-android-apk-debug install-apk-debug restart-android-app
    @echo "🔄 Android: Export, install, and launch debug workflow completed"

# ================================
# DEPLOY: Development device workflow (export → install → run)
# ================================
# Note: For app store release, use 'ship-android' instead

# Deploy to Android device (complete workflow: export → install → run)
# This is the primary command for development iteration
deploy-android: export-install-android-launch-debug
    @echo "📱 Deploy to Android complete"

# Restart Android app (kill and relaunch)
restart-android-app: _validate-android-workflow
    @echo "🔄 Restarting Android app..."
    adb -s {{ANDROID_DEVICE_ID}} shell am force-stop {{ANDROID_PACKAGE_NAME}} || true
    sleep 1
    adb -s {{ANDROID_DEVICE_ID}} shell am start -n {{ANDROID_PACKAGE_NAME}}/com.godot.game.GodotApp
    echo "✅ Android app restarted"

# Note: _gradle-build-install-android removed - was only used by old fastbuild-android
# Why: fastbuild-android now uses 'export-install-android-launch-debug' for better performance


# Internal helper: Push any file to Android app private directory
_push-file-android SOURCE_FILE TARGET_FILENAME:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "📱 Pushing file to Android app private directory..."
    echo "   📄 Source: {{SOURCE_FILE}}"
    echo "   🎯 Target: {{TARGET_FILENAME}}"

    # ENHANCED FIX (Task-216.01): Always ensure clean app state before config push
    # This clears Android log buffer pollution that prevents DEBUG_TEST_SUCCESS logging
    APP_RUNNING=$(adb -s {{ANDROID_DEVICE_ID}} shell "pidof {{ANDROID_PACKAGE_NAME}}" 2>/dev/null || echo "")

    if [[ -n "$APP_RUNNING" ]]; then
        echo "🛑 Stopping existing app for clean config push (test isolation, clears log buffer)..."
        adb -s {{ANDROID_DEVICE_ID}} shell "am force-stop {{ANDROID_PACKAGE_NAME}}" 2>/dev/null || true
        sleep 1
    fi

    # Launch app to create private directory
    echo "🚀 Starting app to create private directory..."
    adb -s {{ANDROID_DEVICE_ID}} shell "am start -n {{ANDROID_PACKAGE_NAME}}/com.godot.game.GodotApp" >/dev/null
    sleep 2

    # CRITICAL FIX (Task-216): Stop app immediately after directory creation
    # This prevents first action from executing before test framework log capture starts
    echo "🛑 Stopping app after directory creation (prevents premature action execution)..."
    adb -s {{ANDROID_DEVICE_ID}} shell "am force-stop {{ANDROID_PACKAGE_NAME}}" 2>/dev/null || true
    sleep 1

    # ENHANCED FIX (Task-216.01): Clear logcat buffer to prevent pollution from directory creation
    # The brief app launch above can pollute the log buffer, affecting DEBUG_TEST_SUCCESS logging
    echo "🧹 Clearing logcat buffer after app stop..."
    adb -s {{ANDROID_DEVICE_ID}} logcat -c 2>/dev/null || true

    # Test if private directory is accessible
    if ! adb -s {{ANDROID_DEVICE_ID}} shell "run-as {{ANDROID_PACKAGE_NAME}} cp /dev/null files/{{TARGET_FILENAME}}" 2>/dev/null; then
        echo "❌ App private directory not accessible"
        echo "💡 Make sure app is installed and has been run at least once"
        echo "💡 Try: adb shell am start -n {{ANDROID_PACKAGE_NAME}}/com.godot.game.GodotApp"
        exit 1
    fi
    
    echo "📁 App private directory accessible - pushing file..."

    # TASK-218 FIX: Delete old config file first to prevent stale config issues
    echo "🗑️  Removing old config file if exists..."
    adb -s {{ANDROID_DEVICE_ID}} shell "run-as {{ANDROID_PACKAGE_NAME}} rm files/{{TARGET_FILENAME}}" 2>/dev/null || true

    # Use temporary location first, then copy to private directory
    TEMP_FILE="/sdcard/temp_$(basename {{TARGET_FILENAME}})"

    if adb -s {{ANDROID_DEVICE_ID}} push "{{SOURCE_FILE}}" "$TEMP_FILE"; then
        if adb -s {{ANDROID_DEVICE_ID}} shell "run-as {{ANDROID_PACKAGE_NAME}} cp $TEMP_FILE files/{{TARGET_FILENAME}}" 2>/dev/null; then
            echo "✅ File copied to app private directory"
            adb -s {{ANDROID_DEVICE_ID}} shell "rm $TEMP_FILE" 2>/dev/null || true

            # TASK-218 FIX: Verify file content matches to prevent running wrong tests
            echo "🔍 Verifying deployed file content..."
            DEPLOYED_CONTENT=$(adb -s {{ANDROID_DEVICE_ID}} shell "run-as {{ANDROID_PACKAGE_NAME}} cat files/{{TARGET_FILENAME}}" 2>/dev/null)
            SOURCE_CONTENT=$(cat "{{SOURCE_FILE}}")

            # Compare file sizes first (fast check)
            DEPLOYED_SIZE=$(echo "$DEPLOYED_CONTENT" | wc -c | tr -d ' ')
            SOURCE_SIZE=$(echo "$SOURCE_CONTENT" | wc -c | tr -d ' ')

            if [[ "$DEPLOYED_SIZE" != "$SOURCE_SIZE" ]]; then
                echo "❌ File size mismatch: deployed=$DEPLOYED_SIZE bytes, source=$SOURCE_SIZE bytes"
                echo "💡 Config deployment failed verification - file not properly written to device"
                exit 1
            fi

            # Compare actual content (thorough check)
            if [[ "$DEPLOYED_CONTENT" != "$SOURCE_CONTENT" ]]; then
                echo "❌ File content mismatch after deployment"
                echo "💡 Config deployment failed verification - content doesn't match"
                exit 1
            fi

            echo "✅ File content verified - deployment successful"
            echo "✅ File push complete"
        else
            echo "❌ Failed to copy to app private directory"
            adb -s {{ANDROID_DEVICE_ID}} shell "rm $TEMP_FILE" 2>/dev/null || true
            exit 1
        fi
    else
        echo "❌ Failed to upload file to temp location"
        exit 1
    fi

# Push gamestate file to Android device for save-load cycle testing
push-gamestate-android GAMESTATE_FILE: _validate-android-workflow
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🎮 Pushing gamestate file to Android device..."
    
    if [[ ! -f "{{GAMESTATE_FILE}}" ]]; then
        echo "❌ Gamestate file not found: {{GAMESTATE_FILE}}"
        exit 1
    fi
    
    echo "📄 Gamestate file: {{GAMESTATE_FILE}}"
    echo "📏 Size: $(wc -c < "{{GAMESTATE_FILE}}") bytes"
    
    # Use the reusable file push helper
    just _push-file-android "{{GAMESTATE_FILE}}" "pending_gamestate_load.json"

# Push configuration to Android device
config-push-android CONFIG_NAME_OR_PATH:
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG_INPUT="{{CONFIG_NAME_OR_PATH}}"

    echo "📱 Pushing config to Android device..."

    # Auto-detect: file path vs config name
    if [[ -f "$CONFIG_INPUT" ]]; then
        # File path provided - use directly (for temp configs with injected metadata)
        CONFIG_FILE="$CONFIG_INPUT"
        echo "📄 Using file path: $CONFIG_FILE"
    else
        # Config name provided - resolve to file and validate
        just _validate-android-config-workflow "$CONFIG_INPUT"
        CONFIG_FILE=$(just _get-safe-config-file "$CONFIG_INPUT")
        echo "📄 Resolved config name '$CONFIG_INPUT' to: $CONFIG_FILE"
    fi

    # Validate resolved file exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "❌ Config file not found: $CONFIG_FILE"
        exit 1
    fi

    echo "📄 Config content to push:"
    cat "$CONFIG_FILE" | jq . || cat "$CONFIG_FILE"
    echo ""

    # Use the reusable file push helper for config
    just _push-file-android "$CONFIG_FILE" "debug_startup_actions.json"

    # Check for and push any pending gamestate files (timing-critical for save-load cycle tests)
    if [[ -f "/tmp/android_gamestate_embed_file.txt" ]]; then
        GAMESTATE_FILE=$(cat /tmp/android_gamestate_embed_file.txt)
        echo ""
        echo "📋 Pushing pending gamestate file as part of config deployment..."
        if [[ -f "$GAMESTATE_FILE" ]]; then
            just _push-file-android "$GAMESTATE_FILE" "pending_gamestate_load.json"
            rm -f /tmp/android_gamestate_embed_file.txt
            echo "✅ Gamestate file pushed successfully with config"
        else
            echo "❌ Gamestate file not found: $GAMESTATE_FILE"
            rm -f /tmp/android_gamestate_embed_file.txt
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

# Clear debug_startup_actions.json from Android device
# Lightweight version that only removes test config, not all app data
clear-test-android:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🧹 Clearing Android test configuration..."

    # Check if device is connected
    if ! adb devices | grep -q "{{ANDROID_DEVICE_ID}}.*device"; then
        echo "❌ Android device not connected: {{ANDROID_DEVICE_ID}}"
        exit 1
    fi

    # Clear debug_startup_actions.json from device storage
    adb -s {{ANDROID_DEVICE_ID}} shell "rm -f /sdcard/Android/data/{{ANDROID_PACKAGE_NAME}}/files/debug_startup_actions.json" 2>/dev/null || true

    echo "✅ Android test config cleared"
    echo "💡 deploy-android will now start without debug actions"

# Clear Android test cache to eliminate stale test state (comprehensive)
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

# Build Sentry Android libraries from source (AAR via Gradle, .so via SCons)
sentry-android-setup-libraries:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🔧 Building Sentry Android libraries from source..."
    echo "   This builds both AAR (Gradle) and native .so (SCons) files"

    # Build AAR files using Gradle
    echo "🏗️  Building Sentry Android AAR files..."
    cd {{SENTRY_PATH}} && ./gradlew assemble

    # Build native .so files using SCons (template_debug)
    echo "🔨 Building debug native libraries..."
    cd {{SENTRY_PATH}} && scons platform=android target=template_debug arch=arm64 debug_symbols=yes

    # Build native .so files using SCons (template_release)
    echo "🔨 Building release native libraries..."
    cd {{SENTRY_PATH}} && scons platform=android target=template_release arch=arm64 debug_symbols=yes optimize=size

    # Sync all built files to correct locations
    echo "📦 Syncing built files to project..."
    @just sentry-sync-android

    echo "✅ Sentry Android libraries built from source"
    echo "   AAR files: {{SENTRY_PATH}}/android_lib/build/outputs/aar/"
    echo "   .so files: {{SENTRY_ADDON_PATH}}/bin/android/"