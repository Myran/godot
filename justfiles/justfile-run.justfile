# Run-related commands for Godot 4 Projects

# ================================
# PLATFORM ABSTRACTION FUNCTIONS
# ================================

# Generic iOS app launcher - handles device selection, build type, and debug modes
_ios-launch-app DEVICE_TYPE BUILD_TYPE="debug" DEBUG_MODE="false": (_validate-ios-workflow DEVICE_TYPE) pre-build
    #!/usr/bin/env bash
    set -euo pipefail

    # Device selection
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

    # Build type selection
    if [ "{{BUILD_TYPE}}" = "debug" ]; then
        BUILD_PATH="Debug-iphoneos"
        BUILD_NAME="debug"
    elif [ "{{BUILD_TYPE}}" = "release" ]; then
        BUILD_PATH="Release-iphoneos"
        BUILD_NAME="release"
    else
        echo "❌ Invalid build type: {{BUILD_TYPE}}. Use 'debug' or 'release'"
        exit 1
    fi

    BUNDLE_ID="{{IOS_BUNDLE_IDENTIFIER}}"
    APP_PATH="export/ios/build/products/${BUILD_PATH}/{{GAME_NAME}}.app"

    # Debug mode selection
    if [ "{{DEBUG_MODE}}" = "true" ]; then
        echo "Running $BUILD_NAME build on $DEVICE_NAME in debug mode..."
        LAUNCH_FLAGS="--start-stopped"
        DEBUG_TEXT=" in debug mode"
    else
        echo "Running $BUILD_NAME build on $DEVICE_NAME..."
        LAUNCH_FLAGS="--activate"
        DEBUG_TEXT=""
    fi

    # Validate app exists
    if [ ! -d "$APP_PATH" ]; then
        echo "❌ iOS app not found: $APP_PATH"
        echo "💡 Build the app first: just build-ios-app"
        exit 1
    fi

    # Install the app
    echo "Installing $BUILD_NAME app on $DEVICE_NAME..."
    xcrun devicectl device install app --device ${DEVICE_ID} ${APP_PATH}

    # Launch the app
    echo "Launching $BUILD_NAME app on $DEVICE_NAME$DEBUG_TEXT..."
    xcrun devicectl device process launch --device ${DEVICE_ID} ${LAUNCH_FLAGS} ${BUNDLE_ID}

# Generic Android APK installer - handles debug/release variants
_android-install-apk APK_TYPE="release": _validate-android-workflow
    #!/usr/bin/env bash
    set -euo pipefail
    
    # APK selection
    if [ "{{APK_TYPE}}" = "debug" ]; then
        APK_FILE="export/android/{{GAME_NAME}}_debug.apk"
        APK_NAME="debug"
    elif [ "{{APK_TYPE}}" = "release" ]; then
        APK_FILE="export/android/{{GAME_NAME}}.apk"
        APK_NAME="release"
    else
        echo "❌ Invalid APK type: {{APK_TYPE}}. Use 'debug' or 'release'"
        exit 1
    fi
    
    # Validate APK file exists
    if [ ! -f "$APK_FILE" ]; then
        echo "❌ APK file not found: $APK_FILE"
        echo "💡 Build APK first: just export-android-apk"
        exit 1
    fi
    
    echo "📦 Installing & launching $APK_NAME Android APK..."
    echo "Checking if package {{ANDROID_PACKAGE_NAME}} exists..."
    if adb -s {{ANDROID_DEVICE_ID}} shell pm list packages | grep -q "{{ANDROID_PACKAGE_NAME}}"; then
        echo "Package exists. Uninstalling..."
        adb -s {{ANDROID_DEVICE_ID}} uninstall {{ANDROID_PACKAGE_NAME}}
    else
        echo "Package does not exist."
    fi
    
    echo "Installing $APK_NAME APK..."
    adb -s {{ANDROID_DEVICE_ID}} install $APK_FILE
    
    echo "Running the app..."
    adb -s {{ANDROID_DEVICE_ID}} shell am start -a android.intent.action.MAIN -n {{ANDROID_PACKAGE_NAME}}/com.godot.game.GodotApp
    echo "✅ $APK_NAME APK installed and launched!"

# Generic iOS hot reload - handles device selection
_ios-hotreload DEVICE_TYPE BUILD_TYPE="debug":
    @echo "Updating game content and running on {{DEVICE_TYPE}}..."
    just ios-update-pck
    just _ios-launch-app {{DEVICE_TYPE}} {{BUILD_TYPE}}

