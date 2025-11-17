# iOS Platform Development Commands
# Complete iOS build, deploy, test, and device management workflow
# Handles iOS-specific development tasks and workflows

# Note: Variables and build functions inherited from imported modules


# Build iOS executable with optimized settings
build-ios-executable force="no":
    #!/usr/bin/env bash
    set -euo pipefail

    if [ "{{force}}" = "yes" ] || [ "{{force}}" = "force=yes" ]; then
        echo "🔥 Force rebuild enabled - rebuilding iOS executable..."
    elif [ -f "export/ios/{{GAME_NAME}}.xcframework/ios-arm64/libgodot.a" ]; then
        echo "✅ iOS executable already built: export/ios/{{GAME_NAME}}.xcframework/ios-arm64/libgodot.a"
        echo "⏭️  Skipping iOS executable rebuild (saves 20+ minutes)"
        echo "   Use 'just build-ios-executable force=yes' to rebuild"
        exit 0
    else
        echo "❌ iOS executable not found, building..."
    fi

    echo "🔨 Building iOS executable..."

    cd {{GODOT_SUBMODULE_PATH}}
    echo "📦 Building iOS template for arm64 (Sentry SDK always included)..."
    scons platform=ios target=template_release arch=arm64 --jobs={{jobs}} production=yes optimize=size

    # Move to export directory - update existing XCFramework
    echo "📁 Moving executable to export directory..."
    cp misc/dist/ios_xcode/libgodot.ios.template_release.xcframework/ios-arm64/libgodot.a ../export/ios/{{GAME_NAME}}.xcframework/ios-arm64/libgodot.a

    echo "✅ iOS executable built successfully and XCFramework updated"

# iOS help information
help-ios:
    #!/usr/bin/env bash
    echo "🍎 iOS Development Commands"
    echo "=========================="
    echo ""
    echo "Build Commands:"
    echo "  just build-ios-executable       # Build iOS executable"
    echo "  just build-ios-app              # Build iOS .app with Xcode"
    echo "  just save-ios-to-app            # Save PCK file to .app"
    echo "  just ios-deploy-config CONFIG   # Deploy test config to app bundle"
    echo "  just ios-test-file-access       # Test iOS file reading mechanism"
    echo "  just export-all-ios             # Export all iOS artifacts (.app bundle)"
    echo "  just ios-build                  # iOS build pipeline"
    echo "  just build-install-ios          # Full iOS rebuild & install (smart rebuild)"
    echo "  just build-all-ios              # Build all iOS components (smart rebuild)"
    echo "  just rebuild-all-ios            # Force rebuild all iOS components"
    echo ""
    echo "Testing Commands:"
    echo "  just test-ios-target CONFIG     # iOS equivalent of test-android-target (NEW!)"
    echo ""
    echo "Export & Deploy:"
    echo "  just ios-export-pck              # Export iOS PCK file"
    echo "  just ios-update-pck              # Update iOS PCK file"
    echo ""
    echo "Device Management:"
    echo "  just ios-launch-help             # iOS launch help"
    echo "  just ios-restart-help            # iOS restart help"
    echo ""
    echo "Device Logging:"
    echo "  just ios-device-logs-iphone      # Monitor live logs from iPhone"
    echo "  just ios-device-logs-ipad        # Monitor live logs from iPad"
    echo "  just ios-recent-logs-iphone      # Recent logs from iPhone (10 min)"
    echo "  just ios-recent-logs-ipad        # Recent logs from iPad (10 min)"
    echo "  just ios-search-logs-iphone \"pattern\"  # Search logs on iPhone"
    echo "  just ios-search-logs-ipad \"pattern\"    # Search logs on iPad"
    echo "  just ios-sentry-logs-iphone      # Sentry-specific logs from iPhone"
    echo "  just ios-sentry-logs-ipad        # Sentry-specific logs from iPad"
    echo "  just ios-config-logs-iphone      # JSON config logs from iPhone"
    echo "  just ios-config-logs-ipad        # JSON config logs from iPad"
    echo ""
    echo "Quick Commands:"
    echo "  just quick-build-ios             # Quick iOS build"

