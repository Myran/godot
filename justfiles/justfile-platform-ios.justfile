# iOS Platform Development Commands
# Complete iOS build, deploy, test, and device management workflow
# Handles iOS-specific development tasks and workflows

# Note: Variables and build functions inherited from imported modules

# iOS help information
help-ios:
    #!/usr/bin/env bash
    echo "🍎 iOS Development Commands"
    echo "=========================="
    echo ""
    echo "Build Commands:"
    echo "  just templates-ios               # Build iOS templates and executables"
    echo "  just build-ios-app              # Build iOS .app with Xcode"
    echo "  just export-pck-build-iphone     # Export PCK to iPhone .app"
    echo "  just export-pck-build-ipad       # Export PCK to iPad .app"
    echo "  just ios-deploy-config CONFIG   # Deploy test config to app bundle"
    echo "  just ios-test-file-access       # Test iOS file reading mechanism"
    echo "  just export-pck-ios              # Export iOS PCK file"
    echo "  just build-all-ios               # Full iOS build pipeline (templates + app + PCK)"
    echo "  just rebuild-all-ios            # Force rebuild all iOS components"
    echo ""
    echo "Testing Commands:"
    echo "  just test-ios CONFIG            # iOS testing with fzf selection"
    echo "  just test-ios-target CONFIG     # iOS automated testing with validation"
    echo "  just test-ios-iphone CONFIG     # iOS testing on iPhone device"
    echo "  just test-ios-ipad CONFIG       # iOS testing on iPad device"
    echo "    • Default: iPad (configurable via IOS_TEST_DEVICE)"
    echo ""
    echo "Manual Testing (Stays Open for Inspection):"
    echo "  just test-ios-manual CONFIG           # iOS manual testing (auto-detects device)"
    echo "  just test-ios-ipad-manual CONFIG      # iPad manual testing"
    echo "  just test-ios-iphone-manual CONFIG    # iPhone manual testing"
    echo ""
    echo "Checksum Baseline Management:"
    echo "  just test-ios-update CONFIG     # Update checksum baseline (after legitimate changes)"
    echo "  just test-ios-reset CONFIG      # Reset checksum baseline (start fresh)"
    echo ""
    echo "Log Cleanup:"
    echo "  just clean-godot-logs            # Clean all Godot test logs (iOS, Android, Desktop)"
    echo "  just clean-godot-logs-by-age [days] # Clean Godot logs older than N days (default: 7)"
    echo "  just clean-all-logs [days]       # Clean all logs (Godot + main directory) older than N days (default: 7)"
    echo ""
    echo "Deploy (Development - export → install → run):"
    echo "  just deploy-ios                  # Deploy to iOS (uses IOS_TEST_DEVICE, default: iPad)"
    echo "  just deploy-ios-iphone           # Deploy to iPhone"
    echo "  just deploy-ios-ipad             # Deploy to iPad"
    echo ""
    echo "Ship (Production - App Store):"
    echo "  just ship-ios                    # Ship to App Store via fastlane"
    echo ""
    echo "Export:"
    echo "  just export-ios-debug            # Export iOS debug build"
    echo "  just export-ios-release          # Export iOS release build"
    echo "  just export-pck-ios              # Export iOS PCK file"
    echo ""
    echo "Device Logging (Unified Commands):"
    echo "  just logs-ios-device SEARCH      # Search device logs (auto-detects iPhone/iPad)"
    echo "  just logs-ios-health             # iOS device health check"
    echo "  just logs-ios-status             # iOS device status (connectivity, app state)"
    echo ""
    echo "Device Logging (Device-Specific):"
    echo "  just logs-ios-device-iphone      # Monitor live logs from iPhone"
    echo "  just logs-ios-device-ipad        # Monitor live logs from iPad"
    echo "  just logs-ios-recent-iphone      # Recent logs from iPhone (10 min)"
    echo "  just logs-ios-recent-ipad        # Recent logs from iPad (10 min)"
    echo "  just logs-ios-search-iphone \"pattern\"  # Search logs on iPhone"
    echo "  just logs-ios-search-ipad \"pattern\"    # Search logs on iPad"
    echo "  just sentry-ios-logs-iphone      # Sentry-specific logs from iPhone"
    echo "  just sentry-ios-logs-ipad        # Sentry-specific logs from iPad"
    echo "  just logs-ios-config-iphone      # JSON config logs from iPhone"
    echo "  just logs-ios-config-ipad        # JSON config logs from iPad"
    echo ""
    echo "Quick Commands:"
    echo "  just quick-build-ios             # Quick iOS build"

# Copy iOS PCK to app bundle (internal helper)
_copy-pck-to-ios-app-bundle:
    #!/usr/bin/env bash
    set -euo pipefail
    APP_BUNDLE_PATH="export/ios/build/products/Debug-iphoneos/{{GAME_NAME}}.app"
    if [ -d "$APP_BUNDLE_PATH" ]; then
        echo "📦 Copying PCK to iOS app bundle..."
        cp export/ios/{{GAME_NAME}}.pck "$APP_BUNDLE_PATH/{{GAME_NAME}}.pck"
        echo "✅ PCK copied to app bundle"
    fi

# Export iOS PCK file
export-pck-ios: pre-build
    @echo "📦 Exporting iOS PCK file..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --export-pack "ios" ../export/ios/{{GAME_NAME}}.pck --headless
    @just _copy-pck-to-ios-app-bundle

# Base iOS app builder - handles debug/release configurations
_ios-build-app BUILD_TYPE: pre-build
    #!/usr/bin/env bash
    set -euo pipefail

    # Validate build type
    if [ "{{BUILD_TYPE}}" != "Debug" ] && [ "{{BUILD_TYPE}}" != "Release" ]; then
        echo "❌ Invalid build type: {{BUILD_TYPE}}. Use 'Debug' or 'Release'"
        exit 1
    fi

    echo "🔨 Building iOS app ({{BUILD_TYPE}}) with Xcode..."
    cd export/ios && xcodebuild -workspace {{GAME_NAME}}.xcworkspace \
                                -scheme {{GAME_NAME}} \
                                -configuration {{BUILD_TYPE}} \
                                -destination "generic/platform=iOS" \
                                -allowProvisioningUpdates

# Build iOS debug app with Xcode (creates .app file)
build-ios-app-debug: (_ios-build-app "Debug")

# Build iOS release app with Xcode (creates .app file)
build-ios-app-release: (_ios-build-app "Release")

# Build iOS app with Xcode (default: debug, backward compatible)
build-ios-app: build-ios-app-debug

# Export PCK file directly to iPhone app bundle
export-pck-build-iphone: pre-build
    @echo "💾 Exporting iOS PCK file to iPhone app bundle..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --headless --export-pack ios ../export/ios/build/products/Debug-iphoneos/{{GAME_NAME}}.app/{{GAME_NAME}}.pck

# Export PCK file directly to iPad app bundle
export-pck-build-ipad: pre-build
    @echo "💾 Exporting iOS PCK file to iPad app bundle..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --headless --export-pack ios ../export/ios/build/products/Debug-iphoneos/{{GAME_NAME}}.app/{{GAME_NAME}}.pck

