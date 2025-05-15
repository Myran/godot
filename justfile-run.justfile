# Run-related commands for Godot 4 Projects

# Run project on different targets
run target *args='':
    #!/usr/bin/env bash
    echo "Running project on {{target}}..."
    if [ "{{args}}" = "debug" ]; then
        just _run-{{target}} debug
    else
        just _run-{{target}}
    fi

# Run on desktop
_run-desktop:
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}}

# Run in debug mode
run-debug:
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

# Run on iOS devices
_run-ios device debug="": pre-build
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Running on iOS {{device}}..."
    
    # Get the device identifier based on the device type
    if [ "{{device}}" = "iPhone" ]; then
        DEVICE_ID="C3BD7DBD-38DE-4A4E-8724-B4F49A1E4713"
    elif [ "{{device}}" = "iPad" ]; then
        DEVICE_ID="A4045434-B5F5-48B5-8654-C128A403149A"
    else
        echo "Unknown device type: {{device}}"
        exit 1
    fi
    
    BUNDLE_ID="com.primaryhive.gametwo"
    
    # Install the app on the selected device
    echo "Installing app on {{device}}..."
    xcrun devicectl device install app --device ${DEVICE_ID} export/ios/build/products/debug-iphoneos/{{GAME_NAME}}.app
    
    # Launch the app on the selected device
    if [ "{{debug}}" = "debug" ]; then
        echo "Launching app on {{device}} in debug mode..."
        echo "xcrun devicectl device process launch --device ${DEVICE_ID} --start-stopped ${BUNDLE_ID}"
        xcrun devicectl device process launch --device ${DEVICE_ID} --start-stopped ${BUNDLE_ID}
    else
        echo "Launching app on {{device}}..."
        xcrun devicectl device process launch --device ${DEVICE_ID} --activate ${BUNDLE_ID}
    fi

# Run on iPhone
_run-iphone *args="":
    just _run-ios "iPhone" {{args}}

# Run on iPad
_run-ipad *args="":
    just _run-ios "iPad" {{args}}

# Save and run iphone
save-and-run-iphone:
    just save-ios-to-app && just run iphone;


# Check if package exists, uninstall if it does, then install and run
_run-android build_type="release":
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Checking if package {{ANDROID_PACKAGE_NAME}} exists..."
    if adb -s 246d2c533a037ece shell pm list packages | grep -q "{{ANDROID_PACKAGE_NAME}}"; then
        echo "Package exists. Uninstalling..."
        adb -s 246d2c533a037ece uninstall {{ANDROID_PACKAGE_NAME}}
    else
        echo "Package does not exist."
    fi
    
    echo "Installing {{build_type}} APK..."
    if [ "{{build_type}}" = "debug" ]; then
        adb -s 246d2c533a037ece install export/android/{{GAME_NAME}}_debug.apk
    else
        adb -s 246d2c533a037ece install export/android/{{GAME_NAME}}.apk
    fi
    
    echo "Running the app..."
    adb -s 246d2c533a037ece shell am start -a android.intent.action.MAIN -n {{ANDROID_PACKAGE_NAME}}/com.godot.game.GodotApp

# Run Android debug version
_run-android-debug:
    just _run-android debug

# Install and run on Android (release version)
install-and-run-android:
    just _run-android

# Install and run on Android (debug version)
install-and-run-android-debug:
    just _run-android debug