# ================================
# DESKTOP COMMANDS
# ================================

# LEVEL 1: Launch in Godot editor (1-2 sec, no build needed)
# Renamed from run-desktop to run-editor for semantic clarity (Task-329)
run-editor: _validate-godot-editor
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "Running project on desktop..."
    
    # Clear any leftover debug config to ensure clean startup
    USER_DIR="${HOME}/Library/Application Support/Godot/app_userdata/gametwo"
    STARTUP_CONFIG="$USER_DIR/debug_startup_actions.json"
    
    if [ -f "$STARTUP_CONFIG" ]; then
        echo "🧹 Removing leftover debug config for clean startup..."
        rm -f "$STARTUP_CONFIG"
    fi
    
    # Start the Godot process in background to capture session ID
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} &
    GODOT_PID=$!
    
    # Wait a moment for the session to start, then extract session ID
    sleep 3
    
    # Extract the most recent session ID from logs
    STANDARD_LOGS_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo/logs"
    PROJECT_LOGS_DIR="./logs"
    
    # Check both log locations for the most recent session
    if [ -d "$STANDARD_LOGS_DIR" ] && [ -n "$(ls -A "$STANDARD_LOGS_DIR"/*.log 2>/dev/null)" ]; then
        LATEST_LOG=$(ls -t "$STANDARD_LOGS_DIR"/*.log 2>/dev/null | head -1)
        SESSION_ID=$(grep "SESSION_START" "$LATEST_LOG" 2>/dev/null | tail -1 | grep -o '"session_id": "[^"]*"' | cut -d'"' -f4 || echo "")
    elif [ -d "$PROJECT_LOGS_DIR" ] && [ -n "$(ls -A "$PROJECT_LOGS_DIR"/*.log 2>/dev/null)" ]; then
        LATEST_LOG=$(ls -t "$PROJECT_LOGS_DIR"/*.log 2>/dev/null | head -1)
        SESSION_ID=$(grep "SESSION_START" "$LATEST_LOG" 2>/dev/null | tail -1 | grep -o '"session_id": "[^"]*"' | cut -d'"' -f4 || echo "")
    fi
    
    if [ -n "$SESSION_ID" ]; then
        echo ""
        echo "🎮 Session ID: $SESSION_ID"
        echo "💡 To create a test from this session:"
        echo "   just replay-generate $SESSION_ID my-test-name"
        echo ""
        echo "🔧 Advanced workflow (manual steps):"
        echo "   1. just replay-generate $SESSION_ID my-test-name"
        echo "   2. just _extract-checksums-to-config $SESSION_ID my-test-name"
        echo ""
    fi
    
    # Wait for the Godot process to complete
    wait $GODOT_PID

# LEVEL 1: Launch in Godot editor with debug (1-2 sec, no build needed)
# Renamed from run-desktop-debug to run-editor-debug for semantic clarity (Task-329)
run-editor-debug VERBOSE="":
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "Running project in debug mode..."
    
    # Build verbose flag - if VERBOSE is provided, add --verbose
    VERBOSE_FLAG=""
    if [ "{{VERBOSE}}" != "" ]; then
        VERBOSE_FLAG="--verbose"
        echo "Running with verbose output to show ObjectDB leak details..."
    fi
    
    # Start the Godot process and save its PID
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --debug $VERBOSE_FLAG &
    DEBUG_PID=$!
    
    echo "Started debug process with PID: $DEBUG_PID"
    
    # Let the user know how to terminate the process
    echo "Press Ctrl+C to terminate the debug process"
    
    # Wait for the user to terminate with Ctrl+C
    wait $DEBUG_PID
    EXIT_CODE=$?
    
    # The wait command above will be interrupted by Ctrl+C
    if [ $EXIT_CODE -ne 0 ] && [ $EXIT_CODE -ne 130 ]; then # 130 is the exit code for Ctrl+C
        echo "Debug process terminated with exit code: $EXIT_CODE"
    else
        echo "Debug process terminated"
    fi

# ================================
# iOS LAUNCH COMMANDS (Using Generic Functions)
# ================================

# LEVEL 1: Launch existing app (1-2 sec, no changes)
run-ios-iphone: (_ios-launch-app "iphone" "debug")

# LEVEL 1: Launch existing app (1-2 sec, no changes)
run-ios-ipad: (_ios-launch-app "ipad" "debug")

# Install and launch debug app on iPhone (installs + launches)
install-ios-iphone: install-ios-iphone-debug

# Install and launch debug app on iPad (installs + launches)
install-ios-ipad: install-ios-ipad-debug

# Install and launch debug build on iPhone
install-ios-iphone-debug: (_ios-launch-app "iphone" "debug")

# Install and launch release build on iPhone
install-ios-iphone-release: (_ios-launch-app "iphone" "release")

# Install and launch debug build on iPad
install-ios-ipad-debug: (_ios-launch-app "ipad" "debug")

# Install and launch release build on iPad
install-ios-ipad-release: (_ios-launch-app "ipad" "release")



# LEVEL 1: Launch existing app in debug mode (1-2 sec, no install/build)  
run-android:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🧹 Clearing any persistent Android configuration..."
    just config-clear-android > /dev/null 2>&1 || echo "   No config to clear (or clearing failed)"
    
    echo "🔄 Stopping any running app instance..."
    adb -s {{ANDROID_DEVICE_ID}} shell am force-stop {{ANDROID_PACKAGE_NAME}} || true
    sleep 1
    
    echo "🐛 Launching Android app in debug mode..."
    adb -s {{ANDROID_DEVICE_ID}} shell am start -a android.intent.action.MAIN -n {{ANDROID_PACKAGE_NAME}}/com.godot.game.GodotApp
    echo "✅ App launched in debug mode!"
    
    # Wait for the session to start and capture session ID
    echo "⏳ Waiting for session to start..."
    sleep 5
    
    # Check for new session ID in Android logs
    # Note: Android logs come through adb logcat, but for semantic sessions we need the desktop logs
    STANDARD_LOGS_DIR="$HOME/Library/Application Support/Godot/app_userdata/gametwo/logs"
    PROJECT_LOGS_DIR="./logs"
    # Initialize SESSION_ID only if not already set (prevents unbound variable error)
    # when called as sub-recipe with existing SESSION_ID
    if [ -z "${SESSION_ID:-}" ]; then
        SESSION_ID=""
    fi

    # Check both log locations for the most recent session
    if [ -d "$STANDARD_LOGS_DIR" ] && [ -n "$(ls -A "$STANDARD_LOGS_DIR"/*.log 2>/dev/null)" ]; then
        LATEST_LOG=$(ls -t "$STANDARD_LOGS_DIR"/*.log 2>/dev/null | head -1)
        SESSION_ID=$(grep "SESSION_START" "$LATEST_LOG" 2>/dev/null | tail -1 | grep -o '"session_id": "[^"]*"' | cut -d'"' -f4 || echo "")
    elif [ -d "$PROJECT_LOGS_DIR" ] && [ -n "$(ls -A "$PROJECT_LOGS_DIR"/*.log 2>/dev/null)" ]; then
        LATEST_LOG=$(ls -t "$PROJECT_LOGS_DIR"/*.log 2>/dev/null | head -1)
        SESSION_ID=$(grep "SESSION_START" "$LATEST_LOG" 2>/dev/null | tail -1 | grep -o '"session_id": "[^"]*"' | cut -d'"' -f4 || echo "")
    fi
    
    if [ -n "$SESSION_ID" ]; then
        echo ""
        echo "🎮 Session ID: $SESSION_ID"
        echo "💡 To create a test from this session:"
        echo "   just replay-generate $SESSION_ID my-test-name"
        echo ""
        echo "🔧 Advanced workflow (manual steps):"
        echo "   1. just replay-generate $SESSION_ID my-test-name"
        echo "   2. just _extract-checksums-to-config $SESSION_ID my-test-name"
        echo ""
    else
        echo "⚠️  Session ID not found in logs yet. Check again after playing the game."
        echo "💡 Use: just logs-last | grep SESSION_START | tail -1"
    fi

# ================================
# ANDROID COMMANDS (Using Generic Functions)
# ================================

# LEVEL 2a: Install existing Release APK + launch (30 sec, requires pre-built APK)
install-apk-android-release: (_android-install-apk "release")

# LEVEL 2a: Install existing Debug APK + launch (30 sec, requires pre-built APK)
install-apk-android-debug: (_android-install-apk "debug")

# Install and launch debug APK on Android (default for development)
install-android: install-apk-android-debug

# ================================
# HOT RELOAD COMMANDS (Using Generic Functions)
# ================================

# LEVEL 2: Update game content & launch (5-10 sec, exports .pck to existing app)
hotreload-ios-iphone: (_ios-hotreload "iphone" "debug")

# LEVEL 2: Update game content & launch (5-10 sec, exports .pck to existing app)
hotreload-ios-ipad: (_ios-hotreload "ipad" "debug")