# Deploy test config to iOS app bundle (DEPRECATED - for backward compatibility only)
# This deploys to res:// (read-only) - use ios-push-config-to-device for user:// (writable)
ios-deploy-config config_name:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "⚠️  WARNING: This deploys to res:// (read-only app bundle)"
    echo "   For determinism tests, use 'just ios-push-config-to-device' instead"
    echo ""
    echo "📱 Deploying test config to iOS app bundle..."
    CONFIG_FILE="tests/debug_configs/{{config_name}}.json"
    APP_BUNDLE_PATH="export/ios/build/products/Debug-iphoneos/{{GAME_NAME}}.app"
    TARGET_PATH="${APP_BUNDLE_PATH}/debug_startup_actions.json"

    # Validate config exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "❌ Config file not found: $CONFIG_FILE"
        echo "💡 Available configs:"
        ls tests/debug_configs/*.json | xargs -n 1 basename | sed 's/.json$//'
        exit 1
    fi

    # Validate app bundle exists
    if [[ ! -d "$APP_BUNDLE_PATH" ]]; then
        echo "❌ iOS app bundle not found: $APP_BUNDLE_PATH"
        echo "💡 Run 'just build-ios-app' first"
        exit 1
    fi

    echo "📄 Config: $CONFIG_FILE"
    echo "🎯 Target: $TARGET_PATH"

    # Deploy config to app bundle
    cp "$CONFIG_FILE" "$TARGET_PATH"

    echo "✅ Test config deployed to iOS app bundle"
    echo "💡 Next: 'just run-ios-iphone' or 'just run-ios-ipad'"

# Push config file to iOS device's user:// directory (writable Documents folder)
# This enables determinism tests to update the config with expectedHash
_push-file-ios DEVICE_ID SOURCE_FILE TARGET_FILENAME:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "📱 Pushing file to iOS device user:// directory..."
    echo "   📄 Source: {{SOURCE_FILE}}"
    echo "   🎯 Target: {{TARGET_FILENAME}} (in Documents/)"
    echo "   📱 Device: {{DEVICE_ID}}"

    # Use xcrun devicectl to copy file to app's Documents directory (user://)
    # --domain-type appDataContainer gives us access to the app's sandbox
    # --domain-identifier is the bundle ID
    if xcrun devicectl device copy to \
        --device "{{DEVICE_ID}}" \
        --source "{{SOURCE_FILE}}" \
        --destination "Documents/{{TARGET_FILENAME}}" \
        --domain-type appDataContainer \
        --domain-identifier "{{IOS_BUNDLE_IDENTIFIER}}" \
        --quiet; then
        echo "✅ File pushed to user://{{TARGET_FILENAME}}"
    else
        echo "❌ Failed to push file to iOS device"
        echo "💡 Make sure the app is installed and the device is unlocked"
        exit 1
    fi

# Push config to iOS device for testing (writable location - user://)
ios-push-config-to-device DEVICE_TYPE CONFIG_NAME_OR_PATH:
    #!/usr/bin/env bash
    set -euo pipefail

    # Determine device ID based on type
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

    CONFIG_INPUT="{{CONFIG_NAME_OR_PATH}}"

    echo "📱 Pushing config to $DEVICE_NAME..."

    # Auto-detect: file path vs config name
    if [[ -f "$CONFIG_INPUT" ]]; then
        # File path provided - use directly (for temp configs with injected metadata)
        CONFIG_FILE="$CONFIG_INPUT"
        echo "📄 Using file path: $CONFIG_FILE"
    else
        # Config name provided - resolve to file
        CONFIG_FILE="tests/debug_configs/${CONFIG_INPUT}.json"
        if [[ ! -f "$CONFIG_FILE" ]]; then
            # Try with _ios_automated suffix
            CONFIG_FILE="tests/debug_configs/${CONFIG_INPUT}_ios_automated.json"
        fi
        echo "📄 Resolved config name to: $CONFIG_FILE"
    fi

    # Validate resolved file exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "❌ Config file not found: $CONFIG_FILE"
        echo "💡 Available configs:"
        ls tests/debug_configs/*.json 2>/dev/null | xargs -n 1 basename | sed 's/.json$//' || echo "No configs found"
        exit 1
    fi

    # Push config to device
    just _push-file-ios "$DEVICE_ID" "$CONFIG_FILE" "debug_startup_actions.json"

    echo "✅ Config pushed to $DEVICE_NAME successfully"

# Test iOS file access by building with placeholder config
ios-test-file-access:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🧪 Testing iOS file access mechanism..."

    # Ensure placeholder config exists
    if [[ ! -f "export/ios/debug_startup_actions.json" ]]; then
        echo "❌ Placeholder config not found in export/ios/"
        exit 1
    fi

    echo "✅ Placeholder config found in export/ios/"
    echo "📄 Content preview:"
    cat export/ios/debug_startup_actions.json | jq '.description, .test_metadata.test_id'

    # Build iOS app
    echo "🔨 Building iOS app..."
    just build-ios-app

    # Copy placeholder config to app bundle (like we do for PCK files)
    echo "📝 Deploying placeholder config to app bundle..."
    APP_BUNDLE_PATH="export/ios/build/products/Debug-iphoneos/{{GAME_NAME}}.app"
    BUNDLE_CONFIG_PATH="${APP_BUNDLE_PATH}/debug_startup_actions.json"

    cp export/ios/debug_startup_actions.json "$BUNDLE_CONFIG_PATH"

    # Verify placeholder config is in app bundle
    if [[ -f "$BUNDLE_CONFIG_PATH" ]]; then
        echo "✅ Placeholder config deployed to app bundle at: $BUNDLE_CONFIG_PATH"
        echo "📄 Bundle content preview:"
        cat "$BUNDLE_CONFIG_PATH" | jq '.description, .test_metadata.test_id'
    else
        echo "❌ Placeholder config deployment failed"
        exit 1
    fi

    echo "✅ iOS file access test complete - placeholder ready for overwriting"
    echo "💡 Use 'just ios-deploy-config CONFIG' to overwrite with test configs"

# iOS build pipeline
# Duplicate removed - use export-pck-ios instead


# Update iOS PCK file
ios-update-pck: pre-build
    @echo "🔄 Updating iOS PCK file..."
    just export-pck-ios
    @echo "✅ iOS PCK updated"

# REMOVED: build-install-ios - duplicate of build-all-ios (incomplete, no .app build)
# Use: just build-all-ios for complete iOS build pipeline (templates + app + PCK)


# Force rebuild all iOS components (ignores existing builds)
rebuild-all-ios:
    @echo "🔥 Force rebuilding all iOS components..."
    just build-all-ios force=yes
    @echo "✅ All iOS rebuilds complete"

# Complete iOS pipeline - from source to device deployment
# Renamed from build-all-ios for platform naming consistency (Task-365)
build-all-ios force="no":
    @echo "🤖 FULL BUILD - iOS ONLY"
    @echo "======================"
    @if [ "{{force}}" = "yes" ]; then \
        echo "⏱️  Estimated time: 30-40 minutes (FORCE REBUILD)"; \
        echo "🔥 Force rebuild enabled - will rebuild everything from scratch"; \
    else \
        echo "⏱️  Estimated time: 5-15 minutes (smart rebuild)"; \
        echo "💡 Use 'just build-all-ios force=yes' to force rebuild everything"; \
    fi
    @echo ""

    just templates-ios {{force}}
    just build-ios-app
    just export-pck-ios
    @echo "✅ iOS full build complete - ready for device deployment"
    @echo "💡 Use 'just run-ios-iphone' to deploy to iPhone"
    @echo "💡 Use 'just run-ios-ipad' to deploy to iPad"


# ================================
# iOS EXPORT COMMANDS (Platform Parity)
# Following macOS/Windows pattern for consistency (Task-371)
# ================================

# Export iOS debug build (templates + debug .app + PCK)
export-ios-debug:
    @echo "🍎 Exporting iOS Debug Build"
    @echo "=============================="
    @echo "⏱️  Estimated time: 5-10 minutes"
    @echo ""

    just templates-ios
    just _ios-build-app "Debug"
    just export-pck-ios

    @echo ""
    @echo "✅ iOS debug export complete"
    @echo "📦 App bundle: export/ios/build/products/Debug-iphoneos/{{GAME_NAME}}.app"
    @echo "📦 PCK file: export/ios/{{GAME_NAME}}.pck"
    @echo "💡 Use 'just test-ios-target CONFIG' to test on device"

# Export iOS release build (templates + release .app + PCK)
export-ios-release:
    @echo "🍎 Exporting iOS Release Build"
    @echo "================================"
    @echo "⏱️  Estimated time: 5-10 minutes"
    @echo ""

    just templates-ios
    just _ios-build-app "Release"
    just export-pck-ios

    @echo ""
    @echo "✅ iOS release export complete"
    @echo "📦 App bundle: export/ios/build/products/Release-iphoneos/{{GAME_NAME}}.app"
    @echo "📦 PCK file: export/ios/{{GAME_NAME}}.pck"
    @echo "💡 Ready for App Store submission or TestFlight distribution"

# Export both iOS debug and release builds
export-ios-all:
    @echo "🍎 Exporting iOS (Debug + Release)"
    @echo "==================================="
    @echo "⏱️  Estimated time: 10-20 minutes"
    @echo ""

    just templates-ios
    just _ios-build-app "Debug"
    just _ios-build-app "Release"
    just export-pck-ios

    @echo ""
    @echo "✅ iOS full export complete (debug + release)"
    @echo "📦 Debug app: export/ios/build/products/Debug-iphoneos/{{GAME_NAME}}.app"
    @echo "📦 Release app: export/ios/build/products/Release-iphoneos/{{GAME_NAME}}.app"
    @echo "📦 PCK file: export/ios/{{GAME_NAME}}.pck"
    @echo "💡 Debug builds for development, Release builds for distribution"


# ================================
# iOS COMBINED EXPORT+INSTALL WORKFLOWS
# ================================
# Platform parity with Android: export-install-android-debug, export-install-android-launch-debug

# Export and install iOS debug build (no launch)
export-install-ios-debug: export-ios-debug (_ios-install-only-app "ipad" "debug")
    @echo "🔄 iOS: Export and install debug workflow completed"

# Export and install iOS release build (no launch)
export-install-ios-release: export-ios-release (_ios-install-only-app "ipad" "release")
    @echo "🔄 iOS: Export and install release workflow completed"

# Export, install, and launch iOS debug build
export-install-ios-launch-debug: export-ios-debug install-ios-ipad-debug
    @echo "🔄 iOS: Export, install, and launch debug workflow completed"

# Export, install, and launch iOS release build
export-install-ios-launch-release: export-ios-release install-ios-ipad-release
    @echo "🔄 iOS: Export, install, and launch release workflow completed"


# ================================
# DEPLOY: Development device workflow (export → install → run)
# ================================
# Note: For app store release, use 'ship-ios' instead

# Internal: Deploy to iOS with device selection
_deploy-ios-internal DEVICE_TYPE="ipad": export-ios-debug (_ios-launch-app DEVICE_TYPE "debug")
    @echo "📱 Deploy to iOS ({{DEVICE_TYPE}}) complete"

# Deploy to iOS (complete workflow: export → install → run)
# Uses IOS_TEST_DEVICE env var or defaults to iPad
# This is the primary command for development iteration
deploy-ios:
    #!/usr/bin/env bash
    set -euo pipefail
    # Use IOS_TEST_DEVICE if set, otherwise default to ipad
    DEVICE="${IOS_TEST_DEVICE:-ipad}"
    # Normalize device name
    if [[ "$DEVICE" == *"iPhone"* ]] || [[ "$DEVICE" == *"iphone"* ]]; then
        just _deploy-ios-internal iphone
    else
        just _deploy-ios-internal ipad
    fi

# Deploy to iPhone (complete workflow: export → install → run)
deploy-ios-iphone: export-ios-debug install-ios-iphone-debug
    @echo "📱 Deploy to iPhone complete"

# Deploy to iPad (complete workflow: export → install → run)
deploy-ios-ipad: export-ios-debug install-ios-ipad-debug
    @echo "📱 Deploy to iPad complete"


# ================================
# iOS DEVICE LOGGING
# ================================

# Core device logging function - takes device ID as argument
_ios-device-logs-internal device_id device_name:
    #!/usr/bin/env bash
    set -euo pipefail

    DEVICE_ID="{{device_id}}"
    DEVICE_NAME="{{device_name}}"

    echo "🔍 Streaming live logs from ${DEVICE_NAME} device..."
    echo "📱 Device ID: $DEVICE_ID"
    echo "🎯 Monitoring process: {{GAME_NAME}}"
    echo "⏹️  Press Ctrl+C to stop streaming"
    echo ""

    # Use idevicesyslog for actual iOS device log access
    idevicesyslog -u "$DEVICE_ID" -p {{GAME_NAME}} --no-colors

# Stream live logs from iPhone device
# Renamed from ios-device-logs-iphone for unified log naming (Task-366)
logs-ios-device-iphone:
    just _ios-device-logs-internal "{{IOS_IPHONE_DEVICE_ID}}" "iPhone"

# Stream live logs from iPad device
# Renamed from ios-device-logs-ipad for unified log naming (Task-366)
logs-ios-device-ipad:
    just _ios-device-logs-internal "{{IOS_IPAD_DEVICE_ID}}" "iPad"

# Core recent logs function - takes device ID as argument
_ios-recent-logs-internal device_id device_name:
    #!/usr/bin/env bash
    set -euo pipefail

    DEVICE_ID="{{device_id}}"
    DEVICE_NAME="{{device_name}}"

    echo "🔍 Searching recent logs from ${DEVICE_NAME} device..."
    echo "📱 Device ID: $DEVICE_ID"
    echo "📊 Time range: Recent logs (no time filter - idevicesyslog shows live)"
    echo "🎯 Monitoring process: {{GAME_NAME}}"
    echo "⏹️  Press Ctrl+C to stop streaming"
    echo ""

    # Use idevicesyslog for actual iOS device log access
    # Note: idevicesyslog doesn't have time-based filtering like macOS log show
    # It shows recent logs from the device buffer
    idevicesyslog -u "$DEVICE_ID" -p {{GAME_NAME}} --no-colors

# Search recent logs from iPhone device (last 10 minutes)
# Renamed from ios-recent-logs-iphone for unified log naming (Task-366)
logs-ios-recent-iphone:
    just _ios-recent-logs-internal "{{IOS_IPHONE_DEVICE_ID}}" "iPhone"

# Search recent logs from iPad device (last 10 minutes)
# Renamed from ios-recent-logs-ipad for unified log naming (Task-366)
logs-ios-recent-ipad:
    just _ios-recent-logs-internal "{{IOS_IPAD_DEVICE_ID}}" "iPad"

# Core pattern search function - takes device ID as argument
_ios-search-logs-internal pattern device_id device_name:
    #!/usr/bin/env bash
    set -euo pipefail

    PATTERN="{{pattern}}"
    DEVICE_ID="{{device_id}}"
    DEVICE_NAME="{{device_name}}"

    echo "🔍 Searching for pattern: ${PATTERN}"
    echo "📱 Device ID: $DEVICE_ID"
    echo "📊 Time range: Live stream (shows recent logs containing pattern)"
    echo "⏹️  Press Ctrl+C to stop streaming"
    echo ""

    # Use idevicesyslog with pattern matching
    idevicesyslog -u "$DEVICE_ID" -p {{GAME_NAME}} -m "$PATTERN" --no-colors

# Search for specific patterns in iPhone device logs
# Renamed from ios-search-logs-iphone for unified log naming (Task-366)
logs-ios-search-iphone pattern:
    just _ios-search-logs-internal "{{pattern}}" "{{IOS_IPHONE_DEVICE_ID}}" "iPhone"

# Search for specific patterns in iPad device logs
# Renamed from ios-search-logs-ipad for unified log naming (Task-366)
logs-ios-search-ipad pattern:
    just _ios-search-logs-internal "{{pattern}}" "{{IOS_IPAD_DEVICE_ID}}" "iPad"

# Core Sentry monitoring function - takes device ID as argument
_ios-sentry-logs-internal device_id device_name:
    #!/usr/bin/env bash
    set -euo pipefail

    DEVICE_ID="{{device_id}}"
    DEVICE_NAME="{{device_name}}"

    echo "🔍 Monitoring Sentry SDK logs from ${DEVICE_NAME} device..."
    echo "📱 Device ID: $DEVICE_ID"
    echo "🎯 Looking for: Sentry initialization, debug messages, crash reports"
    echo "⏹️  Press Ctrl+C to stop streaming"
    echo ""

    # Use idevicesyslog with Sentry pattern matching
    # Using general pattern that matches all Sentry-related terms and debug startup
    idevicesyslog -u "$DEVICE_ID" -p {{GAME_NAME}} -m "entr" -m "debug_startup" --no-colors

# Monitor Sentry-related logs specifically from iPhone
sentry-ios-logs-iphone:
    just _ios-sentry-logs-internal "{{IOS_IPHONE_DEVICE_ID}}" "iPhone"

# Monitor Sentry-related logs specifically from iPad
sentry-ios-logs-ipad:
    just _ios-sentry-logs-internal "{{IOS_IPAD_DEVICE_ID}}" "iPad"

# Core JSON config monitoring function - takes device ID as argument
_ios-config-logs-internal device_id device_name:
    #!/usr/bin/env bash
    set -euo pipefail

    DEVICE_ID="{{device_id}}"
    DEVICE_NAME="{{device_name}}"

    echo "🔍 Monitoring JSON config reading logs from ${DEVICE_NAME} device..."
    echo "📱 Device ID: $DEVICE_ID"
    echo "🎯 Looking for: debug_startup_actions.json, config reader, debug coordinator"
    echo "⏹️  Press Ctrl+C to stop streaming"
    echo ""

    # Use idevicesyslog with config pattern matching
    # Match config-related terms - prioritize most specific patterns first
    idevicesyslog -u "$DEVICE_ID" -p {{GAME_NAME}} -m "debug_startup_actions" -m "config_reader" -m "DebugConfigReader" -m "DebugStartupCoordinator" --no-colors

# Monitor JSON config reading specifically from iPhone
# Renamed from ios-config-logs-iphone for unified log naming (Task-366)
logs-ios-config-iphone:
    just _ios-config-logs-internal "{{IOS_IPHONE_DEVICE_ID}}" "iPhone"

# Monitor JSON config reading specifically from iPad
# Renamed from ios-config-logs-ipad for unified log naming (Task-366)
logs-ios-config-ipad:
    just _ios-config-logs-internal "{{IOS_IPAD_DEVICE_ID}}" "iPad"

# Retrieve stored logs from iOS device Documents/logs/ directory
_ios-retrieve-logs-internal device_id device_name:
    #!/usr/bin/env bash
    set -euo pipefail

    DEVICE_ID="{{device_id}}"
    DEVICE_NAME="{{device_name}}"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    DEST_DIR="/tmp/ios_logs_${TIMESTAMP}"

    echo "📱 Retrieving logs from ${DEVICE_NAME} (${DEVICE_ID})"
    echo "📂 Destination: ${DEST_DIR}"

    xcrun devicectl device copy from \
        --device "$DEVICE_ID" \
        --source "Documents/logs/" \
        --destination "$DEST_DIR" \
        --domain-type appDataContainer \
        --domain-identifier "{{IOS_BUNDLE_IDENTIFIER}}"

    echo "✅ Logs retrieved to: ${DEST_DIR}"
    echo "📄 Available logs:"
    ls -lh "$DEST_DIR"

# Retrieve stored logs from iPhone device
# Renamed from ios-retrieve-logs-iphone for unified log naming (Task-366)
logs-ios-retrieve-iphone:
    just _ios-retrieve-logs-internal "{{IOS_IPHONE_DEVICE_ID}}" "iPhone"

# Retrieve stored logs from iPad device
# Renamed from ios-retrieve-logs-ipad for unified log naming (Task-366)
logs-ios-retrieve-ipad:
    just _ios-retrieve-logs-internal "{{IOS_IPAD_DEVICE_ID}}" "iPad"

# iOS testing interface - manual mode with fzf selection
test-ios target="":
    #!/usr/bin/env bash
    set -euo pipefail

    # If arguments provided, delegate to test-ios-target (automated mode)
    if [ -n "{{target}}" ]; then
        echo "🎯 Automated mode execution: {{target}}"

        # Fix for Task-282: Set MULTI_PLATFORM_SESSION for individual tests to enable session filtering
        if [[ -z "${MULTI_PLATFORM_SESSION:-}" ]]; then
            export MULTI_PLATFORM_SESSION="$(date +%s)"
            echo "🔧 Setting individual test session for filtering: $MULTI_PLATFORM_SESSION"
        else
            echo "🔧 Using existing MULTI_PLATFORM_SESSION: $MULTI_PLATFORM_SESSION"
        fi

        just test-ios-target "{{target}}"
        exit $?
    fi

    # Use shared fzf selection for all configs (automatic mode)
    selected=$(just _fzf-select-config "ios" "all")
    if [ "$?" -eq 0 ] && [ -n "$selected" ]; then
        # Fix for Task-282: Set MULTI_PLATFORM_SESSION for individual tests to enable session filtering
        if [[ -z "${MULTI_PLATFORM_SESSION:-}" ]]; then
            export MULTI_PLATFORM_SESSION="$(date +%s)"
            echo "🔧 Setting individual test session for filtering: $MULTI_PLATFORM_SESSION"
        else
            echo "🔧 Using existing MULTI_PLATFORM_SESSION: $MULTI_PLATFORM_SESSION"
        fi

        echo "Running automatic mode: just test-ios-target '$selected'"
        just test-ios-target "$selected"
    else
        echo "❌ No selection made"
        exit 1
    fi

# Detect connected iOS device (returns first connected device ID)
_detect-ios-device:
    #!/usr/bin/env bash
    set -euo pipefail

    # Try to get first connected iOS device by extracting UUID
    DEVICE=$(xcrun devicectl list devices 2>/dev/null | grep -i "connected" | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -1 || echo "")

    if [[ -z "$DEVICE" ]]; then
        echo "❌ No connected iOS devices found" >&2
        echo "💡 Connect an iOS device and ensure it's trusted" >&2
        exit 1
    fi

    # Output the device ID
    echo "$DEVICE"

# Auto-select iOS device (prefers iPad if both connected, fallback to iPhone or first device)
_auto-select-ios-device:
    #!/usr/bin/env bash
    set -euo pipefail

    # Check if iPad is connected (using configured ID)
    IPAD_ID="{{IOS_IPAD_DEVICE_ID}}"
    IPHONE_ID="{{IOS_IPHONE_DEVICE_ID}}"

    # Get all connected device UUIDs
    CONNECTED_DEVICES=$(xcrun devicectl list devices 2>/dev/null | grep -i "connected" | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' || echo "")

    if [[ -z "$CONNECTED_DEVICES" ]]; then
        echo "❌ No connected iOS devices found" >&2
        echo "💡 Connect an iOS device and ensure it's trusted" >&2
        exit 1
    fi

    # Prefer iPad if connected (case-insensitive match)
    if echo "$CONNECTED_DEVICES" | grep -qi "$IPAD_ID"; then
        echo "$IPAD_ID"
        exit 0
    fi

    # Fallback to iPhone if connected
    if echo "$CONNECTED_DEVICES" | grep -qi "$IPHONE_ID"; then
        echo "$IPHONE_ID"
        exit 0
    fi

    # Fallback to first connected device
    FIRST_DEVICE=$(echo "$CONNECTED_DEVICES" | head -1)
    echo "$FIRST_DEVICE"

# iOS equivalent of test-android-target - complete test workflow with device logging
test-ios-target config_name="":
    #!/usr/bin/env bash
    set -euo pipefail

    # If no config provided, show fzf selection
    if [ -z "{{ config_name }}" ]; then
        selected=$(just _fzf-select-config "ios" "all")
        if [ "$?" -eq 0 ] && [ -n "$selected" ]; then
            CONFIG_NAME="$selected"
        else
            echo "❌ No selection made"
            exit 1
        fi
    else
        CONFIG_NAME="{{ config_name }}"
    fi

    # Create session timestamp for individual test
    # Use multi-platform session if available to ensure coordination
    if [[ -n "${MULTI_PLATFORM_SESSION:-}" ]]; then
        TEST_SESSION="$MULTI_PLATFORM_SESSION"
    else
        TEST_SESSION="$(date +%s)"
    fi

    # Use the unified execution pattern - same as Android!
    just _execute-test-with-analysis "$CONFIG_NAME" "ios" "$TEST_SESSION"

# iOS testing wrapper for iPhone device
test-ios-iphone target="":
    #!/usr/bin/env bash
    set -euo pipefail

    echo "📱 Setting test device to iPhone: {{IOS_IPHONE_DEVICE_ID}}"
    export IOS_TEST_DEVICE="{{IOS_IPHONE_DEVICE_ID}}"

    if [ -n "{{target}}" ]; then
        just test-ios "{{target}}"
    else
        just test-ios
    fi

# iOS testing wrapper for iPad device
test-ios-ipad target="":
    #!/usr/bin/env bash
    set -euo pipefail

    echo "📱 Setting test device to iPad: {{IOS_IPAD_DEVICE_ID}}"
    export IOS_TEST_DEVICE="{{IOS_IPAD_DEVICE_ID}}"

    if [ -n "{{target}}" ]; then
        just test-ios "{{target}}"
    else
        just test-ios
    fi

# iOS manual testing wrapper for iPhone device
test-ios-iphone-manual config_name="":
    #!/usr/bin/env bash
    set -euo pipefail

    echo "📱 Setting test device to iPhone: {{IOS_IPHONE_DEVICE_ID}}"
    export IOS_TEST_DEVICE="{{IOS_IPHONE_DEVICE_ID}}"

    if [ -n "{{config_name}}" ]; then
        just test-ios-manual "{{config_name}}"
    else
        echo "❌ Please specify a configuration name"
        echo "Usage: just test-ios-iphone-manual CONFIG_NAME"
        exit 1
    fi

# iOS manual testing wrapper for iPad device
test-ios-ipad-manual config_name="":
    #!/usr/bin/env bash
    set -euo pipefail

    echo "📱 Setting test device to iPad: {{IOS_IPAD_DEVICE_ID}}"
    export IOS_TEST_DEVICE="{{IOS_IPAD_DEVICE_ID}}"

    if [ -n "{{config_name}}" ]; then
        just test-ios-manual "{{config_name}}"
    else
        echo "❌ Please specify a configuration name"
        echo "Usage: just test-ios-ipad-manual CONFIG_NAME"
        exit 1
    fi

# iOS checksum baseline management - update baseline after legitimate changes
test-ios-update config_name="":
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG_NAME="{{config_name}}"

    # If no config name provided, show interactive selector for checksum-enabled configs
    if [[ -z "$CONFIG_NAME" ]]; then
        echo "🔍 Selecting checksum test configuration..."

        # Find all checksum-enabled configs
        CHECKSUM_CONFIGS=""

        if [[ -d "{{DEBUG_CONFIG_DIR}}" ]]; then
            while IFS= read -r -d '' config_file; do
                if [[ -f "$config_file" ]] && jq -e '.checksum_config' "$config_file" >/dev/null 2>&1; then
                    basename=$(basename "$config_file" .json)
                    state_type=$(jq -r '.checksum_config.state_type // "unknown"' "$config_file")
                    expected_checksums_count=$(jq -r '.checksum_config.expected_checksums | length' "$config_file")
                    description=$(jq -r '.description // "No description"' "$config_file")

                    # Determine status
                    if [[ "$expected_checksums_count" -eq 0 ]]; then
                        status="❌ NO BASELINE SET"
                    else
                        status="✅ BASELINE SET"
                    fi

                    # Format for fzf
                    CHECKSUM_CONFIGS="${CHECKSUM_CONFIGS}📸 ${basename} (${state_type}) ${status} - ${description}\n"
                fi
            done < <(find "{{DEBUG_CONFIG_DIR}}" -name "*.json" -type f -print0)
        fi

        if [[ -z "$CHECKSUM_CONFIGS" ]]; then
            echo "❌ No checksum-enabled configurations found"
            echo ""
            echo "To enable checksum testing, add a checksum_config section to your configuration."
            exit 1
        fi

        echo "📸 Available checksum configurations:"
        echo "===================================="

        # Use fzf for selection if available, otherwise show list
        if command -v fzf >/dev/null 2>&1; then
            SELECTED=$(echo -e "$CHECKSUM_CONFIGS" | fzf --prompt="Select checksum config to update: " --height=10 --layout=reverse)
            if [[ -z "$SELECTED" ]]; then
                echo "❌ No configuration selected"
                exit 1
            fi

            # Extract config name from selection
            CONFIG_NAME=$(echo "$SELECTED" | sed 's/📸 \([^ ]*\) .*/\1/')
        else
            echo -e "$CHECKSUM_CONFIGS"
            echo ""
            echo "❌ fzf not available for interactive selection"
            echo "Please specify a configuration name: just test-ios-update CONFIG_NAME"
            echo ""
            echo "Available configurations:"
            echo -e "$CHECKSUM_CONFIGS" | sed 's/📸 \([^ ]*\) .*/  • \1/'
            exit 1
        fi
    fi

    # Call shared update function
    just _update-checksum-baseline "ios" "$CONFIG_NAME"