# Export iOS PCK file
ios-export-pck: pre-build
    @echo "📦 Exporting iOS PCK file..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --export-pack "ios" ../export/ios/{{GAME_NAME}}.pck --headless

# Build iOS app with Xcode (creates .app file)
build-ios-app: pre-build
    @echo "🔨 Building iOS app with Xcode..."
    cd export/ios && xcodebuild -workspace {{GAME_NAME}}.xcworkspace \
                                -scheme {{GAME_NAME}} \
                                -configuration Debug \
                                -destination "generic/platform=iOS" \
                                -allowProvisioningUpdates

# Save iOS PCK file directly to app
save-ios-to-app: pre-build
    @echo "💾 Saving iOS PCK file directly to app..."
    ./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --headless --export-pack ios ../export/ios/build/products/Debug-iphoneos/{{GAME_NAME}}.app/{{GAME_NAME}}.pck

# Deploy test config to iOS app bundle (overwrites file in app bundle)
ios-deploy-config config_name:
    #!/usr/bin/env bash
    set -euo pipefail

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
    echo "💡 Next: 'just launch-ios-iphone' or 'just launch-ios-ipad'"

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
ios-build: pre-build
    @echo "🍎 iOS build pipeline..."
    just ios-export-pck

# iOS launch help
ios-launch-help:
    #!/usr/bin/env bash
    echo "🚀 iOS Launch Instructions"
    echo "========================="
    echo ""
    echo "To launch on iOS device/simulator:"
    echo "1. Open Xcode project in export/ios/"
    echo "2. Select target device/simulator"
    echo "3. Build and run (Cmd+R)"
    echo ""
    echo "For command line deployment:"
    echo "- ios-deploy --bundle export/ios/{{GAME_NAME}}.app"

# iOS restart help
ios-restart-help:
    #!/usr/bin/env bash
    echo "🔄 iOS Restart Instructions"
    echo "=========================="
    echo ""
    echo "To restart iOS app:"
    echo "1. Background the app (home button/gesture)"
    echo "2. Open app switcher"
    echo "3. Swipe up on app to close"
    echo "4. Relaunch from home screen"
    echo ""
    echo "For development:"
    echo "- Xcode: Stop and restart debug session"

# Update iOS PCK file
ios-update-pck: pre-build
    @echo "🔄 Updating iOS PCK file..."
    just ios-export-pck
    @echo "✅ iOS PCK updated"

# Full iOS rebuild & install (2-5 min, complete project rebuild)
build-install-ios:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔨 Full iOS rebuild & install..."
    
    # Clean previous builds
    echo "🧹 Cleaning previous builds..."
    rm -rf export/ios/{{GAME_NAME}}.pck
    
    # Smart check for iOS executable
    just build-ios-executable force=no
    
    # Export PCK
    echo "📦 Exporting iOS PCK..."
    just ios-export-pck
    
    echo "✅ iOS build & install complete"
    echo "💡 Open Xcode project in export/ios/ to deploy"

# Build all iOS components
build-all-ios force="no": validate-env
    @echo "🍎 Building all iOS components..."
    just build-ios-executable {{force}}
    just ios-export-pck
    @echo "✅ All iOS builds complete"

# Quick iOS build for development iteration
quick-build-ios:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "⚡ Quick iOS build..."
    
    # Only export PCK for faster iteration
    just ios-export-pck
    
    echo "✅ Quick iOS build complete"
    echo "💡 Use build-ios-executable for full rebuild"

# Force rebuild all iOS components (ignores existing builds)
rebuild-all-ios:
    @echo "🔥 Force rebuilding all iOS components..."
    just build-all-ios force=yes
    @echo "✅ All iOS rebuilds complete"

# Complete iOS pipeline - from source to device deployment
export-all-ios force="no":
    @echo "📦 Exporting all iOS artifacts (.app bundle)..."
    just build-ios-executable {{force}}
    just build-ios-app
    just save-ios-to-app
    @echo "✅ iOS export complete - ready for device deployment"
    @echo "💡 Use 'just launch-ios-iphone' to deploy to iPhone"
    @echo "💡 Use 'just launch-ios-ipad' to deploy to iPad"

