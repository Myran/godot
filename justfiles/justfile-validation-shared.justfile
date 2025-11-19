# CONSOLIDATED VALIDATION FUNCTIONS
# ==================================
# This file contains all shared validation functions to eliminate duplicates
# across the justfile system. All validation functions should be defined here
# once and imported where needed.

# Basic Android device validation (always passes - for dependency chains)
_validate-android-device:
    @true

# NOTE: _require-android-device implementations exist in other validation files
# with device-specific logic - not duplicating here

# Validate Godot editor is available
_validate-godot-editor:
    #!/usr/bin/env bash
    set -euo pipefail
    EDITOR_PATH="./editor/{{GODOT_EXECUTABLE}}"
    if [ ! -f "$EDITOR_PATH" ]; then
        echo "❌ Godot editor not found: $EDITOR_PATH"
        echo "💡 Build the editor first: just build-editor"
        exit 1
    fi

# Validate iOS development tools are available
_validate-ios-tools:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v xcrun >/dev/null; then
        echo "❌ Xcode command line tools not found"
        echo "💡 Install: xcode-select --install"
        exit 1
    fi
    
    if ! xcrun --sdk iphoneos --show-sdk-path >/dev/null 2>&1; then
        echo "❌ iOS SDK not found"
        echo "💡 Install Xcode and ensure iOS SDK is available"
        exit 1
    fi

# Validate Android package installation status  
_validate-android-package-installed:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Use shared Android app installation check
    just _android-check-app-installed

# NOTE: _validate-android-workflow has specific implementation in justfile-validation.justfile
# using ANDROID_SDK_PATH configuration - not duplicating here

# NOTE: _validate-path-exists has validation-only implementations in other files
# This shared module focuses on core validation functions only

# Validate iOS device connectivity
_validate-ios-device DEVICE_TYPE:
    #!/usr/bin/env bash
    set -euo pipefail

    # Get device UDID based on type (xcrun devicectl uses UDID format)
    if [ "{{DEVICE_TYPE}}" = "iphone" ]; then
        DEVICE_ID="{{IOS_IPHONE_UDID}}"
    elif [ "{{DEVICE_TYPE}}" = "ipad" ]; then
        DEVICE_ID="{{IOS_IPAD_UDID}}"
    else
        echo "❌ Invalid device type: {{DEVICE_TYPE}}"
        echo "💡 Use: iphone or ipad"
        exit 1
    fi
    
    # Check both physical devices (devicectl) and simulators (simctl)
    if ! xcrun devicectl list devices | grep -q "$DEVICE_ID" && ! xcrun simctl list devices | grep -q "$DEVICE_ID"; then
        echo "❌ iOS {{DEVICE_TYPE}} device not found: $DEVICE_ID"
        echo "💡 Check device ID in core config"
        echo "💡 Available devices:"
        echo "   Physical: xcrun devicectl list devices"
        echo "   Simulators: xcrun simctl list devices"
        exit 1
    fi

# Validate path exists
_validate-path-exists PATH:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -e "{{PATH}}" ]; then
        echo "❌ Path not found: {{PATH}}"
        exit 1
    fi

# Validate Android development workflow
_validate-android-workflow:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Check if Android SDK is available
    if [ ! -d "{{ANDROID_SDK_PATH}}" ]; then
        echo "❌ Android SDK not found: {{ANDROID_SDK_PATH}}"
        echo "💡 Install Android SDK or update ANDROID_SDK_PATH"
        exit 1
    fi
    
    # Check if required tools are available
    if [ ! -f "{{ANDROID_SDK_PATH}}/platform-tools/adb" ]; then
        echo "❌ Android platform tools not found"
        echo "💡 Install: Android SDK Platform-Tools"
        exit 1
    fi

# Validate iOS workflow
_validate-ios-workflow DEVICE_TYPE:
    #!/usr/bin/env bash
    set -euo pipefail
    just _validate-ios-tools
    just _validate-ios-device "{{DEVICE_TYPE}}"
    echo "✅ iOS {{DEVICE_TYPE}} workflow validated"

# ================================
# SHARED VALIDATION HELPERS
# ================================

# Standard file validation with custom action suggestion
_validate-file-exists FILE_PATH ACTION_SUGGESTION:
    #!/usr/bin/env bash
    set -euo pipefail
    
    FILE_PATH="{{FILE_PATH}}"
    ACTION_SUGGESTION="{{ACTION_SUGGESTION}}"
    
    if [ ! -f "$FILE_PATH" ]; then
        echo "❌ File not found: $FILE_PATH"
        echo "💡 $ACTION_SUGGESTION"
        exit 1
    fi