# iOS checksum baseline management - reset baseline to start fresh
test-ios-reset config_name="":
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG_NAME="{{config_name}}"

    # If no config name provided, show interactive selector for checksum-enabled configs
    if [[ -z "$CONFIG_NAME" ]]; then
        echo "🔍 Selecting checksum test configuration to reset..."

        # Find all checksum-enabled configs
        CHECKSUM_CONFIGS=""

        if [[ -d "{{DEBUG_CONFIG_DIR}}" ]]; then
            while IFS= read -r -d '' config_file; do
                if [[ -f "$config_file" ]] && jq -e '.checksum_config' "$config_file" >/dev/null 2>&1; then
                    basename=$(basename "$config_file" .json)
                    state_type=$(jq -r '.checksum_config.state_type // "unknown"' "$config_file")
                    expected_checksums_count=$(jq -r '.checksum_config.expected_checksums | length' "$config_file")
                    description=$(jq -r '.description // "No description"' "$config_file")

                    # Determine status
                    if [[ "$expected_checksums_count" -eq 0 ]]; then
                        status="❌ NO BASELINE"
                    else
                        status="✅ HAS BASELINE ($expected_checksums_count)"
                    fi

                    # Format for fzf
                    CHECKSUM_CONFIGS="${CHECKSUM_CONFIGS}📸 ${basename} (${state_type}) ${status} - ${description}\n"
                fi
            done < <(find "{{DEBUG_CONFIG_DIR}}" -name "*.json" -type f -print0)
        fi

        if [[ -z "$CHECKSUM_CONFIGS" ]]; then
            echo "❌ No checksum-enabled configurations found"
            exit 1
        fi

        echo "📸 Available checksum configurations:"
        echo "===================================="

        # Use fzf for selection if available, otherwise show list
        if command -v fzf >/dev/null 2>&1; then
            SELECTED=$(echo -e "$CHECKSUM_CONFIGS" | fzf --prompt="Select checksum config to RESET: " --height=10 --layout=reverse)
            if [[ -z "$SELECTED" ]]; then
                echo "❌ No configuration selected"
                exit 1
            fi

            # Extract config name from selection
            CONFIG_NAME=$(echo "$SELECTED" | sed 's/📸 \([^ ]*\) .*/\1/')
        else
            echo -e "$CHECKSUM_CONFIGS"
            echo ""
            echo "❌ fzf not available for interactive selection"
            echo "Please specify a configuration name: just test-ios-reset CONFIG_NAME"
            exit 1
        fi
    fi

    CONFIG_PATH="{{DEBUG_CONFIG_DIR}}/${CONFIG_NAME}.json"

    if [[ ! -f "$CONFIG_PATH" ]]; then
        echo "❌ Config not found: $CONFIG_PATH"
        exit 1
    fi

    echo "🗑️  Resetting checksum baseline for: $CONFIG_NAME (iOS)"
    echo "======================================================="

    # Check if configuration has checksum support
    if ! jq -e '.checksum_config' "$CONFIG_PATH" >/dev/null 2>&1; then
        echo "❌ Configuration does not support checksum validation"
        exit 1
    fi

    # Get current checksum configuration
    STATE_TYPE=$(jq -r '.checksum_config.state_type // "unknown"' "$CONFIG_PATH")
    CHECKSUM_COUNT=$(jq -r '.checksum_config.expected_checksums | length' "$CONFIG_PATH")

    echo "📸 Current Checksum Configuration:"
    echo "State Type: $STATE_TYPE"
    echo "Current Checksums: $CHECKSUM_COUNT"

    if [[ "$CHECKSUM_COUNT" -eq 0 ]]; then
        echo ""
        echo "ℹ️  No baseline currently set - nothing to reset"
        exit 0
    fi

    # Confirm reset
    echo ""
    echo "⚠️  WARNING: This will remove the current baseline checksums ($CHECKSUM_COUNT)"
    echo "The next test run will create a new baseline automatically"
    echo ""
    read -p "Are you sure you want to reset the baseline? (y/N): " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Reset cancelled"
        exit 1
    fi

    # Clear expected checksums
    echo ""
    echo "🗑️  Clearing baseline checksums..."
    TEMP_FILE=$(mktemp)
    jq '.checksum_config.expected_checksums = []' "$CONFIG_PATH" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$CONFIG_PATH"

    echo "✅ Baseline reset completed successfully!"
    echo "========================================"
    echo "Configuration: $CONFIG_NAME"
    echo "State Type: $STATE_TYPE"
    echo "Previous Checksums: $CHECKSUM_COUNT"
    echo "New Checksums: (none - will be created on next run)"
    echo ""
    echo "The next test run will automatically create a new baseline."
    echo "Use 'just test-ios-target $CONFIG_NAME' to generate the new baseline."

