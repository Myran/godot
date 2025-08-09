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
    PACKAGE_NAME="{{ANDROID_PACKAGE_NAME}}"
    
    if ! command -v adb >/dev/null; then
        echo "❌ adb command not found"
        exit 1
    fi
    
    if ! adb devices | grep -q 'device$'; then
        echo "❌ No Android device connected"
        exit 1
    fi
    
    if ! adb shell pm list packages | grep -q "package:$PACKAGE_NAME"; then
        echo "❌ Package not installed: $PACKAGE_NAME"
        echo "💡 Install first: just install-apk-android"
        exit 1
    fi

# NOTE: _validate-android-workflow has specific implementation in justfile-validation.justfile
# using ANDROID_SDK_PATH configuration - not duplicating here

# NOTE: _validate-path-exists has validation-only implementations in other files
# This shared module focuses on core validation functions only

# NOTE: _validate-ios-device has specific implementation in justfile-validation.justfile
# NOTE: _validate-ios-workflow would also be a duplicate - keeping existing implementations