# Run-related commands for Godot 4 Projects

# Run project on desktop
run-desktop:
    @echo "Running project on desktop..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}}

# Run project on desktop in debug mode
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

# Run project on iPhone
run-iphone: pre-build
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

# Run project on iPhone in debug mode
run-iphone-debug: pre-build
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

# Run project on iPad
run-ipad: pre-build
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

# Run project on iPad in debug mode
run-ipad-debug: pre-build
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

# Run project on Android (release version)
run-android:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Running on Android (release)..."
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

# Run project on Android (debug version)
run-android-debug:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Running on Android (debug)..."
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

# Build iOS project and run on iPhone
build-and-run-iphone:
    @echo "Building iOS project and running on iPhone..."
    just ios-update-pck
    just run-iphone

# Build iOS project and run on iPad  
build-and-run-ipad:
    @echo "Building iOS project and running on iPad..."
    just ios-update-pck
    just run-ipad

# Legacy aliases for backward compatibility (DEPRECATED - use explicit run-* commands)
run target *args='':
    @echo "⚠️  DEPRECATED: Use explicit 'just run-{{target}}' commands instead"
    @echo "   Examples: just run-iphone, just run-android, just run-desktop"
    @echo "   Run 'just --list | grep run-' to see all available run commands"

# Legacy aliases (DEPRECATED)
install-and-run-android: run-android
install-and-run-android-debug: run-android-debug
save-and-run-iphone: build-and-run-iphone
run-debug: run-desktop-debug