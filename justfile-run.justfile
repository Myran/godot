# Run-related commands for Godot 4 Projects

# ================================
# PLATFORM ABSTRACTION FUNCTIONS
# ================================

# Generic iOS app launcher - handles device selection and debug modes
_ios-launch-app DEVICE_TYPE DEBUG_MODE="false": (_validate-ios-workflow DEVICE_TYPE) pre-build
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
    
    BUNDLE_ID="{{IOS_BUNDLE_IDENTIFIER}}"
    
    # Debug mode selection
    if [ "{{DEBUG_MODE}}" = "true" ]; then
        echo "Running on $DEVICE_NAME in debug mode..."
        LAUNCH_FLAGS="--start-stopped"
        DEBUG_TEXT=" in debug mode"
    else
        echo "Running on $DEVICE_NAME..."
        LAUNCH_FLAGS="--activate"
        DEBUG_TEXT=""
    fi
    
    # Install the app
    echo "Installing app on $DEVICE_NAME..."
    xcrun devicectl device install app --device ${DEVICE_ID} export/ios/build/products/debug-iphoneos/{{GAME_NAME}}.app
    
    # Launch the app
    echo "Launching app on $DEVICE_NAME$DEBUG_TEXT..."
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
        echo "💡 Build APK first: just export-apk-android"
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
_ios-hotreload DEVICE_TYPE:
    @echo "Updating game content and running on {{DEVICE_TYPE}}..."
    just ios-update-pck
    just _ios-launch-app {{DEVICE_TYPE}}

# ================================
# DESKTOP COMMANDS
# ================================

# LEVEL 1: Launch in Godot editor (1-2 sec, no build needed)
run-desktop: _validate-godot-editor
    @echo "Running project on desktop..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}}

# LEVEL 1: Launch in Godot editor with debug (1-2 sec, no build needed)
run-desktop-debug:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "Running project in debug mode..."
    
    # Start the Godot process and save its PID
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --debug --verbose &
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
launch-ios-iphone: (_ios-launch-app "iphone")

# LEVEL 1: Launch existing app in debug (1-2 sec, no changes)
launch-ios-iphone-debug: (_ios-launch-app "iphone" "true")

# LEVEL 1: Launch existing app (1-2 sec, no changes)
launch-ios-ipad: (_ios-launch-app "ipad")

# LEVEL 1: Launch existing app in debug (1-2 sec, no changes)
launch-ios-ipad-debug: (_ios-launch-app "ipad" "true")


# LEVEL 1: Launch existing app in debug mode (1-2 sec, no install/build)  
run-android-debug:
    @echo "🐛 Launching existing Android app in debug mode..."
    adb -s {{ANDROID_DEVICE_ID}} shell am start -a android.intent.action.MAIN -n {{ANDROID_PACKAGE_NAME}}/com.godot.game.GodotApp
    @echo "✅ App launched in debug mode!"

# ================================
# ANDROID COMMANDS (Using Generic Functions)
# ================================

# LEVEL 2a: Install existing APK + launch (30 sec, requires pre-built APK)
install-apk-android: (_android-install-apk "release")

# LEVEL 2a: Install existing debug APK + launch (30 sec, requires pre-built APK)  
install-apk-debug-android: (_android-install-apk "debug")

# ================================
# HOT RELOAD COMMANDS (Using Generic Functions)
# ================================

# LEVEL 2: Update game content & launch (5-10 sec, exports .pck to existing app)
hotreload-ios-iphone: (_ios-hotreload "iphone")

# LEVEL 2: Update game content & launch (5-10 sec, exports .pck to existing app)
hotreload-ios-ipad: (_ios-hotreload "ipad")


