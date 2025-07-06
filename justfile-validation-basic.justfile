# Basic system validation commands
# Self-contained utilities for validating development environment

# Basic Android device validation (always passes - for dependency chains)
_validate-android-device:
    @true

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

# Validate iOS development tools are available
_validate-ios-tools:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! xcrun devicectl list devices >/dev/null 2>&1; then
        echo "❌ iOS development tools not available"
        echo "💡 Install Xcode Command Line Tools: xcode-select --install"
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

# Ensure directory exists, create if missing
_ensure-directory-exists DIR:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -d "{{DIR}}" ]; then
        mkdir -p "{{DIR}}"
        echo "📁 Created directory: {{DIR}}"
    fi

# Validate Android package installation status
_validate-android-package-installed:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! adb -s {{ANDROID_DEVICE_ID}} shell pm list packages | grep -q "{{ANDROID_PACKAGE_NAME}}" 2>/dev/null; then
        echo "❌ Android package not installed: {{ANDROID_PACKAGE_NAME}}"
        echo "💡 Install APK first: just install-apk-android"
        exit 1
    fi