# iOS manual testing mode - deploy config and launch app for manual inspection
test-ios-manual config_name:
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG_NAME="{{config_name}}"
    CONFIG_PATH="{{DEBUG_CONFIG_DIR}}/${CONFIG_NAME}.json"

    echo "🎯 iOS Testing (Manual Mode - stays open): $CONFIG_NAME"
    echo "======================================================"

    # Validate configuration exists
    just _validate-config-exists "$CONFIG_NAME"

    # Use IOS_TEST_DEVICE environment variable (set by test-ios-iphone/ipad commands)
    if [[ -z "${IOS_TEST_DEVICE:-}" ]]; then
        echo "❌ IOS_TEST_DEVICE not set. Use 'just test-ios-iphone-manual CONFIG' or 'just test-ios-ipad-manual CONFIG'"
        exit 1
    fi

    # Create temporary config with auto_quit=false for manual mode
    echo "🍎 Creating temporary config with auto_quit=false for manual mode..."
    TEMP_CONFIG_NAME="${CONFIG_NAME}_ios_manual"
    TEMP_CONFIG_PATH="{{DEBUG_CONFIG_DIR}}/${TEMP_CONFIG_NAME}.json"
    just _inject-auto-quit-metadata "$CONFIG_PATH" "$TEMP_CONFIG_PATH" "false"

    # Deploy config to iOS device
    echo "📱 Deploying configuration to iOS device: $IOS_TEST_DEVICE"
    just _deploy-config-ios "$TEMP_CONFIG_PATH"
    rm -f "$TEMP_CONFIG_PATH"

    # Launch the app (user needs to manually tap the app icon)
    echo ""
    echo "✅ iOS test config deployed in manual mode"
    echo "📱 Device: $IOS_TEST_DEVICE"
    echo "💡 Tap the GameTwo app icon to launch with test config"
    echo "🔍 App will stay running for manual inspection"
    echo ""
    echo "To stop: Press Home/Swipe up to close the app"

