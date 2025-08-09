# System validation and verification commands
# Self-contained utilities for validating development environment and tools
# NOTE: Core validation functions moved to justfile-validation-shared.justfile

# Strict Android device validation (requires actual device connection)
_require-android-device:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! adb -s {{ANDROID_DEVICE_ID}} shell echo "Connected" >/dev/null 2>&1; then
        echo "❌ Android device not connected: {{ANDROID_DEVICE_ID}}"
        echo "💡 Check device connection and run: adb devices"
        exit 1
    fi
    echo "✅ Android device connected"

# Validate iOS device connectivity  
_validate-ios-device DEVICE_TYPE:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Get device ID based on type
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
    
    # Check device connectivity
    if ! xcrun devicectl list devices | grep -q "$DEVICE_ID" 2>/dev/null; then
        echo "❌ $DEVICE_NAME not connected: $DEVICE_ID"
        echo "💡 Check device connection and run: xcrun devicectl list devices"
        exit 1
    fi

# Validate file or directory exists
_validate-path-exists PATH:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -e "{{PATH}}" ]; then
        echo "❌ Path not found: {{PATH}}"
        exit 1
    fi

# Ensure directory exists, create if missing
_ensure-directory-exists DIR:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -d "{{DIR}}" ]; then
        mkdir -p "{{DIR}}"
        echo "📁 Created directory: {{DIR}}"
    fi

# Combined validation for Android workflow requirements
_validate-android-workflow:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Check if Android SDK is available
    if [ ! -d "{{ANDROID_SDK_PATH}}" ]; then
        echo "❌ Android SDK not found: {{ANDROID_SDK_PATH}}"
        echo "💡 Install Android SDK and set ANDROID_SDK_PATH"
        exit 1
    fi
    
    # Check if adb is available
    if ! command -v adb >/dev/null 2>&1; then
        echo "❌ adb not found in PATH"
        echo "💡 Add Android SDK platform-tools to PATH"
        exit 1
    fi
    
    echo "✅ Android workflow environment validated"

# Combined validation for iOS development workflow  
_validate-ios-workflow DEVICE_TYPE:
    #!/usr/bin/env bash
    set -euo pipefail
    just _validate-ios-tools
    just _validate-ios-device "{{DEVICE_TYPE}}"
    echo "✅ iOS {{DEVICE_TYPE}} workflow validated"

# Validate GDScript code by checking for syntax errors using gdparse
check OUTPUT="console":
    #!/usr/bin/env bash
    set -euo pipefail
    
    if [[ "{{OUTPUT}}" == "log" ]]; then
        echo "Validating GDScript code and saving errors to log file..."
        rm -f validation_errors.log
    else
        echo "Validating GDScript code..."
    fi
    
    cd {{PROJECT_PATH}}
    
    # Find all .gd files excluding addons
    gdscript_files=$(find . -name "*.gd" -type f -not -path "./addons/*")
    total_files=$(echo "$gdscript_files" | wc -l)
    
    echo "Checking $total_files GDScript files..."
    
    error_count=0
    current_file=0
    
    for file in $gdscript_files; do
        current_file=$((current_file + 1))
        
        if [[ "{{OUTPUT}}" == "log" ]]; then
            if ! gdparse "$file" >> validation_errors.log 2>&1; then
                echo "ERROR in $file" >> validation_errors.log
                error_count=$((error_count + 1))
            fi
        else
            if ! gdparse "$file" 2>/dev/null; then
                echo "❌ $file"
                error_count=$((error_count + 1))
            fi
        fi
        
        # Show progress every 25 files
        if [[ "{{OUTPUT}}" != "log" && $((current_file % 25)) -eq 0 ]]; then
            echo "Progress: $current_file/$total_files files checked..."
        fi
    done
    
    if [[ $error_count -eq 0 ]]; then
        echo "✅ All $total_files GDScript files passed validation"
        if [[ "{{OUTPUT}}" == "log" ]]; then
            echo "No errors found" > validation_errors.log
        fi
        exit 0
    else
        echo "❌ Found $error_count files with syntax errors"
        if [[ "{{OUTPUT}}" == "log" ]]; then
            echo "Validation complete. Errors saved to validation_errors.log"
        fi
        exit 1
    fi

# Validate GDScript code by checking for syntax errors
validate-gdscript OUTPUT="console": (check OUTPUT)

# Check Android debug connection and app status
check-android-debug-status:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📱 Checking Android debug status..."
    
    # Check if device is connected
    if ! adb -s {{ANDROID_DEVICE_ID}} shell echo "Connected" >/dev/null 2>&1; then
        echo "❌ Android device not connected: {{ANDROID_DEVICE_ID}}"
        exit 1
    fi
    
    # Check if app is installed
    if ! adb -s {{ANDROID_DEVICE_ID}} shell pm list packages | grep -q "{{ANDROID_PACKAGE_NAME}}" 2>/dev/null; then
        echo "❌ App not installed: {{ANDROID_PACKAGE_NAME}}"
        exit 1
    fi
    
    # Check if app is running
    if adb -s {{ANDROID_DEVICE_ID}} shell pgrep "{{ANDROID_PACKAGE_NAME}}" >/dev/null 2>&1; then
        echo "✅ App is running"
    else
        echo "⚠️  App is not running"
    fi
    
    # Check debug bridge status
    echo "📋 Debug bridge status:"
    adb -s {{ANDROID_DEVICE_ID}} shell getprop ro.debuggable 2>/dev/null || echo "  Debug property not accessible"
    
    echo "✅ Android debug status check complete"