# Standard directory validation with custom action suggestion
_validate-dir-exists DIR_PATH ACTION_SUGGESTION:
    #!/usr/bin/env bash
    set -euo pipefail
    
    DIR_PATH="{{DIR_PATH}}"
    ACTION_SUGGESTION="{{ACTION_SUGGESTION}}"
    
    if [ ! -d "$DIR_PATH" ]; then
        echo "❌ Directory not found: $DIR_PATH"
        echo "💡 $ACTION_SUGGESTION"
        exit 1
    fi

# Standard command availability check with install suggestion
_validate-command-exists COMMAND INSTALL_SUGGESTION:
    #!/usr/bin/env bash
    set -euo pipefail
    
    COMMAND="{{COMMAND}}"
    INSTALL_SUGGESTION="{{INSTALL_SUGGESTION}}"
    
    if ! command -v "$COMMAND" >/dev/null 2>&1; then
        echo "❌ Command not found: $COMMAND"
        echo "💡 Install with: $INSTALL_SUGGESTION"
        exit 1
    fi

# ================================
# SHARED ANDROID OPERATIONS
# ================================

# Execute adb run-as command for the app package with error handling
_android-run-as-command COMMAND:
    #!/usr/bin/env bash
    set -euo pipefail
    
    COMMAND="{{COMMAND}}"
    PACKAGE_NAME="{{ANDROID_PACKAGE_NAME}}"
    
    # Execute the run-as command with proper error handling
    if ! adb shell "run-as $PACKAGE_NAME $COMMAND" 2>/dev/null; then
        echo "❌ Failed to execute: run-as $PACKAGE_NAME $COMMAND" >&2
        echo "💡 Ensure app is installed and debuggable" >&2
        return 1
    fi

# Get Android device information in standardized format
_android-get-device-info:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Check if device is connected first
    if ! adb devices | grep -q "device$"; then
        echo "❌ No Android device connected" >&2
        return 1
    fi
    
    # Get device ID (first connected device)
    DEVICE_ID=$(adb devices | grep 'device$' | head -1 | cut -f1)
    
    # Display standardized device information
    echo "📱 Device: $DEVICE_ID"
    echo "📦 Package: {{ANDROID_PACKAGE_NAME}}"
    
    # Additional device details if requested
    if [[ "${1:-}" == "detailed" ]]; then
        ANDROID_VERSION=$(adb shell getprop ro.build.version.release 2>/dev/null || echo "Unknown")
        MODEL=$(adb shell getprop ro.product.model 2>/dev/null || echo "Unknown")
        echo "🔧 Android: $ANDROID_VERSION"
        echo "📲 Model: $MODEL"
    fi

# Check if Android app package is installed
_android-check-app-installed:
    #!/usr/bin/env bash
    set -euo pipefail
    
    PACKAGE_NAME="{{ANDROID_PACKAGE_NAME}}"
    
    # Check device connectivity first
    if ! adb devices | grep -q "device$"; then
        echo "❌ No Android device connected" >&2
        return 1
    fi
    
    # Check if package is installed
    if ! adb shell pm list packages | grep -q "package:$PACKAGE_NAME"; then
        echo "❌ Package not installed: $PACKAGE_NAME" >&2
        echo "💡 Install first: just install-apk-android" >&2
        return 1
    fi
    
    echo "✅ Package installed: $PACKAGE_NAME"

# Enhanced Android device connectivity check with detailed error reporting
_android-check-device-detailed:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Check if adb is available
    if ! command -v adb >/dev/null 2>&1; then
        echo "❌ adb command not found" >&2
        echo "💡 Install Android SDK platform-tools" >&2
        return 1
    fi
    
    # Check if any device is connected
    if ! adb devices | grep -q "device$"; then
        echo "❌ No Android device connected" >&2
        echo "💡 Connect your Android device and enable USB debugging" >&2
        
        # Show available devices for debugging
        DEVICE_LIST=$(adb devices | tail -n +2 | grep -v "^$" || echo "")
        if [[ -n "$DEVICE_LIST" ]]; then
            echo "📱 Detected devices:" >&2
            echo "$DEVICE_LIST" | sed 's/^/  /' >&2
        fi
        return 1
    fi
    
    echo "✅ Android device connected"

# Get Android app log file with standardized path and error handling
_android-get-app-log LOG_FILE_NAME:
    #!/usr/bin/env bash
    set -euo pipefail
    
    LOG_FILE_NAME="{{LOG_FILE_NAME}}"
    PACKAGE_NAME="{{ANDROID_PACKAGE_NAME}}"
    LOG_PATH="files/logs/$LOG_FILE_NAME"
    
    # Check prerequisites
    just _android-check-device-detailed >/dev/null
    
    # Check if log file exists
    if ! just _android-run-as-command "ls $LOG_PATH" >/dev/null 2>&1; then
        echo "❌ Log file not found: $LOG_PATH" >&2
        echo "💡 Run a test first to generate logs" >&2
        return 1
    fi
    
    # Return log file content
    just _android-run-as-command "cat $LOG_PATH"