# iOS deployment function - integrates with existing ios-deploy-config recipe
_deploy-config-ios config_path:
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG_PATH="{{config_path}}"
    echo "📱 Deploying iOS config: $(basename "$CONFIG_PATH")"

    # Validate config exists
    if [[ ! -f "$CONFIG_PATH" ]]; then
        echo "❌ Config file not found: $CONFIG_PATH"
        exit 1
    fi

    # Use IOS_TEST_DEVICE environment variable (set by test-ios-iphone/ipad commands)
    if [[ -z "${IOS_TEST_DEVICE:-}" ]]; then
        echo "❌ IOS_TEST_DEVICE not set. Use test-ios-iphone or test-ios-ipad"
        exit 1
    fi

    echo "📱 Pushing config to iOS device: $IOS_TEST_DEVICE"
    echo "   📄 Config: $CONFIG_PATH"

    # Push config directly to device's user:// directory (writable Documents folder)
    if ! just _push-file-ios "$IOS_TEST_DEVICE" "$CONFIG_PATH" "debug_startup_actions.json"; then
        echo "❌ Failed to push iOS config to device"
        exit 1
    fi

    echo "✅ iOS config pushed to device successfully (user:// writable location)"

# Clean up old iOS test logs by age
clean-ios-logs-by-age days="7":
    #!/usr/bin/env/bash
    set -euo pipefail

    DAYS="{{days}}"

    echo "🧹 Cleaning iOS test logs older than $DAYS days..."

    # Clean iOS device logs
    IOS_LOG_DIR="$HOME/Library/Application Support/Godot/app_userdata/{{GAME_NAME}}/logs"
    if [[ -d "$IOS_LOG_DIR" ]]; then
        echo "📱 Cleaning iOS device logs..."
        find "$IOS_LOG_DIR" -name "ios_*.log" -mtime +${DAYS} -delete -print 2>/dev/null || echo "  No old iOS device logs to clean"

        echo "📊 Cleaning iOS action results..."
        find "$IOS_LOG_DIR" -name "test_action_results_*.json" -mtime +${DAYS} -delete -print 2>/dev/null || echo "  No old iOS action results to clean"
    else
        echo "ℹ️  iOS log directory not found: $IOS_LOG_DIR"
    fi

    echo "✅ iOS log cleanup completed"

