# Run-related commands for Godot 4 Projects

# LEVEL 1: Launch in Godot editor (1-2 sec, no build needed)
run-desktop:
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

# LEVEL 1: Launch existing app (1-2 sec, no changes)
launch-ios-iphone: pre-build
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Running on iPhone..."
    
    DEVICE_ID="C9A2C197-B5E7-5B83-86C2-2D1EDF2CEB48"
    BUNDLE_ID="com.primaryhive.gametwo"
    
    # Install the app on iPhone
    echo "Installing app on iPhone..."
    xcrun devicectl device install app --device ${DEVICE_ID} export/ios/build/products/debug-iphoneos/{{GAME_NAME}}.app
    
    # Launch the app on iPhone
    echo "Launching app on iPhone..."
    xcrun devicectl device process launch --device ${DEVICE_ID} --activate ${BUNDLE_ID}

# LEVEL 1: Launch existing app in debug (1-2 sec, no changes)
launch-ios-iphone-debug: pre-build
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Running on iPhone in debug mode..."
    
    DEVICE_ID="C9A2C197-B5E7-5B83-86C2-2D1EDF2CEB48"
    BUNDLE_ID="com.primaryhive.gametwo"
    
    # Install the app on iPhone
    echo "Installing app on iPhone..."
    xcrun devicectl device install app --device ${DEVICE_ID} export/ios/build/products/debug-iphoneos/{{GAME_NAME}}.app
    
    # Launch the app on iPhone in debug mode
    echo "Launching app on iPhone in debug mode..."
    xcrun devicectl device process launch --device ${DEVICE_ID} --start-stopped ${BUNDLE_ID}

# LEVEL 1: Launch existing app (1-2 sec, no changes)
launch-ios-ipad: pre-build
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Running on iPad..."
    
    DEVICE_ID="A4045434-B5F5-48B5-8654-C128A403149A"
    BUNDLE_ID="com.primaryhive.gametwo"
    
    # Install the app on iPad
    echo "Installing app on iPad..."
    xcrun devicectl device install app --device ${DEVICE_ID} export/ios/build/products/debug-iphoneos/{{GAME_NAME}}.app
    
    # Launch the app on iPad
    echo "Launching app on iPad..."
    xcrun devicectl device process launch --device ${DEVICE_ID} --activate ${BUNDLE_ID}

# LEVEL 1: Launch existing app in debug (1-2 sec, no changes)
launch-ios-ipad-debug: pre-build
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Running on iPad in debug mode..."
    
    DEVICE_ID="A4045434-B5F5-48B5-8654-C128A403149A"
    BUNDLE_ID="com.primaryhive.gametwo"
    
    # Install the app on iPad
    echo "Installing app on iPad..."
    xcrun devicectl device install app --device ${DEVICE_ID} export/ios/build/products/debug-iphoneos/{{GAME_NAME}}.app
    
    # Launch the app on iPad in debug mode
    echo "Launching app on iPad in debug mode..."
    xcrun devicectl device process launch --device ${DEVICE_ID} --start-stopped ${BUNDLE_ID}


# LEVEL 1: Launch existing app in debug mode (1-2 sec, no install/build)  
run-android-debug:
    @echo "🐛 Launching existing Android app in debug mode..."
    adb -s {{ANDROID_DEVICE_ID}} shell am start -a android.intent.action.MAIN -n {{ANDROID_PACKAGE_NAME}}/com.godot.game.GodotApp
    @echo "✅ App launched in debug mode!"

# LEVEL 2a: Install existing APK + launch (30 sec, requires pre-built APK)
install-apk-android:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📦 Installing & launching Android APK..."
    echo "Checking if package {{ANDROID_PACKAGE_NAME}} exists..."
    if adb -s {{ANDROID_DEVICE_ID}} shell pm list packages | grep -q "{{ANDROID_PACKAGE_NAME}}"; then
        echo "Package exists. Uninstalling..."
        adb -s {{ANDROID_DEVICE_ID}} uninstall {{ANDROID_PACKAGE_NAME}}
    else
        echo "Package does not exist."
    fi
    
    echo "Installing release APK..."
    adb -s {{ANDROID_DEVICE_ID}} install export/android/{{GAME_NAME}}.apk
    
    echo "Running the app..."
    adb -s {{ANDROID_DEVICE_ID}} shell am start -a android.intent.action.MAIN -n {{ANDROID_PACKAGE_NAME}}/com.godot.game.GodotApp
    echo "✅ APK installed and launched!"

# LEVEL 2a: Install existing debug APK + launch (30 sec, requires pre-built APK)  
install-apk-debug-android:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📦 Installing & launching debug Android APK..."
    echo "Checking if package {{ANDROID_PACKAGE_NAME}} exists..."
    if adb -s {{ANDROID_DEVICE_ID}} shell pm list packages | grep -q "{{ANDROID_PACKAGE_NAME}}"; then
        echo "Package exists. Uninstalling..."
        adb -s {{ANDROID_DEVICE_ID}} uninstall {{ANDROID_PACKAGE_NAME}}
    else
        echo "Package does not exist."
    fi
    
    echo "Installing debug APK..."
    adb -s {{ANDROID_DEVICE_ID}} install export/android/{{GAME_NAME}}_debug.apk
    
    echo "Running the app..."
    adb -s {{ANDROID_DEVICE_ID}} shell am start -a android.intent.action.MAIN -n {{ANDROID_PACKAGE_NAME}}/com.godot.game.GodotApp
    echo "✅ Debug APK installed and launched!"

# LEVEL 2: Update game content & launch (5-10 sec, exports .pck to existing app)
hotreload-ios-iphone:
    @echo "Updating game content and running on iPhone..."
    just ios-update-pck
    just launch-ios-iphone

# LEVEL 2: Update game content & launch (5-10 sec, exports .pck to existing app)
hotreload-ios-ipad:
    @echo "Updating game content and running on iPad..."
    just ios-update-pck
    just launch-ios-ipad