# Legacy alias for backward compatibility
build-pipeline-ios: export-all-ios

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
    echo "🎯 Monitoring process: gametwo"
    echo "⏹️  Press Ctrl+C to stop streaming"
    echo ""

    # Use log stream --debug for device console access
    log stream --debug --predicate 'processImagePath contains "gametwo"' --style compact

# Stream live logs from iPhone device
ios-device-logs-iphone:
    just _ios-device-logs-internal "{{IOS_IPHONE_DEVICE_ID}}" "iPhone"

# Stream live logs from iPad device
ios-device-logs-ipad:
    just _ios-device-logs-internal "{{IOS_IPAD_DEVICE_ID}}" "iPad"

# Core recent logs function - takes device ID as argument
_ios-recent-logs-internal device_id device_name:
    #!/usr/bin/env bash
    set -euo pipefail

    DEVICE_ID="{{device_id}}"
    DEVICE_NAME="{{device_name}}"

    echo "🔍 Searching recent logs from ${DEVICE_NAME} device..."
    echo "📱 Device ID: $DEVICE_ID"
    echo "📊 Time range: Last 10 minutes"
    echo "🎯 Monitoring process: gametwo"
    echo ""

    # Use log show for recent device logs
    log show --predicate 'processImagePath contains "gametwo"' --last 10m --style compact

# Search recent logs from iPhone device (last 10 minutes)
ios-recent-logs-iphone:
    just _ios-recent-logs-internal "{{IOS_IPHONE_DEVICE_ID}}" "iPhone"

# Search recent logs from iPad device (last 10 minutes)
ios-recent-logs-ipad:
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
    echo "📊 Time range: Last 15 minutes"
    echo ""

    # Use log show for pattern search in device logs
    log show --predicate "processImagePath contains \"gametwo\" and (category contains \"${PATTERN}\" or message contains \"${PATTERN}\")" --last 15m --style compact

# Search for specific patterns in iPhone device logs
ios-search-logs-iphone pattern:
    just _ios-search-logs-internal "{{pattern}}" "{{IOS_IPHONE_DEVICE_ID}}" "iPhone"

# Search for specific patterns in iPad device logs
ios-search-logs-ipad pattern:
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

    # Use log stream for Sentry-specific monitoring
    log stream --debug --predicate 'processImagePath contains "gametwo" and (message contains "Sentry" or message contains "sentry" or message contains "debug_startup")' --style compact

# Monitor Sentry-related logs specifically from iPhone
ios-sentry-logs-iphone:
    just _ios-sentry-logs-internal "{{IOS_IPHONE_DEVICE_ID}}" "iPhone"

# Monitor Sentry-related logs specifically from iPad
ios-sentry-logs-ipad:
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

    # Use log stream for JSON config monitoring
    log stream --debug --predicate 'processImagePath contains "gametwo" and (message contains "debug_startup_actions" or message contains "config_reader" or message contains "DebugConfigReader" or message contains "DebugStartupCoordinator")' --style compact

# Monitor JSON config reading specifically from iPhone
ios-config-logs-iphone:
    just _ios-config-logs-internal "{{IOS_IPHONE_DEVICE_ID}}" "iPhone"

# Monitor JSON config reading specifically from iPad
ios-config-logs-ipad:
    just _ios-config-logs-internal "{{IOS_IPAD_DEVICE_ID}}" "iPad"

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

    # Extract config name for deployment
    CONFIG_NAME=$(basename "$CONFIG_PATH" .json)

    # Use existing ios-deploy-config recipe (handles file copying to app bundle)
    if ! just ios-deploy-config "$CONFIG_NAME"; then
        echo "❌ Failed to deploy iOS config"
        exit 1
    fi

    echo "✅ iOS config deployed successfully"

# iOS test execution function - integrates with existing hotreload-ios-ipad recipe
_execute-test-ios config_name:
    #!/usr/bin/env bash
    set -euo pipefail

    CONFIG_NAME="{{config_name}}"
    echo "🍎 Executing iOS test: $CONFIG_NAME"

    # Use existing hotreload-ios-ipad recipe (launches app with deployed config)
    if ! just hotreload-ios-ipad; then
        echo "❌ Failed to execute iOS test"
        exit 1
    fi

    echo "✅ iOS test execution completed"