# Clean up all iOS test logs (default behavior)
clean-ios-logs:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🧹 Cleaning all iOS test logs..."

    FILES_DELETED=0

    # Clean all iOS logs from app userdata directory
    IOS_LOG_DIR="$HOME/Library/Application Support/Godot/app_userdata/{{GAME_NAME}}/logs"
    if [[ -d "$IOS_LOG_DIR" ]]; then
        echo "📱 Removing all iOS logs from $IOS_LOG_DIR..."

        IOS_FILES_DELETED=$(find "$IOS_LOG_DIR" -name "ios_*.log" -print -delete 2>/dev/null | wc -l)
        ACTION_FILES_DELETED=$(find "$IOS_LOG_DIR" -name "test_action_results_*.json" -print -delete 2>/dev/null | wc -l)
        TOTAL_IOS=$((IOS_FILES_DELETED + ACTION_FILES_DELETED))
        FILES_DELETED=$((FILES_DELETED + TOTAL_IOS))

        if [[ $TOTAL_IOS -gt 0 ]]; then
            echo "  🗑️  Deleted $TOTAL_IOS iOS log files from app directory"
        else
            echo "  ℹ️  No iOS files found in app directory"
        fi
    else
        echo "ℹ️  iOS log directory not found: $IOS_LOG_DIR"
    fi

    # Clean all temporary iOS logs
    echo "🗂️  Removing all temporary iOS logs..."
    TMP_FILES_DELETED=$(find /tmp -name "*ios*.log" -print -delete 2>/dev/null | wc -l)
    TMP_JSON_DELETED=$(find /tmp -name "test_action_results_*ios*.json" -print -delete 2>/dev/null | wc -l)
    TMP_TOTAL=$((TMP_FILES_DELETED + TMP_JSON_DELETED))
    FILES_DELETED=$((FILES_DELETED + TMP_TOTAL))

    if [[ $TMP_TOTAL -gt 0 ]]; then
        echo "  🗑️  Deleted $TMP_TOTAL temporary iOS files"
    else
        echo "  ℹ️  No temporary iOS files found"
    fi

    echo "✅ iOS log cleanup completed - $FILES_DELETED files deleted"

# Clean up old Godot test logs by age
clean-godot-logs-by-age days="7":
    #!/usr/bin/env bash
    set -euo pipefail

    DAYS="{{days}}"
    echo "🧹 Cleaning Godot test logs older than $DAYS days..."

    FILES_DELETED=0

    # Clean all platform logs from app userdata directory
    GODOT_LOG_DIR="$HOME/Library/Application Support/Godot/app_userdata/{{GAME_NAME}}/logs"
    if [[ -d "$GODOT_LOG_DIR" ]]; then
        echo "📱 Cleaning iOS logs..."
        IOS_FILES_DELETED=$(find "$GODOT_LOG_DIR" -name "ios_*.log" -mtime +${DAYS} -print -delete 2>/dev/null | wc -l)
        FILES_DELETED=$((FILES_DELETED + IOS_FILES_DELETED))

        if [[ $IOS_FILES_DELETED -gt 0 ]]; then
            echo "  🗑️  Deleted $IOS_FILES_DELETED iOS log files"
        else
            echo "  ℹ️  No old iOS logs to clean"
        fi

        echo "🤖 Cleaning Android logs..."
        ANDROID_FILES_DELETED=$(find "$GODOT_LOG_DIR" -name "android_*.log" -mtime +${DAYS} -print -delete 2>/dev/null | wc -l)
        FILES_DELETED=$((FILES_DELETED + ANDROID_FILES_DELETED))

        if [[ $ANDROID_FILES_DELETED -gt 0 ]]; then
            echo "  🗑️  Deleted $ANDROID_FILES_DELETED Android log files"
        else
            echo "  ℹ️  No old Android logs to clean"
        fi

        echo "🖥️  Cleaning Desktop logs..."
        DESKTOP_FILES_DELETED=$(find "$GODOT_LOG_DIR" -name "desktop_*.log" -mtime +${DAYS} -print -delete 2>/dev/null | wc -l)
        FILES_DELETED=$((FILES_DELETED + DESKTOP_FILES_DELETED))

        if [[ $DESKTOP_FILES_DELETED -gt 0 ]]; then
            echo "  🗑️  Deleted $DESKTOP_FILES_DELETED Desktop log files"
        else
            echo "  ℹ️  No old Desktop logs to clean"
        fi

        echo "📊 Cleaning test action results..."
        ACTION_FILES_DELETED=$(find "$GODOT_LOG_DIR" -name "test_action_results_*.json" -mtime +${DAYS} -print -delete 2>/dev/null | wc -l)
        FILES_DELETED=$((FILES_DELETED + ACTION_FILES_DELETED))

        if [[ $ACTION_FILES_DELETED -gt 0 ]]; then
            echo "  🗑️  Deleted $ACTION_FILES_DELETED test action result files"
        else
            echo "  ℹ️  No old test action results to clean"
        fi
    else
        echo "ℹ️  Godot log directory not found: $GODOT_LOG_DIR"
    fi

    # Clean temporary Godot logs from /tmp
    echo "🗂️  Cleaning temporary Godot logs..."
    TMP_FILES_DELETED=$(find /tmp -name "*ios*.log" -o -name "*android*.log" -o -name "*desktop*.log" -mtime +${DAYS} -print -delete 2>/dev/null | wc -l)
    TMP_JSON_DELETED=$(find /tmp -name "test_action_results_*.json" -mtime +${DAYS} -print -delete 2>/dev/null | wc -l)
    TMP_TOTAL=$((TMP_FILES_DELETED + TMP_JSON_DELETED))
    FILES_DELETED=$((FILES_DELETED + TMP_TOTAL))

    if [[ $TMP_TOTAL -gt 0 ]]; then
        echo "  🗑️  Deleted $TMP_TOTAL temporary Godot files"
    else
        echo "  ℹ️  No old temporary Godot files to clean"
    fi

    echo "✅ Godot log cleanup completed - $FILES_DELETED files deleted"

# Clean up all Godot test logs (default behavior)
clean-godot-logs:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🧹 Cleaning all Godot test logs..."

    FILES_DELETED=0

    # Clean all platform logs from app userdata directory
    GODOT_LOG_DIR="$HOME/Library/Application Support/Godot/app_userdata/{{GAME_NAME}}/logs"
    if [[ -d "$GODOT_LOG_DIR" ]]; then
        echo "📱 Removing all iOS logs..."
        IOS_FILES_DELETED=$(find "$GODOT_LOG_DIR" -name "ios_*.log" -print -delete 2>/dev/null | wc -l)
        FILES_DELETED=$((FILES_DELETED + IOS_FILES_DELETED))

        echo "🤖 Removing all Android logs..."
        ANDROID_FILES_DELETED=$(find "$GODOT_LOG_DIR" -name "android_*.log" -print -delete 2>/dev/null | wc -l)
        FILES_DELETED=$((FILES_DELETED + ANDROID_FILES_DELETED))

        echo "🖥️  Removing all Desktop logs..."
        DESKTOP_FILES_DELETED=$(find "$GODOT_LOG_DIR" -name "desktop_*.log" -print -delete 2>/dev/null | wc -l)
        FILES_DELETED=$((FILES_DELETED + DESKTOP_FILES_DELETED))

        echo "📊 Removing all test action results..."
        ACTION_FILES_DELETED=$(find "$GODOT_LOG_DIR" -name "test_action_results_*.json" -print -delete 2>/dev/null | wc -l)
        FILES_DELETED=$((FILES_DELETED + ACTION_FILES_DELETED))

        PLATFORM_TOTAL=$((IOS_FILES_DELETED + ANDROID_FILES_DELETED + DESKTOP_FILES_DELETED + ACTION_FILES_DELETED))
        echo "  🗑️  Deleted $PLATFORM_TOTAL Godot log files from app directory"
    else
        echo "ℹ️  Godot log directory not found: $GODOT_LOG_DIR"
    fi

    # Clean all temporary Godot logs
    echo "🗂️  Removing all temporary Godot logs..."
    TMP_FILES_DELETED=$(find /tmp -name "*ios*.log" -o -name "*android*.log" -o -name "*desktop*.log" -print -delete 2>/dev/null | wc -l)
    TMP_JSON_DELETED=$(find /tmp -name "test_action_results_*.json" -print -delete 2>/dev/null | wc -l)
    TMP_TOTAL=$((TMP_FILES_DELETED + TMP_JSON_DELETED))
    FILES_DELETED=$((FILES_DELETED + TMP_TOTAL))

    if [[ $TMP_TOTAL -gt 0 ]]; then
        echo "  🗑️  Deleted $TMP_TOTAL temporary Godot files"
    else
        echo "  ℹ️  No temporary Godot files found"
    fi

    echo "✅ Godot log cleanup completed - $FILES_DELETED files deleted"

# Clean all logs (Godot + main logs directory)
clean-all-logs days="7":
    #!/usr/bin/env bash
    set -euo pipefail

    DAYS="{{days}}"
    echo "🧹 Cleaning all logs older than $DAYS days..."

    # Clean all Godot platform logs
    echo "🎮 Cleaning all Godot platform logs..."
    just clean-godot-logs-by-age {{days}}

    # Clean main logs directory
    echo "📁 Cleaning main logs directory..."
    if [[ -d "logs" ]]; then
        find logs -name "*.log" -mtime +${DAYS} -delete -print 2>/dev/null || echo "  No old main logs to clean"
    fi

    echo "✅ All log cleanup completed"

# iOS test execution function - uses configured device identifier from IOS_TEST_DEVICE variable
_execute-test-ios config_name test_id="":
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG_NAME="{{config_name}}"
    TEST_ID="{{test_id}}"
    IOS_DEVICE_ID="{{IOS_TEST_DEVICE}}"

    # Determine device type based on device ID
    if [[ "$IOS_DEVICE_ID" == "{{IOS_IPHONE_DEVICE_ID}}" ]]; then
        IOS_DEVICE_TYPE="iphone"
        DEVICE_NAME="iPhone"
    elif [[ "$IOS_DEVICE_ID" == "{{IOS_IPAD_DEVICE_ID}}" ]]; then
        IOS_DEVICE_TYPE="ipad"
        DEVICE_NAME="iPad"
    else
        echo "❌ Invalid IOS_TEST_DEVICE identifier: $IOS_DEVICE_ID"
        echo "💡 Valid options:"
        echo "   • iPhone: {{IOS_IPHONE_DEVICE_ID}}"
        echo "   • iPad: {{IOS_IPAD_DEVICE_ID}}"
        echo "💡 Configure in core config or environment"
        exit 1
    fi

    echo "🍎 Executing iOS test: $CONFIG_NAME on $DEVICE_NAME ($IOS_DEVICE_ID)"

    # Clear app data for fresh test (Task-301)
    echo "🧹 Clearing iOS app data for fresh test state..."
    if ! just _clean-ios-data; then
        echo "⚠️  Warning: Failed to clear iOS app data, proceeding with existing state"
    fi

    # Install app (PCK already updated by test list setup)
    echo "📦 Installing app on $DEVICE_NAME..."

    # Determine build path
    BUILD_PATH="Debug-iphoneos"
    APP_PATH="export/ios/build/products/${BUILD_PATH}/{{GAME_NAME}}.app"

    # Install app (creates fresh Documents/ directory)
    xcrun devicectl device install app --device "$IOS_DEVICE_ID" "$APP_PATH"
    echo "✅ App installed successfully"

    # NOW push the config (Documents/ exists and is empty)
    TEMP_CONFIG_PATH="tests/debug_configs/${CONFIG_NAME}_ios_automated.json"
    if [[ -f "$TEMP_CONFIG_PATH" ]]; then
        echo "📱 Pushing config to fresh app installation..."
        just _push-file-ios "$IOS_DEVICE_ID" "$TEMP_CONFIG_PATH" "debug_startup_actions.json"
    fi

    # Clear any existing logs to prevent rotation delays during test
    # Large log files (5MB+) cause iOS to lock the logs directory during rotation,
    # leading to devicectl copy timeouts. Since app was just reinstalled, old logs
    # may still exist from previous installations.
    echo "🧹 Clearing old logs to prevent rotation delays..."

    # Create a temporary empty directory
    TEMP_EMPTY_DIR=$(mktemp -d)

    # Copy empty directory over the logs directory (effectively deletes all files)
    # This works even if Documents/logs/ doesn't exist yet
    xcrun devicectl device copy to \
        --device "$IOS_DEVICE_ID" \
        --source "$TEMP_EMPTY_DIR" \
        --destination "Documents/logs" \
        --domain-type appDataContainer \
        --domain-identifier "{{IOS_BUNDLE_IDENTIFIER}}" 2>/dev/null || true

    # Clean up temp directory
    rm -rf "$TEMP_EMPTY_DIR"
    echo "✅ Old logs cleared"

    # Record test start time BEFORE launching app (Task-320: Log rotation TEST_ID mismatch fix)
    # This timestamp is used to filter logs created DURING this test execution
    TEST_START_TIME=$(date +%s)

    # Launch the app
    echo "🚀 Launching app on $DEVICE_NAME..."
    xcrun devicectl device process launch --device "$IOS_DEVICE_ID" --activate "{{IOS_BUNDLE_IDENTIFIER}}"

    # Give app time to actually start before we check if it's running
    echo "⏳ Waiting for app to start..."
    sleep 5

    # Wait for app to actually quit before pulling logs
    echo "⏳ Waiting for app to quit..."
    MAX_WAIT=60
    ELAPSED=0

    while [ $ELAPSED -lt $MAX_WAIT ]; do
        # Check if app is still running by checking process list
        # Task-322: Search for .app path in executable list for reliable detection
        if xcrun devicectl device info processes \
            --device "$IOS_DEVICE_ID" \
            2>/dev/null | grep -q "{{GAME_NAME}}.app"; then
            echo "   App still running... ($ELAPSED/$MAX_WAIT seconds)"
            sleep 2
            ELAPSED=$((ELAPSED + 2))
        else
            echo "✅ App has quit after $((ELAPSED + 5)) seconds (including startup time)"
            break
        fi
    done

    if [ $ELAPSED -ge $MAX_WAIT ]; then
        echo "⚠️  Warning: App did not quit within $MAX_WAIT seconds"
    fi

    # Pull Godot logs directory from iOS device with retry logic
    # Note: Log rotation can take 20-30 seconds for large log files (5MB+)
    # Retry with exponential backoff to handle log rotation delays
    echo "📥 Pulling Godot logs from iOS device..."
    IOS_LOG_DIR="/tmp/ios_logs_$$"
    mkdir -p "$IOS_LOG_DIR"

    MAX_ATTEMPTS=5
    RETRY_SUCCESS=false

    for attempt in $(seq 1 $MAX_ATTEMPTS); do
        if [ $attempt -eq 1 ]; then
            # First attempt: short wait (most tests complete quickly)
            echo "⏳ Waiting for logs to flush..."
            sleep 3
        fi

        echo "   📥 Attempt $attempt/$MAX_ATTEMPTS..."

        # Pull entire logs directory to get timestamped files
        # Use timeout to prevent hanging on log rotation (max 30s per attempt)
        TIMEOUT_DURATION=30
        if timeout $TIMEOUT_DURATION xcrun devicectl device copy from \
            --device "$IOS_DEVICE_ID" \
            --source "Documents/logs/" \
            --destination "$IOS_LOG_DIR" \
            --domain-type appDataContainer \
            --domain-identifier "{{IOS_BUNDLE_IDENTIFIER}}" \
            --quiet; then
            echo "✅ iOS logs directory retrieved successfully"
            RETRY_SUCCESS=true
            break
        else
            COPY_EXIT_CODE=$?
            if [ $COPY_EXIT_CODE -eq 124 ]; then
                echo "   ⏱️  Timeout after ${TIMEOUT_DURATION}s (log rotation in progress)"
            else
                echo "   ❌ Copy failed with exit code $COPY_EXIT_CODE"
            fi

            if [ $attempt -lt $MAX_ATTEMPTS ]; then
                WAIT_TIME=$((3 * attempt))
                echo "   ⚠️  Retry in ${WAIT_TIME}s (logs may still be rotating)..."
                sleep $WAIT_TIME
            fi
        fi
    done

    if [ "$RETRY_SUCCESS" = false ]; then
        echo "❌ Failed to retrieve iOS logs directory after $MAX_ATTEMPTS attempts"
        echo "💡 This may indicate log rotation is taking longer than expected"
        exit 1
    fi

    # Task-320: Timestamp-based log search with TEST_ID validation
    # Filters logs by test execution time window to prevent stale log retrieval
    echo "🔍 Searching for log file containing current TEST_ID..."
    echo "🔍 Required TEST_ID: $TEST_ID"
    echo "🔍 Test started at: $TEST_START_TIME ($(date -r $TEST_START_TIME))"

    # Find logs modified AFTER test start (macOS date format)
    # Note: || true prevents exit-on-error when no files match
    CANDIDATE_LOGS=$(find "$IOS_LOG_DIR" -name "godot*.log" -type f -newermt "@$TEST_START_TIME" 2>/dev/null || true)

    if [[ -n "$CANDIDATE_LOGS" ]]; then
        # Search recent logs for TEST_ID
        LATEST_LOG=$(echo "$CANDIDATE_LOGS" | xargs grep -l "$TEST_ID" 2>/dev/null | head -1)

        if [[ -n "$LATEST_LOG" ]]; then
            echo "✅ Found log file created during test: $(basename "$LATEST_LOG")"
        else
            echo "⚠️  Recent logs found but no TEST_ID match"
            echo "📋 Candidate logs:"
            echo "$CANDIDATE_LOGS" | while read log; do
                echo "   - $(basename "$log") ($(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$log"))"
            done
        fi
    else
        echo "⚠️  No logs modified after test start time"
        echo "💡 Falling back to most recent log file"

        # Fallback: Find most recently modified log with TEST_ID
        # Note: || true prevents exit-on-error when no files match
        LATEST_LOG=$(find "$IOS_LOG_DIR" -name "godot*.log" -type f -exec stat -f "%m %N" {} \; 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2- | xargs -r grep -l "$TEST_ID" 2>/dev/null | head -1 || true)
    fi

    if [[ -z "$LATEST_LOG" ]]; then
        echo ""
        echo "❌ EXPLICIT FAILURE: No log file found containing TEST_ID: $TEST_ID"
        echo ""
        echo "📋 Available log files in retrieved directory:"
        ls -lh "$IOS_LOG_DIR"/*.log 2>/dev/null || echo "   (no log files found)"
        echo ""
        echo "🔍 Diagnostic Information:"
        echo "   - Expected TEST_ID: $TEST_ID"
        echo "   - Config name: $CONFIG_NAME"
        echo "   - Test start time: $(date -r $TEST_START_TIME)"
        echo "   - Retrieved logs directory: $IOS_LOG_DIR"
        echo ""
        echo "💡 Common causes:"
        echo "   1. App crashed before writing TEST_ID to logs"
        echo "   2. Config file not pushed/loaded correctly"
        echo "   3. App using stale config from previous run"
        echo "   4. Log rotation timing issue (old logs retrieved)"
        echo ""
        echo "🔧 To debug:"
        echo "   1. Check all logs for TEST_ID: grep -r '$TEST_ID' $IOS_LOG_DIR/"
        echo "   2. Check log timestamps: ls -lhT $IOS_LOG_DIR/godot*.log"
        echo "   3. Search for any test_id mentions: grep -r 'test_id' $IOS_LOG_DIR/"
        echo "   4. Check if config was loaded: grep -r 'debug_startup_actions.json' $IOS_LOG_DIR/"
        echo ""
        exit 1
    fi

    echo "📊 Log file size: $(wc -l < "$LATEST_LOG") lines"

    # Copy to predictable location for extraction
    IOS_LOG_FILE="/tmp/ios_test_${TEST_ID}.log"
    cp "$LATEST_LOG" "$IOS_LOG_FILE"
    echo "📄 Using log file: $(basename $LATEST_LOG)"
    echo "📊 Log file size: $(wc -l < "$IOS_LOG_FILE") lines"

    # Export the log file location for the extraction step
    echo "📁 iOS logs saved to: $IOS_LOG_FILE"
    echo "$IOS_LOG_FILE" > "/tmp/ios_last_log_file.txt"

    echo "✅ iOS test execution completed on $DEVICE_NAME"

# Clear iOS logs directory for fresh test logs
# Deletes Documents/logs/ to ensure we get clean logs for current test
_clear-ios-logs DEVICE_ID:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "   🗑️  Deleting iOS logs directory via devicectl..."

    # Try to remove the logs directory
    # Note: devicectl doesn't have a delete command, so we'll need to use a workaround
    # We can copy an empty directory over it or just let the app recreate it
    TEMP_EMPTY_DIR=$(mktemp -d)

    # Remove logs by overwriting with empty directory
    if xcrun devicectl device copy to \
        --device "{{DEVICE_ID}}" \
        --source "$TEMP_EMPTY_DIR" \
        --destination "Documents/logs_delete_marker" \
        --domain-type appDataContainer \
        --domain-identifier "{{IOS_BUNDLE_IDENTIFIER}}" \
        --quiet 2>/dev/null; then
        echo "   ✅ iOS logs directory clearing marker set"
    fi

    rm -rf "$TEMP_EMPTY_DIR"

    # Note: Godot will recreate the logs directory on next launch

# iOS data clearing equivalent to Android pm clear (Task-301)
# Removes app and reinstalls for fresh state, matching Android behavior
_clean-ios-data:
    #!/usr/bin/env bash
    set -euo pipefail

    # Use IOS_TEST_DEVICE environment variable (set by test-ios-iphone/ipad commands)
    if [[ -z "${IOS_TEST_DEVICE:-}" ]]; then
        echo "❌ IOS_TEST_DEVICE not set. Use test-ios-iphone or test-ios-ipad"
        exit 1
    fi

    echo "🗑️  Clearing iOS app data (uninstall/reinstall) - Task-301 fix..."
    echo "   📱 Device: $IOS_TEST_DEVICE"

    # Check if app is installed and uninstall to clear all data
    echo "   🔍 Checking for existing app installation..."
    if xcrun devicectl list devices --device "$IOS_TEST_DEVICE" 2>/dev/null | grep -q "{{IOS_BUNDLE_IDENTIFIER}}"; then
        echo "   📱 Uninstalling existing app to clear all data..."
        if xcrun devicectl device uninstall application --device "$IOS_TEST_DEVICE" "{{IOS_BUNDLE_IDENTIFIER}}" 2>/dev/null; then
            echo "   ✅ App uninstalled successfully"
        else
            echo "   ⚠️  App uninstall failed (may not be installed)"
        fi
    else
        echo "   💡 App not installed - no data to clear"
    fi

    echo "✅ iOS app data cleared via uninstall"
    echo "💡 App will be freshly installed on next test run"
    echo "🎯 This provides iOS equivalent of Android 'pm clear' behavior"